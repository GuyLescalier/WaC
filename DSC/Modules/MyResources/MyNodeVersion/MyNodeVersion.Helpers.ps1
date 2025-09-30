function Get-NvmInstalledVersions
{
    $nvmList = & nvm list
    $installedVersions = $nvmList -split '\r?\n' |
        Where-Object { $_.Trim() -ne '' } |
        ForEach-Object {
            if ($_ -match '\d+\.\d+\.\d+')
            {
                $matches[0] 
            }
        }

    return $installedVersions
}

function Get-NvmCurrentVersion
{
    return (nvm current) -Replace '^v'
}

function Get-NvmStaleVersions
{
    $installedVersions = Get-NvmInstalledVersions
    $latestVersions = @{}
    $staleVersions = @()

    foreach ($version in $installedVersions)
    {
        $splitVersion = $version -split '\.'
        $majorVersion = [int]$splitVersion[0]
        $minorVersion = [int]$splitVersion[1]
        $patchVersion = [int]$splitVersion[2]

        if ($latestVersions.ContainsKey($majorVersion))
        {
            $latestSplitVersion = $latestVersions[$majorVersion] -split '\.'
            $latestMinorVersion = [int]$latestSplitVersion[1]
            $latestPatchVersion = [int]$latestSplitVersion[2]

            if (($minorVersion -gt $latestMinorVersion) -or (($minorVersion -eq $latestMinorVersion) -and ($patchVersion -gt $latestPatchVersion)))
            {
                # Current version is newer, add the older version to staleVersions and update latestVersions
                $staleVersions += $latestVersions[$majorVersion]
                $latestVersions[$majorVersion] = $version
            }
            else
            {
                # Current version is older or equal, add it to staleVersions
                $staleVersions += $version
            }
        }
        else
        {
            # This is the first version of this major version, add it to latestVersions
            $latestVersions[$majorVersion] = $version
        }
    }

    # Output stale versions
    return $staleVersions
}

$script:CacheDurationMinutes = 5
function Get-NodeLatestVersions
{
    if (-not $script:nodeLatestVersionsCache -or (Get-Date) -gt $script:LastNodeLatestVersionsRefreshed.AddMinutes($script:CacheDurationMinutes))
    {
        # Get the HTML content of the Node.js downloads page
        $url = 'https://nodejs.org/en/download/releases/'
        $pageContent = Invoke-WebRequest -Uri $url
    
        # Find all matches for the version numbers
        $regexPattern = '<td data-label="Version">v<!-- -->(.*?)<\/td><td data-label="LTS">(.*?)<\/td>'
        $versionMatches = [regex]::Matches($pageContent, $regexPattern)

        $versionsHashTable = @{}
        $ltsVersion = 0
        $latestVersion = 0
        foreach ($match in $versionMatches)
        {
            $fullVersion = $match.Groups[1].Value
            $majorVersion = [int]($fullVersion -split '\.')[0]
            $isLTS = $match.Groups[2].Value -ne '-'
            if ($isLTS -and $majorVersion -gt $ltsVersion)
            {
                $ltsVersion = $majorVersion
            }
            if ($majorVersion -gt $latestVersion)
            {
                $latestVersion = $majorVersion
            }
            $versionsHashTable[$majorVersion] = $fullVersion
        }
        $versionsHashTable['lts'] = $versionsHashTable[$ltsVersion]
        $versionsHashTable['latest'] = $versionsHashTable[$latestVersion]

        # Update the cache variable and set the expiry time
        $script:nodeLatestVersionsCache = $versionsHashTable
        $script:LastNodeLatestVersionsRefreshed = Get-Date
    }

    # Return the cached result
    return $script:nodeLatestVersionsCache
}