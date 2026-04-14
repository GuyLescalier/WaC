param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)

function Assert-ScoopIsInstalled {
    if ($null -eq (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw "Scoop is not installed."
    }
}

function Assert-PackageInfoIsValid {
    param (
        [Parameter(Mandatory)]
        $PackageInfo,

        [Parameter(Mandatory)]
        [string]$PackageName
    )
    
    if ($null -eq $pkgInfo.Name) {
        throw "Could not find manifest for '$pkgName' in local buckets."
    }
    
}

function Get-ResourceState {
    param($InputObject)

    Assert-ScoopIsInstalled

    $pkgName = $InputObject.packageName

    $pkgInfo = scoop "info" $pkgName 6>$null

    Assert-PackageInfoIsValid -PackageInfo $pkgInfo -PackageName $pkgName


    if ($null -ne ($pkgInfo.Installed) ) {
        return @{
            packageName      = $pkgName
            ensure           = 'Present'
            version          = $InputObject.version
            installedVersion = $pkgInfo.Version
        }
    }
    else {
        return @{
            packageName = $pkgName
            ensure      = 'Absent'
        }
    }
}

function Test-ResourceState {
    param($InputObject)

    Assert-ScoopIsInstalled

    $currentState = Get-ResourceState -InputObject $InputObject

    $desiredEnsure = $InputObject.ensure

    $inDesired = ($currentState.ensure -eq $desiredEnsure)

    # If the package should be present and a specific version is requested,
    # verify that the installed version matches the expected version.

    if ( ($inDesired) -and ($desiredEnsure -eq 'Present') -and ($InputObject.version -ne 'latest') ) {
        $inDesired = ($currentState.installedVersion -eq $InputObject.version)
    }

    $currentState._inDesiredState = $inDesired
    return $currentState
}

function Set-ResourceState {
    param($InputObject)

    Assert-ScoopIsInstalled

    $pkgName = $InputObject.packageName
    $desiredEnsure = $InputObject.ensure

    if ($desiredEnsure -eq 'Present') {

        $version = $InputObject.version

        $installArg = if ($version -ne 'latest') { "$pkgName@$version" } else { $pkgName }

        scoop "install" $installArg
    }
    else {
        scoop "uninstall" $pkgName
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