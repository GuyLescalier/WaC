BeforeAll {
    function Get-PropertySets {
        param([object]$Properties)
        # null 
        if ($null -eq $Properties) {
            return @(@{})
        }
        # liste
        if ($Properties -is [System.Collections.IEnumerable] -and $Properties -isnot [string]) {
            return $Properties
        }
        # objet unique
        return @($Properties)
    }
}

Describe 'Get-PropertySets' {
 
    It 'null' {
        $r = @(Get-PropertySets -Properties $null)
        $r | Should -HaveCount 1
        $r[0] | Should -BeOfType [hashtable]
        $r[0].Count | Should -Be 0
    }

    It 'liste' {
        $input = @(@{ Name = 'A' }, @{ Name = 'B' })
        $result = Get-PropertySets -Properties $input
        $result | Should -HaveCount 2
    }

    It "objet unique" {
        $input = @{ Name = 'Test' }
        $result = Get-PropertySets -Properties $input

        $result | Should -BeOfType [hashtable]
        $result.Count | Should -Be 1
        $result.Name | Should -Be 'Test'
    }
}