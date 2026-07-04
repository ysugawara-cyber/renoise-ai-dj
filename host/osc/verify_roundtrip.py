#!/usr/bin/env python3
"""
verify_roundtrip.py -- end-to-end OSC -> Renoise -> session.json checks for
the int-scaled OSC convention (T1) and macro resolution (T2).

Prereq:
  - osc_bridge.py running
  - Renoise running with the AIDJ Tool started (it broadcasts /ai/status ~10 Hz,
    which updates host/state/session.json)

Usage:
  host/.venv/bin/python host/osc/verify_roundtrip.py

Checks (each sends OSC via send.py, waits, then reads session.json):
  - /ai/bpm i:174       -> state["bpm"] == 174.0
  - /ai/mixer/mute "1" 1 -> state["tracks"]["1"]["mute"] == True  (already int)
  - /ai/mixer/solo "1" 1 -> state["tracks"]["1"]["solo"] == True
  - /ai/mixer/volume "1" 500 -> 0..1 normalised (post-T1)

Excluded (not broadcast by status_publisher, not verifiable via session.json):
  swing, pan, fx/param, fx/macro.
"""
import fcntl
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / "host/state/session.json"
LOCK = ROOT / "host/state/session.lock"
SEND = [str(ROOT / "host/.venv/bin/python"), str(ROOT / "host/osc/send.py")]


def send(path: str, *args):
    cmd = SEND + [path, *[str(a) for a in args]]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("send failed:", r.stdout, r.stderr)
    return r.returncode == 0


def read_state() -> dict:
    try:
        with open(LOCK, "r+") as lf:
            fcntl.flock(lf.fileno(), fcntl.LOCK_SH)
            data = STATE.read_text()
            fcntl.flock(lf.fileno(), fcntl.LOCK_UN)
        if not data:
            return {}
        return json.loads(data)
    except Exception as e:
        print("state read err:", e)
        return {}


def wait_for(predicate, timeout=3.0, step=0.1):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            if predicate(read_state()):
                return True
        except Exception:
            pass
        time.sleep(step)
    return False


def check(name, ok, detail=""):
    mark = "OK " if ok else "FAIL"
    print(f"  [{mark}] {name} {detail}")
    return ok


def run() -> int:
    print("AIDJ roundtrip verification (requires Renoise + bridge running)")
    failures = 0

    # capture baseline bpm once (mute/solo are toggles; capture and restore)
    base = read_state()
    base_bpm = base.get("bpm")
    base_mute = base.get("tracks", {}).get("1", {}).get("mute")
    if base_bpm is None:
        print("  WARN: session.json empty -- is osc_bridge running?")
        return 2

    # 1) /ai/bpm i
    target_bpm = 174 if base_bpm != 174.0 else 200
    if not send("/ai/bpm", target_bpm):
        return 2
    ok = wait_for(lambda s: abs(round(float(s.get("bpm", -999)), 1) - float(target_bpm)) < 0.1)
    if not check(f"/ai/bpm i:{target_bpm}", ok, f"-> bpm={read_state().get('bpm')}"):
        failures += 1

    # 2) /ai/mixer/mute "1" 1 -- mute is a toggle in status? No: it's a value
    send("/ai/mixer/mute", "1", 1)
    ok = wait_for(lambda s: s.get("tracks", {}).get("1", {}).get("mute") is True)
    cur = read_state().get("tracks", {}).get("1", {}).get("mute")
    if not check('/ai/mixer/mute "1" 1', ok, f"-> mute={cur}"):
        failures += 1

    # 3) /ai/mixer/solo "1" 1
    send("/ai/mixer/solo", "1", 1)
    ok = wait_for(lambda s: s.get("tracks", {}).get("1", {}).get("solo") is True)
    cur = read_state().get("tracks", {}).get("1", {}).get("solo")
    if not check('/ai/mixer/solo "1" 1', ok, f"-> solo={cur}"):
        failures += 1

    # 4) /ai/mixer/volume "1" 500 -> normalised 0.35..0.36
    send("/ai/mixer/volume", "1", 500)
    time.sleep(0.3)
    v = read_state().get("tracks", {}).get("1", {}).get("volume")
    ok = v is not None and 0.49 <= v <= 0.51
    if not check('/ai/mixer/volume "1" 500 (int*1000)', ok, f"-> volume={v}"):
        failures += 1

    # restore
    if base_bpm is not None:
        send("/ai/bpm", base_bpm)
    if base_mute is not None:
        send("/ai/mixer/mute", "1", 1 if base_mute else 0)
    send("/ai/mixer/solo", "1", 0)

    print(f"\nresult: {4 - failures}/4 passed, {failures} failed")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(run())