# ====================================
# GESTION DE LA VERSION
# ====================================

function Update-Version {
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter()]
        [ValidateSet('Major', 'Minor', 'Patch')]
        [string]$VersionBump,

        [Parameter()]
        [string]$ReleaseNotes
    )

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
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryPath
    )

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
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryPath
    )

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