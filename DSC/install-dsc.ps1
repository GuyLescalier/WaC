<#
.SYNOPSIS 
    Installe ou met à jour Microsoft Desired State Configuration v3.x.

.DESCRIPTION
    Utilise winget (Microsoft Store) pour déployer PowerShell 7.5 et DSC.
    Nécessite un shell en tant qu'administrateur.
    Lance automatiquement PowerShell 7 en administrateur à la fin.
#>
#Requires -RunAsAdministrator

# ---------- 0. Pré-requis winget ----------
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
Write-Host '│  Étape 1/5 : Installation de PowerShell 7.5             │' -ForegroundColor Cyan
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
Write-Host '│  Étape 2/5 : Recherche du package DSC                   │' -ForegroundColor Cyan
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
Write-Host '│  Étape 3/5 : Installation de DSC v3.x                   │' -ForegroundColor Cyan
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

# ---------- 4. Ajout du dossier "Modules" au PSModulePath ----------
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 4/5 : Configuration du PSModulePath              │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$localModuleDir = Join-Path $scriptDir 'Modules'

if (Test-Path $localModuleDir)
{
    foreach ($scope in 'Process', 'Machine')
    {
        $current = [Environment]::GetEnvironmentVariable('PSModulePath', $scope)
        if (-not $current)
        {
            $current = '' 
        }

        if (($current -split ';') -notcontains $localModuleDir)
        {
            $newValue = if ($current.Trim())
            {
                "$current;$localModuleDir" 
            }
            else
            {
                $localModuleDir 
            }
            [Environment]::SetEnvironmentVariable('PSModulePath', $newValue, $scope)
            Write-Host "  ✓ Ajout de $localModuleDir à PSModulePath ($scope)" -ForegroundColor Green
        }
        else
        {
            Write-Host "  ℹ $localModuleDir déjà dans PSModulePath ($scope)" -ForegroundColor Gray
        }
    }
}
else
{
    Write-Host "  ⚠ Le dossier de modules local n'existe pas : $localModuleDir" -ForegroundColor Yellow
}

# ---------- 5. Copie du dossier "resources" vers C:\WaC\resources ----------
Write-Host "`n┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host '│  Étape 5/5 : Copie des ressources                       │' -ForegroundColor Cyan
Write-Host '└─────────────────────────────────────────────────────────┘' -ForegroundColor Cyan

$localResourcesDir = Join-Path $scriptDir 'resources'
$targetResourcesDir = 'C:\WaC\resources'

if (Test-Path $localResourcesDir)
{
    if (-not (Test-Path $targetResourcesDir))
    {
        New-Item -ItemType Directory -Path $targetResourcesDir -Force | Out-Null
        Write-Host "  ✓ Création du dossier cible : $targetResourcesDir" -ForegroundColor Green
    }

    Copy-Item -Path $localResourcesDir\* -Destination $targetResourcesDir -Recurse -Force
    Write-Host "  ✓ Dossier 'resources' copié vers $targetResourcesDir" -ForegroundColor Green
}
else
{
    Write-Host "  ⚠ Le dossier 'resources' n'existe pas dans : $localResourcesDir" -ForegroundColor Yellow
}

# ---------- 6. Résumé final ----------
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host '║              Installation terminée avec succès             ║' -ForegroundColor Green
Write-Host '╚════════════════════════════════════════════════════════════╝' -ForegroundColor Green

Write-Host "`n  Composants installés :" -ForegroundColor White
Write-Host '    • PowerShell 7.5 : ' -NoNewline -ForegroundColor White
if (Get-Command pwsh -ErrorAction SilentlyContinue)
{
    Write-Host '✓ Installé' -ForegroundColor Green
}
else
{
    Write-Host '✗ Non détecté' -ForegroundColor Red
}

Write-Host '    • DSC v3.x       : ' -NoNewline -ForegroundColor White
if (Get-Command dsc -ErrorAction SilentlyContinue)
{
    Write-Host '✓ Installé' -ForegroundColor Green
}
else
{
    Write-Host '✗ Non détecté' -ForegroundColor Red
}

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