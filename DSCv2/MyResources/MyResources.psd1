#
# Module manifest for module 'MyResources'
#
# Generated by: Guy Lescalier
#
# Generated on: 18/10/2023
#
# https://github.com/craig-martin/TestModule/tree/master
#

@{
    ModuleVersion        = '0.0.1'
    GUID                 = 'f8618f7b-413c-4464-a391-584c6129c651'
    Author               = 'Guy Lescalier'
    CompanyName          = 'Unknown'
    Copyright            = '(c) Guy Lescalier. All rights reserved.'
    NestedModules        = @(
        'MyScoopPackage\MyScoopPackage.psd1'
        'MyWindowsFeature\MyWindowsFeature.psd1'
    )
    FunctionsToExport    = @()
    CmdletsToExport      = '*'
    VariablesToExport    = @()
    AliasesToExport      = @()
    DscResourcesToExport = @(
        'MyScoopPackage'
        'MyWindowsFeature'
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
