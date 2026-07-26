#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
LIVE=false
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--live" ) ]]; then
  echo "Usage: $0 [--live]" >&2
  exit 2
fi
[[ "${1:-}" == "--live" ]] && LIVE=true
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

failures=0
check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '[OK] %s\n' "$label"
  else
    printf '[FAIL] %s\n' "$label"
    failures=$((failures + 1))
  fi
}

check "Python virtual environment" test -x host/.venv/bin/python
check "OpenCode executable" command -v opencode
check "Lua 5.4" command -v lua5.4
check "Project OpenCode config" test -f opencode.json
check "OpenCode config parses" opencode debug config
check "Python dependencies" host/.venv/bin/python -c "import pythonosc, yaml"
check "Python unit tests" host/.venv/bin/python -m unittest discover -s tests/python
check "Lua OSC test" lua5.4 tests/lua/test_osc_protocol.lua
check "Lua skeleton test" lua5.4 tests/lua/test_skeleton.lua
check "Lua FX parameter test" lua5.4 tests/lua/test_fx_param.lua
check "Lua syntax" lua5.4 tests/lua/test_syntax.lua tools/AIDJ/*.lua tools/AIDJ/setup/*.lua
check "Turnkey builder dry-run" lua5.4 tools/AIDJ/validate_dryrun.lua tools/AIDJ/setup/build_turnkey_song.lua
check "Song validator dry-run" lua5.4 tools/AIDJ/validate_dryrun.lua tools/AIDJ/setup/validate_song.lua
check "Tool install safety" bash tests/shell/test_install.sh

if [[ -f host/state/session.json ]]; then
  age="$(python3 -c 'import json,time; s=json.load(open("host/state/session.json")); print(int(time.time()-s.get("renoise_heartbeat",0)))' 2>/dev/null || echo 999)"
  if [[ "$age" -lt 5 ]]; then
    echo "[OK] Renoise heartbeat (${age}s ago)"
  else
    echo "[WARN] Renoise heartbeat is stale (${age}s ago)"
    $LIVE && failures=$((failures + 1))
  fi
else
  echo "[WARN] session.json does not exist; start bridge and Renoise session"
  $LIVE && failures=$((failures + 1))
fi

if $LIVE; then
  check "OSC roundtrip and state restoration" host/.venv/bin/python host/osc/verify_roundtrip.py
fi

if (( failures > 0 )); then
  echo "Preflight failed: $failures required checks" >&2
  exit 1
fi
echo "Preflight passed"
