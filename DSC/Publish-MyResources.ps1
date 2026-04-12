[CmdletBinding()]
param()

# ====================================
# PUBLICATION DU MODULE
# ====================================
function Publish-MyResourcesModule {

    # force English output to avoid parsing issues during Publish-Module
    # related to : https://github.com/PowerShell/PowerShellGetv2/issues/606
    
    $originalNuGetLang = $env:NUGET_CLI_LANGUAGE

    $ModulePath = (Join-Path $PSScriptRoot "Modules\MyResources")

    try {
        $env:NUGET_CLI_LANGUAGE = "en-US"
    
        Write-Host "  Culture forcée en anglais" -ForegroundColor Gray    
    
        Set-Location $ModulePath

        Publish-Module -Path . -Repository WaCLocalRepo -Force
    
        Write-Host "✓ Module publié avec succès via Publish-Module" -ForegroundColor Green

        Set-Location $PSScriptRoot
    }
    finally {
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
