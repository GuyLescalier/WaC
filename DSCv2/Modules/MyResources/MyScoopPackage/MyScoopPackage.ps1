enum MyEnsure
{
    Absent
    Present
}

function Get-RawScoopList
{
    $result = & scoop list

    if (-not $?)
    {
        throw "Failed to get scoop list: $result"
    }
    
    return $result ? $result : @()
}

function Get-RawScoopStatus
{
    $statusResult = & scoop status 6>&1
    if ($statusResult -match 'WARN.*scoop update')
    {
        & scoop update
    }
    
    $result = & scoop status
    
    if (-not $?)
    {
        throw "Failed to get scoop status: $result"
    }
    
    return $result ? $result : @()
}

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
        $hashtable[$obj.$KeyProperty] = $obj
    }

    return $hashtable
}

$script:ScoopListCache
$script:ScoopListCacheExpires
$script:ScoopStatusCache
$script:ScoopStatusCacheExpires
$script:CacheDuration = [TimeSpan]::FromMinutes(5)

function Get-ScoopPackageInfo()
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $packageName
    )

    if ($script:ScoopListCache -and $script:ScoopListCacheExpires -gt (Get-Date))
    {
        $packages = $script:ScoopListCache
    }
    else
    {
        $scoopList = Get-RawScoopList
        $packages = Convert-ObjectArrayToHashtable $scoopList 'Name'
        $script:ScoopListCache = $packages
        $script:ScoopListCacheExpires = (Get-Date) + $script:CacheDuration
    }
    
    if ($packages.ContainsKey($packageName))
    {
        return @{
            Ensure  = [MyEnsure]::Present
            Version = $packages[$packageName].Version
        }
    }

    return @{
        Ensure  = [MyEnsure]::Absent
        Version = $null
    }
}

function Get-ScoopPackageLatestAvailableVersion([string] $packageName)
{
    if ($script:ScoopStatusCache -and $script:ScoopStatusCacheExpires -gt (Get-Date))
    {
        $packages = $script:ScoopStatusCache
    }
    else
    {
        $scoopStatus = Get-RawScoopStatus
        $packages = Convert-ObjectArrayToHashtable $scoopStatus 'Name'
        $script:ScoopStatusCache = $packages
        $script:ScoopStatusCacheExpires = (Get-Date) + $script:CacheDuration
    }

    if ($packages.ContainsKey($packageName))
    {
        return $packages[$packageName].'Latest Version'
    }

    return $null
}

function Update-ScoopPackage()
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $packageName
    )

    $output = & scoop update $packageName *>&1
    if (-not $?)
    {
        $outputString = $output | Out-String
        throw "Failed to update scoop package '$packageName'.`nDetails: $outputString"
    }

    Clear-Cache
}

function Install-ScoopPackage()
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $packageName
    )
    
    & scoop install $target
    if (-not $?)
    {
        throw "Failed to install scoop package '$target'"
    }

    Clear-Cache
}

function Uninstall-ScoopPackage()
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $packageName
    )

    & scoop uninstall $this.PackageName
    if (-not $?)
    {
        throw "Failed to uninstall scoop package '$($this.PackageName)'"
    }

    Clear-Cache
}

function Clear-Cache
{
    $script:ScoopListCache = $null
    $script:ScoopListCacheExpires = $null
    $script:ScoopStatusCache = $null
    $script:ScoopStatusCacheExpires = $null
}
