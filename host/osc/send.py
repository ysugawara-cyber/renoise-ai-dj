#!/usr/bin/env python3
"""
send.py -- helper for opencode TUIs and debugging.

Writes a single JSON file to host/osc/outbox. The osc_bridge.py consumer
picks it up and dispatches to Renoise.

Usage (from repo root, inside the WSL venv):
    host/.venv/bin/python host/osc/send.py /ai/bpm 174
    host/.venv/bin/python host/osc/send.py /ai/note 1 "C-4" 100 1
"""

import sys
from pathlib import Path

from message_queue import MessageValidationError, SIGNATURES, queue_message

ROOT = Path(__file__).resolve().parents[2]
OUTBOX = ROOT / "host/osc/outbox"
def coerce(a: str) -> int | str:
    try:
        return int(a)
    except ValueError:
        try:
            value = float(a)
        except ValueError:
            return a
        if value.is_integer():
            return int(value)
        raise MessageValidationError(f"non-integral floats are unsupported: {a}")


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if not argv:
        print("usage: send.py <path> [args...]", file=sys.stderr)
        return 2
    path = argv[0]
    try:
        signature = SIGNATURES.get(path)
        if signature is None or len(argv[1:]) != len(signature):
            raise MessageValidationError(f"invalid path or argument count: {path}")
        args = [value if expected is str else coerce(value)
                for value, expected in zip(argv[1:], signature)]
        queued = queue_message(OUTBOX, path, args)
    except MessageValidationError as exc:
        print(f"invalid message: {exc}", file=sys.stderr)
        return 2
    print(f"queued {path} {args} -> {queued.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
