# EV Quiz - tiny local web server (no Python needed). Based on air-handle-drive/serve.ps1
# Usage: powershell -ExecutionPolicy Bypass -File serve.ps1 [-Kiosk] [-NoBrowser]   (-Kiosk = fullscreen mode, Esc to exit fullscreen)
# Host stays 127.0.0.1 and the port is searched from 8791 so the saved best scores / settings (per origin) are kept.
param([switch]$Kiosk, [switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $root 'server_log.txt'
function Log($m) { $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Write-Host $line; Add-Content -Path $logFile -Value $line -Encoding UTF8 }

$mime = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.mjs' = 'text/javascript; charset=utf-8'
  '.wasm' = 'application/wasm'; '.data' = 'application/octet-stream'; '.tflite' = 'application/octet-stream'; '.binarypb' = 'application/octet-stream'
  '.mp3' = 'audio/mpeg'; '.css' = 'text/css'; '.json' = 'application/json'; '.csv' = 'text/csv; charset=utf-8'
  '.png' = 'image/png'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.md' = 'text/plain; charset=utf-8'
}

# open Chrome/Edge with its own profile (same profile as the old launcher, so the saved best scores and the camera permission stay)
function Open-Browser($url) {
  $edges = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")
  $chromes = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LocalAppData\Google\Chrome\Application\chrome.exe")
  $edge = $edges | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  $chrome = $chromes | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if ($edge) { $browser = $edge; $prof = Join-Path $env:TEMP 'evquiz_edge' }
  elseif ($chrome) { $browser = $chrome; $prof = Join-Path $env:LOCALAPPDATA 'evquiz_chrome' }
  else { $browser = $null }
  $flags = @("--user-data-dir=`"$prof`"", '--no-first-run', '--autoplay-policy=no-user-gesture-required')
  if ($Kiosk) {
    # app window without address bar; the page goes fullscreen on the first click/key (Esc exits fullscreen)
    $url = "$url`?fs=1"
    $flags += @("--app=$url", '--start-maximized')
  } else { $flags += @('--new-window', $url) }
  if ($browser) { Start-Process -FilePath $browser -ArgumentList $flags; Log "Browser: $browser" }
  else { Start-Process $url; Log 'Edge/Chrome not found. Opened default browser.' }
}

# already running (an earlier window is still open)? -> just open the browser on the same port
# (first a quick TCP connect with a 200 ms limit, so a normal start does not wait)
function Test-Port($p) { $c = New-Object Net.Sockets.TcpClient; try { return $c.ConnectAsync('127.0.0.1', $p).Wait(200) -and $c.Connected } catch { return $false } finally { $c.Close() } }
foreach ($p in (8791..8799 | Where-Object { Test-Port $_ })) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 -Uri "http://127.0.0.1:$p/speech.js"
    if ($r.Content -match 'clipId') {
      Log "Server already running on port $p"
      if (-not $NoBrowser) { Open-Browser "http://127.0.0.1:$p/index.html" }
      Start-Sleep -Seconds 2; exit 0
    }
  } catch { }
}

# find a free port (from 8791, so it is the same port every time)
$listener = $null
foreach ($p in 8791..8799) {
  try {
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://127.0.0.1:$p/")
    $l.Start(); $listener = $l; $port = $p; break
  } catch { }
}
if (-not $listener) { Log 'ERROR: no free port in 8791-8799'; Read-Host 'Press Enter to exit'; exit 1 }
$url = "http://127.0.0.1:$port/index.html"
Log "Serving $root at $url"
if (-not $NoBrowser) { Open-Browser $url }

Log 'Close this window to stop the server.'
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request; $res = $ctx.Response
    try {
      $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/')
      if ($rel -eq '') { $rel = 'index.html' }
      $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
      if (-not $full.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $full -PathType Leaf)) {
        $res.StatusCode = 404; $b = [Text.Encoding]::UTF8.GetBytes('404'); $res.OutputStream.Write($b, 0, $b.Length)
        if ($rel -ne 'favicon.ico') { Log "404 $rel" }
      } else {
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        $res.Headers.Add('Cache-Control', 'no-cache')
        $bytes = [IO.File]::ReadAllBytes($full)
        $res.ContentLength64 = $bytes.Length
        if ($req.HttpMethod -ne 'HEAD') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
      }
    } catch { Log "ERROR $($_.Exception.Message)" }
    finally { try { $res.OutputStream.Close() } catch { } }
  }
} finally { $listener.Stop() }
