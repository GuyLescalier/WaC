. $PSScriptRoot\MyNodeVersion.Helpers.ps1

enum MyEnsure
{
    Absent
    Present
    Used
}

[DscResource()]
class MyNodeVersion
{
    [DscProperty(Key)]
    [string]$Version

    [DscProperty()]
    [MyEnsure]$Ensure = [MyEnsure]::Present

    [DscProperty(NotConfigurable)]
    [string]$CurrentVersion

    [DscProperty(NotConfigurable)]
    [string]$LatestVersion

    [DscProperty(NotConfigurable)]
    [string]$State = 'Unknown'

    hidden [MyNodeVersion] $CachedCurrent

    [MyNodeVersion] Get()
    {
        if (-not ($this.Version -in @('lts', 'latest') -or $this.Version -match '^\d+$'))
        {
            throw "Version must be 'lts', 'latest', or an integer representing the major version."
        }
    
        $current = [MyNodeVersion]::new()
        $current.Version = $this.Version

        $latestVersions = Get-NodeLatestVersions
    
        if ($this.Version -in 'lts', 'latest')
        {
            $current.LatestVersion = $latestVersions[$this.Version]
            $majorVersion = $current.LatestVersion -replace '\.\d+\.\d+$', ''
        }
        else
        {
            $majorVersion = [int]($this.Version -split '\.')[0]
            if ($latestVersions.ContainsKey($majorVersion))
            {
                $current.LatestVersion = $latestVersions[$majorVersion]
            }
            else
            {
                throw "Major version $majorVersion is not available."
            }
        }

        $nvmInstalledVersions = Get-NvmInstalledVersions
        $versionInstalled = $nvmInstalledVersions | Where-Object { $_.StartsWith("$majorVersion.") } | Select-Object -First 1
        if ($null -ne $versionInstalled)
        {
            $current.CurrentVersion = $versionInstalled

            $nvmCurrentVersion = Get-NvmCurrentVersion
            $current.Ensure = $nvmCurrentVersion -eq $current.LatestVersion ? [MyEnsure]::Used : [MyEnsure]::Present
    
            if ($current.CurrentVersion -and $current.LatestVersion)
            {
                $current.State = $current.CurrentVersion -eq $current.LatestVersion ? 'Current' : 'Stale'
            }
        }
        else
        {
            $current.Ensure = [MyEnsure]::Absent
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

        if ($this.Ensure -eq [MyEnsure]::Used -and $current.Ensure -ne $this.Ensure)
        {
            return $false
        }
        
        return $current.LatestVersion -eq $current.CurrentVersion
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }
        
        if ($this.Ensure -eq [MyEnsure]::Absent)
        {
            & nvm uninstall $this.CachedCurrent.CurrentVersion
            return
        }
        
        if ($this.CachedCurrent.Ensure -eq [MyEnsure]::Absent -or $this.CachedCurrent.CurrentVersion -ne $this.CachedCurrent.LatestVersion)
        {
            & nvm install $this.CachedCurrent.LatestVersion
        }
        
        if ($this.CachedCurrent.Ensure -ne $this.Ensure)
        {
            & nvm use $this.CachedCurrent.LatestVersion
        }

        # Cleanup old unused versions
        $nvmStaleVersions = Get-NvmStaleVersions
        $nvmCurrentVersion = Get-NvmCurrentVersion
        $versionsToRemove = $nvmStaleVersions | Where-Object { $_ -ne $nvmCurrentVersion }
        $versionsToRemove | ForEach-Object {
            & nvm uninstall $_
        }
    }
}
