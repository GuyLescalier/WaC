#requires -Module Pester
#requires -RunAsAdministrator

Import-Module Functional
Import-Module Pester-ShouldBeDeep

BeforeAll {
    Get-ChildItem -Path "$PSScriptRoot\*.ps1" -Exclude '*.Tests.ps1' | ForEach-Object { . $_.FullName }

    $script:testVersion = '20.1.0'
    $script:testVersionStale = '20.0.0'

    & nvm install $script:testVersion
    & nvm install $script:testVersionStale
    $script:originalVersion = & nvm current
    & nvm use $script:testVersion
}

AfterAll {
    & nvm uninstall $script:testVersion
    & nvm uninstall $script:testVersionStale
    & nvm use $script:originalVersion
}

Describe 'MyNodeVersion helpers' {
    Context 'Get-NvmInstalledVersions' {

        It 'should return the installed versions' {
            $installedVersions = Get-NvmInstalledVersions
            $installedVersions | Should -Contain $script:testVersion
        }
    }

    Context 'Get-NvmCurrentVersion' {
        It "should return the current version with the leading 'v' removed" {
            $currentVersion = Get-NvmCurrentVersion
            $currentVersion | Should -Be $script:testVersion
        }
    }

    Context 'Get-NvmStaleVersions' {
        It 'should return the stale versions' {
            $staleVersions = Get-NvmStaleVersions
            $staleVersions | Should -Contain @(
                $script:testVersionStale
            )
        }
    }

    Context 'Get-NodeLatestVersions' {
        It 'should return the latest versions' {
            $latestVersions = Get-NodeLatestVersions
            $latestVersions | Should -BeDeeplyEqualPartial @{
                lts = '22.20.0'
            }
        }
    }
}