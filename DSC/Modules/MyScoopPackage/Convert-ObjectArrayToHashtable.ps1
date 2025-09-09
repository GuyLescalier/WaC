
function  Convert-ObjectArrayToHashtable
{
    param (
        [PSCustomObject[]] $ObjectArray,

        [Parameter(Mandatory = $true)]
        [string] $KeyProperty
    )

    if (-not $ObjectArray)
    {
        return @{}
    }

    $hashtable = @{}

    foreach ($obj in $ObjectArray)
    {
        try
        {
            $hashtable[$obj.$KeyProperty] = $obj
        }
        catch
        {
            throw "Failed to insert object '$($obj | ConvertTo-Json -EnumsAsStrings -Depth 100 -Compress)' from array '$($ObjectArray | ConvertTo-Json -EnumsAsStrings -Depth 100 -Compress)' into hashtable.`nDetails: $_"
        }
    }

    return $hashtable
}
