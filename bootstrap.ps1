# Demo2Video Bootstrap (Windows) — fast download, ASCII-only, no backticks

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
  # Try 32-bit location as well (rare on x64)
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

# 5) Fast + robust ZIP download
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$tempZip = Join-Path $env:TEMP ('demo2video_' + $ts + '.zip')

# Rewrite GitHub archive URL to codeload format for speed
if ($RepoZipUrl -match '^https://github\.com/([^/]+)/([^/]+)/archive/refs/heads/([^/]+)\.zip$') {
  $owner  = $Matches[1]
  $repo   = $Matches[2]
  $branch = $Matches[3]
  $RepoZipUrl = 'https://codeload.github.com/{0}/{1}/zip/refs/heads/{2}' -f $owner, $repo, $branch
}

Write-Host 'Downloading archive from:'
Write-Host '  ' $RepoZipUrl

function Download-WithCurl {
  param($url, $out)
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if (-not $curl) { return $false }
  $args = @('-L', $url, '-o', $out, '--retry', '3', '--retry-delay', '2')
  $p = Start-Process -FilePath $curl.Source -ArgumentList $args -PassThru -NoNewWindow
  $null = $p.WaitForExit()
  return ((Test
