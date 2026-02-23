param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)

function Get-ResourceState {
    param($InputObject)

    $pkgName = $InputObject.packageName

    $jsonStr = scoop export | Out-String
    $installed = $false
    $currentVersion = $null

    if ($jsonStr) {
        try {
            $data = $jsonStr | ConvertFrom-Json
            $appInfo = $data.apps | Where-Object { $_.Name -eq $pkgName }
            if ($appInfo -and $appInfo.Info -notmatch 'failed') {
                $installed = $true
                $currentVersion = $appInfo.Version
            }
        } catch {}
    }

    return @{
        packageName      = $pkgName
        ensure           = if ($installed) { 'Present' } else { 'Absent' }
        version          = $InputObject.version ?? 'latest'
        installedVersion = $currentVersion
    }
}

function Test-ResourceState {
    param($InputObject)

    $currentState  = Get-ResourceState -InputObject $InputObject
    $desiredEnsure = $InputObject.ensure ?? 'Present'

    $inDesiredState = ($currentState.ensure -eq $desiredEnsure)

    if ($inDesiredState -and $desiredEnsure -eq 'Present' -and $InputObject.version -and $InputObject.version -ne 'latest') {
        $inDesiredState = ($currentState.installedVersion -eq $InputObject.version)
    }

    $currentState._inDesiredState = $inDesiredState
    return $currentState
}

function Set-ResourceState {
    param($InputObject)

    $pkgName       = $InputObject.packageName
    $desiredEnsure = $InputObject.ensure ?? 'Present'
    $version       = $InputObject.version ?? 'latest'
    $currentState  = Get-ResourceState -InputObject $InputObject

    if ($desiredEnsure -eq 'Present') {
        $installArg = if ($version -ne 'latest') { "$pkgName@$version" } else { $pkgName }
        scoop install $installArg
    }
    elseif ($desiredEnsure -eq 'Absent') {
        scoop uninstall $pkgName
    }
}


$inputJson   = [Console]::In.ReadToEnd()
$inputObject = $inputJson | ConvertFrom-Json

$result = switch ($Operation) {
    'Get' { Get-ResourceState -InputObject $inputObject }
    'Test' { Test-ResourceState -InputObject $inputObject }
    'Set' { Set-ResourceState -InputObject $inputObject }
}

$jsonOutput = $result | ConvertTo-Json -Compress -Depth 10
Write-Output $jsonOutput

exit 0