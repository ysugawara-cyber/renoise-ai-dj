#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

missing=()
for command in python3 setsid pgrep ip git realpath; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done
if (( ${#missing[@]} > 0 )); then
  printf 'Missing commands: %s\n' "${missing[*]}" >&2
  echo "Ubuntu/WSL: sudo apt install python3 python3-venv python3-pip util-linux procps iproute2 git lua5.4" >&2
  exit 2
fi

if ! command -v lua5.4 >/dev/null 2>&1; then
  echo "lua5.4 is required: sudo apt install lua5.4" >&2
  exit 2
fi
if ! command -v opencode >/dev/null 2>&1; then
  echo "OpenCode is required. Install it from https://opencode.ai/docs/" >&2
  exit 2
fi

if grep -qi microsoft /proc/version 2>/dev/null && [[ -z "${AIDJ_RENOISE_OSC_BIND_HOST:-}" ]]; then
  printf '\nAIDJ_RENOISE_OSC_BIND_HOST=0.0.0.0\n' >> .env
  export AIDJ_RENOISE_OSC_BIND_HOST=0.0.0.0
  echo "Configured .env for Windows Renoise + WSL2 OSC"
  echo "Security: install the Windows Firewall rule restricted to the WSL IP (docs/windows_firewall.md)."
fi

if [[ ! -x host/.venv/bin/python ]]; then
  python3 -m venv host/.venv
fi
host/.venv/bin/python -m pip install -r requirements-lock.txt

host/.venv/bin/python -m unittest discover -s tests/python
lua5.4 tests/lua/test_osc_protocol.lua
lua5.4 tests/lua/test_skeleton.lua
lua5.4 tests/lua/test_fx_param.lua
lua5.4 tests/lua/test_syntax.lua tools/AIDJ/*.lua tools/AIDJ/setup/*.lua
lua5.4 tools/AIDJ/validate_dryrun.lua tools/AIDJ/setup/build_turnkey_song.lua
lua5.4 tools/AIDJ/validate_dryrun.lua tools/AIDJ/setup/validate_song.lua
bash -n start.sh setup.sh tools/install.sh tools/preflight.sh tools/stop.sh tools/restart.sh
bash tests/shell/test_install.sh

mkdir -p host/state host/osc/outbox host/osc/sent
bash tools/install.sh

echo
echo "AIDJ setup complete."
echo "1. Authenticate OpenCode: opencode auth login"
echo "2. In Renoise: Scripting -> Reload Tools"
echo "3. Open a blank song, then Tools -> AIDJ -> Setup -> Build Turnkey Song"
echo "4. Save the XRNS and run: ./start.sh"
