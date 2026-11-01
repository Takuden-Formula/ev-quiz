#!/bin/bash
# EVクイズ - macOS launcher. Called from 起動_Mac.command / 起動_全画面_Mac.command （エアハンドルの mac/start.sh と同じ方式）
# Usage: bash mac/start.sh [--kiosk]
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
LOG="$ROOT/server_log.txt"
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# open Chrome (or Edge, or the default browser = Safari)
# 専用プロファイル（前の 起動.command と同じ場所）で開く：ベスト記録・カメラの許可・自動再生の設定がそのまま残る
app_path() { for d in "/Applications" "$HOME/Applications"; do [ -d "$d/$1.app" ] && { echo "$d/$1.app"; return 0; }; done; return 1; }
open_browser() {
  local url="$1" browser="" name
  for name in "Google Chrome" "Microsoft Edge" "Chromium"; do
    if app_path "$name" >/dev/null; then browser="$name"; break; fi
  done
  local flags=(--user-data-dir="$HOME/Library/Application Support/evquiz_browser" --no-first-run --autoplay-policy=no-user-gesture-required)
  if [ "$KIOSK" = 1 ]; then url="$url?fs=1"; flags+=("--app=$url" --start-maximized); else flags+=(--new-window "$url"); fi
  if [ -n "$browser" ]; then
    open -na "$(app_path "$browser")" --args "${flags[@]}"; log "Browser: $browser"
  else
    open "$url"
    log 'Chrome / Edge が見つからないので標準のブラウザ（Safari）で開きました。'
    log '遊ぶことはできますが、記録フォルダは選べません（記録はブラウザ内に残り、設定の「CSV を書き出す」で保存できます）。'
  fi
}
KIOSK=0; [ "$1" = "--kiosk" ] && KIOSK=1

# すでにサーバが動いている（前に開いた窓が残っている）ときは、同じポートでブラウザだけ開く
for p in $(seq 8791 8799); do
  if curl -sf --max-time 1 "http://127.0.0.1:$p/speech.js" 2>/dev/null | grep -q clipId; then
    log "サーバは起動済みです（ポート $p）。ブラウザだけ開きます"
    open_browser "http://127.0.0.1:$p/index.html"
    exit 0
  fi
done

PORTFILE="$(mktemp "${TMPDIR:-/tmp}/evquiz_port.XXXXXX")"
rm -f "$PORTFILE"

# start the server (Perl is always included in macOS; Python is used only if Perl is missing)
if command -v perl >/dev/null 2>&1; then
  perl "$ROOT/mac/serve.pl" "$ROOT" "$PORTFILE" >>"$LOG" 2>&1 &
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import http.server' >/dev/null 2>&1; then
  python3 - "$ROOT" "$PORTFILE" >>"$LOG" 2>&1 <<'PY' &
import sys, os, functools, http.server, socketserver
root, pf = sys.argv[1], sys.argv[2]
http.server.SimpleHTTPRequestHandler.extensions_map.update({'.mjs': 'text/javascript', '.wasm': 'application/wasm', '.mp3': 'audio/mpeg'})
H = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
for p in range(8791, 8800):
    try: s = socketserver.ThreadingTCPServer(('127.0.0.1', p), H); break
    except OSError: s = None
if not s: sys.exit('ERROR: no free port in 8791-8799')
open(pf, 'w').write(str(p)); print('PORT', p, flush=True); s.serve_forever()
PY
else
  log 'ERROR: Perl も Python も見つかりません'; read -r -p 'Enter で閉じます'; exit 1
fi
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null; rm -f "$PORTFILE"' EXIT INT TERM HUP

for _ in $(seq 1 50); do [ -s "$PORTFILE" ] && break; kill -0 $SERVER_PID 2>/dev/null || break; sleep 0.1; done
PORT="$(cat "$PORTFILE" 2>/dev/null)"
if [ -z "$PORT" ]; then log 'ERROR: サーバを起動できません（server_log.txt を見てください）'; read -r -p 'Enter で閉じます'; exit 1; fi
URL="http://127.0.0.1:$PORT/index.html"
log "Serving $ROOT at $URL"
open_browser "$URL"

echo
echo 'この窓を閉じる（または Ctrl+C）とサーバが止まります。遊び終わるまで閉じないでください。'
wait $SERVER_PID
