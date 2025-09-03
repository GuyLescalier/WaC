<#
.SYNOPSIS
    Convertit un fichier YAML entre deux représentations :
      ▸ Mode Expand : format « compact » → DSC v3
      ▸ Mode Pack   : DSC v3            → format « compact »

.DESCRIPTION
    Le format compact est simplement une *liste de groupes*.
    Chaque groupe décrit :
        Name          (facultatif)   – étiquette humaine
        ResourceType  (facultatif)   – ex. Microsoft.WinGet/Package
        Defaults      (facultatif)   – propriétés communes à tous les items
        Property[s]   (obligatoire*) – tableau d’objets « item »

    Si ResourceType n’est pas renseigné, le script suppose « $Name/$Name ».
    Si Defaults n’est pas renseigné, rien n’est ajouté.
    *Si Property(s) est omis, on crée quand même UNE ressource (cas MyScoop, etc.).

    L’algorithme ne lit jamais le *nom* du type ; il agrège, clone
    et fusionne uniquement à partir des données présentes.

.PARAMETER Mode
    Expand  – compact ➜ DSC v3
    Pack    – DSC v3  ➜ compact

.PARAMETER InputFilePath
.PARAMETER OutputFilePath

.DEPENDENCIES
    PowerShell ≥ 7.1            (ConvertFrom/To‑Yaml natifs)
    ou Windows PowerShell 5.1 + module *PowerShell‑Yaml*

.EXAMPLE
    .\Convert-Configuration.ps1 -Mode Expand `
        -Input  .\compact.yml  -Output .\dsc.yml

    .\Convert-Configuration.ps1 -Mode Pack `
        -Input  .\dsc.yml      -Output .\compact-back.yml
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Expand','Pack')]
    [string]$Mode,

    [Parameter(Mandatory)]
    [string]$InputFilePath,

    [Parameter(Mandatory)]
    [string]$OutputFilePath
)

#-- Modules --------------------------------------------------------------
if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    Import-Module PowerShell-Yaml -ErrorAction Stop
}

#-- Petite fonction utilitaire ------------------------------------------
function Merge-Hash {
    param($Base, $Overlay)
    $h              = @{}
    foreach($k in $Base.Keys)    { $h[$k] = $Base[$k] }
    foreach($k in $Overlay.Keys) { $h[$k] = $Overlay[$k] }
    $h
}

#=========================================================================#
#  MODE EXPAND  –  compact  ➜  DSC v3                                     #
#=========================================================================#
if ($Mode -eq 'Expand') {

    $groups = Get-Content -Raw -Path $InputFilePath | ConvertFrom-Yaml
    if ($groups -isnot [System.Collections.IEnumerable]) {
        throw "Le fichier compact doit être un tableau YAML de groupes."
    }

    $doc = [ordered]@{
        '$schema' = 'https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/v3/bundled/config/document.json'
        resources = @()
    }

    foreach ($g in $groups) {

        $resourceType = if ($g.ResourceType) { $g.ResourceType }
                        else                 { "$($g.Name)/$($g.Name)" }

        $defaults  = ($g.Defaults  -as [hashtable]) ?? @{}
        $items     = $g.Property   ?? $g.Properties ?? @(@{})

        $i = 0
        foreach ($item in $items) {
            $i++
            $properties = Merge-Hash -Base $defaults -Overlay $item

            if (-not $properties.ContainsKey('Ensure')) { $properties.Ensure = 'Present' }

            # Génère un nom lisible si possible
            $hint = $item.PackageName ?? $item.id ?? $item.ValueName ?? $item.Name ?? $item.Path
            $hint = ($hint -replace '[^A-Za-z0-9]', '')  # sanitise
            $resName = if ($hint) { "Cfg$hint" } else { "$($g.Name)$i" }

            $doc.resources += [ordered]@{
                name       = $resName
                type       = $resourceType
                properties = $properties
            }
        }
    }

    $doc | ConvertTo-Yaml -NoArrayIndent | Set-Content -Path $OutputFilePath -Encoding UTF8
    return
}

#=========================================================================#
#  MODE PACK  –  DSC v3  ➜  compact                                       #
#=========================================================================#
$dsc = Get-Content -Raw -Path $InputFilePath | ConvertFrom-Yaml
if (-not $dsc.resources) {
    throw "Le fichier DSC doit contenir la clé 'resources'."
}

$groups = @{}

foreach ($res in $dsc.resources) {

    $key = $res.type                               # On groupe 1:1 par type DSC
    if (-not $groups.ContainsKey($key)) {
        $groups[$key] = [ordered]@{
            Name         = ($key -split '/' | Select-Object -Last 1) + 'Group'
            ResourceType = $key
            Property     = @()
        }
    }

    # Copie des propriétés en retirant les valeurs par défaut (Ensure=Present)
    $prop = @{}
    foreach ($kv in $res.properties.GetEnumerator()) {
        if ($kv.Key -eq 'Ensure' -and $kv.Value -eq 'Present') { continue }
        $prop[$kv.Key] = $kv.Value
    }
    $groups[$key].Property += $prop
}

$groups.Values |
    Sort-Object Name |
    ConvertTo-Yaml -NoArrayIndent |
    Set-Content -Path $OutputFilePath -Encoding UTF8
