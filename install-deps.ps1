# install-deps.ps1 (ASCII-safe)
# Installs: NVM (or Node LTS), OBS, Python 3.13, PostgreSQL, and Visual Studio 2022 (or Build Tools) with C++ workload.

param(
    [ValidateSet('Community','Professional','Enterprise','BuildTools')]
    [string]$VsEdition = 'Community',
    [switch]$LeanCpp = $false
)

$ErrorActionPreference = 'Stop'

function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Warning "This script should be run as Administrator (winget installers often require elevation)."
    }
}
Ensure-Admin

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install the Microsoft Store 'App Installer' package, then re-run."
    }
}
Ensure-Winget

function Test-PackageInstalled([string]$Id) {
    $null = winget list --id $Id --accept-source-agreements 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Install-Package([string]$Id, [string]$Notes = "", [string]$Override = "") {
    $args = @(
        'install','--id',$Id,
        '--silent',
        '--accept-source-agreements',
        '--accept-package-agreements'
    )
    if ($Override) { $args += @('--override', $Override) }

    try {
        Write-Host "Installing $Id $Notes"
        winget @args
        if ($LASTEXITCODE -eq 0) {
            return [pscustomobject]@{ Id = $Id; Status = 'Installed'; Notes = $Notes }
        } else {
            return [pscustomobject]@{ Id = $Id; Status = "Failed ($LASTEXITCODE)"; Notes = $Notes }
        }
    }
    catch {
        return [pscustomobject]@{ Id = $Id; Status = 'Error'; Notes = "$Notes :: $($_.Exception.Message)" }
    }
}

# Resolve VS package and workload
$vsId = switch ($VsEdition) {
    'Community'     { 'Microsoft.VisualStudio.2022.Community' }
    'Professional'  { 'Microsoft.VisualStudio.2022.Professional' }
    'Enterprise'    { 'Microsoft.VisualStudio.2022.Enterprise' }
    'BuildTools'    { 'Microsoft.VisualStudio.2022.BuildTools' }
}

$vsCppWorkload = if ($VsEdition -eq 'BuildTools') {
    'Microsoft.VisualStudio.Workload.VCTools'
} else {
    'Microsoft.VisualStudio.Workload.NativeDesktop'
}

$vsSizeFlags = if ($LeanCpp) { '' } else { '--includeRecommended --includeOptional' }

$vsOverrideParts = @('--passive','--wait','--norestart','--add', $vsCppWorkload)
if ($vsSizeFlags) { $vsOverrideParts += $vsSizeFlags }
$vsOverrideString = ($vsOverrideParts -join ' ')

# Package list
$packages = [ordered]@{
    'CoreyButler.NVMforWindows' = @{ when = { $true }; notes = 'NVM for Windows'; override = '' }
    'OpenJS.NodeJS.LTS'         = @{ when = { -not (Test-PackageInstalled 'CoreyButler.NVMforWindows') }; notes = 'Node LTS (skipped if NVM present)'; override = '' }
    'OBSProject.OBSStudio'      = @{ when = { $true }; notes = 'OBS Studio'; override = '' }
    'Python.Python.3.13'        = @{ when = { $true }; notes = 'Python 3.13'; override = '' }
    'PostgreSQL.PostgreSQL'     = @{ when = { $true }; notes = 'PostgreSQL Server'; override = '' }
    $vsId                       = @{ when = { $true }; notes = "Visual Studio 2022 ($VsEdition) with C++ workload"; override = $vsOverrideString }
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($kv in $packages.GetEnumerator()) {
    $id   = $kv.Key
    $meta = $kv.Value
    $ok   = & $meta.when

    if (-not $ok) {
        $results.Add([pscustomobject]@{ Id = $id; Status = 'Skipped (condition false)'; Notes = $meta.notes })
        continue
    }

    if (Test-PackageInstalled $id) {
        Write-Host "Already installed: $id"
        $results.Add([pscustomobject]@{ Id = $id; Status = 'Already installed'; Notes = $meta.notes })
        continue
    }

    $res = Install-Package -Id $id -Notes $meta.notes -Override $meta.override
    $results.Add($res)
}

Write-Host ""
Write-Host "=== Installation Summary ==="
$results | Format-Table -AutoSize

Write-Host ""
Write-Host "Next steps:"
if (Test-PackageInstalled 'CoreyButler.NVMforWindows') {
    Write-Host " - Open a new terminal, then:"
    Write-Host "     nvm list available"
    Write-Host "     nvm install lts"
    Write-Host "     nvm use lts"
    Write-Host "     node -v  &&  npm -v"
}
Write-Host " - Python pip check:  python -m pip --version"
Write-Host " - PostgreSQL: verify service is running and set credentials if needed."
Write-Host " - If Visual Studio requested a reboot, do that before first launch."
