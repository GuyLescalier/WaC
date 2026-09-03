param(
    [Parameter(Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation = 'Get'
)

function Get-ResourceState {
    param($InputObject)
    
    $name = $InputObject.name
    $type = $InputObject.type
    $value = $InputObject.value

    $preference = Get-MpPreference
    $exclusionProperty = "Exclusion$($type)"
    $exclusions = $preference.$exclusionProperty

    if ($exclusions -contains $value) {
        $ensure = 'Present' 
    }
    else {
        $ensure = 'Absent' 
    }

    return @{ 
        name   = $name 
        type   = $type
        value  = $value
        ensure = $ensure
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

    $parameterName = "Exclusion$($testResult.type)"
    $parameters = @{
        $parameterName = $testResult.value
    }

    if ($testResult.ensure -eq 'Absent') { 
        Add-MpPreference @parameters
    }
    else {
        Remove-MpPreference @parameters
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