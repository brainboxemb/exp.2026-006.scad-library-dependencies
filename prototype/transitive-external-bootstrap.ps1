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
            if ($Text -eq 'dependencies:') {
                $InDependencies = $true
                continue
            }
            if ($InDependencies) { break }
            continue
        }

        if (-not $InDependencies) { continue }

        if ($Indent -eq 2 -and $Text -match '^-\s*name:\s*(.+)$') {
            if ($Current -and $Current.Role -eq 'external') { $Dependencies += [PSCustomObject]$Current }
            $Current = [ordered]@{
                Name = $Matches[1].Trim().Trim('"').Trim("'")
                Role = ''
                Type = ''
                Url = ''
                Path = ''
                Ref = ''
            }
            continue
        }

        if ($Current -and $Indent -eq 4 -and $Text -match '^([^:]+):\s*(.*)$') {
            $Key = $Matches[1].Trim()
            $Value = $Matches[2].Trim().Trim('"').Trim("'")
            switch ($Key) {
                'role' { $Current.Role = $Value }
                'type' { $Current.Type = $Value }
                'url'  { $Current.Url = $Value }
                'path' { $Current.Path = $Value }
                'ref'  { $Current.Ref = $Value }
            }
        }
    }

    if ($Current -and $Current.Role -eq 'external') { $Dependencies += [PSCustomObject]$Current }
    return @($Dependencies)
}

function Get-SubmoduleName {
    param([string] $Owner, [string] $Path)
    $Modules = Join-Path $Owner '.gitmodules'
    if (-not (Test-Path $Modules -PathType Leaf)) { return $null }
    $Rows = & git -C $Owner config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>$null
    foreach ($Line in $Rows) {
        $Parts = $Line -split '\s+', 2
        if ($Parts.Count -eq 2 -and $Parts[1].Trim() -eq $Path) {
            return ($Parts[0] -replace '^submodule\.', '' -replace '\.path$', '')
        }
    }
    return $null
}

function Test-RepoInitialized {
    param([string] $FullPath)
    if (-not (Test-Path $FullPath -PathType Container)) { return $false }
    $Top = & git -C $FullPath rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $Top) { return $false }
    $Expected = [System.IO.Path]::GetFullPath($FullPath).TrimEnd('\','/')
    $Actual = [System.IO.Path]::GetFullPath(($Top | Select-Object -First 1).Trim()).TrimEnd('\','/')
    return $Expected -eq $Actual
}

function Assert-Clean {
    param([string] $FullPath, [string] $Name)
    $Dirty = & git -C $FullPath status --porcelain
    if ($Dirty) { throw "Dependency '$Name' has local changes; refusing transitive checkout." }
}

function Resolve-DependencyCommit {
    param([string] $FullPath, [string] $Ref)
    & git -C $FullPath fetch origin --prune --tags | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to fetch $FullPath." }

    $Candidates = @()
    if ($Ref -match '^[0-9a-fA-F]{40}$') { $Candidates += "$Ref^{commit}" }
    $Candidates += "refs/tags/$Ref^{commit}"
    $Candidates += "origin/$Ref^{commit}"
    $Candidates += "$Ref^{commit}"

    foreach ($Candidate in $Candidates) {
        $Resolved = & git -C $FullPath rev-parse --verify $Candidate 2>$null
        if ($LASTEXITCODE -eq 0 -and $Resolved) { return ($Resolved | Select-Object -First 1).Trim() }
    }
    return $null
}

function Invoke-ExternalClosure {
    param([string] $Owner, [string[]] $Lineage)

    foreach ($Dependency in @(Get-ExternalDependencies -Owner $Owner)) {
        if ($Dependency.Type -ne 'git-submodule') { throw "Unsupported external dependency type '$($Dependency.Type)' for $($Dependency.Name)." }
        if (-not $Dependency.Url -or -not $Dependency.Path -or -not $Dependency.Ref) { throw "External dependency '$($Dependency.Name)' has incomplete metadata." }

        $Normalized = Normalize-RepoUrl $Dependency.Url
        if ($Lineage -contains $Normalized) { throw "Dependency cycle detected through $($Dependency.Url) while walking $Owner." }

        $Entry = (& git -C $Owner ls-files --stage -- $Dependency.Path) -join "`n"
        if ($Entry -notmatch '^160000\s+([0-9a-fA-F]{40})\s+') { throw "External dependency '$($Dependency.Name)' is not a committed gitlink at $Owner/$($Dependency.Path)." }
        $Gitlink = $Matches[1]

        $SubmoduleName = Get-SubmoduleName -Owner $Owner -Path $Dependency.Path
        if (-not $SubmoduleName) { throw "No .gitmodules entry found for $Owner/$($Dependency.Path)." }
        $ConfiguredUrl = (& git -C $Owner config -f .gitmodules --get "submodule.$SubmoduleName.url").Trim()
        if ((Normalize-RepoUrl $ConfiguredUrl) -ne $Normalized) { throw "URL mismatch for $Owner/$($Dependency.Path): project.yml=$($Dependency.Url) .gitmodules=$ConfiguredUrl" }

        & git -C $Owner submodule sync -- $Dependency.Path | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Unable to sync $Owner/$($Dependency.Path)." }

        $FullPath = Join-Path $Owner $Dependency.Path
        if (-not (Test-RepoInitialized -FullPath $FullPath)) {
            & git -C $Owner submodule update --init -- $Dependency.Path | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Unable to initialize $Owner/$($Dependency.Path)." }
        }

        Assert-Clean -FullPath $FullPath -Name $Dependency.Name
        $Expected = Resolve-DependencyCommit -FullPath $FullPath -Ref $Dependency.Ref
        if (-not $Expected) { throw "Unable to resolve ref '$($Dependency.Ref)' for $($Dependency.Name)." }
        $Current = (& git -C $FullPath rev-parse HEAD).Trim()
        if ($Current -ne $Expected) {
            Write-Host "Aligning external $($Dependency.Name): $Current -> $Expected ($($Dependency.Ref))"
            & git -C $FullPath checkout --detach $Expected | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Unable to align $($Dependency.Name)." }
            $Current = $Expected
        }

        Write-Host "external $($Dependency.Name) owner=$Owner path=$($Dependency.Path) gitlink=$Gitlink current=$Current ref=$($Dependency.Ref)"
        Invoke-ExternalClosure -Owner $FullPath -Lineage @($Lineage + $Normalized)
    }
}

$RootUrl = (& git -C $Root remote get-url origin 2>$null)
if (-not $RootUrl) { $RootUrl = 'local-root' }
Invoke-ExternalClosure -Owner $Root -Lineage @((Normalize-RepoUrl (($RootUrl | Select-Object -First 1).Trim())))
