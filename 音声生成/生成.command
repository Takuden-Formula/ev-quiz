#!/bin/bash
# 読み上げ音声を作り直す（Mac 用。Windows は 生成.bat）。必要: python3 -m pip install edge-tts、Node.js
cd "$(dirname "$0")" || exit 1
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"   # Finder から開いたときも Homebrew の python3 / node を見つける
pause(){ read -r -p "Enter キーで閉じます" _; }
PY=$(command -v python3 || command -v python)
if [ -z "$PY" ] || ! "$PY" -c 'import sys; sys.exit(sys.version_info[0] < 3)' 2>/dev/null; then
  echo "Python 3 が使えません。インストールしてから、もう一度実行してください。"; pause; exit 1
fi
if ! "$PY" -c 'import edge_tts' 2>/dev/null; then
  echo "edge-tts が入っていません。ターミナルで次を実行してください:"
  echo "  \"$PY\" -m pip install --user edge-tts"
  echo "（externally-managed-environment と断られたら、最後に --break-system-packages を付ける）"
  pause; exit 1
fi
if ! command -v node >/dev/null; then
  echo "Node.js が見つかりません。https://nodejs.org/ から入れてください。"; pause; exit 1
fi
"$PY" gen_audio.py
pause
