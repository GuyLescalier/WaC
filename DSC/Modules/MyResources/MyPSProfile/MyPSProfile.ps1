param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)


function Get-ProfileBasePath {
    param(
        [ValidateSet('v5', 'v7')]
        [string]$PowerShellVersion
    )

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')

    switch ($PowerShellVersion) {
        'v5' { Join-Path $documentsPath 'WindowsPowerShell' }
        'v7' { Join-Path $documentsPath 'PowerShell' }
    }
}


function Get-TargetPowerShellVersions {
    param(
        [AllowNull()]
        [string]$PowerShellVersion
    )

    if ([string]::IsNullOrWhiteSpace($PowerShellVersion)) {
        return @('v7')
    }

    switch ($PowerShellVersion) {
        'v5' { return @('v5') }
        'v7' { return @('v7') }
        'both' { return @('v5', 'v7') }
        default { throw "Unsupported PowerShell version '$PowerShellVersion'." }
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
        $InputObject,

        [AllowNull()]
        [string]$PowerShellVersion
    )

    if ([string]::IsNullOrWhiteSpace($PowerShellVersion)) {
        $PowerShellVersion = 'v7'
    }

    $basePath = Get-ProfileBasePath -PowerShellVersion $PowerShellVersion

    $fileName = Get-ProfileFileName -MyHost $InputObject.MyHost

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

    foreach ($line in Get-Content -LiteralPath $ProfileFilePath) {
        if ($found) {
            $scriptCall = $line
            break
        }

        if ($line -eq $ExpectedScriptHeader) {
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

    if (-not (Test-Path -Path $ProfileFilePath -PathType Leaf)) {
        New-Item -Path $ProfileFilePath -ItemType File -Force | Out-Null
    }

    $scriptHeader = "# WAC - $Name"
    $scriptCall = ". '$SourceFilePath'"

    Add-Content -Path $ProfileFilePath -Value @($scriptHeader, $scriptCall)
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

    $scriptHeader = "# WAC - $($InputObject.name)"
    $scriptCall = ". '$($InputObject.sourceFilePath)'"

    $powerShellVersion = if (
        [string]::IsNullOrWhiteSpace($InputObject.PowerShellVersion)
    ) {
        'v7'
    }
    else {
        $InputObject.PowerShellVersion
    }

    $targetVersions = Get-TargetPowerShellVersions `
        -PowerShellVersion $powerShellVersion

    $profiles = @(
        foreach ($version in $targetVersions) {
            $profileFilePath = Get-ProfileFilePath `
                -InputObject $InputObject `
                -PowerShellVersion $version

            $scriptInProfile = IsScriptInProfile `
                -ProfileFilePath $profileFilePath `
                -ExpectedScriptHeader $scriptHeader `
                -ExpectedScriptCall $scriptCall

            @{
                PowerShellVersion = $version
                profileFilePath   = $profileFilePath
                ensure            = if ($scriptInProfile) { 'Present' } else { 'Absent' }
            }
        }
    )

    $allProfilesPresent = @(
        $profiles | Where-Object { $_.ensure -eq 'Present' }
    ).Count -eq $profiles.Count

    $state = @{
        name              = $InputObject.name
        ensure            = if ($allProfilesPresent) { 'Present' } else { 'Absent' }
        PowerShellVersion = $powerShellVersion
        MyHost            = $InputObject.MyHost
        sourceFilePath    = $InputObject.sourceFilePath
        profileFilePath   = if ($profiles.Count -eq 1) {
            $profiles[0].profileFilePath
        }
        else {
            @($profiles.profileFilePath)
        }
        profiles          = $profiles
    }

    return $state
}


function Test-ResourceState {
    param($InputObject)

    $currentState = Get-ResourceState `
        -InputObject $InputObject

    $desiredEnsure = $InputObject.ensure

    $profilesInDesiredState = @(
        $currentState.profiles |
        Where-Object { $_.ensure -eq $desiredEnsure }
    ).Count

    $currentState._inDesiredState = (
        $profilesInDesiredState -eq @($currentState.profiles).Count
    )

    return $currentState
}


function Set-ResourceState {
    param($InputObject)

    $testResult = Test-ResourceState -InputObject $InputObject

    if ($testResult._inDesiredState) {
        return
    }

    $desiredEnsure = $InputObject.ensure

    foreach ($profile in @($testResult.profiles)) {
        if ($profile.ensure -eq $desiredEnsure) {
            continue
        }

        if ($desiredEnsure -eq 'Present') {
            Install-PSProfile -ProfileFilePath $profile.profileFilePath -Name $InputObject.name -SourceFilePath $InputObject.sourceFilePath
        }
        else {
            Uninstall-PSProfile -ProfileFilePath $profile.profileFilePath -Name $InputObject.name -SourceFilePath $InputObject.sourceFilePath
        }
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