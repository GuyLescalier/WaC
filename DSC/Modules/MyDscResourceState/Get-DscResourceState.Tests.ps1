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
    . $PSScriptRoot\Get-DscResourceState.ps1

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
    Context 'Get-DscResourceState' {
        It 'Does not get the state of a non-existing registry value' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name     = 'Registry'
                Property = @{
                    ValueName = 'NonExistingValue'
                    Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion'
                }
            }

            $expected = @{
                ValueType = $null
                ValueData = $null
                Ensure    = 'Absent'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of an existing registry value' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name     = 'Registry'
                Property = @{
                    ValueName = 'ProgramFilesDir'
                    Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion'
                }
            }

            $expected = @{
                ValueType = 'String'
                ValueData = 'C:\Program Files'
                Ensure    = 'Present'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of an existing Windows optional feature' -Skip:(!$script:IsWindowsServer) {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name     = 'WindowsOptionalFeature'
                Property = @{
                    Name = 'IIS-ApplicationDevelopment'
                }
            }

            $expected = @{
                Ensure = 'Present'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of Scoop' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyScoop'
                ModuleName = 'MyResources'
            }

            $expected = @{
                Ensure = 'Present'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-Type -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of a Scoop package' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyScoopPackage'
                ModuleName = 'MyResources'
                Property   = @{
                    PackageName = 'git'
                }
            }

            $expected = @{
                # State         = 'Stale'
                # Version       = '2.42.0.2'
                Ensure = 'Present'
                # LatestVersion = '2.43.0'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of Chocolatey' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyChocolatey'
                ModuleName = 'MyResources'
            }

            $expected = @{
                Ensure = 'Present'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-Type -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of a Chocolatey package' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyChocolateyPackage'
                ModuleName = 'MyResources'
                Property   = @{
                    PackageName = '7zip'
                }
            }

            $expected = @{
                # State         = 'Current'
                # Version       = '23.1.0'
                Ensure = 'Present'
                # LatestVersion = '23.1.0'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of a WinGet package' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'WinGetPackage'
                ModuleName = 'Microsoft.WinGet.DSC'
                Property   = @{
                    Id = 'Fork.Fork'
                }
            }

            $expected = @{
                # Source            = $null
                # Version           = $null
                Ensure      = 'Present'
                # InstalledVersion  = '1.92.0'
                # MatchOption       = 1
                # IsInstalled       = $true          # No longer existing in WinGetPackage
                # UseLatest         = $false
                # InstallMode       = 1
                # IsUpdateAvailable = $false                
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of Visual Studio' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'VSComponents'
                ModuleName = 'Microsoft.VisualStudio.DSC'
                Property   = @{
                    productId = 'Microsoft.VisualStudio.Product.Enterprise'
                    channelId = 'VisualStudio.17.Release'
                    # vsConfigFile       = 'C:\Projets\WaC\resources\visual-studio\.vsconfig'
                    # includeRecommended = $true
                }
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State.installedComponents | Should -Not -BeNullOrEmpty
        }

        It 'Gets the state of a certificate' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyCertificate'
                ModuleName = 'MyResources'
                Property   = @{
                    Path = 'C:\WaC\resources\certificates\_.cr-paca.fr.crt'
                }
            }

            $expected = @{
                # Thumbprint = '3D30B009E3FA41AEBF125824E58B1C8692E94E0B'
                StoreName = 'Root'
                Location  = 'LocalMachine'
                Ensure    = 'Present'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of a Windows Defender exclusion' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyWindowsDefenderExclusion'
                ModuleName = 'MyResources'
                Property   = @{
                    Type  = 'Path'
                    Value = 'C:\Wac'
                }
            }

            $expected = @{
                Ensure = 'Present'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of a Node version' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyNodeVersion'
                ModuleName = 'MyResources'
                Property   = @{
                    Version = 'lts'
                }
            }

            $expected = @{
                Ensure = 'Used'
                State  = 'Current'
                # CurrentVersion = '20.10.0'
                # LatestVersion  = '20.10.0'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource -Verbose

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }

        It 'Gets the state of the hosts file' {
            # Arrange: Set up any preconditions and inputs
            $resource = @{
                Name       = 'MyHosts'
                ModuleName = 'MyResources'
                Property   = @{
                    Name = 'RégionSUD'
                    Path = 'C:\WaC\resources\hosts'
                }
            }

            $expected = @{
                Ensure = 'Present'
            }

            # Act: Run the function to test
            $result = Get-DscResourceState $resource -Verbose

            # Assert: Verify the function did what it's supposed to
            Assert-TypeAndIdentifier -Resource $resource -Result $result
            $result.State | Should -BeDeeplyEqualPartial $expected
        }
    }
}
