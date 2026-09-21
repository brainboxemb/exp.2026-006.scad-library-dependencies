$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root

$ExpectedRootTool = "7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
$ExpectedScadTool = "78e26949c6f2397ed90bb7888c1386d3dd423312"
$ExpectedMechint = "bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
$ExpectedUtil = "5c88cd9b6b118d376825927ed67e26aff6eaee2d"
$Mechint = "dsg/openscad/ext/lib.scad.mechint"
$Util = "$Mechint/ext/lib.scad.util"

& .\scripts\dep-01-baseline.ps1
if ($LASTEXITCODE -ne 0) { throw "DEP-01 baseline failed." }
& .\prototype\transitive-external-bootstrap.ps1 -RepoRoot .
if ($LASTEXITCODE -ne 0) { throw "Transitive external closure failed." }

$ActualUtil = (& git -C $Util rev-parse HEAD).Trim()
if ($ActualUtil -ne $ExpectedUtil) { throw "Unexpected util HEAD: $ActualUtil" }

function Assert-Uninitialized {
    param([string] $Owner, [string] $Path, [string] $Expected)
    $Status = ((& git -C $Owner submodule status -- $Path) -join "`n").TrimEnd()
    if (-not ($Status.StartsWith("-$Expected ") -or $Status -eq "-$Expected")) {
        throw "Expected $Owner/$Path to remain uninitialized; got: $Status"
    }
}

Assert-Uninitialized -Owner $Mechint -Path "tools/tool.git-project" -Expected $ExpectedRootTool
Assert-Uninitialized -Owner $Mechint -Path "tools/tool.scad-project" -Expected $ExpectedScadTool
Assert-Uninitialized -Owner $Util -Path "tools/tool.git-project" -Expected $ExpectedRootTool
Assert-Uninitialized -Owner $Util -Path "tools/tool.scad-project" -Expected $ExpectedScadTool

Write-Host ""
Write-Host "Mechint nested state after controlled closure:"
& git -C $Mechint submodule status
Write-Host ""
Write-Host "Util nested state after controlled closure:"
& git -C $Util submodule status

New-Item -ItemType Directory -Force -Path "out" | Out-Null
$SourceSha = (& git rev-parse HEAD).Trim()
$Evidence = [ordered]@{
    testcase = "DEP-02"
    source_sha = $SourceSha
    closure = "role:external"
    "lib.scad.mechint" = $ExpectedMechint
    nested = [ordered]@{
        "ext/lib.scad.util" = [ordered]@{ sha = $ExpectedUtil; initialized = $true }
        "mechint/tools/tool.git-project" = [ordered]@{ sha = $ExpectedRootTool; initialized = $false }
        "mechint/tools/tool.scad-project" = [ordered]@{ sha = $ExpectedScadTool; initialized = $false }
        "util/tools/tool.git-project" = [ordered]@{ sha = $ExpectedRootTool; initialized = $false }
        "util/tools/tool.scad-project" = [ordered]@{ sha = $ExpectedScadTool; initialized = $false }
    }
}
$Evidence | ConvertTo-Json -Depth 5 | Set-Content -Path "out/dep-02-closure.json"
Get-Content "out/dep-02-closure.json"
