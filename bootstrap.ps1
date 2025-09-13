# Demo2Video Bootstrap (Windows) — simple, fast, ASCII-only

[CmdletBinding()]
param(
  # Default ZIP of your main branch
  [string]$RepoZipUrl = 'https://github.com/m0onmo0n/Demo2Video-Installer/archive/refs/heads/main.zip',
  # Install destination (keep short to avoid path issues). Override with -DestRoot 'X:\path'
  [string]$DestRoot   = 'C:\d2v',
  # Optional: install Git for contributors
  [bool]  $InstallGit = $false
)

$ErrorActionPreference = 'Stop'
Write-Host '== Demo2Video Bootstrap =='

# 1) Enable NTFS long paths
try {
  $lp = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop
  if ($lp.LongPathsEnabled -ne 1) {
    Write-Host 'Enabling Windows long paths...'
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -PropertyType DWord -Value 1 -Force | Out-Null
  } else {
    Write-Host 'Windows long paths already enabled.'
  }
} catch {
  Write-Warning 'Could not verify/enable LongPathsEnabled; continuing.'
}

# 2) Require winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget not found. Install 'App Installer' from the Microsoft Store, then rerun."
  exit 1
}

# 3) Ensure 7-Zip CLI
$sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
if (-not (Test-Path $sevenZip)) {
  $sevenZipX86 = Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe'
  if (Test-Path $sevenZipX86) { $sevenZip = $sevenZipX86 }
}
if (-not (Test-Path $sevenZip)) {
  Write-Host 'Installing 7-Zip...'
  winget install -e --id 7zip.7zip --silent --accept-source-agreements --accept-package-agreements
}
if (-not (Test-Path $sevenZip)) {
  Write-Error '7-Zip not found after install.'
  exit 1
}

# 4) Optional: Git for contributors (and long paths in Git)
if ($InstallGit -and -not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host 'Installing Git...'
  winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
  try { git config --system core.longpaths true | Out-Null } catch {}
}

# 5) Fast ZIP download (codeload + curl, with fallbacks)
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$tempZip = Join-Path $env:TEMP ('demo2video_' + $ts + '.zip')

# Rewrite GitHub archive URL to codeload for speed
if ($RepoZipUrl -match '^https://github\.com/([^/]+)/([^/]+)/archive/refs/heads/([^/]+)\.zip$') {
  $owner  = $Matches[1]
  $repo   = $Matches[2]
  $branch = $Matches[3]
  $RepoZipUrl = 'https://codeload.github.com/{0}/{1}/zip/refs/heads/{2}' -f $owner, $repo, $branch
}

Write-Host 'Downloading archive from:'
Write-Host '  ' $RepoZipUrl

$ok = $false

# Try curl.exe first
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($curl) {
  $proc = Start-Process -FilePath $curl.Source -ArgumentList @('-L', $RepoZipUrl, '-o', $tempZip, '--retry', '3', '--retry-delay', '2') -PassThru -NoNewWindow
  $null = $proc.WaitForExit()
  if (Test-Path $tempZip) {
    $fi = Get-Item $tempZip
    if ($fi.Length -gt 0) { $ok = $true }
  }
}

# Fall back to Invoke-WebRequest
if (-not $ok) {
  try {
    $old = $global:ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $tempZip -MaximumRedirection 5 -TimeoutSec 300
    $global:ProgressPreference = $old
    if (Test-Path $tempZip) {
      $fi = Get-Item $tempZip
      if ($fi.Length -gt 0) { $ok = $true }
    }
  } catch {
    $ok = $false
  }
}

# Fall back to BITS
if (-not $ok) {
  try {
    Start-BitsTransfer -Source $RepoZipUrl -Destination $tempZip -TransferPolicy AlwaysForeground -ErrorAction Stop
    if (Test-Path $tempZip) {
      $fi = Get-Item $tempZip
      if ($fi.Length -gt 0) { $ok = $true }
    }
  } catch {
    $ok = $false
  }
}

if (-not $ok) {
  Write-Error ('Failed to download ZIP from {0}' -f $RepoZipUrl)
  exit 1
}

# 6) Extract to a short path (use \\?\ to help long paths)
$dest = $DestRoot.TrimEnd('\')
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
$destLong = '\\?\{0}' -f $dest

Write-Host ('Extracting to {0} ...' -f $dest)
& $sevenZip x $tempZip ('-o' + $destLong) -y | Out-Null

# 7) Normalize folder name (<repo>-<branch> -> Demo2Video-Installer)
$extracted = Get-ChildItem -Path $dest -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $extracted) {
  Write-Error ('Extraction failed (no folder found in {0}).' -f $dest)
  exit 1
}
$projectDir = Join-Path $dest 'Demo2Video-Installer'
if (-not (Test-Path $projectDir)) { New-Item -ItemType Directory -Path $projectDir | Out-Null }

Write-Host 'Finalizing folder layout...'
& robocopy $extracted.FullName $projectDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null

# 8) Launch installer (elevated)
$installer = Join-Path $projectDir 'install.bat'
if (-not (Test-Path $installer)) {
  Write-Error ('install.bat not found at {0}' -f $installer)
  exit 1
}
Write-Host 'Launching installer...'
Start-Process -FilePath 'cmd.exe' -Verb RunAs -ArgumentList @('/c', $installer)

Write-Host 'Bootstrap finished. If the installer did not appear, run it manually as Administrator:'
Write-Host '  ' $installer
