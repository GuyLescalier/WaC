# .\Expand-Configuration.ps1 -InputFilePath ".\configuration.dsc.yaml" -OutputFilePath ".\expanded-configuration.dsc.yaml"
param(
    [Parameter(Mandatory = $true)]
    [string] $InputFilePath,
    [Parameter(Mandatory = $true)]
    [string] $OutputFilePath
)

Import-Module powershell-yaml
$compressedResources = Get-Content -Raw -Path $InputFilePath | ConvertFrom-Yaml

function Get-PropertySets {
    param([object]$Properties)
    
    # null 
    if ($null -eq $Properties) {
        return @(@{})
    }
    
    # liste
    if ($Properties -is [System.Collections.IEnumerable] -and $Properties -isnot [string]) {
        return $Properties
    }
    
    # objet unique
    return @($Properties)
}

function Expand-ResourceName {
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [object]$Properties
    )
    if ($null -eq $Properties) {
        $Properties = @{}
    }
    if (-not $Name) {
        return $Name
    }
    $pattern = '\[([^\]]+)\]'
    $expanded = [regex]::Replace($Name, $pattern, {
        param($m)
        $key = $m.Groups[1].Value
        if ($Properties.ContainsKey($key)) {
            return [string]$Properties[$key]
        } else {
            return $m.Value
        }
    })
    return $expanded
}

function Remove-ResourceNameKey {
    param([object]$InputObject)
    $InputObject.Remove('resourceName')
    return $InputObject
}

$expandedResources = @()
foreach ($resource in $compressedResources) {
    $propSets = Get-PropertySets -Properties $resource.properties
    foreach ($propSet in $propSets) {
        $expandedItem = [ordered]@{
            name       = Expand-ResourceName -Name $resource.name -Properties $propSet
            type       = $resource.type
            properties = Remove-ResourceNameKey -InputObject $propSet
        }
        $expandedResources = $expandedResources + @($expandedItem)
    }
}

$finalDocument = [ordered]@{
    '$schema' = 'https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/v3/bundled/config/document.json'
    resources = $expandedResources
}

$yamlOut = ConvertTo-Yaml -Data $finalDocument
Set-Content -Path $OutputFilePath -Value $yamlOut -Encoding UTF8
Write-Host "Le fichier de configuration a été développé avec succès dans '$OutputFilePath'."