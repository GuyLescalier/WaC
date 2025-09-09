# Inspired by https://github.com/chocolatey/cChoco

@{
    RootModule           = 'MyChocolatey.psm1'
    ModuleVersion        = '0.0.1'
    GUID                 = '0fcc04b9-b393-444d-b796-04dc402f8b67'
    Author               = 'Guy Lescalier'
    CompanyName          = 'SopraSteria'
    Copyright            = '(c) Guy Lescalier. All rights reserved.'
    FunctionsToExport    = @()
    CmdletsToExport      = '*'
    VariablesToExport    = @()
    AliasesToExport      = @()
    DscResourcesToExport = @('MyChocolatey') 
}
