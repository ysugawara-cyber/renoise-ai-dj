"""Validated, atomic file queue used by AIDJ OSC producers."""

from __future__ import annotations

import json
import fcntl
import os
import time
import uuid
from pathlib import Path
from typing import Any


class MessageValidationError(ValueError):
    pass


SIGNATURES: dict[str, tuple[type, ...]] = {
    "/ai/transport": (str,),
    "/ai/bpm": (int,),
    "/ai/swing": (int,),
    "/ai/scene": (int,),
    "/ai/pattern/write": (str, str, str, str, int, str),
    "/ai/pattern/clear": (str, int, int),
    "/ai/pattern/lock": (str, str, int),
    "/ai/note": (str, str, int, int),
    "/ai/mixer/volume": (str, int),
    "/ai/mixer/pan": (str, int),
    "/ai/mixer/mute": (str, int),
    "/ai/mixer/solo": (str, int),
    "/ai/mixer/cue": (str, int),
    "/ai/fx/param": (str, int, int, int),
    "/ai/fx/macro": (str, int),
}

TRACK_OWNERS: dict[str, set[str]] = {
    "tui1": {"5", "6", "8"},
    "tui2": {"3", "4", "7"},
    "tui3": {"1", "2"},
    "tui4": set(),
}
TRACK_PATHS = {
    "/ai/pattern/write",
    "/ai/pattern/clear",
    "/ai/note",
    "/ai/mixer/volume",
    "/ai/mixer/pan",
    "/ai/mixer/mute",
    "/ai/mixer/solo",
    "/ai/mixer/cue",
    "/ai/fx/param",
    "/ai/pattern/lock",
}
CONDUCTOR_PATHS = {"/ai/transport", "/ai/bpm", "/ai/swing", "/ai/scene"}
CONDUCTOR_TRACK_PATHS = {
    "/ai/mixer/volume",
    "/ai/mixer/pan",
    "/ai/mixer/mute",
    "/ai/mixer/solo",
    "/ai/mixer/cue",
}
MACRO_OWNERS: dict[str, str] = {
    "bpm_coarse": "tui4",
    "swing": "tui4",
    "master_volume": "tui4",
    "send_reverb": "tui2",
    "send_delay": "tui2",
    "filter_cutoff": "tui4",
    "distortion": "tui3",
    "bitcrush": "tui2",
}


def normalize_arg(value: Any) -> int | str:
    if isinstance(value, bool):
        raise MessageValidationError("OSC booleans are unsupported; use integer 0/1")
    if isinstance(value, int):
        if not -(2**31) <= value < 2**31:
            raise MessageValidationError(f"integer outside int32 range: {value}")
        return value
    if isinstance(value, float) and value.is_integer():
        return normalize_arg(int(value))
    if isinstance(value, str):
        if "\0" in value:
            raise MessageValidationError("OSC strings cannot contain NUL")
        return value
    raise MessageValidationError(f"unsupported OSC argument type: {type(value).__name__}")


def validate_message(message: dict[str, Any]) -> dict[str, Any]:
    path = message.get("path")
    args = message.get("args")
    if not isinstance(path, str) or not path.startswith("/"):
        raise MessageValidationError("path must be a string beginning with '/'")
    if not isinstance(args, list):
        raise MessageValidationError("args must be a list")
    result = dict(message)
    result["args"] = [normalize_arg(arg) for arg in args]
    signature = SIGNATURES.get(path)
    if signature is None:
        raise MessageValidationError(f"unsupported OSC path: {path}")
    if len(result["args"]) != len(signature):
        raise MessageValidationError(
            f"{path} expects {len(signature)} args, got {len(result['args'])}"
        )
    for index, (argument, expected) in enumerate(zip(result["args"], signature)):
        if not isinstance(argument, expected):
            raise MessageValidationError(
                f"{path} arg {index} must be {expected.__name__}, got {type(argument).__name__}"
            )
    tui_id = result.get("tui_id")
    if tui_id is not None:
        if not isinstance(tui_id, str) or tui_id not in TRACK_OWNERS:
            raise MessageValidationError(f"unsupported tui_id: {tui_id}")
        conductor_override = tui_id == "tui4" and path in CONDUCTOR_TRACK_PATHS
        if path in TRACK_PATHS and not conductor_override and result["args"][0] not in TRACK_OWNERS[tui_id]:
            raise MessageValidationError(
                f"{tui_id} does not own track {result['args'][0]} for {path}"
            )
        if path == "/ai/pattern/lock" and result["args"][1] != tui_id:
            raise MessageValidationError("pattern lock owner must match tui_id")
        if path in CONDUCTOR_PATHS and tui_id != "tui4":
            raise MessageValidationError(f"{path} is owned by tui4")
        if path == "/ai/fx/macro":
            owner = MACRO_OWNERS.get(result["args"][0])
            if owner is not None and tui_id not in (owner, "tui4"):
                raise MessageValidationError(f"macro {result['args'][0]} is owned by {owner}")
    return result


def build_message(path: str, args: list[Any], tui_id: str | None = None) -> dict[str, Any]:
    message: dict[str, Any] = {
        "id": uuid.uuid4().hex,
        "ts": int(time.time() * 1000),
        "path": path,
        "args": args,
    }
    if tui_id:
        message["tui_id"] = tui_id
    return validate_message(message)


def atomic_write_json(path: Path, payload: dict[str, Any]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.parent / f".{path.name}.{uuid.uuid4().hex}.tmp"
    try:
        with tmp.open("w", encoding="utf-8") as stream:
            json.dump(payload, stream, indent=2, ensure_ascii=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
    finally:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
    return path


def _row_lock_range(message: dict[str, Any]) -> tuple[str, range] | None:
    if message["path"] == "/ai/pattern/write":
        try:
            row = int(message["args"][2])
        except ValueError as exc:
            raise MessageValidationError("note_index must be a decimal row number") from exc
        if row < 0 or row > 511:
            raise MessageValidationError("note_index must be in range 0..511")
        return message["args"][0], range(row, row + 1)
    if message["path"] == "/ai/pattern/clear":
        start, count = message["args"][1:3]
        if start < 0 or count < 1 or start + count > 512:
            raise MessageValidationError("clear range must fit rows 0..511")
        return message["args"][0], range(start, start + count)
    return None


def _acquire_row_locks(outbox: Path, message: dict[str, Any]) -> None:
    lock_range = _row_lock_range(message)
    tui_id = message.get("tui_id")
    if lock_range is None or tui_id is None:
        return
    if outbox.name != "outbox" or outbox.parent.name != "osc":
        return
    state_dir = outbox.parent.parent / "state"
    state_path = state_dir / "session.json"
    lock_path = state_dir / "session.lock"
    state_dir.mkdir(parents=True, exist_ok=True)
    lock_path.touch(exist_ok=True)
    track_id, rows = lock_range
    with lock_path.open("r+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            try:
                state = json.loads(state_path.read_text()) if state_path.exists() else {}
            except (OSError, json.JSONDecodeError):
                state = {}
            locked_rows = state.setdefault("tracks", {}).setdefault(
                track_id, {}
            ).setdefault("locked_rows", {})
            for row in rows:
                owner = locked_rows.get(str(row))
                if owner is not None and owner != tui_id:
                    raise MessageValidationError(
                        f"track {track_id} row {row} is locked by {owner}"
                    )
            for row in rows:
                locked_rows[str(row)] = tui_id
            atomic_write_json(state_path, state)
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def _enqueue_in_order(outbox: Path, message: dict[str, Any]) -> Path:
    outbox.mkdir(parents=True, exist_ok=True)
    queue_lock = outbox / ".queue.lock"
    sequence_path = outbox / ".sequence"
    queue_lock.touch(exist_ok=True)
    with queue_lock.open("r+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            try:
                previous = int(json.loads(sequence_path.read_text())["sequence"])
            except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
                previous = 0
            sequence = max(previous + 1, time.time_ns())
            atomic_write_json(sequence_path, {"sequence": sequence})
            filename = f"{sequence:020d}_{message['id'][:8]}.json"
            return atomic_write_json(outbox / filename, message)
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def queue_message(outbox: Path, path: str, args: list[Any], tui_id: str | None = None) -> Path:
    message = build_message(path, args, tui_id)
    _acquire_row_locks(outbox, message)
    return _enqueue_in_order(outbox, message)
