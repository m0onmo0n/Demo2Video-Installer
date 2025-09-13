@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
cd /d "%ROOT%"

REM ================================================================
REM Self-elevate if not running as Administrator
REM ================================================================
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elevated' -Verb RunAs"
  exit /b
)
if /I "%~1"=="elevated" shift

cls
echo =================================================================
echo == CS Demo Processor - Installer                                ==
echo =================================================================
echo.

REM ================================================================
REM Ensure dependency installer exists, then run it
REM ================================================================
if not exist "%ROOT%install-deps.ps1" (
  echo Missing install-deps.ps1 next to install.bat. Update your repo and retry.
  goto :PAUSE_AND_EXIT_FAIL
)

echo [1/6] Installing prerequisites (Python, Node/NVM, OBS, PostgreSQL, VS Build Tools)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%install-deps.ps1"
if errorlevel 1 (
  echo.
  echo ============================= ERROR ===============================
  echo Dependency installation failed. See output above.
  echo ===================================================================
  echo.
  goto :PAUSE_AND_EXIT_FAIL
)
echo Prerequisites installed.
echo.

REM ================================================================
REM Robust Python resolver (works without PATH refresh)
REM ================================================================
set "PYEXE="
set "PYLAUNCH=%SystemRoot%\py.exe"

python --version >nul 2>&1 && set "PYEXE=python"

if not defined PYEXE if exist "%PYLAUNCH%" (
  "%PYLAUNCH%" -3 --version >nul 2>&1 && set "PYEXE=%PYLAUNCH% -3"
)

if not defined PYEXE (
  for /f "usebackq delims=" %%P in (`
    powershell -NoProfile -Command ^
      "$c=@(); foreach($r in 'HKCU:\Software\Python\PythonCore','HKLM:\Software\Python\PythonCore'){" ^
      " if(Test-Path $r){ Get-ChildItem $r -Name|?{$_ -match '^\d+(\.\d+)?$'}|Sort-Object {[version]$_} -desc |" ^
      "   %%{ $ip=Join-Path $r $_ 'InstallPath'; if(Test-Path $ip){ $ep=(gp $ip -ea 0).ExecutablePath; if($ep){$c+=$ep} } } } }" ^
      "$c += Get-ChildItem -Path $env:LocalAppData\Programs\Python -Filter python.exe -Recurse -ea 0 | Select-Object -Expand FullName;" ^
      "$c += Get-ChildItem -Path $env:ProgramFiles -Filter python.exe -Recurse -ea 0 | ? FullName -match 'Python3' | Select-Object -Expand FullName;" ^
      "($c | ? {$_}) | Select-Object -First 1"
  `) do set "PYEXE=%%P"
  if not defined PYEXE (
    echo ============================= ERROR ===============================
    echo Python is not available yet. Close and re-open this window, or rerun later.
    echo ===================================================================
    goto :PAUSE_AND_EXIT_FAIL
  )
  for %%D in ("%PYEXE%") do set "PYDIR=%%~dpD"
  if defined PYDIR set "PATH=%PATH%;%PYDIR%;%PYDIR%Scripts"
)

for /f "delims=" %%V in ('call %PYEXE% --version 2^>^&1') do set "PYVER=%%V"
echo Using Python via: %PYEXE%   (%PYVER%)
echo.

REM ================================================================
REM Verify Node (optional; nvm is installed by install-deps.ps1)
REM ================================================================
echo [2/6] Checking for Node.js...
node --version >nul 2>&1
if errorlevel 1 (
  echo Node not found on PATH yet; continuing, npm steps will attempt to proceed.
) else (
  for /f "delims=" %%V in ('node --version 2^>^&1') do set "NODEVER=%%V"
  echo Node found: %NODEVER%
)
echo.

REM ================================================================
REM Install Python dependencies
REM ================================================================
echo [3/6] Installing Python dependencies...
call %PYEXE% -m pip install -r "%ROOT%cs-demo-processor\requirements.txt"
if errorlevel 1 (
  echo.
  echo ============================= ERROR ===============================
  echo pip failed to install dependencies.
  echo ===================================================================
  echo.
  goto :PAUSE_AND_EXIT_FAIL
)
echo Python dependencies installed.
echo.

REM ================================================================
REM Install Node dependencies and build native addon
REM ================================================================
echo [4/6] Installing CS Demo Manager dependencies...
pushd "%ROOT%cs-demo-processor\csdm-fork"

set "GYP_MSVS_VERSION=2022"
call npm config set engine-strict false --location=project >nul
call npm config set fund false --location=project >nul
call npm config set audit false --location=project >nul

echo Running: npm install (this may take a while)...
call npm install
set "NPM_RC=%ERRORLEVEL%"
echo npm install exit code: %NPM_RC%
echo.

echo Forcing compilation of the native C++ addon...
pushd src\node\os\get-running-process-exit-code
if exist "..\..\..\..\node_modules\.bin\node-gyp.cmd" (
  call "..\..\..\..\node_modules\.bin\node-gyp.cmd" rebuild --msvs_version=2022
) else (
  call npx --yes node-gyp rebuild --msvs_version=2022
)
if errorlevel 1 (
  echo.
  echo ============================= ERROR ===============================
  echo Native module rebuild failed. See messages above.
  echo ===================================================================
  echo.
  popd
  popd
  goto :PAUSE_AND_EXIT_FAIL
)
echo Native module built successfully.
popd
popd
echo.

REM ================================================================
REM Final setup (interactive with config.ini detection)
REM ================================================================
echo [5/6] Configuration

set "CONFIG_REPO=%ROOT%cs-demo-processor\config.ini"
set "CONFIG_APPDATA=%APPDATA%\Demo2Video\config.ini"
set "CONFIG_FOUND="

if exist "%CONFIG_REPO%"   set "CONFIG_FOUND=%CONFIG_REPO%"
if exist "%CONFIG_APPDATA%" set "CONFIG_FOUND=%CONFIG_APPDATA%"

if not defined CONFIG_FOUND (
  echo No existing config.ini detected. Running initial setup...
  echo.
  goto :RUN_SETUP
) else (
  echo Found existing config.ini at:
  echo   %CONFIG_FOUND%
  echo.
  choice /c YN /n /m "Do you want to re-create config.ini now? [y/N]: "
  if errorlevel 2 goto :SKIP_SETUP
  if errorlevel 1 (
    echo Backing up current config.ini...
    set "CFG_BAK=%CONFIG_FOUND%.bak"
    copy /Y "%CONFIG_FOUND%" "%CFG_BAK%" >nul 2>&1
    echo Backup saved to: %CFG_BAK%
    echo.
    goto :RUN_SETUP
  )
)

:RUN_SETUP
set "PYTHONUNBUFFERED=1"
set "PYTHONIOENCODING=utf-8"
set "PYTHONLEGACYWINDOWSSTDIO=1"
set "CI="
pushd "%ROOT%cs-demo-processor"
echo Running: %PYEXE% setup.py  (follow the prompts below)
call %PYEXE% setup.py
set "SETUP_RC=%ERRORLEVEL%"
popd
echo.
if not "%SETUP_RC%"=="0" (
  echo ============================= ERROR ===============================
  echo setup.py exited with code %SETUP_RC%. Please review the messages above.
  echo ===================================================================
  echo.
  goto :PAUSE_AND_EXIT_FAIL
)
goto :DONE_SETUP

:SKIP_SETUP
echo Skipping setup; keeping existing config.ini.
echo.

:DONE_SETUP
echo.
echo =================================================================
echo == Installation and configuration are complete!                ==
echo =================================================================
echo.
goto :PAUSE_AND_EXIT_OK

:PAUSE_AND_EXIT_FAIL
echo Press any key to close...
pause >nul
endlocal
exit /b 1

:PAUSE_AND_EXIT_OK
echo Press any key to close...
pause >nul
endlocal
exit /b 0
