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

  Quick start:
    irm https://raw.githubusercontent.com/m0onmo0n/Demo2Video-Installer/main/bootstrap.ps1 | iex
#>

[CmdletBinding()]
param(
  # ZIP of your default branch
  [string]$RepoZipUrl = "https://github.com/m0onmo0n/Demo2Video-Installer/archive/refs/heads/main.zip",

  # Where to place the project (keep short to avoid path issues)
  [string]$DestRoot   = "C:\d2v",

  # Set to $true if you also want Git installed for contributors
  [bool]  $InstallGit = $false
)

$ErrorActionPreference = 'Stop'
$HadToElevate = $false

function Restart-AsAdmin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  if (-not $isAdmin) {
    # If invoked via irm|iex, $PSCommandPath can be empty. Persist self to temp and elevate that.
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
      $scriptPath = Join-Path $env:TEMP "d2v_bootstrap.ps1"
      Set-Content -Encoding UTF8 -NoNewline -Path $scriptPath -Value ($MyInvocation.MyCommand.Definition)
    }
    $scriptArgs = @(
      '-NoProfile','-ExecutionPolicy','Bypass',
      '-File', $scriptPath,
      '-RepoZipUrl', $RepoZipUrl,
      '-DestRoot',   $DestRoot,
      '-InstallGit', $InstallGit
    )
    $global:HadToElevate = $true
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $scriptArgs | Out-Null
    exit
  }
}
Restart-AsAdmin

$ts  = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $env:TEMP "demo2video_bootstrap_$ts.log"
try { Start-Transcript -Path $log -Append | Out-Null } catch {}

Write-Host "== Demo2Video Bootstrap =="
Write-Host "Log: $log"

try {
  # 1) Enable NTFS long paths
  try {
    $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop
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
    throw "winget not found. Install 'App Installer' from Microsoft Store, then rerun."
  }

  # 3) Ensure 7-Zip CLI
  $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
  if (-not (Test-Path $sevenZip)) {
    Write-Host "Installi
