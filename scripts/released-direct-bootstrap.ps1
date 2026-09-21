$ErrorActionPreference = "Stop"
$Root = (& git rev-parse --show-toplevel).Trim()
$ToolPath = "tools/tool.git-project"
$ExpectedTool = "7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
$Entry = (& git -C $Root ls-files --stage -- $ToolPath 2>$null) -join "`n"
if ($Entry -notmatch "^160000\s+$ExpectedTool\s+") {
    throw "Released DEP-01 bootstrap expects $ToolPath gitlink $ExpectedTool; got: $Entry"
}
& git -C $Root submodule sync -- $ToolPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Unable to synchronize $ToolPath." }
& git -C $Root submodule update --init -- $ToolPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Unable to initialize $ToolPath." }
& (Join-Path $Root "$ToolPath/git-project.ps1") bootstrap -RepoRoot $Root
if ($LASTEXITCODE -ne 0) { throw "Released direct-only bootstrap failed." }
