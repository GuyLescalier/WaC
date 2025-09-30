# \Parallelize-Task.ps1 -InputFilePath config.yaml -Operation set

param(
  [Parameter(Mandatory = $true)]
  [string] $InputFilePath,
  
  [Parameter(Mandatory = $false)]
  [ValidateSet('test', 'get', 'set')]
  [string] $Operation = 'test'
)

Import-Module powershell-yaml
$doc = Get-Content -Raw -Path $InputFilePath | ConvertFrom-Yaml
$schema = $doc.'$schema'
$commands = @()

foreach ($r in $doc.resources) {
  if ($r.ContainsKey('name') -and $r.ContainsKey('type') -and $r.ContainsKey('properties')) {
    
    $singleResourceDoc = @{
      '$schema' = $schema
      resources = @($r)
    }
    
    $config = ConvertTo-Yaml -Data $singleResourceDoc
    
    $commands += "dsc config $Operation -i @'`n$config`n'@ -o yaml"
  }
}

$elapsedForParallel = Measure-Command {
  $results = $commands | ForEach-Object -Parallel {
    Invoke-Expression $_ 2>&1
  }
}

$results | Format-List
$elapsedForParallel | Select-Object TotalSeconds