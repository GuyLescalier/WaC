enum MyEnsure
{
    Absent
    Present
}

enum ExclusionType
{
    Path
    Extension
    Process
    IpAddress
}

[DscResource()]
class MyWindowsDefenderExclusion
{
    [DscProperty(Key)]
    [string]$Name = 'WindowsDefenderPreference'

    [DscProperty(Key)]
    [ExclusionType]$Type

    [DscProperty(Key)]
    [string]$Value

    [DscProperty()]
    [MyEnsure]$Ensure = [MyEnsure]::Present

    [MyWindowsDefenderExclusion] Get()
    {
        $current = [MyWindowsDefenderExclusion]::new()
        $current.Name = $this.Name
        $current.Type = $this.Type
        $current.Value = $this.Value

        $preference = Get-MpPreference
        $exclusionProperty = "Exclusion$($this.Type)"
        $exclusions = $preference.$exclusionProperty

        if ($exclusions -contains $this.Value)
        {
            $current.Ensure = [MyEnsure]::Present
        }
        else
        {
            $current.Ensure = [MyEnsure]::Absent
        }

        return $current
    }

    [bool] Test()
    {
        $current = $this.Get()
        return $current.Ensure -eq $this.Ensure
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }
    
        $parameterName = "Exclusion$($this.Type)"
        $parameters = @{
            $parameterName = $this.Value
        }
    
        if ($this.Ensure -eq [MyEnsure]::Present)
        {
            Add-MpPreference @parameters
        }
        elseif ($this.Ensure -eq [MyEnsure]::Absent)
        {
            Remove-MpPreference @parameters
        }
    }
}
