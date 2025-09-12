:: --- Manually build the problematic native module ---
echo Forcing compilation of the native C++ addon...
cd %~dp0\cs-demo-processor\csdm-fork\src\node\os\get-running-process-exit-code
call ..\..\..\..\node_modules\.bin\node-gyp rebuild --msvs_version=2019
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
