param(
  [ValidateSet("update","status")]
  [string] $Command = "update"
)

$ErrorActionPreference = "Stop"
$ToolPath = "tools/tool.git-project"
$Root = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $Root) { throw "Run update-repo.ps1 from inside a Git repository." }
$Root = $Root.Trim()
$Tool = Join-Path $Root "$ToolPath/git-project.ps1"
if (-not (Test-Path $Tool -PathType Leaf)) { throw "tool.git-project is not initialized. Run .\bootstrap.ps1 first." }

if ($Command -eq "status") {
  Write-Host "Direct dependencies:"
  & $Tool status -RepoRoot $Root
  if ($LASTEXITCODE -ne 0) { throw "Generic project status failed." }
  Write-Host ""
  Write-Host "Nested external dependencies:"
  & (Join-Path $Root "prototype/transitive-external-status.ps1") -RepoRoot $Root
  if ($LASTEXITCODE -ne 0) { throw "Nested external dependency status failed." }
  exit 0
}

& $Tool update -RepoRoot $Root
if ($LASTEXITCODE -ne 0) { throw "Generic project update failed." }
& (Join-Path $Root "prototype/transitive-external-bootstrap.ps1") -RepoRoot $Root
if ($LASTEXITCODE -ne 0) { throw "Transitive external dependency update failed." }
Write-Host ""
Write-Host "Repository update complete, including transitive external library dependencies."
Write-Host "Review dependency gitlink changes with: git status"
