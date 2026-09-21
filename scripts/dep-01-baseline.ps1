$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root

$ExpectedRootTool = "7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
$ExpectedScadTool = "78e26949c6f2397ed90bb7888c1386d3dd423312"
$ExpectedMechint = "bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
$ExpectedUtil = "5c88cd9b6b118d376825927ed67e26aff6eaee2d"
$MechintPath = "dsg/openscad/ext/lib.scad.mechint"

function Assert-Head {
    param([string] $Path, [string] $Expected)
    $Actual = (& git -C $Path rev-parse HEAD).Trim()
    if ($Actual -ne $Expected) { throw "Unexpected HEAD for $Path`: $Actual (expected $Expected)" }
}

function Assert-NestedGitlinkUninitialized {
    param([string] $Owner, [string] $Path, [string] $Expected)

    $Entry = (& git -C $Owner ls-files --stage -- $Path) -join "`n"
    if ($Entry -notmatch "^160000\s+$Expected\s+") {
        throw "Unexpected gitlink for $Owner/$Path`: $Entry"
    }

    $Status = ((& git -C $Owner submodule status -- $Path) -join "`n").TrimEnd()
    if (-not ($Status.StartsWith("-$Expected ") -or $Status -eq "-$Expected")) {
        throw "Expected $Owner/$Path to remain uninitialized; got: $Status"
    }
}

Write-Host "DEP-01: bootstrap released direct-only dependency model"
& .\scripts\released-direct-bootstrap.ps1
if ($LASTEXITCODE -ne 0) { throw "Released direct-only bootstrap failed." }

Assert-Head -Path "tools/tool.git-project" -Expected $ExpectedRootTool
Assert-Head -Path "tools/tool.scad-project" -Expected $ExpectedScadTool
Assert-Head -Path $MechintPath -Expected $ExpectedMechint

Assert-NestedGitlinkUninitialized -Owner $MechintPath -Path "ext/lib.scad.util" -Expected $ExpectedUtil
Assert-NestedGitlinkUninitialized -Owner $MechintPath -Path "tools/tool.git-project" -Expected $ExpectedRootTool
Assert-NestedGitlinkUninitialized -Owner $MechintPath -Path "tools/tool.scad-project" -Expected $ExpectedScadTool

Write-Host ""
Write-Host "Root dependency status:"
& .\tools\tool.git-project\git-project.ps1 status -RepoRoot .
if ($LASTEXITCODE -ne 0) { throw "Root dependency status failed." }

Write-Host ""
Write-Host "Nested mechint submodule status:"
& git -C $MechintPath submodule status
if ($LASTEXITCODE -ne 0) { throw "Nested submodule status failed." }

New-Item -ItemType Directory -Force -Path "out" | Out-Null
$SourceSha = (& git rev-parse HEAD).Trim()
$Evidence = [ordered]@{
    testcase = "DEP-01"
    source_sha = $SourceSha
    bootstrap_model = "released-direct-only"
    direct_dependencies = [ordered]@{
        "tool.git-project" = $ExpectedRootTool
        "tool.scad-project" = $ExpectedScadTool
        "lib.scad.mechint" = $ExpectedMechint
    }
    nested_mechint_gitlinks = [ordered]@{
        "ext/lib.scad.util" = [ordered]@{ sha = $ExpectedUtil; initialized = $false }
        "tools/tool.git-project" = [ordered]@{ sha = $ExpectedRootTool; initialized = $false }
        "tools/tool.scad-project" = [ordered]@{ sha = $ExpectedScadTool; initialized = $false }
    }
}
$Evidence | ConvertTo-Json -Depth 5 | Set-Content -Path "out/dep-01-baseline.json"
Get-Content "out/dep-01-baseline.json"
