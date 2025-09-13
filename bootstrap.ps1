# Demo2Video Bootstrap (Windows) — minimal, ASCII-only

[CmdletBinding()]
param(
  [string]$RepoZipUrl = "https://github.com/m0onmo0n/Demo2Video-Installer/archive/refs/heads/main.zip",
  [string]$DestRoot   = "C:\d2v",
  [bool]  $InstallGit = $false
)

$ErrorActionPreference = "Stop"

Write-Host "== Demo2Video Bootstrap =="

# 1) Enable NTFS long paths
try {
  $cur = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -ErrorAction Stop
  if ($cur.LongPathsEnabled -ne 1) {
    Write-Host "Enabling Windows long paths..."
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -PropertyType DWord -Value 1 -Force | Out-Null
  } else {
    Write-Host "Windows long paths already enabled."
  }
} catch {
  Write-Warning "Could not verify/enable LongPathsEnabled; continuing."
}

# 2) Require winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget not found. Install 'App Installer' from Microsoft Store, then rerun."
  exit 1
}

# 3) Ensure 7-Zip CLI
$sevenZip = Join-Path $env:ProgramFiles "7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) {
  Write-Host "Installing 7-Zip..."
  winget install -e --id 7zip.7zip --silent --accept-source-agreements --accept-package-agreements
}
if (-not (Test-Path $sevenZip)) {
  Write-Error "7-Zip not found after install."
  exit 1
}

# 4) (Optional) Git for contributors
if ($InstallGit -and -not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Git..."
  winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
  try { git config --system core.longpaths true | Out-Null } catch {}
}

# 5) Download ZIP
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$tempZip = Join-Path $env:TEMP ("demo2video_" + $ts + ".zip")
Write-Host "Downloading archive..."
Invoke-WebRequest -UseBasicParsing -Uri $RepoZipUrl -OutFile $tempZip

# 6) Extract to short path
$dest = $DestRoot.TrimEnd("\")
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
$destLong = "\\?\$dest"
Write-Host "Extracting to $dest ..."
& $sevenZip x $tempZip ("-o" + $destLong) -y | Out-Null

# 7) Normalize folder name
$extracted = Get-ChildItem -Path $dest -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $extracted) {
  Write-Error "Extraction failed (no folder found in $dest)."
  exit 1
}
$projectDir = Join-Path $dest "Demo2Video-Installer"
if (-not (Test-Path $projectDir)) { New-Item -ItemType Directory -Path $projectDir | Out-Null }

Write-Host "Finalizing folder layout..."
$robocopyArgs = @("`"$($extracted.FullName)`"", "`"$projectDir`"", "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/NP")
$p = Start-Process -FilePath robocopy.exe -ArgumentList $robocopyArgs -PassThru -WindowStyle Hidden
$p.WaitForExit() | Out-Null

# 8) Launch installer
$installer = Join-Path $projectDir "install.bat"
if (-not (Test-Path $installer)) {
  Write-Error "install.bat not found at $installer"
  exit 1
}
Write-Host "Launching installer..."
Start-Process -FilePath "cmd.exe" -Verb RunAs -ArgumentList ("/c `"" + $installer + "`"")

Write-Host "Bootstrap finished. If the installer did not appear, run the file manually as Administrator:"
Write-Host "  $installer"
