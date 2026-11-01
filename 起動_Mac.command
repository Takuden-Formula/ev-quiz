#!/bin/bash
# EVクイズを起動します（この窓を閉じると終了します）
echo "EVクイズを起動します（この窓を閉じると終了します）"
exec bash "$(dirname "$0")/mac/start.sh"
