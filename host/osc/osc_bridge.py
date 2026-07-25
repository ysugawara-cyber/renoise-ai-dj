#!/usr/bin/env python3
"""
osc_bridge.py -- opencode <-> Renoise broker.

Responsibilities:
  1. Watch host/osc/outbox/ for JSON files produced by opencode TUIs.
     Each file encodes one OSC message. Send to Renoise Tool (host/port detected
     or configured with AIDJ_RENOISE_HOST/AIDJ_RENOISE_PORT)
     and move to host/osc/sent/.
  2. Listen on AIDJ_STATUS_BIND_HOST:AIDJ_STATUS_PORT for /ai/status broadcasts.
     Update host/state/session.json (BPM, scene, play state, per-track mixer).
3. Maintain a process-wide file lock over session.json to arbitrate writes
      from multiple opencode TUIs.
  4. Expand named macros from config/macros.yaml. Hardware MIDI input is
     handled only by the Renoise Lua Tool.

Run (from repo root, inside the WSL venv):
    host/.venv/bin/python host/osc/osc_bridge.py
"""

from __future__ import annotations
import json
import os
import shutil
import subprocess
import time
import threading
import fcntl
from pathlib import Path
from typing import Any

from message_queue import MessageValidationError, atomic_write_json, validate_message

try:
    from pythonosc.udp_client import SimpleUDPClient
    from pythonosc.dispatcher import Dispatcher
    from pythonosc.osc_server import BlockingOSCUDPServer
except ImportError as e:  # pragma: no cover
    raise SystemExit(
        "missing dependency: pip install -r requirements.txt"
    ) from e

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

ROOT = Path(__file__).resolve().parents[2]
OUTBOX = ROOT / "host/osc/outbox"
SENT = ROOT / "host/osc/sent"
STATE = ROOT / "host/state/session.json"
LOCK = ROOT / "host/state/session.lock"
MACROS_YAML = ROOT / "config/macros.yaml"
WSL_IP_FILE = ROOT / "host/state/wsl_ip.txt"
TOOL_DIR: Path | None = None
WSL_IP = "127.0.0.1"
RENOISE_HOST = "127.0.0.1"
RENOISE_PORT = int(os.environ.get("AIDJ_RENOISE_PORT", "8080"))
BRIDGE_LISTEN_PORT = int(os.environ.get("AIDJ_STATUS_PORT", "8088"))
STATUS_BIND_HOST = "127.0.0.1"


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
    """Returns the Windows host IP as visible from WSL (the default gateway)."""
    try:
        out = subprocess.check_output(
            ["ip", "route", "show", "default"], text=True, timeout=2)
        for part in out.split():
            if part.count(".") == 3:
                return part
    except Exception:
        pass
    return "127.0.0.1"


def _candidate_renoise_data_dirs() -> list[Path]:
    configured = os.environ.get("AIDJ_RENOISE_DATA_DIR")
    if configured:
        return [Path(configured).expanduser()]
    users_root = Path("/mnt/c/Users")
    if not users_root.is_dir():
        return []
    return sorted(users_root.glob("*/AppData/Roaming/Renoise"))


def _detect_tool_dir() -> Path | None:
    """Find the installed AIDJ tool directory under Renoise AppData."""
    configured = os.environ.get("AIDJ_RENOISE_TOOL_DIR")
    if configured:
        candidate = Path(configured).expanduser()
        return candidate if candidate.is_dir() else None
    candidates: list[Path] = []
    for data_dir in _candidate_renoise_data_dirs():
        for version_dir in data_dir.iterdir() if data_dir.is_dir() else []:
            candidate = version_dir / "Scripts/Tools/com.aidj.live.xrnx"
            if candidate.is_dir():
                candidates.append(candidate)
    owners = {candidate.parents[5] for candidate in candidates}
    if len(owners) > 1:
        print("warning: multiple Windows Renoise users found; set AIDJ_RENOISE_TOOL_DIR")
        return None
    if candidates:
        def version_key(candidate: Path) -> tuple[int, ...]:
            version = candidate.parents[2].name.removeprefix("V")
            try:
                return tuple(int(part) for part in version.split("."))
            except ValueError:
                return (0,)
        return max(candidates, key=version_key)
    return None


def _resolve_renoise_bind_host(tool_dir: Path) -> str:
    bind_file = tool_dir / "osc_bind_host.txt"
    configured = os.environ.get("AIDJ_RENOISE_OSC_BIND_HOST")
    if configured is not None:
        return configured
    return bind_file.read_text().strip() if bind_file.exists() else "127.0.0.1"


def _initialize_environment() -> None:
    global WSL_IP, RENOISE_HOST, TOOL_DIR, STATUS_BIND_HOST
    WSL_IP = os.environ.get("AIDJ_WSL_IP", _detect_wsl_ip())
    RENOISE_HOST = os.environ.get("AIDJ_RENOISE_HOST", _detect_windows_host_ip())
    STATUS_BIND_HOST = os.environ.get(
        "AIDJ_STATUS_BIND_HOST", WSL_IP if WSL_IP != "127.0.0.1" else "127.0.0.1"
    )
    TOOL_DIR = _detect_tool_dir()
    OUTBOX.mkdir(parents=True, exist_ok=True)
    SENT.mkdir(parents=True, exist_ok=True)
    STATE.parent.mkdir(parents=True, exist_ok=True)
    LOCK.touch(exist_ok=True)
    WSL_IP_FILE.write_text(WSL_IP)
    if TOOL_DIR:
        (TOOL_DIR / "wsl_ip.txt").write_text(WSL_IP)
        bind_file = TOOL_DIR / "osc_bind_host.txt"
        bind_host = _resolve_renoise_bind_host(TOOL_DIR)
        if bind_host not in ("127.0.0.1", "0.0.0.0"):
            raise SystemExit("AIDJ_RENOISE_OSC_BIND_HOST must be 127.0.0.1 or 0.0.0.0")
        bind_file.write_text(bind_host)
        print("wrote bridge config to tool dir: " + str(TOOL_DIR))
    else:
        print("warning: Renoise tool directory not found; set AIDJ_RENOISE_TOOL_DIR")


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


MACROS: dict[str, dict] = {}


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
        if target.get("param") == "volume":
            return [("/ai/mixer/volume", [track, int(value)])]
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


def _messages_for_dispatch(message: dict[str, Any]) -> list[tuple[str, list[Any]]]:
    path = message["path"]
    args = message["args"]
    if path != "/ai/fx/macro":
        return [(path, args)]
    expansions = _expand_macro(str(args[0]), args[1])
    if not expansions:
        raise ValueError(f"unknown or invalid macro: {args[0]}")
    return expansions


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
    # tmp へ書いてから os.replace でアトミックに差し替える。
    # (bridge 死亡や OneDrive 競合時に 0 バイトの session.json が残るのを防ぐ)
    payload = json.dumps(state, indent=2)
    with open(LOCK, "r+") as lf:
        fcntl.flock(lf.fileno(), fcntl.LOCK_EX)
        atomic_write_json(STATE, state)
        fcntl.flock(lf.fileno(), fcntl.LOCK_UN)


def _merge_status_into_state(latest: dict[str, Any]) -> None:
    """Read, merge bridge-owned fields, and save under one exclusive lock."""
    with open(LOCK, "r+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            try:
                state = json.loads(STATE.read_text()) if STATE.exists() and STATE.stat().st_size else {}
            except (OSError, json.JSONDecodeError):
                state = {}
            state["bpm"] = latest["bpm"]
            state["active_scene"] = latest["active_scene"]
            state["play_state"] = latest["play_state"]
            for track_index, context in enumerate(latest.get("tracks") or [], start=1):
                track = state.setdefault("tracks", {}).setdefault(str(track_index), {})
                track["volume"] = float(context.get("v", 1.0)) / 1.41253
                track["mute"] = bool(context.get("m", 0))
                track["solo"] = bool(context.get("s", 0))
                if "in" in context:
                    track["instrument"] = str(context["in"])
                    track["instrument_index"] = int(context.get("ii", -1))
                    track["instrument_resolved"] = bool(context.get("io", 0))
            state["renoise_heartbeat"] = latest["renoise_heartbeat"]
            atomic_write_json(STATE, state)
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


# /ai/status の受信ハンドラはファイル I/O を行わずメモリ上の最新値を更新するだけ。
# OneDrive 上の flock/ファイル書込が遅く、ThreadingOSCUDPServer の
# パケット毎スレッド生成と組み合わさるとハンドラが詰まってスレッドが無限蓄積し
# "can't start new thread" で bridge が死亡する(実故障 2026-07-18)。
_latest_status: dict[str, Any] = {}
_status_lock = threading.Lock()
_status_dirty = False


def _update_state_from_status(args: list[Any]) -> None:
    # args: [i bpm_x10, i active_scene, i play_state, s json_tracks]
    global _status_dirty
    if len(args) < 4:
        return
    bpm_x10, scene, play, tracks_json = args[:4]
    try:
        bpm = round(int(bpm_x10) / 10.0, 1)
        active_scene = int(scene)
        play_state = int(play)
        tracks = json.loads(tracks_json) if isinstance(tracks_json, str) else tracks_json
        if not isinstance(tracks, list) or any(not isinstance(track, dict) for track in tracks):
            raise ValueError("tracks must be a list of objects")
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        print("status validation err:", exc)
        return
    with _status_lock:
        _latest_status["bpm"] = bpm
        _latest_status["active_scene"] = active_scene
        _latest_status["play_state"] = "playing" if play_state == 1 else "stopped"
        _latest_status["tracks"] = tracks
        _latest_status["renoise_heartbeat"] = int(time.time())
        _status_dirty = True


def _start_state_writer() -> threading.Thread:
    """0.5 s 間隔で _latest_status を session.json に反映する単一ライター。

    locked_rows / tui_instances などエージェント編集フィールドを保持するため
    既存 state をロードしてからマージする。
    """
    def loop():
        global _status_dirty
        while True:
            time.sleep(0.5)
            with _status_lock:
                if not _status_dirty:
                    continue
                latest = dict(_latest_status)
                _status_dirty = False
            try:
                _merge_status_into_state(latest)
            except Exception as e:
                print("state writer err:", e)
    t = threading.Thread(target=loop, daemon=True, name="state-writer")
    t.start()
    return t


def _start_outbox_consumer(client: SimpleUDPClient) -> threading.Thread:
    def loop():
        while True:
            try:
                files = sorted(p for p in OUTBOX.glob("*.json"))
            except Exception as e:
                # OneDrive 同期ロック等で glob が一時的に失敗しても
                # consumer スレッドを死なせない
                print("outbox glob err:", e)
                files = []
            for p in files:
                try:
                    msg = validate_message(json.loads(p.read_text()))
                    for dispatch_path, dispatch_args in _messages_for_dispatch(msg):
                        client.send_message(dispatch_path, dispatch_args)
                        print(f"-> {dispatch_path} {dispatch_args}")
                    shutil.move(str(p), str(SENT / p.name))
                except (OSError, json.JSONDecodeError, MessageValidationError, KeyError, ValueError) as e:
                    print("outbox send err:", p.name, e)
                    try:
                        err = p.with_suffix(".err")
                        shutil.move(str(p), str(SENT / err.name))
                    except Exception:
                        pass
            time.sleep(0.01)
    t = threading.Thread(target=loop, daemon=True, name="outbox")
    t.start()
    return t


def _start_status_server() -> "BlockingOSCUDPServer":
    # 単一スレッドの BlockingOSCUDPServer を使う。ThreadingOSCUDPServer は
    # 10 Hz の status パケット毎にスレッドを生成し、ハンドラが詰まると
    # スレッド枯渇で bridge ごと死亡するため。
    dispatcher = Dispatcher()
    dispatcher.map("/ai/status", lambda path, *args: _update_state_from_status(list(args)))
    dispatcher.set_default_handler(lambda path, args: print(f"[debug] unknown OSC: {path} {args}"))
    srv = BlockingOSCUDPServer((STATUS_BIND_HOST, BRIDGE_LISTEN_PORT), dispatcher)
    threading.Thread(target=srv.serve_forever, daemon=True, name="osc-status").start()
    print(f"osc_bridge listening /ai/status on {STATUS_BIND_HOST}:{BRIDGE_LISTEN_PORT}")
    return srv


def main() -> None:
    global MACROS
    _initialize_environment()
    MACROS = _load_macros()
    # 空/欠損の session.json を初期化(前回の異常終了で 0 バイト化した場合等)
    if not STATE.exists() or STATE.stat().st_size == 0:
        _save_state({})
    renoise_client = SimpleUDPClient(RENOISE_HOST, RENOISE_PORT)
    _start_outbox_consumer(renoise_client)
    _start_status_server()
    _start_state_writer()
    print("host MIDI disabled (Renoise Lua MIDI router is authoritative)")
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
