#!/bin/bash
# AIDJ Live: 起動スクリプト
# WSL 側の全プロセスを一括起動し、Renois/TUI の起動指示を表示する

set -e
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
cd "$ROOT"

echo "========================================"
echo "  AIDJ Live Startup"
echo "========================================"
echo ""

# ── 1. osc_bridge.py ──────────────────
# ターミナルを閉じても死なないよう setsid で新セッションにデタッチし、
# 出力は host/state/bridge.log へリダイレクトする(旧版は & だけで
# ターミナル終了時に SIGHUP で bridge が死亡し、書き込みが静かに失敗していた)。
LOG="$ROOT/host/state/bridge.log"
PIDFILE="$ROOT/host/state/bridge.pid"
mkdir -p "$ROOT/host/state"
if [ -f "$LOG" ] && [ "$(stat -c%s "$LOG" 2>/dev/null || echo 0)" -gt 10485760 ]; then
    mv "$LOG" "$LOG.1"
fi

# pgrep は末尾アンカー必須: "osc_bridge.py" を含むシェルのコマンドライン
# (例: py_compile 経由の起動)に誤マッチして起動スキップする事故があった
BRIDGE_PAT='osc_bridge\.py$'

if pgrep -f "$BRIDGE_PAT" >/dev/null 2>&1; then
    echo "[✓] osc_bridge.py は既に起動中 (pid: $(pgrep -f "$BRIDGE_PAT" | tr '\n' ' '))"
else
    echo "[*] osc_bridge.py をデタッチ起動 (log: host/state/bridge.log)..."
    setsid -f "$ROOT/host/.venv/bin/python" -u "$ROOT/host/osc/osc_bridge.py" >> "$LOG" 2>&1 < /dev/null
    sleep 2
    if pgrep -f "$BRIDGE_PAT" >/dev/null 2>&1; then
        pgrep -f "$BRIDGE_PAT" > "$PIDFILE"
        echo "[✓] osc_bridge.py 起動完了 (pid: $(tr '\n' ' ' < "$PIDFILE"))"
    else
        echo "[✗] osc_bridge.py 起動失敗。$LOG を確認:"
        tail -20 "$LOG" 2>/dev/null
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
    echo "    -> Renoise 側で Tools → AIDJ → Start Session を実行してください"
    echo "    -> 実行済みなら host/state/bridge.log と Windows 側ファイアウォール(UDP 8080/8088)を確認"
fi

echo ""
echo "========================================"
echo "  Windows 側の操作"
echo "========================================"
echo ""
echo "  1. Renoise 起動"
echo "  2. File → Open → 自分で作成した AIDJ XRNS (README参照)"
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
