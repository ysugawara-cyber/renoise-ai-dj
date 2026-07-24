#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/tools/AIDJ"
TARGET="${AIDJ_RENOISE_TOOL_DIR:-}"

if [[ -z "$TARGET" ]]; then
  shopt -s nullglob
  candidates=(/mnt/c/Users/*/AppData/Roaming/Renoise/V*/Scripts/Tools)
  shopt -u nullglob
  valid_candidates=()
  for candidate in "${candidates[@]}"; do
    version_dir="${candidate%/Scripts/Tools}"
    version="${version_dir##*/}"
    if [[ "$version" =~ ^V[0-9]+([.][0-9]+)*$ ]]; then
      valid_candidates+=("$candidate")
    fi
  done
  candidates=("${valid_candidates[@]}")
  if (( ${#candidates[@]} == 0 )); then
    echo "Renoise Tool directory not found. Set AIDJ_RENOISE_TOOL_DIR." >&2
    exit 2
  fi
  users=()
  for candidate in "${candidates[@]}"; do
    user_root="${candidate%%/AppData/Roaming/Renoise/*}"
    if [[ ! " ${users[*]} " =~ " ${user_root} " ]]; then
      users+=("$user_root")
    fi
  done
  if (( ${#users[@]} > 1 )); then
    echo "Multiple Windows Renoise users found. Set AIDJ_RENOISE_TOOL_DIR." >&2
    exit 2
  fi
  tools_root="$(printf '%s\n' "${candidates[@]}" | sort -V | tail -n 1)"
  TARGET="$tools_root/com.aidj.live.xrnx"
fi

mkdir -p "$TARGET"
cp "$SOURCE"/*.lua "$SOURCE/manifest.xml" "$TARGET"/
rm -rf "$TARGET/setup"
cp -R "$SOURCE/setup" "$TARGET/setup"
mkdir -p "$TARGET/logs" "$TARGET/generated"
echo "Installed AIDJ Tool: $TARGET"
echo "Reload Tools in Renoise, then Tools -> AIDJ -> Start Session."
