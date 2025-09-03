<#
.SYNOPSIS
    Installe ou met à jour Microsoft Desired State Configuration v3.x.

.DESCRIPTION
    Utilise winget (Microsoft Store) pour déployer DSC.
    Nécessite un shell en tant qu'administrateur.
#>
#Requires -RunAsAdministrator

# ---------- 0. Pré‑requis winget ----------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "Winget/App Installer n’est pas disponible. Installez-le d’abord dans le Microsoft Store."
    exit 1
}

# ---

## 1. Recherche du package DSC

# Use a more robust way to select the non-preview package ID
$pkgInfo = (winget search DesiredStateConfiguration --source msstore --exact --accept-source-agreements |
            Where-Object { $_ -match '^DesiredStateConfiguration\s' } | # Filter for the exact package name (non-preview)
            Select-Object -First 1).ToString().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)[1]

if (-not $pkgInfo) {
    Write-Error "Impossible de trouver l’ID du package DesiredStateConfiguration dans le Store."
    exit 1
}

Write-Host "Package ID détecté : $pkgInfo"

# ---


## 2. Installation / mise à jour

winget install --id $pkgInfo --source msstore --accept-package-agreements --accept-source-agreements --silent

if ($LASTEXITCODE -ne 0) {
    # Define acceptable exit codes for "already installed" or "no update"
    $acceptableExitCodes = @(
        0           # Success
        -1978335189 # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (No update available / Already installed)
    )

    if ($LASTEXITCODE -notin $acceptableExitCodes) {
        Write-Error "Winget a signalé une erreur inattendue ($LASTEXITCODE) lors de l'installation ou de la mise à jour."
        exit $LASTEXITCODE
    } else {
        Write-Warning "Winget a signalé que le package est déjà installé ou qu'aucune mise à jour n'est disponible ($LASTEXITCODE). Poursuite du script."
    }
}

# ---


## 3. Validation de l'installation

if (-not (Get-Command dsc -ErrorAction SilentlyContinue)) {
    Write-Warning "dsc.exe n’est pas dans le PATH actuel. Ouvrez une nouvelle session PowerShell."
} else {
    Write-Host "DSC v$((dsc --version).Split()[-1]) est installé."
}

# ---


## 4. Ajout du dossier "Modules" au PSModulePath

$scriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path    # répertoire du .ps1
$localModuleDir  = Join-Path $scriptDir 'Modules'

if (Test-Path $localModuleDir) {
    foreach ($scope in 'Process','Machine') { # Process = session courante, Machine = persistant
        $current = [Environment]::GetEnvironmentVariable('PSModulePath', $scope)
        if (-not $current) { $current = '' }

        # On ne l’ajoute que s’il n’est pas déjà présent
        if (($current -split ';') -notcontains $localModuleDir) {
            $newValue = if ($current.Trim()) { "$current;$localModuleDir" } else { $localModuleDir }
            [Environment]::SetEnvironmentVariable('PSModulePath', $newValue, $scope)
            Write-Host "Ajout de $localModuleDir à PSModulePath ($scope)."
        }
    }
} else {
    Write-Warning "Le dossier de modules local n’existe pas : $localModuleDir"
}

Write-Host "`nInstallation terminée. Ouvrez une nouvelle console PowerShell pour prendre en compte la mise à jour de PSModulePath."