$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root

$ExpectedRootGitTool = "9879da589101f41b2b0e634d196ddcc51e1a6102"
$ExpectedRootScadTool = "70fd4162731484a949dc390e942dde8b8d811f10"
$ExpectedLibraryGitTool = "7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
$ExpectedLibraryScadTool = "78e26949c6f2397ed90bb7888c1386d3dd423312"
$ExpectedMechint = "bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
$ExpectedNestedUtil = "5c88cd9b6b118d376825927ed67e26aff6eaee2d"
$ExpectedProjectUtil = "da1892a201c3bfc78a65e10df84d4a8d142ae8f6"

$Mechint = "dsg/openscad/ext/lib.scad.mechint"
$NestedUtil = "$Mechint/ext/lib.scad.util"
$ProjectUtil = "dsg/openscad/ext/lib.scad.util"

function Assert-Head {
    param([string] $Path, [string] $Expected)
    $Actual = (& git -C $Path rev-parse HEAD).Trim()
    if ($Actual -ne $Expected) { throw "Unexpected HEAD for ${Path}: $Actual (expected $Expected)" }
}

function Assert-Uninitialized {
    param([string] $Owner, [string] $Path, [string] $Expected)
    $Status = ((& git -C $Owner submodule status -- $Path) -join [Environment]::NewLine).TrimEnd()
    if (-not ($Status.StartsWith("-$Expected ") -or $Status -eq "-$Expected")) {
        throw "Expected $Owner/$Path to remain uninitialized; got: $Status"
    }
}

Write-Host "DEP-01: bootstrap released controlled external closure"
& .\bootstrap.ps1
if ($LASTEXITCODE -ne 0) { throw "Released bootstrap failed." }

Assert-Head "tools/tool.git-project" $ExpectedRootGitTool
Assert-Head "tools/tool.scad-project" $ExpectedRootScadTool
Assert-Head $Mechint $ExpectedMechint
Assert-Head $NestedUtil $ExpectedNestedUtil
Assert-Head $ProjectUtil $ExpectedProjectUtil

foreach ($Owner in @($Mechint, $NestedUtil, $ProjectUtil)) {
    Assert-Uninitialized $Owner "tools/tool.git-project" $ExpectedLibraryGitTool
    Assert-Uninitialized $Owner "tools/tool.scad-project" $ExpectedLibraryScadTool
}

New-Item -ItemType Directory -Force -Path "out" | Out-Null
$Status = (& .\update-repo.ps1 status 2>&1) -join [Environment]::NewLine
$Status | Set-Content "out/dep-01-status.txt"
Write-Host $Status

$SourceSha = (& git rev-parse HEAD).Trim()
$Evidence = [ordered]@{
    testcase = "DEP-01"
    source_sha = $SourceSha
    bootstrap_model = "released-controlled-external-closure"
    root_tool_git_project = $ExpectedRootGitTool
    root_tool_scad_project = $ExpectedRootScadTool
    lib_scad_mechint = $ExpectedMechint
    project_util = [ordered]@{ sha = $ExpectedProjectUtil; initialized = $true }
    mechint_nested_util = [ordered]@{ sha = $ExpectedNestedUtil; initialized = $true }
    nested_tooling_initialized = $false
}
$Evidence | ConvertTo-Json -Depth 5 | Set-Content "out/dep-01-baseline.json"
Get-Content "out/dep-01-baseline.json"
