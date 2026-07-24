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

    # Capture every value changed by this destructive integration test.
    base = read_state()
    base_bpm = base.get("bpm")
    base_track = base.get("tracks", {}).get("1", {})
    base_mute = base_track.get("mute")
    base_solo = base_track.get("solo")
    base_volume = base_track.get("volume")
    heartbeat = base.get("renoise_heartbeat", 0)
    if base_bpm is None or time.time() - heartbeat > 5:
        print("  WARN: session.json is missing or stale -- is Renoise + bridge running?")
        return 2
    if any(value is None for value in (base_mute, base_solo, base_volume)):
        print("  WARN: track 1 status is incomplete; refusing a test that cannot be restored")
        return 2
    if not float(base_bpm).is_integer():
        print("  WARN: current BPM is fractional and /ai/bpm cannot restore it exactly")
        return 2
    target_bpm = 174 if base_bpm != 174.0 else 200
    target_mute = not bool(base_mute)
    target_solo = not bool(base_solo)
    target_volume = 500 if base_volume is None or abs(float(base_volume) - 0.5) > 0.05 else 750

    try:
        if not send("/ai/bpm", target_bpm):
            failures += 1
        else:
            ok = wait_for(lambda s: abs(float(s.get("bpm", -999)) - target_bpm) < 0.1)
            failures += 0 if check(f"/ai/bpm i:{target_bpm}", ok, f"-> bpm={read_state().get('bpm')}") else 1

        if not send("/ai/mixer/mute", "1", int(target_mute)):
            failures += 1
        else:
            ok = wait_for(lambda s: s.get("tracks", {}).get("1", {}).get("mute") is target_mute)
            cur = read_state().get("tracks", {}).get("1", {}).get("mute")
            failures += 0 if check(f'/ai/mixer/mute "1" {int(target_mute)}', ok, f"-> mute={cur}") else 1

        if not send("/ai/mixer/solo", "1", int(target_solo)):
            failures += 1
        else:
            ok = wait_for(lambda s: s.get("tracks", {}).get("1", {}).get("solo") is target_solo)
            cur = read_state().get("tracks", {}).get("1", {}).get("solo")
            failures += 0 if check(f'/ai/mixer/solo "1" {int(target_solo)}', ok, f"-> solo={cur}") else 1

        if not send("/ai/mixer/volume", "1", target_volume):
            failures += 1
        else:
            expected = target_volume / 1000.0
            ok = wait_for(lambda s: abs(float(s.get("tracks", {}).get("1", {}).get("volume", -1)) - expected) < 0.02)
            volume = read_state().get("tracks", {}).get("1", {}).get("volume")
            failures += 0 if check(f'/ai/mixer/volume "1" {target_volume}', ok, f"-> volume={volume}") else 1
    finally:
        restore_commands = [
            ("/ai/bpm", (int(base_bpm),)),
            ("/ai/mixer/mute", ("1", int(bool(base_mute)))),
            ("/ai/mixer/solo", ("1", int(bool(base_solo)))),
            ("/ai/mixer/volume", ("1", int(round(float(base_volume) * 1000)))),
        ]
        restore_results = []
        for restore_path, restore_args in restore_commands:
            try:
                restore_results.append(send(restore_path, *restore_args))
            except Exception as exc:
                print(f"  restore send failed for {restore_path}: {exc}")
                restore_results.append(False)
        try:
            restored = all(restore_results) and wait_for(
                lambda s: (
                    abs(float(s.get("bpm", -999)) - float(base_bpm)) < 0.1
                    and s.get("tracks", {}).get("1", {}).get("mute") is bool(base_mute)
                    and s.get("tracks", {}).get("1", {}).get("solo") is bool(base_solo)
                    and abs(
                        float(s.get("tracks", {}).get("1", {}).get("volume", -1))
                        - float(base_volume)
                    ) < 0.02
                )
            )
        except Exception as exc:
            print(f"  restore verification failed: {exc}")
            restored = False
        if not restored:
            failures += 1
            print("  [FAIL] original state restoration was not confirmed")

    print(f"\nresult: {max(0, 4 - failures)}/4 checks passed, {failures} failures")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(run())
