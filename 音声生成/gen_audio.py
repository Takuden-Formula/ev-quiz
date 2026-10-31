"""読み上げ音声ファイルを作る（Microsoft の AI 音声 / edge-tts を使う。インターネットが必要）。
問題や READ（speech.js）を変えたら、もう一度実行する。済んだファイルは飛ばす。
使い方:  pip install edge-tts   →   音声生成\生成.bat（Mac は 音声生成/生成.command）  （または python gen_audio.py）"""
import asyncio, json, os, subprocess, sys
import edge_tts

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FAILED = []
VOICES = {"nanami": "ja-JP-NanamiNeural", "keita": "ja-JP-KeitaNeural"}

def load_list():
    out = subprocess.run(["node", os.path.join(HERE, "gen_list.js")], capture_output=True, check=True, encoding="utf-8").stdout
    return json.loads(out)

async def one(sem, pack, voice, item):
    path = os.path.join(ROOT, "audio", pack, item["id"] + ".mp3")
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return 0
    async with sem:
        for _ in range(4):
            try:
                tmp = path + ".tmp"
                await edge_tts.Communicate(item["text"], voice, rate="+0%").save(tmp)
                if os.path.getsize(tmp) == 0:
                    raise RuntimeError("empty audio")
                os.replace(tmp, path)          # 完成してから置く（途中の壊れた mp3 を残さない）
                return 1
            except Exception as e:
                err = e
                await asyncio.sleep(1.5)
        print("失敗:", item["text"], err, file=sys.stderr)
        FAILED.append(item["text"])
        return 0

async def main():
    items = load_list()
    sem = asyncio.Semaphore(6)
    for pack, voice in VOICES.items():
        os.makedirs(os.path.join(ROOT, "audio", pack), exist_ok=True)
        for f in os.listdir(os.path.join(ROOT, "audio", pack)):   # 前回の中断で残った一時ファイルを掃除
            if f.endswith(".tmp"): os.remove(os.path.join(ROOT, "audio", pack, f))
        n = sum(await asyncio.gather(*[one(sem, pack, voice, it) for it in items]))
        print(f"{pack}: 新規 {n} / 全 {len(items)} 文")

asyncio.run(main())
if FAILED:
    print(f"失敗 {len(FAILED)} 文。もう一度実行してください。", file=sys.stderr)
    sys.exit(1)
