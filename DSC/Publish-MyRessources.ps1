[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$VersionBump,
    
    [Parameter()]
    [string]$ReleaseNotes,
    
    [Parameter()]
    [string]$ModulePath,
    
    [Parameter()]
    [string]$RepositoryPath
)

# --- Détection des chemins ---
if (-not $ModulePath) {
    $ModulePath = Join-Path $PSScriptRoot "Modules\MyResources"

    Write-Host "This is PS script root : $PSScriptRoot" -ForegroundColor Gray

    Write-Host "ModulePath auto-détecté: $ModulePath" -ForegroundColor Gray
}

if (-not $RepositoryPath) {
    $RepositoryPath = Join-Path $PSScriptRoot "resources\PSRepository"
    Write-Host "RepositoryPath auto-détecté: $RepositoryPath" -ForegroundColor Gray
}

Write-Host "Publication du module MyResources..." -ForegroundColor Cyan

$manifestPath = Join-Path $ModulePath "MyResources.psd1"


# ====================================
# GESTION DE LA VERSION
# ====================================
function Update-Version {
    try {
        $manifest = Import-PowerShellDataFile $manifestPath
        $currentVersion = [version]$manifest.ModuleVersion
    }
    catch {
        Write-Host "✗ Erreur: Impossible de charger le manifeste du module à l'emplacement $manifestPath" -ForegroundColor Red
        exit 1
    }

    if ($VersionBump) {
        Write-Host "`nMise à jour de la version..." -ForegroundColor Yellow
            
        $newVersion = switch ($VersionBump) {
            'Major' { [version]::new($currentVersion.Major + 1, 0, 0) }
            'Minor' { [version]::new($currentVersion.Major, $currentVersion.Minor + 1, 0) }
            'Patch' { [version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1) }
        }
        
        Write-Host "  Bumping version: $currentVersion → $newVersion" -ForegroundColor Cyan
        
        #  SAUVEGARDE DU MANIFESTE ORIGINAL 
        $backupPath = "$manifestPath.backup"
        Copy-Item $manifestPath $backupPath -Force
        
        try {
            # MODIFICATION MANUELLE PLUS PRÉCISE
            $manifestContent = Get-Content $manifestPath -Raw -Encoding UTF8
            
            # Mise à jour de la version avec pattern plus strict
            $manifestContent = $manifestContent -replace "(ModuleVersion\s*=\s*)'[\d\.]+'", "`$1'$newVersion'"
            
            if ($ReleaseNotes) {
                # Échapper les apostrophes dans les release notes
                $escapedNotes = $ReleaseNotes -replace "'", "''"
                
                # Mise à jour ou ajout des ReleaseNotes
                if ($manifestContent -match "ReleaseNotes\s*=") {
                    $manifestContent = $manifestContent -replace "(ReleaseNotes\s*=\s*)'[^']*'", "`$1'$escapedNotes'"
                }
                else {
                    # Insérer après ModuleVersion
                    $manifestContent = $manifestContent -replace "(ModuleVersion\s*=\s*'[\d\.]+')", "`$1`n    ReleaseNotes = '$escapedNotes'"
                }
            }
            
            # Écrire le nouveau contenu avec BOM UTF-8
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($manifestPath, $manifestContent, $utf8WithBom)
            
            Write-Host "✓ Manifeste mis à jour" -ForegroundColor Green
            
            # *** VALIDATION DU MANIFESTE ***
            Write-Host "  Validation du manifeste..." -ForegroundColor Gray
            $testResult = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue
            
            if ($testResult.Version -eq $newVersion) {
                Write-Host "✓ Manifeste validé avec succès" -ForegroundColor Green
                Remove-Item $backupPath -Force
            }
            else {
                throw "La version du manifeste ne correspond pas"
            }
            
            $versionToPublish = $newVersion
        }
        catch {
            Write-Host "✗ Erreur lors de la mise à jour du manifeste: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Restauration de la sauvegarde..." -ForegroundColor Yellow
            Copy-Item $backupPath $manifestPath -Force
            Remove-Item $backupPath -Force
            exit 1
        }   
    }
    else {
        $versionToPublish = $currentVersion
        Write-Host "`nPublication de la version courante: $versionToPublish (avec écrasement forcé)" -ForegroundColor Cyan
    }
}


# ====================================
# Delete possible existant versions
# ====================================
function Remove-OldPackages {
    $packagePattern = Join-Path $RepositoryPath "MyResources.*.nupkg"

    $oldPackages = Get-ChildItem -Path $packagePattern -ErrorAction SilentlyContinue

    if ($oldPackages) {
        Write-Host "⚠ $($oldPackages.Count) old version(s) found. deleting ..." -ForegroundColor Yellow

        $oldPackages | Remove-Item -Force
    
        Write-Host "✓ All older packages are deleted" -ForegroundColor Green
    }
    else {
        Write-Host "✓ No packages were deleted." -ForegroundColor Gray
    }

}


# ====================================
# CRÉATION AUTO DU REPOSITORY
# ====================================
function Set-Repository {
    if (-not (Test-Path $RepositoryPath)) {
        Write-Host "Création du dossier repository: $RepositoryPath" -ForegroundColor Gray
        New-Item -ItemType Directory -Path $RepositoryPath -Force | Out-Null
    }

    $repo = Get-PSRepository -Name WaCLocalRepo -ErrorAction SilentlyContinue

    if (-not $repo) {
        Write-Host "Enregistrement du repository WaCLocalRepo..." -ForegroundColor Yellow
        Register-PSRepository `
            -Name WaCLocalRepo `
            -SourceLocation $RepositoryPath `
            -PublishLocation $RepositoryPath `
            -InstallationPolicy Trusted
        Write-Host "✓ Repository enregistré" -ForegroundColor Green
    }
    else {
        Set-PSRepository `
            -Name WaCLocalRepo `
            -SourceLocation $RepositoryPath `
            -PublishLocation $RepositoryPath `
            -InstallationPolicy Trusted
    }    
}


# ====================================
# PUBLICATION DU MODULE
# ====================================
function Publish-MyResourcesModule {
    
    $originalNuGetLang = $env:NUGET_CLI_LANGUAGE

    try {
        # $env:DOTNET_CLI_UI_LANGUAGE = "en-US"
        $env:NUGET_CLI_LANGUAGE = "en-US"
    
        Write-Host "  Culture forcée en anglais" -ForegroundColor Gray    
    
        Set-Location $ModulePath

        Publish-Module -Path . -Repository WaCLocalRepo -Force
    
        Write-Host "✓ Module publié avec succès via Publish-Module" -ForegroundColor Green

        Set-Location $PSScriptRoot
    }
    finally {
        # $env:DOTNET_CLI_UI_LANGUAGE = $originalLang
        $env:NUGET_CLI_LANGUAGE = $originalNuGetLang
    }

}

# ====================================
# VÉRIFICATION FINALE
# ====================================

function Test-Publication {
    Write-Host "`nVérification du module dans le repository..." -ForegroundColor Cyan
    $module = Find-Module -Repository WaCLocalRepo -Name MyResources -ErrorAction SilentlyContinue

    if ($module) {
        Write-Host "✓ Module trouvé dans le repository" -ForegroundColor Green
        Write-Host "  Nom     : $($module.Name)" -ForegroundColor Gray
        Write-Host "  Version : $($module.Version)" -ForegroundColor Gray
    }
    else {
        Write-Host "⚠ Module non trouvé via Find-Module" -ForegroundColor Yellow
        Write-Host "  Contenu du repository :" -ForegroundColor Cyan
        Get-ChildItem $RepositoryPath -Filter "*.nupkg" -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host "    ✓ $($_.Name)" -ForegroundColor Green }
    }

    Write-Host "`n=== Publication terminée ===" -ForegroundColor Green
}

$functions = @(
    @{ Message = "Mise à jour de la version du module"; Function = { Update-Version } },
    @{ Message = "Suppression des anciennes versions du repository"; Function = { Remove-OldPackages } },
    @{ Message = "Configuration du repository local"; Function = { Set-Repository } },
    @{ Message = "Publication du module MyResources"; Function = { Publish-MyResourcesModule } },
    @{ Message = "Vérification finale de la publication"; Function = { Test-Publication } }
)

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host '║        Publication des ressources DSC                      ║' -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan


$functionCount = $functions.count

for ($i = 0; $i -lt $functionCount; $i++) {

    $f = $functions[$i]

    $LargeurCadre = 75 

    $TexteEtape = "  Étape $($i + 1)/$functionCount : $($f.Message)"

    $LigneInterne = $TexteEtape.PadRight($LargeurCadre - 2)

    $BarreHorizontale = "─" * ($LargeurCadre - 2)

    Write-Host "`n┌$BarreHorizontale┐" -ForegroundColor Cyan
    Write-Host "│$LigneInterne│" -ForegroundColor Cyan
    Write-Host "└$BarreHorizontale┘" -ForegroundColor Cyan


    & $f.Function
}
