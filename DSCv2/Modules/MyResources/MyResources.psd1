# https://github.com/craig-martin/TestModule/tree/master

@{
    ModuleVersion        = '0.0.1'
    GUID                 = 'f8618f7b-413c-4464-a391-584c6129c651'
    Author               = 'Guy Lescalier'
    CompanyName          = 'Unknown'
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
        'MyWindowsFeature\MyWindowsFeature.psd1'
        'MyWindowsOptionalFeatures\MyWindowsOptionalFeatures.psd1'
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
        'MyWindowsFeature'
        'MyWindowsOptionalFeatures'
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
