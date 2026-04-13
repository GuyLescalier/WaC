# This resource require administrator privileges.

param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)

function Test-ScoopInstalled {
    return $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
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

    if (! (Test-ScoopInstalled)) {
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
    else {
        #scoop uninstall scoop --purge
        Remove-Item -Recurse -Force ~\scoop
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