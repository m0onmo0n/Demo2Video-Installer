@echo off
setlocal EnableExtensions
CLS
echo =================================================================
echo == CS Demo Processor - Installer                                ==
echo =================================================================
echo.

REM --- Resolve repo root (folder where this BAT lives) ---
set "ROOT=%~dp0"

REM --- Check for Administrator Privileges (robust) ---
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================= ERROR ===============================
    echo This script requires Administrator privileges.
    echo Right-click install.bat and select "Run as administrator".
    echo ===================================================================
    echo.
    goto :PAUSE_AND_EXIT_FAIL
)

REM --- 1/6: Run unified dependency installer ---
echo [1/6] Installing prerequisites (Python, Node/NVM, OBS, PostgreSQL, VS Build Tools)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%install-deps.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================= ERROR ===============================
    echo Dependency installation failed. See output above.
    echo ===================================================================
    echo.
    goto :PAUSE_AND_EXIT_FAIL
)
echo Prerequisites installed.
echo.

REM --- If NVM exists, ensure a compatible LTS in THIS session (quietly bumps to >=20.19) ---
where nvm >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Ensuring NVM is using a compatible Node LTS for this session...
    call nvm install 20.19.1 >nul 2>&1
    call nvm use 20.19.1   >nul 2>&1
)

REM --- 2/6: Python check ---
echo [2/6] Checking for Python...
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python is not installed or not in PATH.
    goto :PAUSE_AND_EXIT_FAIL
)
for /f "delims=" %%V in ('python --version 2^>^&1') do set "PYVER=%%V"
echo Python found: %PYVER%
echo.

REM --- 3/6: Node check ---
echo [3/6] Checking for Node.js...
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not installed or not in PATH.
    goto :PAUSE_AND_EXIT_FAIL
)
for /f "delims=" %%V in ('node --version 2^>^&1') do set "NODEVER=%%V"
echo Node found: %NODEVER%
echo.

REM --- 4/6: Install Python dependencies ---
echo [4/6] Installing Python dependencies...
python -m pip install -r "%ROOT%cs-demo-processor\requirements.txt"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================= ERROR ===============================
    echo pip failed to install dependencies.
    echo ===================================================================
    echo.
    goto :PAUSE_AND_EXIT_FAIL
)
echo Python dependencies installed.
echo.

REM --- 5/6: Install Node dependencies and build addon ---
echo [5/6] Installing CS Demo Manager dependencies...
pushd "%ROOT%cs-demo-processor\csdm-fork"

REM Tell node-gyp to use VS2022 via env (safer than npm flag)
set "GYP_MSVS_VERSION=2022"

REM Make engine mismatches non-fatal for THIS project
call npm config set engine-strict false --location=project >nul

REM Optional: reduce noise
call npm config set fund false --location=project >nul
call npm config set audit false --location=project >nul

echo Running: npm install (this may take a while)...
call npm install
set "NPM_RC=%ERRORLEVEL%"
echo npm install exit code: %NPM_RC%
echo.

REM Even if npm returned nonzero (e.g., engine warnings escalated), continue to manual rebuild
echo Forcing compilation of the native C++ addon...
pushd src\node\os\get-running-process-exit-code

REM Prefer the local cmd shim; fall back to npx
if exist "..\..\..\..\node_modules\.bin\node-gyp.cmd" (
    call "..\..\..\..\node_modules\.bin\node-gyp.cmd" rebuild --msvs_version=2022
) else (
    call npx --yes node-gyp rebuild --msvs_version=2022
)

if %ERRORLEVEL% NEQ 0 (
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

REM --- 6/6: Final setup (INTERACTIVE) ---
echo [6/6] Starting interactive configuration setup...
set "PYTHONUNBUFFERED=1"
set "PYTHONIOENCODING=utf-8"
set "PYTHONLEGACYWINDOWSSTDIO=1"
set "CI="

pushd "%ROOT%cs-demo-processor"
echo Running: python setup.py  (follow the prompts below)
call python setup.py
set "SETUP_RC=%ERRORLEVEL%"
popd
echo.

if "%SETUP_RC%"=="0" (
    echo setup.py completed successfully.
) else (
    echo ============================= ERROR ===============================
    echo setup.py exited with code %SETUP_RC%. Please review the messages above.
    echo ===================================================================
    echo.
    goto :PAUSE_AND_EXIT_FAIL
)

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
