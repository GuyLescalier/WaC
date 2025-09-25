. $PSScriptRoot\Constants.ps1
. $PSScriptRoot\Get-DeepClone.ps1

function Set-DscResourceState
{
    [CmdletBinding()]
    param ([hashtable]$Resource)

    Write-Verbose "Setting DSC Resource State for $($Resource | ConvertTo-Json -EnumsAsStrings -Depth 100)"

    $resourceClone = Get-DeepClone $Resource
    $resourceClone.ModuleName = $resourceClone.ModuleName ?? $DefaultDscResourceModuleName
    $resourceClone.Property = $resourceClone.Property ?? @{}
    if ($DscResourcesDefaultProperties.ContainsKey($resourceClone.Name))
    {
        $resourceClone.Property = New-MergedHashtable $DscResourcesDefaultProperties[$resourceClone.Name] $resourceClone.Property
    }
    if ($DscResourcesWithoutEnsure -notcontains $resourceClone.Name)
    {
        $resourceClone.Property.Ensure = $resourceClone.Property.Ensure ?? 'Present'
    }

    try
    {
        $originalProgressPreference = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'
        $setResult = Invoke-DscResource @resourceClone -Method Set -Verbose:($VerbosePreference -eq 'Continue')
    }
    finally
    {
        $global:ProgressPreference = $originalProgressPreference
    }

    $identifier = Select-DscResourceIdProperties $resourceClone

    return [PSCustomObject]@{
        Type       = $resourceClone.Name
        Identifier = $identifier
        Result     = $setResult
    }
}

function New-MergedHashtable
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
        [hashtable[]]$Hashtables
    )

    $mergedHashtable = @{}

    foreach ($hashtable in $Hashtables)
    {
        foreach ($key in $hashtable.Keys)
        {
            $mergedHashtable[$key] = $hashtable[$key]
        }
    }

    return $mergedHashtable
}
