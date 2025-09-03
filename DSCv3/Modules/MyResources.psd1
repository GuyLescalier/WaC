# https://github.com/craig-martin/TestModule/tree/master

@{
    RootModule           = 'MyResources.psm1'
    ModuleVersion        = '0.0.1'
    GUID                 = '530fd41e-bbda-4f5e-ae44-4bdac28a04c2'
    Author               = 'Guy Lescalier'
    CompanyName          = 'SopraSteria'
    Copyright            = '(c) Guy Lescalier. All rights reserved.'
    NestedModules        = @(
        'MyCertificate\MyCertificate.psd1'
        'MyChocolatey\MyChocolatey.psd1'
        'MyChocolateyPackage\MyChocolateyPackage.psd1'
        'MyHosts\MyHosts.psd1'
        'MyNodeVersion\MyNodeVersion.psd1'
        'MyScoop\MyScoop.psd1'
        'MyScoopPackage\MyScoopPackage.psd1'
        'MyWindowsDefenderExclusion\MyWindowsDefenderExclusion.psd1'
    )
    FunctionsToExport    = @()
    CmdletsToExport      = '*'
    VariablesToExport    = @()
    AliasesToExport      = @()
    DscResourcesToExport = @(
        'MyCertificate'
        'MyChocolatey'
        'MyChocolateyPackage'
        'MyHosts'
        'MyNodeVersion'
        'MyScoop'
        'MyScoopPackage'
        'MyWindowsDefenderExclusion'
    )
    PrivateData          = @{
        PSData = @{
            Tags = @(
                'DSC'
                'Resources'
            )
        }
    }
}
