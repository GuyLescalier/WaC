param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)


function Test-ChocolateyInstalled {
    return $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
}

#region DSC Operations

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
    
    $desiredEnsure = if ($InputObject.ensure) { $InputObject.ensure } else { 'Present' }
    
    try {
        $currentState = Get-ResourceState -InputObject $InputObject
        
        # Ne faire des changements que si nécessaire
        if ($currentState.ensure -ne $desiredEnsure) {
            if ($desiredEnsure -eq 'Present') {
                # Installer Chocolatey
                if (-not (Test-ChocolateyInstalled)) {
                    try {
                        # Configuration de la sécurité
                        Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
                        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                        
                        # Télécharger et exécuter le script d'installation
                        $installScript = Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing -ErrorAction Stop
                        
                        # Exécuter dans un bloc try-catch séparé
                        try {
                            Invoke-Expression $installScript
                        }
                        catch {
                            # L'installation peut générer des warnings, mais réussir quand même
                            # Vérifier si Chocolatey est maintenant installé
                            if (-not (Test-ChocolateyInstalled)) {
                                throw "Installation failed: $_"
                            }
                        }
                        
                        # Rafraîchir PATH
                        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + 
                        [System.Environment]::GetEnvironmentVariable('Path', 'User')
                    }
                    catch {
                        # Retourner l'état avec l'erreur mais ne pas exit 1
                        $errorState = Get-ResourceState -InputObject $InputObject
                        $errorState.error = "Installation failed: $($_.Exception.Message)"
                        return $errorState
                    }
                }
            }
            elseif ($desiredEnsure -eq 'Absent') {
                # Désinstaller Chocolatey
                if (Test-ChocolateyInstalled) {
                    try {
                        $chocoPath = "$env:ProgramData\chocolatey"
                        
                        # Supprimer le répertoire Chocolatey
                        if (Test-Path $chocoPath) {
                            Remove-Item -Path $chocoPath -Recurse -Force -ErrorAction Stop
                        }
                        
                        # Nettoyer les variables d'environnement
                        $envVars = @('ChocolateyInstall', 'ChocolateyToolsLocation', 'ChocolateyLastPathUpdate')
                        $scopes = @([System.EnvironmentVariableTarget]::Machine, [System.EnvironmentVariableTarget]::User)
                        
                        foreach ($envVar in $envVars) {
                            foreach ($scope in $scopes) {
                                try {
                                    $value = [System.Environment]::GetEnvironmentVariable($envVar, $scope)
                                    if ($value) {
                                        [System.Environment]::SetEnvironmentVariable($envVar, $null, $scope)
                                    }
                                }
                                catch {
                                    # Continuer même si une variable ne peut pas être supprimée
                                }
                            }
                        }
                        
                        # Nettoyer PATH
                        foreach ($scope in $scopes) {
                            try {
                                $path = [System.Environment]::GetEnvironmentVariable('Path', $scope)
                                if ($path) {
                                    $newPath = ($path -split ';' | Where-Object { $_ -notlike '*chocolatey*' }) -join ';'
                                    [System.Environment]::SetEnvironmentVariable('Path', $newPath, $scope)
                                }
                            }
                            catch {
                                # Continuer même si PATH ne peut pas être modifié
                            }
                        }
                    }
                    catch {
                        # Retourner l'état avec l'erreur mais ne pas exit 1
                        $errorState = Get-ResourceState -InputObject $InputObject
                        $errorState.error = "Uninstallation failed: $($_.Exception.Message)"
                        return $errorState
                    }
                }
            }
        }
        
        # Retourner le nouvel état
        return Get-ResourceState -InputObject $InputObject
    }
    catch {
        # En cas d'erreur générale, retourner un état avec l'erreur
        $errorState = Get-ResourceState -InputObject $InputObject
        $errorState.error = $_.Exception.Message
        return $errorState
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