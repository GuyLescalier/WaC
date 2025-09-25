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
        try {
            $url = 'https://nodejs.org/dist/index.json'

            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing
            $versions = $resp.Content | ConvertFrom-Json

            # Construire la table UNIQUEMENT avec lts et latest
            $versionsHashTable = @{}

            # LTS
            $ltsVersion = $versions |
                Where-Object { $PSItem.lts } |
                Sort-Object { $PSItem.version -replace '^v' -as [version] } |
                Select-Object -Last 1

            # Latest
            $latestVersion = $versions |
                Sort-Object { $PSItem.version -replace '^v' -as [version] } |
                Select-Object -Last 1

            # Ajouter SEULEMENT lts et latest
            if ($ltsVersion)
            {
                $versionsHashTable['lts'] = ($ltsVersion.version   -replace '^v')
            }
            if ($latestVersion)
            {
                $versionsHashTable['latest'] = ($latestVersion.version -replace '^v')
            }

            $script:nodeLatestVersionsCache = $versionsHashTable
            $script:LastNodeLatestVersionsRefreshed = Get-Date
        }
        catch
        {
            Write-Error "Failed to retrieve Node.js versions. Details: $_"
            return $null
        }
    }

    # Return the cached result
    return $script:nodeLatestVersionsCache
}