. $PSScriptRoot\Convert-ObjectArrayToHashtable.ps1
. $PSScriptRoot\Invoke-RetryableOperation.ps1

enum MyEnsure
{
    Absent
    Present
}

$script:ScoopListCache
$script:ScoopListCacheExpires
$script:ScoopStatusCache
$script:ScoopStatusCacheExpires
$script:CacheDuration = [TimeSpan]::FromMinutes(5)

function Get-RawScoopList
{
    try {
         $json = & scoop export | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse scoop export JSON: $_"
    }
    
    # scoop export outputs a JSON object with 'apps' and 'buckets' keys. We only need the 'apps'.
    return $json.apps ?? @()
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
            $packages = Convert-ObjectArrayToHashtable $scoopList 'Name'
            $script:ScoopListCache = $packages
            $script:ScoopListCacheExpires = (Get-Date) + $script:CacheDuration
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
            PackageName = $packageName # Add this line
            Ensure      = [MyEnsure]::Present
            Version     = $packages[$packageName].Version
        }
    }

    return @{
        PackageName = $packageName # Add this line for absent packages too
        Ensure      = [MyEnsure]::Absent
        Version     = $null
    }
}

function Update-ScoopStatusCache
{
    Invoke-RetryableOperation {
        $scoopStatus = Get-RawScoopStatus
            
        if (-not $scoopStatus)
        {
            # Empty status is normal when no updates are available
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

    # Suppress all output to avoid contaminating DSC response
    $output = & scoop update $packageName *>&1
    
    # Check if command succeeded by looking for error indicators in output
    $errorIndicators = $output | Where-Object { $_ -match "error|failed|not found" }
    
    if ($errorIndicators) {
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
    
    # Suppress all output to avoid contaminating DSC response
    $output = & scoop install $packageName *>&1
    
    # Check for success by looking for error patterns
    $errorIndicators = $output | Where-Object { $_ -match "error|failed|not found|couldn't find" }
    
    if ($errorIndicators) {
        $outputString = $output | Out-String
        throw "Failed to install scoop package '$packageName'.`nDetails: $outputString"
    }

    Clear-Cache
}

function Uninstall-ScoopPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $packageName
    )

    # Suppress all output to avoid contaminating DSC response
    $output = & scoop uninstall $packageName *>&1
    
    # Check for success by looking for error patterns
    $errorIndicators = $output | Where-Object { $_ -match "error|failed|not found|isn't installed" }
    
    if ($errorIndicators) {
        $outputString = $output | Out-String
        throw "Failed to uninstall scoop package '$packageName'.`nDetails: $outputString"
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