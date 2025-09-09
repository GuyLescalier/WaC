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
#  MODE EXPAND  -  compact  >  DSC v3                                     #
#=========================================================================#
if ($Mode -eq 'Expand') {

    [array]$groups = Get-Content -Raw -Path $InputFilePath | ConvertFrom-Yaml
    if ($null -eq $groups) {
        throw "Le fichier compact est vide ou invalide."
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

            $hint = $properties.PackageName ?? $properties.id ?? $properties.ValueName ?? $properties.Name ?? $properties.Path
            $hint = ($hint -replace '[^A-Za-z0-9]', '')
            $resName = if ($hint) { "$hint" } else { "$($g.Name)$i" }

            $doc.resources += [ordered]@{ 
                name       = $resName
                type       = $resourceType
                properties = $properties
            }
        }
    }

    $doc | ConvertTo-Yaml | Set-Content -Path $OutputFilePath -Encoding UTF8
    return
}

#=========================================================================#
#  MODE PACK  –  DSC v3  >  compact                                       #
#=========================================================================#
$dsc = Get-Content -Raw -Path $InputFilePath | ConvertFrom-Yaml
if (-not $dsc.resources) {
    throw "Le fichier DSC doit contenir la clé 'resources'."
}

$groups = [ordered]@{}

foreach ($res in $dsc.resources) {

    $key = $res.type
    if (-not $groups.Keys.Contains($key)) {
        $groups[$key] = [ordered]@{
            Name         = ($key -split '/' | Select-Object -Last 1)
            ResourceType = $key
            Property     = @()
        }
    }

    $prop = [ordered]@{}
    if ($null -ne $res.properties) {
        foreach ($kv in $res.properties.GetEnumerator()) {
            $prop[$kv.Key] = $kv.Value
        }
    }

    
    $groups[$key].Property += @($prop)
}

$groups.Values |
    Sort-Object Name |
    ConvertTo-Yaml |
    Set-Content -Path $OutputFilePath -Encoding UTF8
