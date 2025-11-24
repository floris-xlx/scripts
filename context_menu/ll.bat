@echo off
setlocal

set "SCRIPT=%~dp0ll.py"
if not exist "%SCRIPT%" (
    echo ll.py not found at "%SCRIPT%".
    endlocal
    exit /b 1
)

where py >nul 2>nul
if not errorlevel 1 (
    py -3 "%SCRIPT%" %*
    endlocal
    exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
    python "%SCRIPT%" %*
    endlocal
    exit /b %ERRORLEVEL%
)

echo Python executable not found. Install Python and ensure it's on PATH.
endlocal
exit /b 1