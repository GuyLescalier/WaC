param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)


function Get-ProfileBasePath {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('v5', 'v7')]
        [string]$PowerShellVersion
    )

    switch ($PowerShellVersion) {
        'v5' {
            return Join-Path $HOME 'Documents\WindowsPowerShell'
        }

        'v7' {
            return Join-Path $HOME 'Documents\PowerShell'
        }
    }
}


function Get-ProfileFileName {
    param(
        [AllowNull()]
        [string]$MyHost
    )

    if ($null -eq $MyHost) {
        return 'profile.ps1'
    }

    switch ($MyHost) {
        'AllHosts' {
            return 'profile.ps1'
        }

        default {
            return "$MyHost.ps1"
        }
    }
}


function Get-ProfileFilePath {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    $basePath = Get-ProfileBasePath -PowerShellVersion $InputObject.PowerShellVersion

    $fileName = Get-ProfileFileName -MyHost $InputObject.host

    return Join-Path $basePath $fileName
}


function IsScriptInProfile {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileFilePath,

        [Parameter(Mandatory)]
        [string]$ExpectedScriptHeader,

        [Parameter(Mandatory)]
        [string]$ExpectedScriptCall
    )

    if (-not (Test-Path -Path $ProfileFilePath -PathType Leaf)) {
        return $false
    }

    $found = $false
    $scriptCall = $null

    Get-Content -Path $ProfileFilePath | ForEach-Object {
        if ($found) {
            $scriptCall = $_
            break
        }

        if ($_ -eq $ExpectedScriptHeader) {
            $found = $true
        }
    }

    if (-not $scriptCall) {
        return $false
    }

    return $scriptCall -eq $ExpectedScriptCall
}


function Install-PSProfile {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileFilePath,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$SourceFilePath
    )

    if (-not (Test-Path -Path $SourceFilePath -PathType Leaf)) {
        throw "Source profile script '$SourceFilePath' does not exist."
    }

    $profileDirectory = Split-Path -Path $ProfileFilePath -Parent

    if (-not (Test-Path -Path $ProfileFilePath -PathType Leaf)) {
        New-Item -Path $ProfileFilePath -ItemType File -Force | Out-Null
    }

    $scriptHeader = "# WAC - $Name"
    $scriptCall = ". '$SourceFilePath'"

    Add-Content-Path $ProfileFilePath -Value @($scriptHeader, $scriptCall)
}


function Uninstall-PSProfile {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileFilePath,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$SourceFilePath
    )

    if (-not (Test-Path -Path $ProfileFilePath -PathType Leaf)) {
        return
    }

    $scriptHeader = "# WAC - $Name"
    $scriptCall = ". '$SourceFilePath'"

    $content = Get-Content -Path $ProfileFilePath
    $newContent = @()

    $skipNextLine = $false

    foreach ($line in $content) {
        if ($skipNextLine) {
            if ($line -eq $scriptCall) {
                $skipNextLine = $false
                continue
            }

            $skipNextLine = $false
        }

        if ($line -eq $scriptHeader) {
            $skipNextLine = $true
            continue
        }

        $newContent += $line
    }

    Set-Content -Path $ProfileFilePath -Value $newContent
}


function Get-ResourceState {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    $profileFilePath = Get-ProfileFilePath `
        -InputObject $InputObject

    $scriptHeader = "# WAC - $($InputObject.name)"
    $scriptCall = ". '$($InputObject.sourceFilePath)'"

    $scriptInProfile = IsScriptInProfile `
        -ProfileFilePath $profileFilePath `
        -ExpectedScriptHeader $scriptHeader `
        -ExpectedScriptCall $scriptCall

    $state = @{
        name              = $InputObject.name
        ensure            = if ($scriptInProfile) { 'Present' } else { 'Absent' }
        PowerShellVersion = $InputObject.PowerShellVersion
        host              = $InputObject.host
        sourceFilePath    = $InputObject.sourceFilePath
        profileFilePath   = $profileFilePath
    }

    return $state
}


function Test-ResourceState {
    param($InputObject)

    $currentState = Get-ResourceState `
        -InputObject $InputObject

    $desiredEnsure = $InputObject.ensure

    $currentState._inDesiredState = (
        $currentState.ensure -eq $desiredEnsure
    )

    return $currentState
}


function Set-ResourceState {
    param($InputObject)

    $testResult = Test-ResourceState -InputObject $InputObject

    if ($testResult._inDesiredState) {
        return
    }

    if ($InputObject.ensure -eq 'Present') {
        Install-PSProfile -ProfileFilePath $testResult.profileFilePath -Name $InputObject.name -SourceFilePath $InputObject.sourceFilePath
    }
    else {
        Uninstall-PSProfile -ProfileFilePath $testResult.profileFilePath -Name $InputObject.name -SourceFilePath $InputObject.sourceFilePath
    }
}

try {
    $inputJson = [Console]::In.ReadToEnd()
    $inputObject = $inputJson | ConvertFrom-Json

    $result = switch ($Operation) {
        'Get' { Get-ResourceState -InputObject $inputObject }
        'Test' { Test-ResourceState -InputObject $inputObject }
        'Set' { Set-ResourceState -InputObject $inputObject }
    }

    $jsonOutput = $result | ConvertTo-Json -Compress -Depth 10
    Write-Output $jsonOutput

    exit 0

}
catch {
    $errorJson = @{
        message   = $_.Exception.Message
        operation = $Operation
        level     = "error"
    } | ConvertTo-Json -Compress

    Write-Error $errorJson
    exit 1
}