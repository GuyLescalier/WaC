using namespace System.Security.Cryptography.X509Certificates

enum MyEnsure
{
    Absent
    Present
}

[DscResource()]
class MyCertificate
{
    [DscProperty(Key)]
    [string]$Path

    [DscProperty(NotConfigurable)]
    [string]$Thumbprint

    [DscProperty()]
    [string]$Location = 'LocalMachine'

    [DscProperty()]
    [string]$StoreName = 'Root'

    [DscProperty()]
    [MyEnsure]$Ensure = [MyEnsure]::Present

    [MyCertificate] Get()
    {
        $current = [MyCertificate]::new()
        $current.Path = $this.Path
        "C:\\Projets\\WaC\\Certificats\\Autorite de Certification Region SUD Provence-Alpes-Cote d'Azur.crt"
        $fileCert = [X509Certificate2]::new($this.Path)
        $current.Thumbprint = $fileCert.Thumbprint

        $storeCert = $this.GetCertificate($fileCert.Thumbprint)
        $current.Ensure = $null -ne $storeCert ? [MyEnsure]::Present : [MyEnsure]::Absent

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
            $this.InstallCertificate()
        }
        elseif ($this.Ensure -eq [MyEnsure]::Absent)
        {
            $this.RemoveCertificate()
        }
    }

    hidden [void] InstallCertificate()
    {
        Write-Verbose "Installing certificate with thumbprint $($this.Thumbprint) to $($this.StoreName) store in $($this.Location) location."
        Import-Certificate -FilePath $this.Path -CertStoreLocation "Cert:\$($this.Location)\$($this.StoreName)"
    }

    hidden [void] RemoveCertificate()
    {
        Write-Verbose "Removing certificate with thumbprint $($this.Thumbprint) from $($this.StoreName) store in $($this.Location) location."
        $cert = $this.GetCertificate($this.Thumbprint)
        if ($null -ne $cert)
        {
            Remove-Item $cert.PSPath
        }
    }

    hidden [X509Certificate2] GetCertificate([string]$thumbprint)
    {
        try
        {
            return Get-ChildItem -Path "Cert:\$($this.Location)\$($this.StoreName)\$($thumbprint)" -ErrorAction Stop
        }
        catch
        {
            return $null
        }
    }
}
