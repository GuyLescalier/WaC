param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)


function Test-ChocolateyInstalled {
    return $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
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

    if (! (Test-ChocolateyInstalled)) {
        # Install Chocolatey
        $script = Invoke-RestMethod -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing
        Invoke-Expression -Command $script
    }
    else {
        # Uninstall Chocolatey
        $chocoPath = $this.GetChocolateyInstallPath()
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