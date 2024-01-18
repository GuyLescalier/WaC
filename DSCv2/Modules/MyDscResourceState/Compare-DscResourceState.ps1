Import-Module PSDesiredStateConfiguration
Import-Module Hashtable-Helpers
Import-Module CompareDiff-Helpers

. $PSScriptRoot\Constants.ps1
. $PSScriptRoot\Select-DscResourceProperties.ps1

function Get-DeepClone
{
    [cmdletbinding()]
    param(
        $InputObject
    )
    process
    {
        if ($InputObject -is [hashtable])
        {
            
            $clone = @{}
            foreach ($key in $InputObject.keys)
            {
                $clone[$key] = Get-DeepClone $InputObject[$key]
            }
            return $clone
        }
        else
        {
            return $InputObject
        }
    }
}


function Compare-DscResourceState
{
    [CmdletBinding()]
    param ([hashtable]$resource)

    Write-Verbose "Comparing DSC Resource State for $($resource | ConvertTo-Json -Depth 100)"

    # Clone the hashtable to prevent modifying the original
    $dscResource = Get-DeepClone $resource
    $dscResource.ModuleName = $dscResource.ModuleName ?? $DefaultDscResourceModuleName
    if (-not $dscResource.Property)
    {
        $dscResource.Property = @{}
    }
    $dscResource.Property.Remove('Ensure')
    
    $currentValue = Invoke-DscResource @dscResource -Method Get -Verbose:($VerbosePreference -eq 'Continue') | ConvertTo-Hashtable

    $identifier = Select-DscResourceIdProperties -Resource $resource
    $expected = Select-DscResourceStateProperties -Resource $resource
    $actual = Select-DscResourceStateProperties -Resource $currentValue -ResourceName $resource.Name

    if ($resource.Property.Ensure -ne $currentValue.Ensure)
    {
        $status = $resource.Property.Ensure -eq 'Present' ? 'Missing' : 'Unexpected'
        $diff = @{}
    }
    elseif ($resource.Property.Ensure -eq 'Absent')
    {
        $status = 'Compliant'
        $diff = @{}
    }
    else
    {
        $diff = Get-Diff $expected $actual
        $status = $diff.Count -eq 0 ? 'Compliant' : 'NonCompliant'
    }

    return @{
        Type       = $resource.Name
        Identifier = $identifier
        Status     = $status
        Diff       = $diff
    }
}