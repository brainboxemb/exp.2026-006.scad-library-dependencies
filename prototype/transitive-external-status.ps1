param([string] $RepoRoot = ".")

$ErrorActionPreference = "Stop"
$Root = (& git -C $RepoRoot rev-parse --show-toplevel).Trim()

function Normalize-RepoUrl {
  param([string] $Url)
  $Value = $Url.Trim().TrimEnd('/')
  if ($Value.EndsWith('.git')) { $Value = $Value.Substring(0, $Value.Length - 4) }
  if ($Value -match '^git@github\.com:(.+)$') { $Value = "https://github.com/$($Matches[1])" }
  return $Value
}

function Get-ExternalDependencies {
  param([string] $Owner)
  $ProjectFile = Join-Path $Owner "project.yml"
  if (-not (Test-Path $ProjectFile -PathType Leaf)) { return @() }
  $Dependencies = @()
  $InDependencies = $false
  $Current = $null
  foreach ($Raw in Get-Content $ProjectFile) {
    if (-not $Raw.Trim() -or $Raw.TrimStart().StartsWith('#')) { continue }
    $Indent = $Raw.Length - $Raw.TrimStart().Length
    $Text = $Raw.Trim()
    if ($Indent -eq 0) {
      if ($Text -eq 'dependencies:') { $InDependencies = $true; continue }
      if ($InDependencies) { break }
      continue
    }
    if (-not $InDependencies) { continue }
    if ($Indent -eq 2 -and $Text -match '^-\s*name:\s*(.+)$') {
      if ($Current -and $Current.Role -eq 'external') { $Dependencies += [PSCustomObject]$Current }
      $Current = [ordered]@{ Name = $Matches[1].Trim().Trim('"').Trim("'"); Role=''; Type=''; Url=''; Path=''; Ref='' }
      continue
    }
    if ($Current -and $Indent -eq 4 -and $Text -match '^([^:]+):\s*(.*)$') {
      $Key=$Matches[1].Trim(); $Value=$Matches[2].Trim().Trim('"').Trim("'")
      switch ($Key) {
        'role' { $Current.Role=$Value }
        'type' { $Current.Type=$Value }
        'url' { $Current.Url=$Value }
        'path' { $Current.Path=$Value }
        'ref' { $Current.Ref=$Value }
      }
    }
  }
  if ($Current -and $Current.Role -eq 'external') { $Dependencies += [PSCustomObject]$Current }
  return @($Dependencies)
}

function Test-RepoInitialized {
  param([string] $FullPath)
  if (-not (Test-Path $FullPath -PathType Container)) { return $false }
  $Top = & git -C $FullPath rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $Top) { return $false }
  $Expected=[System.IO.Path]::GetFullPath($FullPath).TrimEnd('\','/')
  $Actual=[System.IO.Path]::GetFullPath(($Top | Select-Object -First 1).Trim()).TrimEnd('\','/')
  return $Expected -eq $Actual
}

function Resolve-LocalCommit {
  param([string] $FullPath,[string] $Ref)
  $Candidates=@()
  if ($Ref -match '^[0-9a-fA-F]{40}$') { $Candidates += "$Ref^{commit}" }
  $Candidates += "refs/tags/$Ref^{commit}"
  $Candidates += "origin/$Ref^{commit}"
  $Candidates += "$Ref^{commit}"
  foreach ($Candidate in $Candidates) {
    $Resolved=& git -C $FullPath rev-parse --verify $Candidate 2>$null
    if ($LASTEXITCODE -eq 0 -and $Resolved) { return ($Resolved | Select-Object -First 1).Trim() }
  }
  return $null
}

function Owner-Label {
  param([string] $Owner)
  $OwnerFull=[System.IO.Path]::GetFullPath($Owner).TrimEnd('\','/')
  $RootFull=[System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  if ($OwnerFull -eq $RootFull) { return "." }
  return [System.IO.Path]::GetRelativePath($RootFull,$OwnerFull).Replace("\","/")
}

function Show-NestedStatus {
  param([string] $Owner,[string[]] $Lineage,[int] $Depth)
  foreach ($Dependency in @(Get-ExternalDependencies -Owner $Owner)) {
    if ($Dependency.Type -ne 'git-submodule') { continue }
    $Normalized=Normalize-RepoUrl $Dependency.Url
    if ($Lineage -contains $Normalized) {
      if ($Depth -gt 0) { Write-Host ("nested {0,-20} CYCLE owner={1} path={2} ref={3}" -f $Dependency.Name,(Owner-Label $Owner),$Dependency.Path,$Dependency.Ref) }
      continue
    }
    $Entry=(& git -C $Owner ls-files --stage -- $Dependency.Path 2>$null) -join [Environment]::NewLine
    if ($Entry -notmatch '^160000\s+([0-9a-fA-F]{40})\s+') {
      if ($Depth -gt 0) { Write-Host ("nested {0,-20} MISSING_GITLINK owner={1} path={2} ref={3}" -f $Dependency.Name,(Owner-Label $Owner),$Dependency.Path,$Dependency.Ref) }
      continue
    }
    $Gitlink=$Matches[1]
    $FullPath=Join-Path $Owner $Dependency.Path
    if (-not (Test-RepoInitialized $FullPath)) {
      if ($Depth -gt 0) { Write-Host ("nested {0,-20} UNINITIALIZED owner={1} path={2} gitlink={3} ref={4}" -f $Dependency.Name,(Owner-Label $Owner),$Dependency.Path,$Gitlink.Substring(0,12),$Dependency.Ref) }
      continue
    }
    $Current=(& git -C $FullPath rev-parse HEAD).Trim()
    $Expected=Resolve-LocalCommit $FullPath $Dependency.Ref
    $Dirty=& git -C $FullPath status --porcelain
    if ($Dirty) { $State="DIRTY" }
    elseif ($Expected -and $Current -eq $Expected) { $State="OK" }
    elseif ($Expected) { $State="DIFF" }
    else { $State="UNKNOWN" }
    if ($Depth -gt 0) { Write-Host ("nested {0,-20} {1,-13} owner={2} path={3} current={4} ref={5}" -f $Dependency.Name,$State,(Owner-Label $Owner),$Dependency.Path,$Current.Substring(0,12),$Dependency.Ref) }
    Show-NestedStatus -Owner $FullPath -Lineage @($Lineage + $Normalized) -Depth ($Depth + 1)
  }
}

$RootUrl=& git -C $Root remote get-url origin 2>$null
if (-not $RootUrl) { $RootUrl='local-root' }
Show-NestedStatus -Owner $Root -Lineage @((Normalize-RepoUrl (($RootUrl | Select-Object -First 1).Trim()))) -Depth 0
