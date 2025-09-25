Import-Module Functional
Import-Module Pester-ShouldBeDeep

function Test-IsWindowsServer 
{
    try 
    { 
        ((Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).ProductType -in 2,3) 
    }
    catch 
    { 
        $false 
    }
}

$script:IsWindowsServer = Test-IsWindowsServer

BeforeAll {
    . $PSScriptRoot\Set-DscResourceState.ps1

    function Assert-Type
    {
        param (
            [Parameter(Mandatory = $true)]
            $Resource,
    
            [Parameter(Mandatory = $true)]
            $Result
        )
    
        $Result.Type | Should -Be $Resource.Name
    }

    function Assert-Identifier
    {
        param (
            [Parameter(Mandatory = $true)]
            $Resource,
    
            [Parameter(Mandatory = $true)]
            $Result
        )
    
        $Result.Identifier | Should -BeDeeplyEqualPartial $Resource.Property
    }

    function Assert-TypeAndIdentifier
    {
        param (
            [Parameter(Mandatory = $true)]
            $Resource,
    
            [Parameter(Mandatory = $true)]
            $Result
        )
    
        Assert-Type -Resource $Resource -Result $Result
        Assert-Identifier -Resource $Resource -Result $Result
    }
}

Describe 'MyDscResourceState' {
    Context 'Set-DscResourceState' {
        It 'Returns InDesiredState = True for an existing resource' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'WinGetPackage'
                ModuleName = 'Microsoft.WinGet.DSC'
                Property   = @{
                    Id = 'Microsoft.PowerShell'
                }
            }

            # Act: Run the function to test
            $result = Set-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
        }
    }

    Context 'Set-DscResourceState specific cases' {
        It 'Sets desired state for WCF-HTTP-Activation Windows optional feature' -Skip:(!$script:IsWindowsServer) {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name     = 'WindowsOptionalFeature'
                Property = @{
                    Name = 'WCF-HTTP-Activation45'
                }
            }

            # Act: Run the function to test
            $result = Set-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.InDesiredState | Should -Be $true
        }

        It 'Sets desired state for CascadiaCode-NF-Mono Scoop package' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyScoopPackage'
                ModuleName = 'MyResources'
                Property   = @{
                    PackageName = 'CascadiaCode-NF-Mono'
                }
            }

            # Act: Run the function to test
            $result = Set-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.Result.RebootRequired | Should -Be $false
        }

        It 'Sets desired state for MyWindowsDefenderExclusion' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyWindowsDefenderExclusion'
                ModuleName = 'MyResources'
                Property   = @{
                    Type  = 'Path'
                    Value = 'C:\Projets'
                }
            }

            # Act: Run the function to test
            $result = Set-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.Result.RebootRequired | Should -Be $false
        }
    }
}
