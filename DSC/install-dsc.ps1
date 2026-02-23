<#
.SYNOPSIS
    Installe ou met à jour Microsoft Desired State Configuration v3.x.

.DESCRIPTION
    Utilise winget (Microsoft Store) pour déployer PowerShell 7.5 et DSC.
    Nécessite un shell en tant qu'administrateur.
    Lance automatiquement PowerShell 7 en administrateur à la fin.
#>
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryPath = (Join-Path $PSScriptRoot "DSC\resources"),    

    [Parameter()]
    [string]$RepositoryName = "WaCLocalRepo"
)


# ---------- Pré-requis ----------
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
Set-PSRepository PSGallery -InstallationPolicy Trusted

Install-Module powershell-yaml
Install-Module PSDscResources -Repository PSGallery
Install-Module PSDesiredStateConfiguration -Repository PSGallery
Install-Module Microsoft.WinGet.DSC
Install-Module Microsoft.VisualStudio.DSC


Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host '║        Installation DSC v3 & PowerShell 7.5                ║' -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if (-not (Get-Command winget -ErrorAction SilentlyContinue))
{
    Write-Host '✗ ' -ForegroundColor Red -NoNewline
    Write-Error "Winget/App Installer n'est pas disponible. Installez-le d'abord dans le Microsoft Store."
    exit 1
}
Write-Host '✓ Winget détecté' -ForegroundColor Green

# ---------- 1. Installation de PowerShell 7.5 ----------
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 1/7 : Installation de PowerShell 7.5             │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

$ps7Installed = Get-Command pwsh -ErrorAction SilentlyContinue
if ($ps7Installed)
{
    $currentVersion = (pwsh --version).Split()[-1]
    Write-Host "  ℹ PowerShell 7 déjà installé (version $currentVersion)" -ForegroundColor Yellow
}
else
{
    Write-Host '  → PowerShell 7 non détecté. Installation en cours...' -ForegroundColor White
}

winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements --silent

if ($LASTEXITCODE -ne 0)
{
    $acceptableExitCodes = @(
        0           # Success
        -1978335189 # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
    )
    if ($LASTEXITCODE -notin $acceptableExitCodes)
    {
        Write-Host "  ✗ Erreur lors de l'installation de PowerShell 7 (code $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    else
    {
        Write-Host '  ✓ PowerShell 7 est déjà à jour' -ForegroundColor Green
    }
}
else
{
    Write-Host '  ✓ PowerShell 7.5 installé avec succès' -ForegroundColor Green
}

# Vérification de l'installation
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue))
{
    Write-Host "  ⚠ pwsh.exe n'est pas encore dans le PATH" -ForegroundColor Yellow
}
else
{
    $installedVersion = (pwsh --version).Split()[-1]
    Write-Host "  ✓ PowerShell version $installedVersion disponible" -ForegroundColor Green
}

# ---------- 2. Recherche du package DSC ----------
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 2/7 : Recherche du package DSC                   │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

$pkgInfo = (winget search DesiredStateConfiguration --source msstore --exact --accept-source-agreements |
        Where-Object { $_ -match '^DesiredStateConfiguration\s' } |
        Select-Object -First 1).ToString().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)[1]

if (-not $pkgInfo)
{
    Write-Host "  ✗ Impossible de trouver l'ID du package DesiredStateConfiguration" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Package ID détecté : $pkgInfo" -ForegroundColor Green

# ---------- 3. Installation / mise à jour DSC ----------
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 3/7 : Installation de DSC v3.x                   │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

winget install --id $pkgInfo --source msstore --accept-package-agreements --accept-source-agreements --silent

if ($LASTEXITCODE -ne 0)
{
    $acceptableExitCodes = @(
        0           # Success
        -1978335189 # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
    )

    if ($LASTEXITCODE -notin $acceptableExitCodes)
    {
        Write-Host "  ✗ Erreur inattendue lors de l'installation de DSC ($LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    else
    {
        Write-Host "  ✓ DSC est déjà installé ou à jour ($LASTEXITCODE)" -ForegroundColor Green
    }
}
else
{
    Write-Host '  ✓ DSC installé avec succès' -ForegroundColor Green
}

# Validation de l'installation
if (-not (Get-Command dsc -ErrorAction SilentlyContinue))
{
    Write-Host "  ⚠ dsc.exe n'est pas dans le PATH actuel" -ForegroundColor Yellow
}
else
{
    $dscVersion = (dsc --version).Split()[-1]
    Write-Host "  ✓ DSC v$dscVersion est installé" -ForegroundColor Green
}

# ---------- 4 : Enregistrement du repository ----------
# ====================================
# ÉTAPE 1 : ENREGISTREMENT DU REPOSITORY
# ====================================
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 4/7 : Enregistrement du repository               │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

# Utilisation du RepositoryPath dynamique
$existingRepo = Get-PSRepository -Name $RepositoryName -ErrorAction SilentlyContinue

if (-not $existingRepo) 
{
    Write-Host "  Repository '$RepositoryName' non trouvé, enregistrement..." -ForegroundColor Gray
    Register-PSResourceRepository -Name $RepositoryName -SourceLocation $RepositoryPath -InstallationPolicy Trusted
    Write-Host "  ✓ Repository enregistré" -ForegroundColor Green
} 
else 
{
    Write-Host "  ✓ Repository déjà enregistré" -ForegroundColor Green
}

# ---------- Étape 5 : Suppression des anciennes versions de ressources----------
Write-Host "`n┌──────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 5/7 : Suppression des anciennes versions de ressources        │' -ForegroundColor Cyan
Write-Host '└──────────────────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

Write-Host "   Vérification des anciennes versions..." -ForegroundColor Gray

$oldVersions = Get-Module -Name MyResources -ListAvailable

if ($oldVersions) 
{
    foreach ($ver in $oldVersions) 
    {
        Write-Host "   Suppression de la version existante : $($ver.Version) située dans $($ver.ModuleBase)" -ForegroundColor Magenta

        Remove-Item -Path $ver.ModuleBase -Recurse -Force -ErrorAction Stop
        Write-Host "   ✓ Version $($ver.Version) supprimée." -ForegroundColor Green
    }
}


# ---------- Étape 6 : Installation du module MyResources ----------
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 6/7 : Installation du module MyResources         │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

Install-PSResource -Name MyResources -Repository $RepositoryName -TrustRepository -ErrorAction Stop

$installedModule = Get-Module -Name MyResources -ListAvailable | Select-Object -First 1

if (-not $installedModule) {
    Write-Host "  ✗ Erreur : Module MyResources non trouvé après installation" -ForegroundColor Red
    exit 1
}

Write-Host "  Module installé :" -ForegroundColor Gray
Write-Host "    Version : $($installedModule.Version)" -ForegroundColor Gray
Write-Host "    Chemin  : $($installedModule.ModuleBase)" -ForegroundColor Gray


# ---------- Étape 7 : Configuration du PATH ----------
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 7/7 : Configuration du PATH                      │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

$dscResourcePath = Join-Path $installedModule.ModuleBase "resources"

Write-Host " Dossier des ressources identifié : $dscResourcePath" -ForegroundColor Gray

$resourceDirs = Get-ChildItem $dscResourcePath -Directory

$pathList = @(
    $resourceDirs.FullName                                  # Les ressources
    $PSHOME                                                 # PowerShell 7 
    [Environment]::SystemDirectory                          # System32 
    (Get-Module Microsoft.WinGet.DSC -ListAvailable).ModuleBase # WinGet
    $env:Path.Split([IO.Path]::PathSeparator)                     # Les chemins déjà présents dans PATH 
) | Where-Object { $_ } | Select-Object -Unique

# 2. On joint tout avec le séparateur (;)
$finalPath = $pathList -join [IO.Path]::PathSeparator

# 3. On applique la configuration 
[Environment]::SetEnvironmentVariable("PATH", $finalPath, "User")
$env:PATH = $finalPath

Write-Host " ✓ Variable PATH mise à jour." -ForegroundColor Green


# ---------- 7. Ouverture de PowerShell 7 en administrateur ----------
Write-Host "`n  → Lancement de PowerShell 7 en administrateur..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if ($pwshPath)
{
    Start-Process -FilePath $pwshPath -Verb RunAs
    Write-Host '  ✓ PowerShell 7 lancé avec succès' -ForegroundColor Green
}
else
{
    Write-Host '  ✗ Impossible de localiser pwsh.exe' -ForegroundColor Red
    Write-Host '  → Veuillez ouvrir manuellement PowerShell 7 en administrateur' -ForegroundColor Yellow
}

Write-Host "`n  Appuyez sur une touche pour fermer cette fenêtre..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')