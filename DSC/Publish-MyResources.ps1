[CmdletBinding()]
param()

# ====================================
# PUBLICATION DU MODULE
# ====================================
function Publish-MyResourcesModule {
    $modulePath = Join-Path $PSScriptRoot "Modules\MyResources"

    if (-not (Test-Path -LiteralPath $modulePath -PathType Container)) {
        throw "Module introuvable : $modulePath"
    }

    if (-not (Get-PSResourceRepository -Name WaCLocalRepo -ErrorAction SilentlyContinue)) {
        throw "Le repository PSResourceGet 'WaCLocalRepo' n'est pas enregistré."
    }

    try {
        Publish-PSResource -Path $modulePath -Repository WaCLocalRepo -ErrorAction Stop

        Write-Host "✓ Module publié avec succès" -ForegroundColor Green
    }
    catch {
        Write-Host "Échec de la publication : $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ====================================
# VÉRIFICATION FINALE
# ====================================

function Test-Publication {
    Write-Host "`nVérification du module dans le repository..." -ForegroundColor Cyan
    $module = Find-PSResource -Repository WaCLocalRepo -Name MyResources -ErrorAction SilentlyContinue

    if ($module) {
        Write-Host "✓ Module trouvé dans le repository" -ForegroundColor Green
        Write-Host "  Nom     : $($module.Name)" -ForegroundColor Gray
        Write-Host "  Version : $($module.Version)" -ForegroundColor Gray
    }
    else {
        Write-Host "⚠ Module non trouvé via Find-Module" -ForegroundColor Yellow
    }

    Write-Host "`n=== Publication terminée ===" -ForegroundColor Green
}

# ====================================

$functions = @(
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
