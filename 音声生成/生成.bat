@echo off
rem Generate read-aloud audio clips (needs: pip install edge-tts, node)
cd /d "%~dp0"
python gen_audio.py || py -3 gen_audio.py
pause
