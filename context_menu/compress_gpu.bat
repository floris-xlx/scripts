@echo off
setlocal
set "input=%~1"
set "folder=%~dp1"
set "filename=%~n1"
set "output=%folder%%filename%_compressed.mp4"

:: Change ffmpeg path if needed
"C:\ffmpeg\bin\ffmpeg.exe" -hwaccel cuda -i "%input%" -c:v hevc_nvenc -preset slow -cq 25 "%output%"

echo Done: %output%
pause
