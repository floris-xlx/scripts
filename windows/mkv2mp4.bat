@echo off
setlocal

REM Input file passed from context menu
set "infile=%~1"

REM Output file (same folder, same name, but .mp4)
set "outfile=%~dpn1.mp4"

echo Converting "%infile%" to "%outfile%"...
ffmpeg -i "%infile%" -c copy "%outfile%"

echo Done!
pause
