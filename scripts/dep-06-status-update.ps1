$ErrorActionPreference = "Stop"
$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root
$Mechint = "dsg/openscad/ext/lib.scad.mechint"

& .\bootstrap.ps1
if ($LASTEXITCODE -ne 0) { throw "Bootstrap failed." }

$Status = (& .\update-repo.ps1 status 2>&1) -join [Environment]::NewLine
Write-Host $Status
if ($Status -notmatch "owner=dsg/openscad/ext/lib.scad.mechint" -or $Status -notmatch "ref=v0.1.0") {
  throw "Nested util status not visible on Windows."
}

& .\update-repo.ps1
if ($LASTEXITCODE -ne 0) { throw "Normal update failed on Windows." }

$FinalStatus = (& .\update-repo.ps1 status 2>&1) -join [Environment]::NewLine
Write-Host $FinalStatus
if ($FinalStatus -match "DIRTY|DIFF|UNINITIALIZED|MISSING_GITLINK") {
  throw "Windows final closure status is not clean."
}
