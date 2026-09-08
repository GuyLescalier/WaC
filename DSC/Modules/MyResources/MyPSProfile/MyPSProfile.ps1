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
        [Parameter(Mandatory)]
        [string]$MyHost
    )

    switch ($MyHost) {
        'AllHosts' {
            return 'profile.ps1'
        }

        'ConsoleHost' {
            return 'Microsoft.PowerShell_profile.ps1'
        }

        'VisualStudioCode' {
            return 'Microsoft.VSCode_profile.ps1'
        }

        default {
            return 'profile.ps1'
        }
    }
}


function Get-ProfileFilePath {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    # Explicit path has priority
    if ($InputObject.profileFilePath) {
        return $InputObject.profileFilePath
    }

    $basePath = Get-ProfileBasePath `
        -PowerShellVersion $InputObject.PowerShellVersion

    $fileName = Get-ProfileFileName `
        -MyHost $InputObject.host

    return Join-Path $basePath $fileName
}


function Test-ProfileExists {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileFilePath
    )

    return Test-Path -Path $ProfileFilePath -PathType Leaf
}


function Install-PSProfile {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileFilePath
    )

    $profileDirectory = Split-Path -Path $ProfileFilePath -Parent

    if (-not (Test-Path -Path $profileDirectory)) {
        New-Item `
            -Path $profileDirectory `
            -ItemType Directory `
            -Force | Out-Null
    }

    if (-not (Test-Path -Path $ProfileFilePath)) {
        New-Item `
            -Path $ProfileFilePath `
            -ItemType File `
            -Force | Out-Null
    }
}


function Uninstall-PSProfile {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileFilePath
    )

    if (Test-Path -Path $ProfileFilePath -PathType Leaf) {
        Remove-Item `
            -Path $ProfileFilePath `
            -Force
    }
}


function Get-ResourceState {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    $profileFilePath = Get-ProfileFilePath -InputObject $InputObject
    $profileExists = Test-ProfileExists -ProfileFilePath $profileFilePath

    $state = @{
        name              = $InputObject.name
        ensure            = if ($profileExists) { 'Present' } else { 'Absent' }
        PowerShellVersion = $InputObject.PowerShellVersion
        host              = $InputObject.host
        profileFilePath   = $profileFilePath
    }

    return $state
}


function Test-ResourceState {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    $currentState = Get-ResourceState -InputObject $InputObject
    $desiredEnsure = $InputObject.ensure

    $currentState._inDesiredState = (
        $currentState.ensure -eq $desiredEnsure
    )

    return $currentState
}


function Set-ResourceState {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    $testResult = Test-ResourceState -InputObject $InputObject

    if ($testResult._inDesiredState) {
        return
    }

    if ($InputObject.ensure -eq 'Present') {
        Install-PSProfile `
            -ProfileFilePath $testResult.profileFilePath
    }
    else {
        Uninstall-PSProfile `
            -ProfileFilePath $testResult.profileFilePath
    }
}


try {
    $inputJson = [Console]::In.ReadToEnd()
    $inputObject = $inputJson | ConvertFrom-Json

    $result = switch ($Operation) {
        'Get' {
            Get-ResourceState -InputObject $inputObject
        }

        'Test' {
            Test-ResourceState -InputObject $inputObject
        }

        'Set' {
            Set-ResourceState -InputObject $inputObject
        }
    }

    if ($null -ne $result) {
        $jsonOutput = $result | ConvertTo-Json -Compress -Depth 10
        Write-Output $jsonOutput
    }

    exit 0
}
catch {
    $errorJson = @{
        message   = $_.Exception.Message
        operation = $Operation
        level     = 'error'
    } | ConvertTo-Json -Compress

    Write-Error $errorJson
    exit 1
}