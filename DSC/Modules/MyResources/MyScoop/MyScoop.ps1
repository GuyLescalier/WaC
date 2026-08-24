# This resource require administrator privileges.

param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)

function Test-ScoopInstalled {
    return $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
}

function Install-Scoop {
    # Install Scoop
    try {
        $installerPath = Join-Path $env:TEMP "scoop-install-$(New-Guid).ps1"

        Invoke-RestMethod -Uri 'https://get.scoop.sh' -OutFile $installerPath

        & $installerPath
    }
    finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Uninstall-Scoop {
    # Revisit this once one these issues are resolved:
    # https://github.com/ScoopInstaller/Scoop/issues/5734
    # https://github.com/ScoopInstaller/Scoop/issues/6447
        
    $installedPackages = scoop list 6>$null
    if ($installedPackages.Count -gt 0) {
        throw "failed to uninstall scoop, all installed resources via scoop must be removed before uninstalling scoop itself."
    }
    echo y | powershell -ExecutionPolicy Bypass -Command "scoop uninstall scoop"
}

function Get-ResourceState {
    param($InputObject)

    $isInstalled = Test-ScoopInstalled

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

    if (! (Test-ScoopInstalled)) {
        Install-Scoop
    }

    else {
        Uninstall-Scoop
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