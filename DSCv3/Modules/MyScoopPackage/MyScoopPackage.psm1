. $PSScriptRoot\MyScoopPackage.ps1

enum MyEnsure
{
    Absent
    Present
}

# TODO: Same properties as WinGetPackage
# Ensure, IsUpdateAvailable, MatchOption, UseLatest, InstallMode, Source, IsInstalled, InstalledVersion, Version
[DscResource()]
class MyScoopPackage
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

    hidden [MyScoopPackage] $CachedCurrent

    [MyScoopPackage] Get()
    {
        $current = [MyScoopPackage]::new()
        $current.PackageName = $this.PackageName

        $packageInfo = Get-ScoopPackageInfo $this.PackageName

        $current.Ensure = $packageInfo.Ensure
        $current.Version = $packageInfo.Version

        if ($current.Version)
        {
            if ($this.Version -eq 'latest')
            {
                $current.LatestVersion = Get-ScoopPackageLatestAvailableVersion $this.PackageName
                $current.LatestVersion = $current.LatestVersion ? $current.LatestVersion : $current.Version
                $current.State = $current.LatestVersion -eq $current.Version ? 'Current' : 'Stale'
            }
            else
            {
                $current.LatestVersion = 'NotApplicable'
                $current.State = $current.Version -eq $this.Version ? 'Current' : 'Stale'
            }
        }
        else
        {
            $current.LatestVersion = $null
            $current.State = 'NotInstalled'
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
                $target += "@$($this.Version)"
            }

            if ($current.Ensure -eq [MyEnsure]::Present -and $this.Version -eq 'latest')
            {
                Update-ScoopPackage $target
            }
            else
            {
                Install-ScoopPackage $target
            }
        }
        elseif ($this.Ensure -eq [MyEnsure]::Absent)
        {
            if ($current.Ensure -eq [MyEnsure]::Present)
            {
                Uninstall-ScoopPackage $this.PackageName
            }
        }
    }
}
