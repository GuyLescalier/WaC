<#
.SYNOPSIS
    Installe ou met à jour Microsoft Desired State Configuration v3.x.

.DESCRIPTION
    Utilise winget (Microsoft Store) pour déployer DSC.
    Nécessite un shell en tant qu'administrateur.
#>
#Requires -RunAsAdministrator

# ---------- 0. Pré-requis winget ----------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "Winget/App Installer n’est pas disponible. Installez-le d’abord dans le Microsoft Store."
    exit 1
}

# ---

## 1. Recherche du package DSC

$pkgInfo = (winget search DesiredStateConfiguration --source msstore --exact --accept-source-agreements |
            Where-Object { $_ -match '^DesiredStateConfiguration\s' } |
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
    $acceptableExitCodes = @(
        0           # Success
        -1978335189 # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
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

$scriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$localModuleDir  = Join-Path $scriptDir 'Modules'

if (Test-Path $localModuleDir) {
    foreach ($scope in 'Process','Machine') {
        $current = [Environment]::GetEnvironmentVariable('PSModulePath', $scope)
        if (-not $current) { $current = '' }

        if (($current -split ';') -notcontains $localModuleDir) {
            $newValue = if ($current.Trim()) { "$current;$localModuleDir" } else { $localModuleDir }
            [Environment]::SetEnvironmentVariable('PSModulePath', $newValue, $scope)
            Write-Host "Ajout de $localModuleDir à PSModulePath ($scope)."
        }
    }
} else {
    Write-Warning "Le dossier de modules local n’existe pas : $localModuleDir"
}

# ---

## 5. Copie du dossier "resources" vers C:\WaC\resources

$localResourcesDir = Join-Path $scriptDir 'resources'
$targetResourcesDir = 'C:\WaC\resources'

if (Test-Path $localResourcesDir) {
    if (-not (Test-Path $targetResourcesDir)) {
        New-Item -ItemType Directory -Path $targetResourcesDir -Force | Out-Null
        Write-Host "Création du dossier cible : $targetResourcesDir"
    }

    Copy-Item -Path $localResourcesDir\* -Destination $targetResourcesDir -Recurse -Force
    Write-Host "Dossier 'resources' copié vers $targetResourcesDir"
} else {
    Write-Warning "Le dossier 'resources' n’existe pas dans : $localResourcesDir"
}

Write-Host "`nInstallation terminée. Ouvrez une nouvelle console PowerShell pour prendre en compte la mise à jour de PSModulePath."
