@{
    RootModule           = 'MyScoopPackage.psm1'
    ModuleVersion        = '0.0.1'
    GUID                 = '8f9b5b85-5edc-40c5-a3c9-5863e1850428'
    Author               = 'Guy Lescalier'
    CompanyName          = 'SopraSteria'
    Copyright            = '(c) Guy Lescalier. All rights reserved.'
    FunctionsToExport    = @()
    CmdletsToExport      = '*'
    VariablesToExport    = @()
    AliasesToExport      = @()
    DscResourcesToExport = 'MyScoopPackage'
    FileList             = @(
        'MyScoopPackage.psm1',
        'MyScoopPackage.psd1',
        'Convert-ObjectArrayToHashtable.ps1',
        'Invoke-RetryableOperation.ps1'
    )
}
