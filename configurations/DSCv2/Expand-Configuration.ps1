# ..\configurations\Expand-Configuration.ps1 -InputFilePath "..\configurations\configuration.dsc.yaml" -OutputFilePath "..\configurations\expanded-configuration.dsc.yaml"

param (
    [Parameter(Mandatory = $true)]
    [string]$InputFilePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputFilePath
)

# Import the necessary module
Import-Module powershell-yaml

# Load the original YAML content
$originalConfiguration = Get-Content -Path $InputFilePath | ConvertFrom-Yaml

# Process the original object to create the updated object
$expandedResources = @()
foreach ($resource in $originalConfiguration.properties.resources) {
    if ($resource.settings -is [system.collections.generic.list[object]]) {
        foreach ($setting in $resource.settings) {
            # Deep clone the resource object using JSON serialization and deserialization
            $expandedResource = $resource | ConvertTo-Json -Depth 100 | ConvertFrom-Json

            # Update the settings and description for the new resource
            $expandedResource.settings = $setting
            foreach ($key in $setting.Keys) {
                $expandedResource.directives.description = $expandedResource.directives.description -replace "\[$key\]", $setting[$key]
            }
            $expandedResources += $expandedResource
        }

    }
    else {
        $expandedResources += $resource
    }
}
$originalConfiguration.properties.resources = $expandedResources

# Prepending the first line to the updated YAML
$expandedConfiguration = "# yaml-language-server: `$schema=https://aka.ms/configuration-dsc-schema/0.2`n"

# Adding the rest of the YAML content
$expandedConfiguration += $originalConfiguration | ConvertTo-Yaml

# Write the expanded YAML content to the output file
$expandedConfiguration | Set-Content -Path $OutputFilePath
