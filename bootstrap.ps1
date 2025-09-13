<# 
  Bootstrap installer for Demo2Video on Windows.

  What it does:
   - Elevates to Admin
   - Enables NTFS long paths
   - Ensures winget is available
   - Installs 7-Zip (CLI) if missing
   - (Optional) Installs Git if you want to clone later
   - Downloads the repo ZIP and extracts with 7-Zip to a short path (C:\d2v)
   - Runs install.bat

  Usage (PowerShell as user or admin; it will self-elevate if needed):
    irm https://raw.githubusercontent.com/<you>/<repo>/main/bootstrap.ps1 | iex
#>

[CmdletBinding()]
param(
  # ZIP of your default branch (adjust if you use 'main'/'master' differently)
  [string]$RepoZipUrl = "https://github.com/<you>/<repo>/archive/refs/heads/main.zip",

  # Where to place the project. Keep it SHORT to avoid path issues.
  [string]$DestRoot   = "C:\d2v",

  # Set to $true if you also want Git installed for contributors.
  [bool]  $InstallGit = $false
)

function Restart-AsAdmin {
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
     ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"",
              "-RepoZipUrl","`"$RepoZipUrl`"","-DestRoot","`"$DestRoot`"",
              "-InstallGit",$InstallGit)
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $args | Out-Null
    exit
  }
}
Restart-AsAdmin

Write-Host "== Demo2Video Bootstrap =="

# 1) Enable NTFS long paths (Win11 usually supports; Explorer still struggles, so we use 7-Zip)
try {
  $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
                           -Name LongPathsEnabled -ErrorAction Stop
  if ($val.LongPathsEnabled -ne 1) {
    Write-Host "Enabling Windows long paths..."
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
      -Name LongPathsEnabled -PropertyType DWord -Value 1 -Force | Out-Null
  } else {
    Write-Host "Windows long paths already enabled."
  }
} catch {
  Write-Warning "Could not verify/enable LongPathsEnabled; continuing."
}

# 2) Ensure winget exists
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget not found. Please install 'App Installer' from Microsoft Store, then rerun."
  exit 1
}

# 3) Install 7-Zip CLI (for long-path-safe extraction)
$sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) {
  Write-Host "Installing 7-Zip..."
  winget install -e --id 7zip.7zip --silent --accept-source-agreements --accept-package-agreements
}
if (-not (Test-Path $sevenZip)) {
  Write-Error "7-Zip (7z.exe) not found after install. Aborting."
  exit 1
}

# 4) (Optional) Install Git (so devs can clone later)
if ($InstallGit) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git..."
    winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
  }
  try { git config --system core.longpaths true | Out-Null } catch {}
}

# 5) Download the ZIP to a temp file
$tempZip = Join-Path $env:TEMP "demo2video.zip"
Write-Host "Downloading archive..."
Invoke-WebRequest -UseBasicParsing -Uri $RepoZipUrl -OutFile $tempZip

# 6) Extract with 7-Zip to a SHORT path (use \\?\ long-path prefix to be extra safe)
$dest      = $DestRoot.TrimEnd('\')
$destLong  = if ($dest.StartsWith("\\?\")) { $dest } else { "\\?\$dest" }
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

Write-Host "Extracting to $dest ..."
# -y overwrite, -aoa overwrite all existing files
& $sevenZip x $tempZip "-o$destLong" -y | Out-Null

# 7) Move extracted folder content up one level (GitHub names it <repo>-<branch>)
$extracted = Get-ChildItem -Path $dest -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $extracted) {
  Write-Error "Extraction failed (no folder found)."
  exit 1
}
# If the extracted folder is nested, sync/move contents to $dest\project
$projectDir = Join-Path $dest "Demo2Video-Installer"
if (-not (Test-Path $projectDir)) { New-Item -ItemType Directory -Path $projectDir | Out-Null }

Write-Host "Finalizing folder layout..."
# Use robocopy to handle deep trees reliably
$rc = (Start-Process -FilePath robocopy.exe -ArgumentList @(
  "`"$($extracted.FullName)`"", "`"$projectDir`"", "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/NP"
) -PassThru -WindowStyle Hidden).WaitForExit()

# 8) Run the project installer
$installer = Join-Path $projectDir "install.bat"
if (-not (Test-Path $installer)) {
  Write-Error "install.bat not found at $installer"
  exit 1
}

Write-Host "Launching installer..."
Start-Process -FilePath "cmd.exe" -Verb RunAs -ArgumentList "/c `"$installer`""
Write-Host "Done. If the installer window didn't appear, run: `"$installer`" as Administrator."
