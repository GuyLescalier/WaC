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
    
    $output = choco list $PackageName --exact --limit-output --no-progress 2>$null

    if ($output -notmatch '^(?<name>[^|]+)\|(?<version>[^|]+)$') {
        return @{
            packageName      = $PackageName
            installedVersion = $null
        }
    }

    return @{
        packageName      = $PackageName
        installedVersion = $matches.version
    }
}

function Get-LatestVersion {
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    $output = choco search $PackageName --exact --limit-output --no-progress 2>$null

    if ($output -notmatch '^[^|]+\|(?<version>[^|]+)$') {
        throw "Could not find package '$PackageName' in Chocolatey sources."
    }
    return $matches.version
}

function Get-ResourceState {
    param($InputObject)
    
    $packageName = $InputObject.packageName
    $desiredVersion = $InputObject.version

    $pkgInfo = Get-ChocolateyPackageInfo -PackageName $packageName
    $latestVersion = Get-LatestVersion -PackageName $packageName


    if ($null -eq $pkgInfo.installedVersion) {
        return @{
            packageName      = $packageName
            ensure           = 'Absent'
            version          = $desiredVersion
            installedVersion = $null
            latestVersion    = $latestVersion
            state            = 'Unknown'
        }
    }

    $state = if ($pkgInfo.installedVersion -eq $latestVersion) { 'Current' } else { 'Stale' }

    return @{
        packageName      = $packageName
        ensure           = 'Present'
        version          = $desiredVersion
        installedVersion = $pkgInfo.installedVersion
        latestVersion    = $latestVersion
        state            = $state
    }
}

function Test-ResourceState {
    param($InputObject)

    $currentState = Get-ResourceState -InputObject $InputObject

    if ($InputObject.ensure -eq 'Absent') {
        $currentState._inDesiredState = ($currentState.ensure -eq 'Absent')
        return $currentState
    }

    if ($currentState.ensure -eq 'Absent') {
        $currentState._inDesiredState = $false
        return $currentState
    }

    if ($InputObject.version -eq 'latest') {
        $currentState._inDesiredState =
        ($currentState.installedVersion -eq $currentState.latestVersion)

        return $currentState
    }

    $currentState._inDesiredState =
    ($currentState.installedVersion -eq $InputObject.version)

    return $currentState
}

function Set-ResourceState {
    param($InputObject)

    $testResult = Test-ResourceState -InputObject $InputObject

    if ($testResult._inDesiredState) {
        return
    }

    $pkgName = $InputObject.packageName
    $desiredEnsure = $InputObject.ensure
    $desiredVersion = $InputObject.version

    if ($desiredEnsure -eq 'Present') {
        if ($desiredVersion -ne 'latest') {
            & choco upgrade $pkgName "--version=$desiredVersion" -y
        }
        else {
            & choco upgrade $pkgName -y
        }
        return
    }

    if ($testResult.ensure -eq 'Present') {
        & choco uninstall $pkgName -y
    }
}

try {
    Assert-ChocolateyIsInstalled
    
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