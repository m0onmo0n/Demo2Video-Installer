# bootstrap.ps1 — Download + extract this repo and run install.bat
# Windows PowerShell 5.1 safe (ASCII only)

[CmdletBinding()]
param(
  [string]$RepoZipUrl = 'https://github.com/m0onmo0n/Demo2Video-Installer/archive/refs/heads/main.zip',
  [string]$DestRoot   = 'C:\d2v',
  [switch]$Force,
  [switch]$KeepExtracted
)

$ErrorActionPreference = 'Stop'

function Restart-AsAdmin {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  if (-not $isAdmin) {
    $args = @(
      '-NoProfile','-ExecutionPolicy','Bypass',
      '-File', $PSCommandPath,
      '-RepoZipUrl', $RepoZipUrl,
      '-DestRoot',   $DestRoot
    )
    if ($Force)        { $args += '-Force' }
    if ($KeepExtracted){ $args += '-KeepExtracted' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $args | Out-Null
    exit
  }
}

function Enable-LongPaths {
  try {
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    $name    = 'LongPathsEnabled'
    $val     = 0
    try { $val = (Get-ItemProperty -Path $regPath -Name $name -ErrorAction Stop).LongPathsEnabled } catch { }
    if ($val -ne 1) {
      New-ItemProperty -Path $regPath -Name $name -PropertyType DWord -Value 1 -Force | Out-Null
      Write-Host 'Enabled Windows long paths.'
    } else {
      Write-Host 'Windows long paths already enabled.'
    }
  } catch {
    Write-Warning 'Could not verify/enable LongPathsEnabled; continuing.'
  }
}

function Try-RepairWinget {
  try {
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if ($wg) {
      winget source list > $null 2>&1
      if ($LASTEXITCODE -ne 0) {
        winget source reset --force | Out-Null
        winget source update | Out-Null
      }
      return $true
    }
    return $false
  } catch { return $false }
}

function Try-Install7Zip {
  # Returns full path to 7z.exe on success; $null otherwise
  $sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
  if (Test-Path $sevenZip) { return $sevenZip }

  if (Try-RepairWinget) {
    try {
      Write-Host 'Installing 7-Zip via winget...'
      $p = Start-Process -FilePath 'winget' -ArgumentList @(
        'install','-e','--id','7zip.7zip','--silent',
        '--accept-source-agreements','--accept-package-agreements'
      ) -Wait -PassThru -NoNewWindow
      if ($p.ExitCode -eq 0 -and (Test-Path $sevenZip)) { return $sevenZip }
    } catch { }
  }
  return $null
}

function Get-Extractor {
  # Prefer 7-Zip CLI; else tar.exe
  $sevenZip = Try-Install7Zip
  if ($sevenZip) { return @{ Tool = '7z'; Path = $sevenZip } }
  $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($tar) {
    Write-Warning '7-Zip not available; falling back to built-in tar.exe for ZIP extraction.'
    return @{ Tool = 'tar'; Path = $tar.Source }
  }
  throw 'No extractor available (7-Zip missing and tar.exe not found). Install 7-Zip or ensure tar.exe exists.'
}

function Download-Zip {
  param([Parameter(Mandatory=$true)][string]$Url,[Parameter(Mandatory=$true)][string]$OutFile)
  if ([string]::IsNullOrWhiteSpace($Url)) { throw 'RepoZipUrl is empty.' }
  if (Test-Path $OutFile) { try { Remove-Item -Force $OutFile } catch { } }
  Write-Host 'Downloading archive...'
  $p = Start-Process -FilePath 'curl.exe' -ArgumentList @('-L', $Url, '-o', $OutFile) -PassThru -NoNewWindow -Wait
  if ($p.ExitCode -ne 0) { throw ('curl.exe failed (exit {0})' -f $p.ExitCode) }
  if (-not (Test-Path $OutFile)) { throw 'Download failed: file not found.' }
}

function Extract-Zip {
  param([Parameter(Mandatory=$true)][string]$ZipPath,[Parameter(Mandatory=$true)][string]$Dest,[Parameter(Mandatory=$true)][hashtable]$Extractor)
  if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest | Out-Null }
  Write-Host ("Extracting to {0} ..." -f $Dest)
  if ($Extractor.Tool -eq '7z') {
    $destLong = ("\\?\{0}" -f $Dest)
    & $Extractor.Path 'x' $ZipPath ("-o" + $destLong) '-y' | Out-Null
  } else {
    & $Extractor.Path '-xf' $ZipPath '-C' $Dest
  }
}

function Finalize-Folder {
  param([Parameter(Mandatory=$true)][string]$Dest,[switch]$Keep,[switch]$ForceExisting)
  # GitHub ZIP contains a single top-level folder like Demo2Video-Installer-main
  $extracted = Get-ChildItem -Path $Dest -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $extracted) { throw 'Extraction failed (no folder found).' }

  $projectDir = Join-Path $Dest 'Demo2Video-Installer'
  if (Test-Path $projectDir -and $ForceExisting) {
    Write-Host ("Removing existing ""{0}"" due to -Force..." -f $projectDir)
    Remove-Item -Recurse -Force $projectDir
  }
  if (-not (Test-Path $projectDir)) { New-Item -ItemType Directory -Path $projectDir | Out-Null }

  Write-Host 'Finalizing folder layout...'
  $args = @(
    ('"{0}"' -f $extracted.FullName),
    ('"{0}"' -f $projectDir),
    '/MIR','/NFL','/NDL','/NJH','/NJS','/NP'
  )
  $rob = Start-Process -FilePath 'robocopy.exe' -ArgumentList $args -PassThru -WindowStyle Hidden -Wait
  if ($rob.ExitCode -ge 8) { throw ('robocopy failed (exit {0})' -f $rob.ExitCode) }

  if (-not $Keep) {
    if ($extracted.FullName -ne $projectDir) {
      Write-Host ("Removing raw extracted folder ""{0}""..." -f $extracted.FullName)
      Remove-Item -Recurse -Force $extracted.FullName
    }
  }
  return $projectDir
}

function Run-Installer {
  param([Parameter(Mandatory=$true)][string]$ProjectDir)
  $installer = Join-Path $ProjectDir 'install.bat'
  if (-not (Test-Path $installer)) { throw ('install.bat not found at {0}' -f $installer) }
  Write-Host 'Launching installer...'
  Start-Process -FilePath 'cmd.exe' -Verb RunAs -ArgumentList '/c', ('"{0}"' -f $installer) | Out-Null
  Write-Host 'Installer launched. If no window appeared, run install.bat as Administrator.'
}

# -------------------- Main --------------------

Restart-AsAdmin
Write-Host '== Demo2Video Bootstrap =='

Enable-LongPaths

$dest = $DestRoot.TrimEnd('\')
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

$tempZip   = Join-Path $env:TEMP 'demo2video.zip'
$extractor = Get-Extractor
Download-Zip -Url $RepoZipUrl -OutFile $tempZip
Extract-Zip  -ZipPath $tempZip -Dest $dest -Extractor $extractor

# Build a param set and only add switches when true (avoids -Keep:$var parsing quirks)
$finalizeParams = @{ Dest = $dest }
if ($KeepExtracted) { $finalizeParams.Keep = $true }
if ($Force)         { $finalizeParams.ForceExisting = $true }
$proj = Finalize-Folder @finalizeParams

if (Test-Path $tempZip) { try { Remove-Item -Force $tempZip } catch { } }

Run-Installer -ProjectDir $proj

Write-Host 'Done.'
