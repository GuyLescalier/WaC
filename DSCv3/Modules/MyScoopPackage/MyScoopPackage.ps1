. $PSScriptRoot\Convert-ObjectArrayToHashtable.ps1
. $PSScriptRoot\Invoke-RetryableOperation.ps1

enum MyEnsure
{
    Absent
    Present
}

# Define CacheDuration BEFORE it's used
$script:CacheDuration = [TimeSpan]::FromMinutes(5)

$script:ScoopListCache = $null
$script:ScoopListCacheExpires = $null
$script:ScoopStatusCache = $null
$script:ScoopStatusCacheExpires = $null

function Get-RawScoopList
{
    $result = & scoop list *>&1 | Select-Object -Skip 4

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
        & scoop update *> $null
    }

    $result = & scoop status

    if (-not $?)
    {
        throw "Failed to get scoop status: $result"
    }

    if ($result -is [string] -or ($result -is [array] -and $result.Length -gt 0 -and $result[0] -is [string])) {
        return @()
    }

    return $result ? $result : @()
}

function Update-ScoopListCache
{
    Invoke-RetryableOperation {
        $scoopList = Get-RawScoopList

        if (-not $scoopList)
        {
            throw 'Unable to get scoop list'
        }

        try
        {
            Write-Debug "Scoop List: $($scoopList | ConvertTo-Json -Depth 100)"
            $packages = Convert-ObjectArrayToHashtable $scoopList 'Name'
            Write-Debug "Packages: $($packages | ConvertTo-Json -Depth 100)"
            $script:ScoopListCache = $packages
            $script:ScoopListCacheExpires = (Get-Date) + $script:CacheDuration
            Write-Debug "Cache Duration: $($script:CacheDuration)"
        }
        catch
        {
            throw "Failed to convert scoop list '$($scoopList | ConvertTo-Json -EnumsAsStrings -Depth 100 -Compress)' to hashtable.`nDetails: $_"
        }
    }
}

function Get-ScoopPackageInfo
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
        try
        {
            $packages = Convert-ObjectArrayToHashtable $scoopList 'Name'
            $script:ScoopListCache = $packages
            $script:ScoopListCacheExpires = (Get-Date) + $script:CacheDuration
        }
        catch
        {
            throw "Failed to convert scoop list '$($scoopList | ConvertTo-Json -EnumsAsStrings -Depth 100 -Compress)' to hashtable.`nDetails: $_"
        }
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

function Update-ScoopStatusCache
{
    Invoke-RetryableOperation {
        $scoopStatus = Get-RawScoopStatus

        if (-not $scoopStatus)
        {
            $script:ScoopStatusCache = @{}
            $script:ScoopStatusCacheExpires = (Get-Date) + $script:CacheDuration
            return
        }

        try
        {
            $packages = Convert-ObjectArrayToHashtable $scoopStatus 'Name'
            $script:ScoopStatusCache = $packages
            $script:ScoopStatusCacheExpires = (Get-Date) + $script:CacheDuration
        }
        catch
        {
            throw "Failed to convert scoop status '$($scoopStatus | ConvertTo-Json -EnumsAsStrings -Depth 100 -Compress)' to hashtable.`nDetails: $_"
        }
    }
}

function Get-ScoopPackageLatestAvailableVersion
{
    param (
        [string]$PackageName
    )

    if (-not $script:ScoopStatusCache -or $script:ScoopStatusCacheExpires -le (Get-Date))
    {
        Update-ScoopStatusCache
    }

    if ($script:ScoopStatusCache.ContainsKey($PackageName))
    {
        return $script:ScoopStatusCache[$PackageName].'Latest Version'
    }

    return $null
}

function Update-ScoopPackage
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

function Install-ScoopPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $packageName
    )

    & scoop install $packageName
    if (-not $?)
    {
        throw "Failed to install scoop package '$packageName'"
    }

    Clear-Cache
}

function Uninstall-ScoopPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $packageName
    )

    & scoop uninstall $packageName
    if (-not $?)
    {
        throw "Failed to uninstall scoop package '$packageName'"
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
