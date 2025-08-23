# install_vs_tools.ps1

Write-Host "Downloading Visual Studio Build Tools installer..."
$installerPath = Join-Path $env:TEMP "vs_buildtools.exe"
$uri = "https://aka.ms/vs/17/release/vs_BuildTools.exe"

try {
    Invoke-WebRequest -Uri $uri -OutFile $installerPath
} catch {
    Write-Error "Failed to download the installer. Please check your internet connection."
    exit 1
}

Write-Host "Installing required C++ components... This may take 10-20 minutes."
$arguments = "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

try {
    Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -Verb RunAs
} catch {
    Write-Error "Failed to start the installer. Please ensure you are running the script as an administrator."
    exit 1
}

Write-Host "C++ Build Tools are configured."