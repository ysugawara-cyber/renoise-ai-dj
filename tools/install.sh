#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/tools/AIDJ"
TARGET="${AIDJ_RENOISE_TOOL_DIR:-}"

if [[ -z "$TARGET" && -n "${AIDJ_RENOISE_DATA_DIR:-}" ]]; then
  TARGET="${AIDJ_RENOISE_DATA_DIR%/}/Scripts/Tools/com.aidj.live.xrnx"
fi

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

original_target="$TARGET"
while [[ "$original_target" != "/" && "$original_target" != "." ]]; do
  if [[ -L "$original_target" ]]; then
    echo "Refusing Tool target with symlink component: $TARGET" >&2
    exit 2
  fi
  original_target="$(dirname -- "$original_target")"
done
TARGET="$(realpath -m -- "$TARGET")"
if [[ "${TARGET##*/}" != "com.aidj.live.xrnx" ]]; then
  echo "Refusing unsafe Tool target (must end in com.aidj.live.xrnx): $TARGET" >&2
  exit 2
fi
if [[ -e "$TARGET" && ! -d "$TARGET" ]]; then
  echo "Refusing non-directory Tool target: $TARGET" >&2
  exit 2
fi
if [[ -d "$TARGET" ]]; then
  if [[ -L "$TARGET/manifest.xml" ]] || [[ ! -f "$TARGET/manifest.xml" ]] ||
     ! grep -q '<Id>com.aidj.live</Id>' "$TARGET/manifest.xml"; then
    echo "Refusing to replace an unowned Tool directory: $TARGET" >&2
    exit 2
  fi
  for runtime_path in logs generated osc_bind_host.txt wsl_ip.txt; do
    if [[ -L "$TARGET/$runtime_path" ]]; then
      echo "Refusing symlink in Tool runtime state: $TARGET/$runtime_path" >&2
      exit 2
    fi
  done
fi

PARENT="$(dirname -- "$TARGET")"
mkdir -p "$PARENT"
STAGE="$(mktemp -d "$PARENT/.aidj-install.XXXXXX")"
BACKUP="${STAGE}.backup"
cleanup() {
  rm -rf -- "$STAGE"
  if [[ -d "$BACKUP" && ! -e "$TARGET" ]]; then mv -- "$BACKUP" "$TARGET"; fi
}
trap cleanup EXIT

cp "$SOURCE"/*.lua "$SOURCE/manifest.xml" "$STAGE"/
cp -R "$SOURCE/setup" "$STAGE/setup"
mkdir -p "$STAGE/logs" "$STAGE/generated"
if [[ -d "$TARGET/logs" ]]; then cp -a "$TARGET/logs/." "$STAGE/logs/"; fi
if [[ -d "$TARGET/generated" ]]; then cp -a "$TARGET/generated/." "$STAGE/generated/"; fi
for runtime_config in osc_bind_host.txt wsl_ip.txt; do
  if [[ -f "$TARGET/$runtime_config" ]]; then cp -a "$TARGET/$runtime_config" "$STAGE/"; fi
done
if [[ -d "$TARGET" ]]; then mv -- "$TARGET" "$BACKUP"; fi
mv -- "$STAGE" "$TARGET"
rm -rf -- "$BACKUP"
trap - EXIT
echo "Installed AIDJ Tool: $TARGET"
echo "Reload Tools in Renoise, then Tools -> AIDJ -> Start Session."
