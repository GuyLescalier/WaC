param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)


function Assert-ChocolateyIsInstalled {
    if ($null -eq (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw "Chocolatey is not installed. Please install Chocolatey first."
    }
}

function Get-ChocolateyPackageInfo {
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )
    
    Assert-ChocolateyIsInstalled

    $output = choco list $PackageName --exact --limit-output --no-progress 2>$null

    if ($output -match '^(?<name>[^|]+)\|(?<version>[^|]+)$') {
        return @{
            packageName      = $PackageName
            installedVersion = $matches.version
        }
    }

    return @{
        packageName      = $PackageName
        installedVersion = $null
    }
}

function Get-LatestVersion {
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    $output = choco search $PackageName --exact --limit-output --no-progress 2>$null

    if ($output -match '^[^|]+\|(?<version>[^|]+)$') {
        return $matches.version
    }

    throw "Could not find package '$PackageName' in Chocolatey sources."
}

function Get-ResourceState {
    param($InputObject)

    $packageName = $InputObject.packageName
    $desiredVersion = $InputObject.version
    $pkgInfo = Get-ChocolateyPackageInfo -PackageName $packageName

    if ($null -eq $pkgInfo.installedVersion) {
        return @{
            packageName      = $packageName
            ensure           = 'Absent'
            version          = $desiredVersion
            installedVersion = $null
        }
    }

    $expectedVersion = if ($desiredVersion -eq 'latest') {
        Get-LatestVersion -PackageName $packageName
    }
    else {
        $desiredVersion
    }

    $state = if ($pkgInfo.installedVersion -eq $expectedVersion) {
        'Present'
    }
    else {
        'Stale'
    }

    return @{
        packageName      = $packageName
        ensure           = $state
        version          = $desiredVersion
        installedVersion = $pkgInfo.installedVersion
    }
}

function Test-ResourceState {
    param($InputObject)

    Assert-ScoopIsInstalled

    $currentState = Get-ResourceState -InputObject $InputObject
    $desiredEnsure = $InputObject.ensure

    $inDesired = $false

    if ($desiredEnsure -eq 'Present') {
        $inDesired = ($currentState.ensure -eq 'Present')
    }
    elseif ($desiredEnsure -eq 'Absent') {
        $inDesired = ($currentState.ensure -eq 'Absent')
    }

    $currentState._inDesiredState = $inDesired
    return $currentState
}

function Set-ResourceState {
    param($InputObject)

    Assert-ScoopIsInstalled

    $target = $InputObject.packageName

    if ($InputObject.ensure -eq 'Present') {

        if ($InputObject.version -ne 'latest') {
            $target += " --version $($InputObject.Version)"
        }
        # If you do not have a package installed, upgrade will install it.
        & choco upgrade $target -y
    }
    else {
        & choco uninstall $target -y
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