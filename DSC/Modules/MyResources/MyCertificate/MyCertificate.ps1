using namespace System.Security.Cryptography.X509Certificates

param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)


function InstallCertificate() {
    param($InputObject)

    Write-Verbose "Installing certificate with thumbprint $($InputObject.Thumbprint) to $($InputObject.StoreName) store in $($InputObject.Location) location."
    Import-Certificate -FilePath $InputObject.Path -CertStoreLocation "Cert:\$($InputObject.Location)\$($InputObject.StoreName)"

}

function RemoveCertificate {
    param($InputObject)

    Write-Verbose "Removing certificate with thumbprint $($InputObject.Thumbprint) from $($InputObject.StoreName) store in $($InputObject.Location) location."
    $cert = GetCertificate -InputObject $InputObject -Thumbprint $InputObject.Thumbprint
    if ($null -ne $cert) {
        Remove-Item $cert.PSPath
    }

}

function GetCertificate {
    param($InputObject , $Thumbprint)

    try {
        return Get-ChildItem -Path "Cert:\$($InputObject.Location)\$($InputObject.StoreName)\$($Thumbprint)" -ErrorAction Stop
    }
    catch {
        return $null
    }

}

function Get-ResourceState {
    param($InputObject)

    $Path = $InputObject.Path

    $fileCert = [X509Certificate2]::new($Path)
    $Thumbprint = $fileCert.Thumbprint

    $storeCert = GetCertificate -InputObject $InputObject -Thumbprint $Thumbprint

    return @{
        Path       = $Path
        Thumbprint = $Thumbprint
        Ensure     = if ($null -ne $storeCert) { 'Present' } else { 'Absent' }
        Location   = $InputObject.Location
        StoreName  = $InputObject.StoreName
    }

}

function Test-ResourceState {
    param($InputObject)

    $currentState = Get-ResourceState -InputObject $InputObject
    $desiredEnsure = $InputObject.Ensure
        
    $inDesiredState = ($currentState.Ensure -eq $desiredEnsure)
        
    $currentState._inDesiredState = $inDesiredState
    return $currentState
}

function Set-ResourceState {
    param($InputObject)

    $testResult = Test-ResourceState -InputObject $InputObject

    if ($testResult._inDesiredState) {
        return
    }

    if ( !($testResult.Ensure -eq 'Present') ) {
        InstallCertificate -InputObject $InputObject
    }
    else {
        RemoveCertificate -InputObject $testResult
    }

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