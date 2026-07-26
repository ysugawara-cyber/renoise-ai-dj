#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    echo "Expected command to fail: $*" >&2
    exit 1
  fi
}

target="$TMP/valid/com.aidj.live.xrnx"
AIDJ_RENOISE_TOOL_DIR="$target" bash "$ROOT/tools/install.sh" >/dev/null
printf '0.0.0.0' > "$target/osc_bind_host.txt"
AIDJ_RENOISE_TOOL_DIR="$target" bash "$ROOT/tools/install.sh" >/dev/null
[[ "$(<"$target/osc_bind_host.txt")" == "0.0.0.0" ]]

unowned="$TMP/unowned/com.aidj.live.xrnx"
mkdir -p "$unowned"
expect_failure env AIDJ_RENOISE_TOOL_DIR="$unowned" bash "$ROOT/tools/install.sh"

linked_manifest="$TMP/linked-manifest/com.aidj.live.xrnx"
mkdir -p "$linked_manifest"
ln -s "$ROOT/tools/AIDJ/manifest.xml" "$linked_manifest/manifest.xml"
expect_failure env AIDJ_RENOISE_TOOL_DIR="$linked_manifest" bash "$ROOT/tools/install.sh"

mkdir -p "$TMP/real-parent"
ln -s "$TMP/real-parent" "$TMP/linked-parent"
expect_failure env AIDJ_RENOISE_TOOL_DIR="$TMP/linked-parent/com.aidj.live.xrnx" bash "$ROOT/tools/install.sh"

echo "OK: install safety"
