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

function Ensure-GitInstalled {
    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
        scoop "install" git
    }
}


function Get-LatestVersion {
    param(
        [Parameter(Mandatory)]
        [string]$pkgName
    )

    Ensure-GitInstalled
   
    scoop "update"

    $manifest = scoop "cat" $pkgName | ConvertFrom-Json
    $version = $manifest.version

    return $version    
}

function Get-ResourceState {
    param($InputObject)

    $pkgName = $InputObject.packageName

    $pkgInfo = scoop "info" $pkgName 6>$null

    if ($null -eq $pkgInfo.Name) {
        throw "Could not find manifest for '$pkgName' in local buckets."
    }


    if ($null -eq $pkgInfo.Installed) {

        return @{
            packageName = $pkgName
            ensure      = 'Absent'
        }
    }

    if ($InputObject.version -eq 'latest') {
        $version = Get-LatestVersion -pkgName $pkgName
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

function Test-ResourceState {
    param($InputObject)

    $currentState = Get-ResourceState -InputObject $InputObject
    $desiredEnsure = $InputObject.ensure

    $currentState._inDesiredState = ($currentState.ensure -eq $desiredEnsure)

    return $currentState
}

# TODO: Handle version downgrade scenario 
function Set-ResourceState {
    param($InputObject)

    $pkgName = $InputObject.packageName

    if ($InputObject.ensure -eq 'Absent') {
        scoop "uninstall" $pkgName
        return
    }
        
    $currentState = Get-ResourceState -InputObject $InputObject

    if ($InputObject.version -eq 'latest') {
        $version = Get-LatestVersion -pkgName $pkgName
    }
    else {
        $version = $InputObject.version
    }

    $installArg = if ($version -ne 'latest') { "$pkgName@$version" } else { $pkgName }

    if ($currentState.ensure -eq 'Absent') {
        scoop "install" $installArg
    }
    else {
        Ensure-GitInstalled

        scoop "update" $installArg
    }


}

try {
    Assert-ScoopIsInstalled

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