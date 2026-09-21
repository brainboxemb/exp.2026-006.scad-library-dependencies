$ErrorActionPreference = "Stop"
$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root

$ExpectedLibraryGitTool = "7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
$ExpectedLibraryScadTool = "78e26949c6f2397ed90bb7888c1386d3dd423312"
$ExpectedNestedUtil = "5c88cd9b6b118d376825927ed67e26aff6eaee2d"
$Mechint = "dsg/openscad/ext/lib.scad.mechint"
$NestedUtil = "$Mechint/ext/lib.scad.util"

& .\scripts\dep-01-baseline.ps1
if ($LASTEXITCODE -ne 0) { throw "DEP-01 failed." }
$Before = (& git status --porcelain) -join [Environment]::NewLine
& .\bootstrap.ps1
if ($LASTEXITCODE -ne 0) { throw "Second bootstrap failed." }
$After = (& git status --porcelain) -join [Environment]::NewLine
if ($Before -ne $After) { throw "Released bootstrap is not idempotent." }

$ActualNested = (& git -C $NestedUtil rev-parse HEAD).Trim()
if ($ActualNested -ne $ExpectedNestedUtil) { throw "Unexpected nested util HEAD: $ActualNested" }

foreach ($Owner in @($Mechint, $NestedUtil)) {
    $Status = ((& git -C $Owner submodule status -- "tools/tool.git-project") -join [Environment]::NewLine).TrimEnd()
    if (-not ($Status.StartsWith("-$ExpectedLibraryGitTool ") -or $Status -eq "-$ExpectedLibraryGitTool")) { throw "Nested Git tooling unexpectedly initialized." }
    $Status = ((& git -C $Owner submodule status -- "tools/tool.scad-project") -join [Environment]::NewLine).TrimEnd()
    if (-not ($Status.StartsWith("-$ExpectedLibraryScadTool ") -or $Status -eq "-$ExpectedLibraryScadTool")) { throw "Nested SCAD tooling unexpectedly initialized." }
}

New-Item -ItemType Directory -Force -Path "out" | Out-Null
$StatusText = (& .\update-repo.ps1 status 2>&1) -join [Environment]::NewLine
$StatusText | Set-Content "out/dep-02-status.txt"
Write-Host $StatusText
if ($StatusText -notmatch "owner=dsg/openscad/ext/lib.scad.mechint" -or $StatusText -notmatch "ref=v0.1.0") {
    throw "Released full-closure status does not identify the nested util owner/ref."
}

$SourceSha = (& git rev-parse HEAD).Trim()
$Evidence = [ordered]@{
    testcase = "DEP-02"
    source_sha = $SourceSha
    implementation = "tool.git-project v0.2.9"
    closure = "role:external"
    nested_util = [ordered]@{ sha = $ExpectedNestedUtil; initialized = $true }
    nested_tooling_initialized = $false
    bootstrap_idempotent = $true
}
$Evidence | ConvertTo-Json -Depth 5 | Set-Content "out/dep-02-closure.json"
Get-Content "out/dep-02-closure.json"
