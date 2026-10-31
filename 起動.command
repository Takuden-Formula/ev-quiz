#!/bin/bash
# EVクイズ 起動（Mac 用。Windows は 起動.bat）
# このフォルダを localhost:8791 で配信し、専用プロファイルの Chrome（無ければ Edge、どちらも無ければ既定のブラウザ）で開く
cd "$(dirname "$0")" || exit 1
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"   # Finder から開いたときも Homebrew の python3 を見つける
PORT=8791
URL="http://127.0.0.1:$PORT/index.html"
# このアプリのサーバーが応答しているか（別アプリが同じポートを使っていても誤判定しないよう、このアプリにしか無いファイルで見る）
ours(){ curl -sf --max-time 2 -o /dev/null "http://127.0.0.1:$PORT/speech.js"; }

pause(){ read -r -p "Enter キーで閉じます" _; }

find_app(){ for d in "/Applications" "$HOME/Applications"; do [ -d "$d/$1.app" ] && return 0; done; return 1; }
open_browser(){
  # プロファイルは TMPDIR だと macOS が消してカメラ許可を聞き直すので、Application Support に置く
  local flags=(--user-data-dir="$HOME/Library/Application Support/evquiz_browser" --no-first-run --autoplay-policy=no-user-gesture-required)
  if find_app "Google Chrome"; then
    open -na "Google Chrome" --args "${flags[@]}" "$URL"
  elif find_app "Microsoft Edge"; then
    open -na "Microsoft Edge" --args "${flags[@]}" "$URL"
  else
    open "$URL"   # 既定のブラウザ（多くは Safari）。Safari: 自動再生を許可していないと読み上げが出ない（README 参照。一度クリックしても鳴る）
  fi
}

# すでにサーバーが動いている（前に開いたウィンドウが残っている）ときは、ブラウザだけ開く
if ours; then
  open_browser
  echo "サーバーは起動済みです。ブラウザを開きました: $URL"
  exit 0
fi

PY=$(command -v python3 || command -v python)
# /usr/bin/python3 は Command Line Tools が無いとインストール案内を出すだけなので、実際に動くか確かめる
if [ -z "$PY" ] || ! "$PY" -c 'import sys, http.server; sys.exit(sys.version_info[0] < 3)' 2>/dev/null; then
  echo "Python 3 が使えません。インストールの案内が出たら済ませてから、もう一度起動してください。"
  echo "（または https://www.python.org/ から入れる）"
  pause; exit 1
fi

"$PY" -m http.server "$PORT" --bind 127.0.0.1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null' EXIT INT TERM HUP
for _ in $(seq 50); do ours && break; kill -0 "$SERVER" 2>/dev/null || break; sleep 0.2; done   # 待ち受け開始を最大10秒待つ
if ! ours; then
  echo "サーバーを起動できませんでした（ポート $PORT を別のアプリが使っているかもしれません）。"
  pause; exit 1
fi

open_browser
echo "EVクイズを開きました: $URL"
echo "遊び終わるまでこのウィンドウは閉じないでください（閉じるか Ctrl+C でサーバーが止まります）。"
wait "$SERVER"
