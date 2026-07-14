#!/bin/bash
# AIDJ Live: 起動スクリプト
# WSL 側の全プロセスを一括起動し、Renois/TUI の起動指示を表示する

set -e
ROOT="/mnt/c/Users/y_sugawara/OneDrive - sugamasalab/ドキュメント/workdir/renoise_AI_music"
cd "$ROOT"

echo "========================================"
echo "  AIDJ Live Startup"
echo "========================================"
echo ""

# ── 1. osc_bridge.py ──────────────────
if ps aux | grep -q "[o]sc_bridge"; then
    echo "[✓] osc_bridge.py は既に起動中"
else
    echo "[*] osc_bridge.py を起動..."
    host/.venv/bin/python -u host/osc/osc_bridge.py &
    sleep 2
    if ps aux | grep -q "[o]sc_bridge"; then
        echo "[✓] osc_bridge.py 起動完了"
    else
        echo "[✗] osc_bridge.py 起動失敗。host/.venv が正しいか確認してください"
        exit 1
    fi
fi

# ── 2. session heartbeat 確認 ──────────
sleep 2
HB_AGE=$(python3 -c "
import json, time
try:
    s = json.load(open('host/state/session.json'))
    hb = s.get('renoise_heartbeat', 0)
    print(int(time.time() - hb))
except: print('999')
" 2>/dev/null)

if [ "$HB_AGE" -lt 5 ] 2>/dev/null; then
    echo "[✓] Renoise セッション アクティブ (heartbeat: ${HB_AGE}s ago)"
else
    echo "[!] Renoise セッション未検出 (heartbeat: ${HB_AGE}s ago)"
fi

echo ""
echo "========================================"
echo "  Windows 側の操作"
echo "========================================"
echo ""
echo "  1. Renoise 起動"
echo "  2. File → Open → AIDJ-TEMPLATE.xrns"
echo "  3. Tools → AIDJ → Start Session"
echo ""

echo "========================================"
echo "  TUI 起動コマンド"
echo "========================================"
echo ""
echo "  ターミナル1 (conductor):"
echo "    cd \"$ROOT\" && opencode --agent dj_conductor"
echo ""
echo "  ターミナル2 (drums):"
echo "    cd \"$ROOT\" && opencode --agent dj_live_drums"
echo ""
echo "  ターミナル3 (bass/fx):"
echo "    cd \"$ROOT\" && opencode --agent dj_live_bass_fx"
echo ""
echo "  ターミナル4 (pads):"
echo "    cd \"$ROOT\" && opencode --agent dj_live_pads"
echo ""

echo "========================================"
echo "  準備完了。あとは Renoise と TUI を起動してください"
echo "========================================"
