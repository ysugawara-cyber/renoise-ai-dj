#!/usr/bin/env python3
"""
osc_bridge.py -- opencode <-> Renoise broker.

Responsibilities:
  1. Watch host/osc/outbox/ for JSON files produced by opencode TUIs.
     Each file encodes one OSC message. Send to Renoise Tool (127.0.0.1:8080)
     and move to host/osc/sent/.
  2. Listen on 127.0.0.1:8088 for /ai/status broadcasts from Renoise.
     Update host/state/session.json (BPM, scene, play state, per-track mixer).
3. Maintain a process-wide file lock over session.json to arbitrate writes
      from multiple opencode TUIs.
  4. Listen to MIDImix macro knobs (CC 10..17) and resolve them via
      config/macros.yaml into /ai/fx/param (or /ai/bpm, /ai/swing).

Run (from repo root, inside the WSL venv):
    host/.venv/bin/python host/osc/osc_bridge.py
"""

from __future__ import annotations
import json
import os
import shutil
import subprocess
import time
import uuid
import threading
import fcntl
from pathlib import Path
from typing import Any

try:
    from pythonosc.udp_client import SimpleUDPClient
    from pythonosc.dispatcher import Dispatcher
    from pythonosc.osc_server import ThreadingOSCUDPServer
except ImportError as e:  # pragma: no cover
    raise SystemExit(
        "missing deps: pip install python-osc pyyaml mido python-rtmidi"
    ) from e

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

try:
    import mido
except ImportError:  # pragma: no cover
    mido = None

ROOT = Path(__file__).resolve().parents[2]
OUTBOX = ROOT / "host/osc/outbox"
SENT = ROOT / "host/osc/sent"
STATE = ROOT / "host/state/session.json"
LOCK = ROOT / "host/state/session.lock"
MACROS_YAML = ROOT / "config/macros.yaml"
WSL_IP_FILE = ROOT / "host/state/wsl_ip.txt"


def _detect_wsl_ip() -> str:
    """Return this WSL instance's IP visible from Windows."""
    try:
        out = subprocess.check_output(
            ["hostname", "-I"], text=True, timeout=2)
        ip = out.strip().split()[0]
        if ip.count(".") == 3:
            return ip
    except Exception:
        pass
    return "127.0.0.1"


def _detect_windows_host_ip() -> str:
    """Return the Windows host IP as visible from WSL (the default gateway)."""
    try:
        out = subprocess.check_output(
            ["ip", "route", "show", "default"], text=True, timeout=2)
        for part in out.split():
            if part.count(".") == 3:
                return part
    except Exception:
        pass
    return "127.0.0.1"


WSL_IP = _detect_wsl_ip()
RENOISE_HOST = _detect_windows_host_ip()
RENOISE_PORT = 8080
BRIDGE_LISTEN_PORT = 8088

OUTBOX.mkdir(parents=True, exist_ok=True)
SENT.mkdir(parents=True, exist_ok=True)
STATE.parent.mkdir(parents=True, exist_ok=True)
LOCK.touch(exist_ok=True)
WSL_IP_FILE.write_text(WSL_IP)


def _load_macros() -> dict[str, dict]:
    if yaml is None or not MACROS_YAML.exists():
        return {}
    try:
        data = yaml.safe_load(MACROS_YAML.read_text()) or {}
    except Exception as e:
        print("macros load err:", e)
        return {}
    out: dict[str, dict] = {}
    for m in data.get("macros", []):
        name = m.get("name")
        if name:
            out[name] = m
    return out


MACROS = _load_macros()
CC_TO_MACRO = {int(m["cc"]): name for name, m in MACROS.items() if m.get("cc") is not None}
MIDIMIX_NAME_HINTS = ("midi mix", "midimix")


def _expand_macro(macro_name: str, value: int) -> list[tuple[str, list[Any]]]:
    """Resolve a /ai/fx/macro call into one or more concrete OSC messages.

    Returns a list of (path, args) tuples. Value is int in 0..1000
    (the documented int-scaled convention). Range mapping:
      - macros with `target` -> /ai/fx/param with value passed through
      - macros with `osc` -> direct path (e.g. /ai/bpm, /ai/swing);
        value mapped from [0,1000] onto macro's declared range
    """
    macro = MACROS.get(macro_name)
    if not macro:
        return []
    target = macro.get("target")
    if target:
        track = str(target.get("track"))
        fx_index = int(target.get("fx_index", 0))
        param_index = int(target.get("param_index", 0))
        return [("/ai/fx/param", [track, fx_index, param_index, int(value)])]
    osc = macro.get("osc")
    rng = macro.get("range")
    if osc and rng and len(rng) == 2:
        lo, hi = float(rng[0]), float(rng[1])
        mapped = lo + (hi - lo) * (int(value) / 1000.0)
        if osc == "/ai/bpm":
            return [("/ai/bpm", [int(round(mapped))])]
        if osc == "/ai/swing":
            return [("/ai/swing", [int(value)])]
        return [(osc, [int(round(mapped))])]
    if osc:
        return [(osc, [int(value)])]
    return []


def _load_state() -> dict[str, Any]:
    try:
        with open(LOCK, "r+") as lf:
            fcntl.flock(lf.fileno(), fcntl.LOCK_SH)
            data = STATE.read_text()
            fcntl.flock(lf.fileno(), fcntl.LOCK_UN)
        if not data:
            return {}
        return json.loads(data)
    except Exception:
        return {}


def _save_state(state: dict[str, Any]) -> None:
    with open(LOCK, "r+") as lf:
        fcntl.flock(lf.fileno(), fcntl.LOCK_EX)
        STATE.write_text(json.dumps(state, indent=2))
        fcntl.flock(lf.fileno(), fcntl.LOCK_UN)


def _update_state_from_status(args: list[Any]) -> None:
    # args: [i bpm_x10, i active_scene, i play_state, s json_tracks]
    if len(args) < 4:
        return
    bpm_x10, scene, play, tracks_json = args[:4]
    state = _load_state()
    state["bpm"] = round(int(bpm_x10) / 10.0, 1)
    state["active_scene"] = int(scene)
    state["play_state"] = "playing" if int(play) == 1 else "stopped"
    try:
        tracks = json.loads(tracks_json) if isinstance(tracks_json, str) else tracks_json
        for ti, ctx in enumerate(tracks, start=1):
            tk = state.setdefault("tracks", {}).setdefault(str(ti), {})
            tk["volume"] = float(ctx.get("v", 1.0)) / 1.415
            tk["mute"] = bool(ctx.get("m", 0))
            tk["solo"] = bool(ctx.get("s", 0))
    except Exception as e:
        print("status parse err:", e)
    state["renoise_heartbeat"] = int(time.time())
    _save_state(state)


def _start_outbox_consumer(client: SimpleUDPClient) -> threading.Thread:
    def loop():
        while True:
            files = sorted(p for p in OUTBOX.glob("*.json"))
            for p in files:
                try:
                    msg = json.loads(p.read_text())
                    path = msg["path"]
                    args = msg["args"]
                    if path == "/ai/fx/macro" and len(args) >= 2:
                        expansions = _expand_macro(str(args[0]), args[1])
                        for ep, ea in expansions:
                            client.send_message(ep, ea)
                            print(f"-> {ep} {ea} (macro {args[0]})")
                        shutil.move(str(p), str(SENT / p.name))
                        continue
                    client.send_message(path, args)
                    shutil.move(str(p), str(SENT / p.name))
                    print(f"-> {path} {args}")
                except Exception as e:
                    print("outbox send err:", p.name, e)
                    err = p.with_suffix(".err")
                    shutil.move(str(p), str(SENT / err.name))
            time.sleep(0.01)
    t = threading.Thread(target=loop, daemon=True, name="outbox")
    t.start()
    return t


def _start_status_server() -> ThreadingOSCUDPServer:
    dispatcher = Dispatcher()
    dispatcher.map("/ai/status", lambda path, *args: _update_state_from_status(list(args)))
    dispatcher.set_default_handler(lambda path, args: print(f"[debug] unknown OSC: {path} {args}"))
    srv = ThreadingOSCUDPServer(("0.0.0.0", BRIDGE_LISTEN_PORT), dispatcher)
    threading.Thread(target=srv.serve_forever, daemon=True, name="osc-status").start()
    print(f"osc_bridge listening /ai/status on 0.0.0.0:{BRIDGE_LISTEN_PORT}")
    return srv


def _find_midimix_port() -> str | None:
    if mido is None:
        return None
    try:
        names = mido.get_input_names()
    except Exception as e:
        print("mido input enum err:", e)
        return None
    for n in names:
        ln = n.lower()
        if any(h in ln for h in MIDIMIX_NAME_HINTS):
            return n
    return None


def _start_midi_macro_listener(client: SimpleUDPClient):
    """Listen to MIDImix macro knobs (CC 10..17, ch 1) and fire /ai/fx/macro.

    CC value 0..127 is rescaled to int 0..1000 (the documented convention),
    then resolved via _expand_macro and sent directly to Renoise. Writes a
    record JSON into host/osc/sent/ for audit.
    """
    if mido is None:
        print("mido not available; macro knob auto-fire disabled (pip install mido python-rtmidi)")
        return None
    port_name = _find_midimix_port()
    if not port_name:
        print("MIDImix input not found; macro knob auto-fire disabled")
        return None
    try:
        inport = mido.open_input(port_name)
    except Exception as e:
        print("mido open_input err:", e)
        return None
    print(f"midi macro listener on '{port_name}' (CC 10..17 -> /ai/fx/macro)")

    def loop():
        for msg in inport:
            try:
                if msg.type != "control_change" or msg.channel != 0:
                    continue
                cc = int(msg.control)
                if cc < 10 or cc > 17:
                    continue
                macro_name = CC_TO_MACRO.get(cc)
                if not macro_name:
                    continue
                value = int(round(msg.value * 1000 / 127))
                expansions = _expand_macro(macro_name, value)
                for ep, ea in expansions:
                    client.send_message(ep, ea)
                    print(f"-> {ep} {ea} (macro {macro_name} cc{cc}={msg.value})")
                rec = {
                    "id": uuid.uuid4().hex,
                    "ts": int(time.time() * 1000),
                    "tui_id": "midi",
                    "path": "/ai/fx/macro",
                    "args": [macro_name, value],
                }
                (SENT / f"{rec['ts']}_{rec['id'][:8]}.json").write_text(json.dumps(rec))
            except Exception as e:
                print("midi macro err:", e)
    t = threading.Thread(target=loop, daemon=True, name="midi-macro")
    t.start()
    return t


def main() -> None:
    renoise_client = SimpleUDPClient(RENOISE_HOST, RENOISE_PORT)
    _start_outbox_consumer(renoise_client)
    _start_status_server()
    _start_midi_macro_listener(renoise_client)
    print(f"osc_bridge started")
    print(f"  WSL IP:  {WSL_IP}  (Renoise -> {WSL_IP}:{BRIDGE_LISTEN_PORT})")
    print(f"  Windows: {RENOISE_HOST}  (bridge -> {RENOISE_HOST}:{RENOISE_PORT})")
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        print("osc_bridge stopping")


if __name__ == "__main__":
    main()