param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)

function Test-GitInstalled {
    try {
        Get-Command git -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}


function Test-ScoopBucketInstalled { 
    param($InputObject) 
    try { 
        $buckets = scoop bucket list 
        return $buckets.name -contains $InputObject.name 
    } 
    catch {
        return $false 
    } 
}



function Get-ResourceState {
    param($InputObject)
    
    $name = $InputObject.name
    $isInstalled = Test-ScoopBucketInstalled -InputObject $inputObject

    return @{ 
        name   = $name 
        ensure = if ($isInstalled) { 'Present' } else { 'Absent' } 
    } 
}


function Test-ResourceState {
    param($InputObject)
    $currentState = Get-ResourceState -InputObject $inputObject
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

    $ensure = $InputObject.ensure

    if ($ensure -eq 'Present') { 

        if (-not (Test-GitInstalled)) {
            scoop install git
        }

        scoop bucket add $InputObject.name
    
    } 
    else {
        scoop bucket rm $InputObject.name 
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