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

function Test-GitInstalled {
    try {
        Get-Command git -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}


function convert-latestToVersion {
    param(
        [Parameter(Mandatory)]
        [string]$pkgName
    )

    $manifest = scoop cat $pkgName | ConvertFrom-Json
    $version = $manifest.version

    return $version    
}

function Get-ResourceState {
    param($InputObject)

    Assert-ScoopIsInstalled

    $pkgName = $InputObject.packageName

    $pkgInfo = scoop "info" $pkgName 6>$null

    if ($null -eq $pkgInfo.Name) {
        throw "Could not find manifest for '$PkgName' in local buckets."
    }


    if ($null -ne ($pkgInfo.Installed) ) {

        if ($InputObject.version -eq 'latest') {
            $version = convert-latestToVersion -pkgName $pkgName
        }
        else {
            $version = $InputObject.version
        }

        $state = if ($pkgInfo.Installed -eq $version) { 'Present' } else { 'Stale' }

        return @{
            packageName      = $pkgName
            ensure           = $state
            version          = $InputObject.version
            installedVersion = $pkgInfo.Installed
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

# TODO: Handle version downgrade scenario 
function Set-ResourceState {
    param($InputObject)

    Assert-ScoopIsInstalled

    $pkgName = $InputObject.packageName

    if ($InputObject.ensure -eq 'Present') {
        
        $currentState = Get-ResourceState -InputObject $InputObject

        if ($InputObject.version -eq 'latest') {
            $version = convert-latestToVersion -pkgName $pkgName
        }
        else {
            $version = $InputObject.version
        }

        $installArg = if ($version -ne 'latest') { "$pkgName@$version" } else { $pkgName }

        if ($currentState.ensure -eq 'Absent') {
            scoop "install" $installArg
        }
        else {
            if (-not (Test-GitInstalled)) {
                scoop install git
            }
            scoop "update" $installArg
        }

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