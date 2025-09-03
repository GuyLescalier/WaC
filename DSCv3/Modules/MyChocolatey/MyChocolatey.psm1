enum MyEnsure
{
    Absent
    Present
}

[DscResource()]
class MyChocolatey
{
    [DscProperty(Key)]
    [string] $MyChocolateyKey = 'MyChocolateyKey'

    [DscProperty()]
    [MyEnsure] $Ensure = [MyEnsure]::Present

    hidden [bool] IsInstalled()
    {
        return $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
    }

    hidden [string] GetChocolateyInstallPath()
    {
        $scopes = @([System.EnvironmentVariableTarget]::Machine, [System.EnvironmentVariableTarget]::User)
        foreach ($scope in $scopes)
        {
            $chocoPath = [System.Environment]::GetEnvironmentVariable('ChocolateyInstall', $scope)
            if ($chocoPath)
            {
                return $chocoPath
            }
        }
        return 'C:\ProgramData\chocolatey'
    }
    

    [MyChocolatey] Get()
    {
        $current = [MyChocolatey]::new()
        $current.Ensure = if ($this.IsInstalled())
        {
            [MyEnsure]::Present 
        }
        else
        {
            [MyEnsure]::Absent 
        }
        return $current
    }

    [bool] Test()
    {
        $current = $this.Get()
        return ($current.Ensure -eq $this.Ensure)
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }
    
        if ($this.Ensure -eq [MyEnsure]::Present)
        {
            # Install Chocolatey
            $script = Invoke-RestMethod -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing
            Invoke-Expression -Command $script
        }
        elseif ($this.Ensure -eq [MyEnsure]::Absent)
        {
            # Uninstall Chocolatey
            $chocoPath = $this.GetChocolateyInstallPath()
            Remove-Item -Path $chocoPath -Recurse -Force -ErrorAction SilentlyContinue
    
            # Remove environment variables
            $envVars = @('ChocolateyInstall', 'ChocolateyToolsLocation', 'ChocolateyLastPathUpdate')
            $scopes = @([System.EnvironmentVariableTarget]::Machine, [System.EnvironmentVariableTarget]::User)
            foreach ($envVar in $envVars)
            {
                foreach ($scope in $scopes)
                {
                    if ([System.Environment]::GetEnvironmentVariable($envVar, $scope))
                    {
                        [System.Environment]::SetEnvironmentVariable($envVar, $null, $scope)
                    }
                }
            }
        }
    }
      
}
