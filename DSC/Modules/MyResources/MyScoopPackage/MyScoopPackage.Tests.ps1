Import-Module Functional
Import-Module Pester-ShouldBeDeep

BeforeAll {
    . $PSScriptRoot\MyScoopPackage.ps1
}

Describe 'MyScoopPackage' {
    Context 'Get-RawScoopList' {
        It 'Should return scoop list output' {
            # Act
            $scoopList = Get-RawScoopList

            # Assert
            $scoopList | Should -BeOfType '[PSCustomObject]'
            $scoopList | ForEach-Object {
                $_ | Should -BeOfType 'PSCustomObject'
                $_.PSObject.Properties | Where-Object { $_.Name -eq 'Name' } | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Get-RawScoopStatus' {
        It 'Should return scoop status output' {
            # Act
            $scoopStatus = Get-RawScoopStatus

            # Assert
            $scoopStatus | Should -BeOfType '[PSCustomObject]'
            if ($scoopStatus)
            {
                $scoopStatus | ForEach-Object {
                    $_ | Should -BeOfType 'PSCustomObject'
                    $_.PSObject.Properties | Where-Object { $_.Name -eq 'Name' } | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context 'Convert-ObjectArrayToHashtable' {
        It 'Should convert scoop list output to hashtable' {
            # Arrange
            $scoopList = Get-RawScoopList

            # Act
            $packages = Convert-ObjectArrayToHashtable $scoopList 'Name'

            # Assert
            $packages | Should -BeOfType 'Hashtable'
            $packages.Values | ForEach-Object {
                $_ | Should -BeOfType 'PSCustomObject'
                $_.PSObject.Properties | Where-Object { $_.Name -eq 'Version' } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should convert scoop status output to hashtable' {
            # Arrange
            $scoopStatus = Get-RawScoopStatus

            # Act
            $packages = Convert-ObjectArrayToHashtable $scoopStatus 'Name'

            # Assert
            $packages | Should -BeOfType 'Hashtable'
            $packages.Values | ForEach-Object {
                $_ | Should -BeOfType 'PSCustomObject'
                $_.PSObject.Properties | Where-Object { $_.Name -eq 'Installed Version' } | Should -Not -BeNullOrEmpty
                $_.PSObject.Properties | Where-Object { $_.Name -eq 'Latest Version' } | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Get-ScoopPackageInfo' {
        It 'Should return package info' {
            # Arrange
            $packageName = 'git'

            # Act
            $packageInfo = Get-ScoopPackageInfo $packageName

            # Assert
            $packageInfo | Should -BeOfType 'Hashtable'
            $packageInfo.Keys | Sort-Object | Should -Be @('Ensure', 'PackageName', 'Version')
            $packageInfo['Ensure'] | Should -Be 'Present'
            $packageInfo['Version'] | Should -Not -BeNullOrEmpty
            $packageInfo['Version'] | Should -Match '^\d+\.\d+\.\d+$'
        }

        It 'Should return package info for not installed package' {
            # Arrange
            $packageName = 'notarealpackage'

            # Act
            $packageInfo = Get-ScoopPackageInfo $packageName

            # Assert
            $packageInfo | Should -BeOfType 'Hashtable'
            $packageInfo.Keys | Sort-Object | Should -Be @('Ensure', 'PackageName', 'Version')
            $packageInfo['Ensure'] | Should -Be 'Absent'
            $packageInfo['Version'] | Should -BeNullOrEmpty
        }
    }

    Context 'Get-ScoopPackageLatestAvailableVersion' {
        It 'Should return latest available version' {
            # Arrange
            $packageName = 'dotnet-sdk'

            # Act
            $latestVersion = Get-ScoopPackageLatestAvailableVersion $packageName

            # Assert
            if ($latestVersion)
            {
                $latestVersion | Should -Match '^\d+\.\d+\.\d+$'
            }
        }
    }
}
