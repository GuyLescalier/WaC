Import-Module MyDscResourceState

. $PSScriptRoot\Get-DscResourcesFromYaml.ps1
. $PSScriptRoot\Cache.ps1

function Get-DscConfigurationState
{
    [CmdletBinding(DefaultParameterSetName = 'YamlFilePath')]
    param (
        [Parameter(ParameterSetName = 'YamlFilePath', Mandatory = $true)]
        [string]$YamlFilePath,

        [Parameter(ParameterSetName = 'ResourceCollection', Mandatory = $true)]
        [hashtable[]]$Resources,
        
        [switch]$Force
    )

    if ($PSCmdlet.ParameterSetName -eq 'YamlFilePath')
    {
        $resources = Get-DscResourcesFromYaml -YamlFilePath $YamlFilePath
    }
    else
    {
        $resources = $Resources
    }

    Get-DscConfigurationStateFromResources -Resources $resources -Force:$Force
}

function Get-DscConfigurationStateFromResources
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Resources,
        
        [switch]$Force
    )

    Write-Verbose 'Getting DSC Configuration'

    foreach ($resource in $Resources)
    {
        $cacheKey = Get-DscResourceHash -Resource $resource
        $resourceState = Get-CacheEntry -CacheName 'State' -Key $cacheKey -CacheDuration ([timespan]::FromMinutes(5)) `
            -ResourceAction { Get-DscResourceState -resource $resource } `
            -Force:$Force

        Write-Output $resourceState
    }
}
