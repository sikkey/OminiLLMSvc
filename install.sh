#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$ROOT_DIR/template/config"
TARGET_DIR="$ROOT_DIR/apps/config"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "[ERROR] Source template directory not found: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$TARGET_DIR"

while IFS= read -r -d '' src; do
  rel_path="${src#$SOURCE_DIR/}"
  target="$TARGET_DIR/$rel_path"

  if [ -e "$target" ]; then
    echo "[INFO] Already exists, keeping current config: $target"
    continue
  fi

  mkdir -p "$(dirname "$target")"
  cp "$src" "$target"
  echo "[OK] Installed template file: $target"
done < <(find "$SOURCE_DIR" -type f -print0)

echo "[OK] Template installation complete."
