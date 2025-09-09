enum MyEnsure
{
    Absent
    Present
}

[DscResource()]
class MyPSProfile
{
    [DscProperty(Key)]
    [string]$Name

    [DscProperty()]
    [string]$Path

    [DscProperty(Mandatory)]
    [MyEnsure]$Ensure = [MyEnsure]::Present

    # hidden [string] $EtcDirectory = [System.Environment]::GetEnvironmentVariable('SystemRoot') + '\System32\drivers\etc'

    # hidden [string] GetHostsFilePath()
    # {
    #     $fileName = $this.Name -replace '\s', '' | Remove-Diacritics
    #     return Join-Path -Path $this.EtcDirectory -ChildPath "$fileName.hosts"
    # }

    # hidden [bool] HasMatchingHash([string]$sourceFile, [string]$targetFile)
    # {
    #     if (-not (Test-Path -Path $sourceFile) -or
    #         -not (Test-Path -Path $targetFile))
    #     {
    #         return $false
    #     }

    #     $sourceFileHash = (Get-FileHash -Path $sourceFile).Hash
    #     $targetFileHash = (Get-FileHash -Path $targetFile).Hash

    #     return $sourceFileHash -eq $targetFileHash
    # }

    hidden [bool] IsScriptInProfile([string]$expectedScriptHeader, [string]$expectedScriptCall)
    {
        $systemProfilePath = $global:PROFILE.CurrentUserAllHosts

        $headerIndex = 0
        $found = $false
        $scriptCall = $null
        Get-Content -Path $systemProfilePath | ForEach-Object -Process {
            $headerIndex++
            if ($found)
            {
                $function:scriptCall = $_
                break
            }
            if ($_ -match $expectedScriptHeader)
            {
                $found = $true
            }
        }

        if (-not $scriptCall)
        {
            return $false
        }

        return $scriptCall -eq $expectedScriptCall
    }

    # hidden [void] MergeHostsFiles()
    # {
    #     $systemHosts = Join-Path -Path $this.EtcDirectory -ChildPath 'hosts'
    #     $defaultBackupPath = Join-Path -Path $this.EtcDirectory -ChildPath 'default.hosts'

    #     # Ensure default backup exists
    #     if (-not (Test-Path -Path $defaultBackupPath))
    #     {
    #         Copy-Item -Path $systemHosts -Destination $defaultBackupPath
    #     }

    #     # Start with the content of default.hosts file
    #     $allHostsContent = Get-Content -Path $defaultBackupPath -Raw
    #     $allHostsContent = $allHostsContent -replace '^\s*\r\n|\r\n\s*$'
    #     $allHostsContent += "`n"

    #     # Concatenate all other *.hosts files, with headers
    #     $allHostsFiles = Get-ChildItem -Path $this.EtcDirectory -Filter '*.hosts' | Where-Object { $_.Name -ne 'default.hosts' }

    #     foreach ($file in $allHostsFiles)
    #     {
    #         $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    #         $header = '##################################################' + "`n" +
    #         "# $fileNameWithoutExtension" + "`n" +
    #         '##################################################' + "`n`n"

    #         $fileContent = Get-Content -Path $file.FullName -Raw
    #         $fileContent = $fileContent -replace '^\s*\r\n|\r\n\s*$'

    #         # Append the header and content
    #         $allHostsContent += "`n" + $header + $fileContent
    #     }

    #     # Write the concatenated content to the system hosts file
    #     Set-Content -Path $systemHosts -Value $allHostsContent
    # }

    [MyPSProfile] Get()
    {
        $current = [MyPSProfile]::new()
        $current.Name = $this.Name
        $current.Path = $this.Path
        $current.Ensure = [MyEnsure]::Absent

        $scriptHeader = "# WAC - $($this.Name)"
        $scriptCall = ". '$($this.Path)'"

        if ($this.IsScriptInProfile($scriptHeader, $scriptCall))
        {
            $current.Ensure = [MyEnsure]::Present
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

        # $hostsFilePath = $this.GetHostsFilePath()
        # if ($this.Ensure -eq [MyEnsure]::Present)
        # {
        #     # Copy the source hosts file if it's different from the current one.
        #     if (-not $this.HasMatchingHash($hostsFilePath, $this.Path))
        #     {
        #         Copy-Item -Path $this.Path -Destination $hostsFilePath -Force
        #     }
        # }
        # elseif ($this.Ensure -eq [MyEnsure]::Absent)
        # {
        #     if (Test-Path -Path $hostsFilePath)
        #     {
        #         Remove-Item -Path $hostsFilePath
        #     }        
        # }

        # # Merge all hosts files into the system hosts file
        # $this.MergeHostsFiles()
    }
}

function Remove-Diacritics
{
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$Text
    )
    process
    {
        $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
        $sb = New-Object Text.StringBuilder

        $normalized.ToCharArray() | ForEach-Object {
            if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark)
            {
                [void]$sb.Append($_)
            }
        }

        return $sb.ToString()
    }
}