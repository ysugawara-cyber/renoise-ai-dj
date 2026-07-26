#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="$ROOT/host/state/bridge.pid"
SCRIPT="$ROOT/host/osc/osc_bridge.py"

find_bridge_pid() {
  python3 - "$SCRIPT" <<'PY'
import os, pathlib, sys
script = sys.argv[1]
for path in pathlib.Path("/proc").glob("[0-9]*/cmdline"):
    if path.parent.name == str(os.getpid()):
        continue
    try:
        args = [part.decode() for part in path.read_bytes().split(b"\0") if part]
    except (OSError, UnicodeDecodeError):
        continue
    if script in args:
        print(path.parent.name)
        break
PY
}

pid=""
if [[ -f "$PIDFILE" ]]; then pid="$(tr -d '[:space:]' < "$PIDFILE")"; fi
if [[ ! "$pid" =~ ^[0-9]+$ ]] || [[ ! -r "/proc/$pid/cmdline" ]]; then
  rm -f "$PIDFILE"
  pid="$(find_bridge_pid)"
fi
if [[ -z "$pid" ]]; then
  echo "osc_bridge is not running for this checkout"
  exit 0
fi

matches=false
if ! exec {cmdline_fd}<"/proc/$pid/cmdline" 2>/dev/null; then
  rm -f "$PIDFILE"
  echo "osc_bridge exited before it could be stopped"
  exit 0
fi
while IFS= read -r -d '' argument; do
  [[ "$argument" == "$SCRIPT" ]] && matches=true
done <&$cmdline_fd
exec {cmdline_fd}<&-
if ! $matches; then
  echo "Refusing to stop PID $pid: command is not this checkout's bridge" >&2
  exit 1
fi

kill "$pid"
for _ in {1..20}; do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$pid" 2>/dev/null; then
  echo "osc_bridge PID $pid did not stop within 2 seconds" >&2
  exit 1
fi
rm -f "$PIDFILE"
echo "Stopped osc_bridge PID $pid"
