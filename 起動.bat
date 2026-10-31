@echo off
rem EVquiz launcher: serves this folder on localhost:8791 and opens Edge with its own profile (autoplay allowed)
cd /d "%~dp0"
start "" cmd /c "timeout /t 2 >nul & (start msedge --user-data-dir=%TEMP%\evquiz_edge --no-first-run --autoplay-policy=no-user-gesture-required http://127.0.0.1:8791/index.html || start http://127.0.0.1:8791/index.html)"
python -m http.server 8791 --bind 127.0.0.1 || py -3 -m http.server 8791 --bind 127.0.0.1
pause
