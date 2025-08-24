@echo off
setlocal

REM Input file from context menu
set "infile=%~1"

REM Get input extension (lowercased)
set "ext=%~x1"
set "ext=%ext:~1%"
for %%A in (mp4 mov) do (
    if /I "%ext%"=="%%A" (
        goto ok
    )
)

echo Unsupported file type: %~x1
pause
exit /b

:ok
REM Output file (same folder, same name, same extension)
set "outfile=%~dpn1.%ext%"

echo Converting "%infile%" to "%outfile%"...
ffmpeg -i "%infile%" -c copy "%outfile%"

echo Done!
pause
