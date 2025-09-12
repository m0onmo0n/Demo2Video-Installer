@echo off
CLS
echo =================================================================
echo == CS Demo Processor - Prerequisite Checker ^& Installer        ==
echo =================================================================
echo.

:: --- Check for Administrator Privileges ---
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
IF '%ERRORLEVEL%' NEQ '0' (
    echo.
    echo ============================= ERROR ===============================
    echo.
    echo This script requires Administrator privileges.
    echo Please right-click on install.bat and select "Run as administrator".
    echo.
    echo ===================================================================
    echo.
    pause
    exit /b
)

:: --- (Your other prerequisite checks and steps remain the same) ---
cd cs-demo-processor
echo This script will check for required software and install all necessary dependencies.
echo.
echo [1/6] Checking for Python...
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python is not installed or not in PATH.
    pause
    exit /b
)
echo Python found.
echo.
echo [2/6] Checking for Node.js...
node --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not installed or not in PATH.
    pause
    exit /b
)
echo Node.js found.
echo.
echo Press any key to begin the dependency installation...
pause > nul
echo.

:: --- Install Visual Studio Build Tools ---
echo [3/6] Verifying and installing C++ Build Tools...
powershell -ExecutionPolicy Bypass -File %~dp0\install_vs_tools.ps1
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================= ERROR ===============================
    echo.
    echo The Visual Studio Build Tools installation script failed.
    echo Please check the output above for more details.
    echo.
    echo ===================================================================
    echo.
    pause
    exit /b
)
echo.

:: --- (The rest of your script remains the same) ---
echo [4/6] Installing Python dependencies...
pip install -r requirements.txt
echo Python dependencies installed.
echo.
echo [5/6] Installing CS Demo Manager dependencies...
cd csdm-fork
call npm config set msvs_version 2019
call npm install

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================= WARNING ===============================
    echo.
    echo 'npm install' reported an error, which is expected for some native modules.
    echo Attempting to build the native module manually...
    echo.
    echo =====================================================================
    echo.
)

:: --- Manually build the problematic native module ---
echo Forcing compilation of the native C++ addon...
cd src\node\os\get-running-process-exit-code
call ..\..\..\..\node_modules\.bin\node-gyp rebuild
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================= ERROR ===============================
    echo.
    echo Failed to manually build the native module. The installation cannot continue.
    echo Please check the error messages above.
    echo.
    echo ===================================================================
    echo.
    pause
    exit /b
)
echo Native module built successfully.
cd ..\..\..\..

cd ..
echo.
echo [6/6] Starting interactive configuration setup...
python setup.py
echo.
echo =================================================================
echo == Installation and configuration are complete!              ==
echo =================================================================
echo.
pause
