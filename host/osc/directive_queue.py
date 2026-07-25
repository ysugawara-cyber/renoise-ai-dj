#!/usr/bin/env python3
"""Atomic FIFO directives from the conductor to track-owning TUIs."""

from __future__ import annotations

import argparse
import fcntl
import os
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRECTIVES = ROOT / "host/state/directives"
TARGETS = {"tui1", "tui2", "tui3"}


def _validate_target(target: str) -> None:
    if target not in TARGETS:
        raise ValueError(f"unsupported directive target: {target}")


def _atomic_write(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.parent / f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp"
    with temp.open("w", encoding="utf-8") as handle:
        handle.write(body)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temp, path)


def publish_directive(
    targets: list[str], body: str, root: Path = DIRECTIVES
) -> list[Path]:
    if not body.strip():
        raise ValueError("directive body must not be empty")
    for target in targets:
        _validate_target(target)
    root.mkdir(parents=True, exist_ok=True)
    lock_path = root / ".lock"
    lock_path.touch(exist_ok=True)
    published: list[Path] = []
    with lock_path.open("r+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            timestamp = time.time_ns()
            for index, target in enumerate(targets):
                path = root / target / f"{timestamp + index:020d}_{uuid.uuid4().hex[:8]}.md"
                _atomic_write(path, body.rstrip() + "\n")
                published.append(path)
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
    return published


def claim_directives(target: str, root: Path = DIRECTIVES) -> tuple[str, str]:
    _validate_target(target)
    root.mkdir(parents=True, exist_ok=True)
    lock_path = root / ".lock"
    lock_path.touch(exist_ok=True)
    with lock_path.open("r+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            queued = root / target
            queued.mkdir(parents=True, exist_ok=True)
            inflight = root / ".inflight" / target
            inflight.mkdir(parents=True, exist_ok=True)
            for interrupted in sorted(inflight.glob(".*.tmp")):
                if interrupted.is_dir():
                    for path in interrupted.glob("*.md"):
                        os.replace(path, queued / path.name)
                    interrupted.rmdir()
            existing = sorted(
                path for path in inflight.glob("*")
                if path.is_dir() and not path.name.startswith(".")
            )
            if existing:
                batch = existing[0]
                bodies = [path.read_text(encoding="utf-8").strip() for path in sorted(batch.glob("*.md"))]
                body = "\n\n".join(item for item in bodies if item)
                if body:
                    return batch.name, body
                for path in batch.glob("*.md"):
                    path.unlink()
                batch.rmdir()

            legacy = root / f"{target}.md"
            if legacy.exists():
                migrated = queued / f"{legacy.stat().st_mtime_ns:020d}_legacy.md"
                os.replace(legacy, migrated)
            paths = []
            for path in sorted(queued.glob("*.md")):
                if path.read_text(encoding="utf-8").strip():
                    paths.append(path)
                else:
                    path.unlink()
            if not paths:
                return "", ""
            token = uuid.uuid4().hex
            batch = inflight / token
            interrupted = inflight / f".{token}.tmp"
            interrupted.mkdir()
            for path in paths:
                os.replace(path, interrupted / path.name)
            os.replace(interrupted, batch)
            bodies = [path.read_text(encoding="utf-8").strip() for path in sorted(batch.glob("*.md"))]
            return token, "\n\n".join(body for body in bodies if body)
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def ack_directives(target: str, token: str, root: Path = DIRECTIVES) -> None:
    _validate_target(target)
    if len(token) != 32 or any(char not in "0123456789abcdef" for char in token):
        raise ValueError("invalid directive token")
    lock_path = root / ".lock"
    lock_path.touch(exist_ok=True)
    with lock_path.open("r+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            batch = root / ".inflight" / target / token
            if not batch.is_dir():
                raise ValueError("directive token is not pending")
            for path in batch.glob("*.md"):
                path.unlink()
            batch.rmdir()
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    publish = subparsers.add_parser("publish")
    publish.add_argument("target", choices=sorted(TARGETS))
    publish.add_argument("body")
    consume = subparsers.add_parser("consume")
    consume.add_argument("target", choices=sorted(TARGETS))
    ack = subparsers.add_parser("ack")
    ack.add_argument("target", choices=sorted(TARGETS))
    ack.add_argument("token")
    args = parser.parse_args()

    if args.command == "publish":
        publish_directive([args.target], args.body)
    elif args.command == "consume":
        token, body = claim_directives(args.target)
        if body:
            sys.stdout.write(f"AIDJ_DIRECTIVE_TOKEN={token}\n{body}\n")
    else:
        ack_directives(args.target, args.token)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
