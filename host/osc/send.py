#!/usr/bin/env python3
"""
send.py -- helper for opencode TUIs and debugging.

Writes a single JSON file to host/osc/outbox. The osc_bridge.py consumer
picks it up and dispatches to Renoise.

Usage (from repo root, inside the WSL venv):
    host/.venv/bin/python host/osc/send.py /ai/bpm 174
    host/.venv/bin/python host/osc/send.py /ai/note 1 "C-4" 100 1
"""

import json
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTBOX = ROOT / "host/osc/outbox"
OUTBOX.mkdir(parents=True, exist_ok=True)

if len(sys.argv) < 2:
    print("usage: send.py <path> [args...]")
    sys.exit(2)

path = sys.argv[1]
args_raw = sys.argv[2:]


def coerce(a: str):
    try:
        if "." in a:
            return float(a)
        return int(a)
    except ValueError:
        return a


args = [coerce(a) for a in args_raw]

msg = {
    "id": uuid.uuid4().hex,
    "ts": int(time.time() * 1000),
    "path": path,
    "args": args,
}

p = OUTBOX / f"{int(time.time() * 1000)}_{uuid.uuid4().hex[:8]}.json"
p.write_text(json.dumps(msg, indent=2))
print(f"queued {path} {args} -> {p.name}")