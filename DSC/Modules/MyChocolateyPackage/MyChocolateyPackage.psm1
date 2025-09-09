enum MyEnsure
{
    Absent
    Present
}

[DscResource()]
class MyChocolateyPackage
{
    [DscProperty(Key)]
    [string] $PackageName

    [DscProperty()]
    [string] $Version = 'latest'

    [DscProperty()]
    [MyEnsure] $Ensure = [MyEnsure]::Present

    [DscProperty(NotConfigurable)]
    [string] $LatestVersion

    [DscProperty(NotConfigurable)]
    [string] $State = 'Unknown'

    hidden [MyChocolateyPackage] $CachedCurrent

    hidden static [datetime] $LastChocolateyListRefreshed
    hidden static [hashtable] $ChocolateyListCache
    hidden static [datetime] $LastChocolateyStatusRefreshed
    hidden static [hashtable] $ChocolateyStatusCache

    hidden [timespan] $CacheDuration = [timespan]::FromMinutes(5)

    hidden [hashtable] GetChocolateyPackageInfo([string] $packageName)
    {
        if ([MyChocolateyPackage]::ChocolateyListCache -and ((Get-Date) - [MyChocolateyPackage]::LastChocolateyListRefreshed) -lt $this.CacheDuration)
        {
            $packages = [MyChocolateyPackage]::ChocolateyListCache
        }
        else
        {
            $chocolateyList = & choco list | Out-String
            $packages = @{}
            $chocolateyList -split '\r?\n' | ForEach-Object {
                if ($_ -match '^\s*(\S+)\s+(\S+)$')
                {
                    $packages[$matches[1]] = $matches[2]
                }
            }
            [MyChocolateyPackage]::ChocolateyListCache = $packages
            [MyChocolateyPackage]::LastChocolateyListRefreshed = Get-Date
        }
        
        if ($packages.ContainsKey($packageName))
        {
            return @{
                Ensure  = [MyEnsure]::Present
                Version = $packages[$packageName]
            }
        }
    
        return @{
            Ensure  = [MyEnsure]::Absent
            Version = $null
        }
    }

    hidden [string] GetLatestAvailableVersion([string] $packageName)
    {
        if ([MyChocolateyPackage]::ChocolateyStatusCache -and ((Get-Date) - [MyChocolateyPackage]::LastChocolateyStatusRefreshed) -lt $this.CacheDuration)
        {
            $packages = [MyChocolateyPackage]::ChocolateyStatusCache
        }
        else
        {
            $chocolateyStatus = & choco outdated | Out-String
            $packages = @{}
            $chocolateyStatus -split '\r?\n' | ForEach-Object {
                if ($_ -match '^\s*(\S+)\|\S+\|(\S+)\|\S+$')
                {
                    $packages[$matches[1]] = $matches[2]
                }
            }
            [MyChocolateyPackage]::ChocolateyStatusCache = $packages
            [MyChocolateyPackage]::LastChocolateyStatusRefreshed = Get-Date
        }
    
        if ($packages.ContainsKey($packageName))
        {
            return $packages[$packageName]
        }
    
        return $null
    }

    [MyChocolateyPackage] Get()
    {
        $current = [MyChocolateyPackage]::new()
        $current.PackageName = $this.PackageName

        $packageInfo = $this.GetChocolateyPackageInfo($this.PackageName)

        $current.Ensure = $packageInfo.Ensure
        $current.Version = $packageInfo.Version
    
        $latestAvailableVersion = $this.GetLatestAvailableVersion($this.PackageName)
        if ($latestAvailableVersion)
        {
            $current.LatestVersion = $latestAvailableVersion
        }
        else
        {
            $current.LatestVersion = $current.Version
        }

        if ($current.Version -and $current.LatestVersion)
        {
            if ($current.Version -eq $current.LatestVersion)
            {
                $current.State = 'Current'
            }
            else
            {
                $current.State = 'Stale'
            }
        }

        $this.CachedCurrent = $current

        return $current
    }

    [bool] Test()
    {
        $current = $this.Get()

        if ($this.Ensure -eq [MyEnsure]::Absent)
        {
            return ($current.Ensure -eq $this.Ensure)
        }
        
        if ($current.Ensure -eq [MyEnsure]::Absent)
        {
            return $false
        }

        if ($this.Version -eq 'latest')
        {
            return $current.Version -eq $current.LatestVersion
        }
        else
        {
            return $current.Version -eq $this.Version
        }
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        $current = $this.CachedCurrent

        if ($this.Ensure -eq [MyEnsure]::Present)
        {
            $target = $this.PackageName
            if ($this.Version -ne 'latest')
            {
                $target += " --version $($this.Version)"
            }

            # If you do not have a package installed, upgrade will install it.
            & choco upgrade $target -y
        }
        elseif ($this.Ensure -eq [MyEnsure]::Absent)
        {
            if ($current.Ensure -eq [MyEnsure]::Present)
            {
                & choco uninstall $this.PackageName -y
            }
        }
        
        # Invalidate the caches
        [MyChocolateyPackage]::ChocolateyListCache = $null
        [MyChocolateyPackage]::ChocolateyStatusCache = $null
    }
}
