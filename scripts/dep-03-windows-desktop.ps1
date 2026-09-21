$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root

Write-Host "Preparing DEP-03 Windows desktop fixture..."
& .\scripts\dep-02-closure.ps1
if ($LASTEXITCODE -ne 0) { throw "DEP-02 closure preparation failed." }

$Target = (Resolve-Path "dsg/openscad/ext/lib.scad.mechint/main.scad").Path
$UtilInspection = (Resolve-Path "dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util/openscad/inspection.scad").Path

Write-Host ""
Write-Host "Nested mechint entrypoint:"
Write-Host "  $Target"
Write-Host "Nested util source:"
Write-Host "  $UtilInspection"

$Candidates = @()
$Command = Get-Command openscad.exe -ErrorAction SilentlyContinue
if ($Command) { $Candidates += $Command.Source }
$Command = Get-Command openscad -ErrorAction SilentlyContinue
if ($Command) { $Candidates += $Command.Source }
if ($env:ProgramFiles) { $Candidates += (Join-Path $env:ProgramFiles "OpenSCAD\openscad.exe") }
if ($env:LOCALAPPDATA) { $Candidates += (Join-Path $env:LOCALAPPDATA "Programs\OpenSCAD\openscad.exe") }
$OpenScad = $Candidates | Where-Object { $_ -and (Test-Path $_ -PathType Leaf) } | Select-Object -First 1

if ($OpenScad) {
    Write-Host ""
    Write-Host "Found local OpenSCAD CLI: $OpenScad"
    New-Item -ItemType Directory -Force -Path "out" | Out-Null
    $Output = Join-Path $Root "out\dep-03-windows-cli.stl"
    $Log = Join-Path $Root "out\dep-03-windows-cli.log"

    $HadOpenScadPath = Test-Path Env:OPENSCADPATH
    $OldOpenScadPath = $env:OPENSCADPATH
    try {
        $env:OPENSCADPATH = ""
        $Lines = & $OpenScad --enable=object-function --render -o $Output $Target 2>&1
        $Code = $LASTEXITCODE
        $Lines | Set-Content -Path $Log
        $Lines | ForEach-Object { Write-Host $_ }
    } finally {
        if ($HadOpenScadPath) { $env:OPENSCADPATH = $OldOpenScadPath }
        else { Remove-Item Env:OPENSCADPATH -ErrorAction SilentlyContinue }
    }

    if ($Code -ne 0) { throw "Local OpenSCAD CLI failed with exit code $Code. See $Log" }
    if (-not (Test-Path $Output -PathType Leaf) -or (Get-Item $Output).Length -le 0) {
        throw "Local OpenSCAD CLI did not produce a non-empty STL."
    }

    $LogText = Get-Content $Log -Raw
    if ($LogText -match "(?i)(can't open|cannot open|could not open|unable to open).*(include|use|inspection\.scad|lib\.scad\.util)|(include|use).*(not found|can't open|cannot open)") {
        throw "Local OpenSCAD CLI reported an unresolved include/use dependency. See $Log"
    }

    Write-Host "Local CLI proof: PASS ($((Get-Item $Output).Length) bytes)"
} else {
    Write-Host ""
    Write-Host "No local OpenSCAD CLI executable was discovered automatically; skipping CLI proof."
}

Write-Host ""
Write-Host "DEP-03 Windows desktop acceptance is still required:"
Write-Host "  1. Start normal OpenSCAD from the Windows Start menu/desktop, not through a wrapper."
Write-Host "  2. File > Open: $Target"
Write-Host "  3. Press F6 (Render)."
Write-Host "  4. Confirm the lock-section renders and there is no missing lib.scad.util/inspection.scad warning."
Write-Host "  5. Report DEP-03 desktop PASS only if those conditions are met."
