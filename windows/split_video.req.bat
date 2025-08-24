@echo off
setlocal enabledelayedexpansion

REM ================================
REM  Split video if > 3.5GB with ffmpeg
REM  Drag & Drop a file onto this script
REM ================================

if "%~1"=="" (
    echo Please drag and drop a video file onto this script.
    pause
    exit /b
)

set "INPUT=%~1"

if not exist "%INPUT%" (
    echo File not found: %INPUT%
    pause
    exit /b
)

) else (
    echo File is <= 3.5GB, no need to split.
    pause
    exit /b
)

REM Max size = 3.5GB in bytes
set /a MAXSIZE=3758096384

REM Get file size
for %%A in ("%INPUT%") do set FILESIZE=%%~zA

REM Original name (with extension)
set "BASENAME=%~nx1"

REM Sanitize filename (replace spaces & bad chars with _)
set "SANITIZED=%BASENAME%"
for %%C in (" " "!" "#" "$" "%%" "&" "(" ")" "{" "}" "[" "]" ";" "^" "=" "+" "," "'" "`" "~") do (
    set "SANITIZED=!SANITIZED:%%~C=_!"
)

REM Output folder = sanitized name without extension
set "OUTDIR=!SANITIZED:~0,-4!"

if not exist "!OUTDIR!" mkdir "!OUTDIR!"

if %FILESIZE% GTR %MAXSIZE% (
    echo File is larger than 3.5GB, splitting...
    ffmpeg -i "%INPUT%" -c copy -map 0 -f segment -reset_timestamps 1 -fs %MAXSIZE% "!OUTDIR!\%~n1_part%%03d.mp4"
) else (
    echo File is <= 3.5GB, copying...
    copy "%INPUT%" "!OUTDIR!\"
)

echo.
echo Done! Output saved in: "!OUTDIR!"
pause
