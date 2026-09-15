# This resource requires administrator privileges.

param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)

$script:EtcDirectory = Join-Path `
    -Path ([System.Environment]::GetEnvironmentVariable('SystemRoot')) `
    -ChildPath 'System32\drivers\etc'


function Remove-Diacritics {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$Text
    )

    process {
        $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)

        $sb = New-Object Text.StringBuilder

        $normalized.ToCharArray() | ForEach-Object {
            if (
                [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne
                [Globalization.UnicodeCategory]::NonSpacingMark
            ) {
                [void]$sb.Append($_)
            }
        }

        return $sb.ToString()
    }
}


function Get-HostsFilePath {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $fileName = $Name -replace '\s', ''
    $fileName = $fileName | Remove-Diacritics

    return Join-Path `
        -Path $script:EtcDirectory `
        -ChildPath "$fileName.hosts"
}


function Test-MatchingHash {
    param(
        [Parameter(Mandatory)]
        [string]$SourceFile,

        [Parameter(Mandatory)]
        [string]$TargetFile
    )

    if (
        -not (Test-Path -Path $SourceFile) -or
        -not (Test-Path -Path $TargetFile)
    ) {
        return $false
    }

    $sourceFileHash = (Get-FileHash -Path $SourceFile).Hash
    $targetFileHash = (Get-FileHash -Path $TargetFile).Hash

    return $sourceFileHash -eq $targetFileHash
}


function Test-ContentInHostsFile {
    param(
        [Parameter(Mandatory)]
        [string]$HostsFilePath
    )

    if (-not (Test-Path -Path $HostsFilePath)) {
        return $false
    }

    $systemHostsPath = Join-Path -Path $script:EtcDirectory -ChildPath 'hosts'

    if (-not (Test-Path -Path $systemHostsPath)) {
        return $false
    }

    $systemHostsContent = Get-Content -Path $systemHostsPath -Raw
    $hostsFileContent = Get-Content -Path $HostsFilePath -Raw

    $hostsFileContent = $hostsFileContent -replace '^\s*\r?\n|\r?\n\s*$'

    return $systemHostsContent.Contains($hostsFileContent)
}


function Merge-HostsFiles {

    $systemHosts = Join-Path -Path $script:EtcDirectory -ChildPath 'hosts'

    $defaultBackupPath = Join-Path -Path $script:EtcDirectory -ChildPath 'default.hosts'


    # Ensure default backup exists
    if (-not (Test-Path -Path $defaultBackupPath)) {
        Copy-Item `
            -Path $systemHosts `
            -Destination $defaultBackupPath
    }


    # Start with the content of default.hosts
    $allHostsContent = Get-Content `
        -Path $defaultBackupPath `
        -Raw

    $allHostsContent = $allHostsContent -replace '^\s*\r?\n|\r?\n\s*$'
    $allHostsContent += "`n"


    # Get all resource-specific hosts files
    $allHostsFiles = Get-ChildItem `
        -Path $script:EtcDirectory `
        -Filter '*.hosts' |
    Where-Object {
        $_.Name -ne 'default.hosts'
    }


    foreach ($file in $allHostsFiles) {

        $fileNameWithoutExtension =
        [System.IO.Path]::GetFileNameWithoutExtension(
            $file.Name
        )

        $header =
        '##################################################' + "`n" +
        "# $fileNameWithoutExtension" + "`n" +
        '##################################################' + "`n`n"


        $fileContent = Get-Content -Path $file.FullName -Raw

        $fileContent =
        $fileContent -replace '^\s*\r?\n|\r?\n\s*$'


        $allHostsContent +=
        "`n" +
        $header +
        $fileContent
    }
    # Rewrite the Windows hosts file
    Set-Content -Path $systemHosts -Value $allHostsContent
}


function Get-ResourceState {
    param($InputObject)

    $hostsFilePath = Get-HostsFilePath -Name $InputObject.name
    $ensure = 'Absent'

    if ( (Test-MatchingHash -SourceFile $hostsFilePath -TargetFile $InputObject.path) -and (Test-ContentInHostsFile -HostsFilePath $hostsFilePath)) {
        $ensure = 'Present'
    }


    $state = @{
        name   = $InputObject.name
        path   = $InputObject.path
        ensure = $ensure
    }


    return $state
}

function Test-ResourceState {
    param($InputObject)
    
    $currentState = Get-ResourceState -InputObject $InputObject
    $desiredEnsure = $InputObject.ensure
        
    $inDesiredState = ($currentState.ensure -eq $desiredEnsure)
        
    $currentState._inDesiredState = $inDesiredState
    return $currentState

}

function Set-ResourceState {
    param($InputObject)

    $testResult = Test-ResourceState -InputObject $InputObject


    if ($testResult._inDesiredState) {
        return
    }

    $hostsFilePath = Get-HostsFilePath -Name $InputObject.name

    if ($InputObject.ensure -eq 'Present') {

        # Copy source hosts file if different
        if (-not ( Test-MatchingHash -SourceFile $hostsFilePath -TargetFile $InputObject.path)) {
            Copy-Item -Path $InputObject.path -Destination $hostsFilePath -Force
        }
    }

    elseif ($InputObject.ensure -eq 'Absent') {

        if (Test-Path -Path $hostsFilePath) {
            Remove-Item -Path $hostsFilePath -Force
        }
    }

    # Rebuild the Windows hosts file
    Merge-HostsFiles
}

try {
    $inputJson = [Console]::In.ReadToEnd()
    $inputObject = $inputJson | ConvertFrom-Json

    $result = switch ($Operation) {
        'Get' { Get-ResourceState -InputObject $inputObject }
        'Test' { Test-ResourceState -InputObject $inputObject }
        'Set' { Set-ResourceState -InputObject $inputObject }
    }

    $jsonOutput = $result | ConvertTo-Json -Compress -Depth 10
    Write-Output $jsonOutput

    exit 0

}
catch {
    $errorJson = @{
        message   = $_.Exception.Message
        operation = $Operation
        level     = "error"
    } | ConvertTo-Json -Compress

    Write-Error $errorJson
    exit 1
}