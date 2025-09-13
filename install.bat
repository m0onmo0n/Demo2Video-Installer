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

REM ------------------------------------------------------------------
REM Python command resolver: prefer "python", else use "py -3"
REM (this avoids PATH refresh issues after winget installs)
REM ------------------------------------------------------------------
set "PY=python"
%PY% --version >nul 2>&1
if errorlevel 1 (
    where py >nul 2>&1
    if not errorlevel 1 (
        set "PY=py -3"
    ) else (
        echo ============================= ERROR ===============================
        echo Python is not available on PATH and "py" launcher not found.
        echo Please open a new terminal or install Python, then re-run install.bat.
        echo ===================================================================
        goto :PAUSE_AND_EXIT_FAIL
    )
)
for /f "delims=" %%V in ('call %PY% --version 2^>^&1') do set "PYVER=%%V"
echo Using Python via: %PY%   (%PYVER%)
echo.

REM --- Optional: ensure NVM LTS in THIS shell (harmless if NVM missing) ---
where nvm >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Ensuring NVM is using a compatible Node LTS for this session...
    call nvm install 20.19.1 >nul 2>&1
    call nvm use 20.19.1   >nul 2>&1
)

REM --- 2/6: Node check ---
echo [2/6] Checking for Node.js...
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not installed or not in PATH.
    goto :PAUSE_AND_EXIT_FAIL
)
for /f "delims=" %%V in ('node --version 2^>^&1') do set "NODEVER=%%V"
echo Node found: %NODEVER%
echo.

REM --- 3/6: Install Python dependencies ---
echo [3/6] Installing Python dependencies...
call %PY% -m pip install -r "%ROOT%cs-demo-processor\requirements.txt"
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

REM --- 4/6: Install Node dependencies and build addon ---
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

REM --- 5/6: Final setup (INTERACTIVE) ---
echo [5/6] Starting interactive configuration setup...
set "PYTHONUNBUFFERED=1"
set "PYTHONIOENCODING=utf-8"
set "PYTHONLEGACYWINDOWSSTDIO=1"
set "CI="

pushd "%ROOT%cs-demo-processor"
echo Running: %PY% setup.py  (follow the prompts below)
call %PY% setup.py
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
