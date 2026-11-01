#!/bin/bash
# EVクイズ - Mac にダウンロードして展開する（ターミナルに1行貼るだけ）
#   curl -fsSL https://raw.githubusercontent.com/Takuden-Formula/ev-quiz/main/mac/install.sh | bash
# ブラウザでダウンロードしたものと違い「開発元を検証できません」の警告が出ない（curl は隔離の印を付けないため）
set -e
URL="https://github.com/Takuden-Formula/ev-quiz/archive/refs/heads/main.zip"   # ブランチの最新
DEST="${1:-$HOME/Desktop}"
[ -d "$DEST" ] || DEST="$HOME"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/evquiz.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "ダウンロードしています…（約 60 MB）"
curl -fL --progress-bar -o "$TMP/a.zip" "$URL"
ditto -x -k "$TMP/a.zip" "$TMP/x"
SRC="$(find "$TMP/x" -maxdepth 2 -type f -name speech.js -path '*ev-quiz*' | head -1)"   # ZIP の中のゲームのフォルダ（ev-quiz-main）
SRC="${SRC%/speech.js}"
[ -n "$SRC" ] || { echo "ZIP の中に EVクイズ のフォルダがありません"; exit 1; }
if [ -e "$DEST/ev-quiz" ]; then
  OLD="$DEST/ev-quiz_old_$(date +%Y%m%d_%H%M%S)"
  mv "$DEST/ev-quiz" "$OLD"
  echo "前の版は $OLD に残しました（記録 records.csv を置いていたら移してください）"
fi
ditto "$SRC" "$DEST/ev-quiz"
xattr -dr com.apple.quarantine "$DEST/ev-quiz" 2>/dev/null || true
chmod +x "$DEST/ev-quiz/"*.command "$DEST/ev-quiz/mac/"*.sh "$DEST/ev-quiz/mac/"*.pl "$DEST/ev-quiz/音声生成/"*.command 2>/dev/null || true
echo
echo "できました: $DEST/ev-quiz"
echo "開いたフォルダの「起動_Mac.command」をダブルクリックするとゲームが始まります"
open "$DEST/ev-quiz"
