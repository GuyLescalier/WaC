param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)


function Test-ChocolateyInstalled {
    return $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
}

function Get-ChocolateyInstallPath() {
    $scopes = @([System.EnvironmentVariableTarget]::Machine, [System.EnvironmentVariableTarget]::User)
    foreach ($scope in $scopes) {
        $chocoPath = [System.Environment]::GetEnvironmentVariable('ChocolateyInstall', $scope)
        if ($chocoPath) {
            return $chocoPath
        }
    }
    return 'C:\ProgramData\chocolatey'
}

function Install-Chocolatey {
    $script = Invoke-RestMethod -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing
    Invoke-Expression -Command $script
}

function Uninstall-Chocolatey {
    # Uninstall Chocolatey
    $chocoPath = Get-ChocolateyInstallPath
    Remove-Item -Path $chocoPath -Recurse -Force -ErrorAction SilentlyContinue
    
    # Remove environment variables
    $envVars = @('ChocolateyInstall', 'ChocolateyToolsLocation', 'ChocolateyLastPathUpdate')
    $scopes = @([System.EnvironmentVariableTarget]::Machine, [System.EnvironmentVariableTarget]::User)
    foreach ($envVar in $envVars) {
        foreach ($scope in $scopes) {
            if ([System.Environment]::GetEnvironmentVariable($envVar, $scope)) {
                [System.Environment]::SetEnvironmentVariable($envVar, $null, $scope)
            }
        }
    }
}

function Get-ResourceState {
    param($InputObject)
    
    $isInstalled = Test-ChocolateyInstalled
    $state = @{
        name   = $InputObject.name
        ensure = if ($isInstalled) { 'Present' } else { 'Absent' }
    }

    return $state
}

function Test-ResourceState {
    param($InputObject)
    
    $currentState = Get-ResourceState -InputObject $InputObject
    $desiredEnsure = $InputObject.ensure
        
    $inDesiredState = ($currentState.ensure -eq $desiredEnsure)
        
    $currentState._inDesiredState = $inDesiredState
    return $currentState

}

function Set-ResourceState {
    param($InputObject)

    $testResult = Test-ResourceState -InputObject $InputObject

    if ($testResult._inDesiredState) {
        return
    }

    if ($InputObject.ensure -eq 'Present') {
        Install-Chocolatey
    }

    else {
        Uninstall-Chocolatey
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