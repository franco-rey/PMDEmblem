#!/bin/zsh
set -e
PROJECT="${PROJECT:-$(cd "$(dirname "$0")/../.." && pwd)}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="${1:-$PROJECT/../PMDEmblem-builds}"
MARKERS=("assets/audio/pmdo/.gdignore" "assets/audio/cries/.gdignore")

restore_markers() {
  for marker in $MARKERS; do
    mkdir -p "$PROJECT/$(dirname $marker)"
    touch "$PROJECT/$marker"
  done
  find "$PROJECT/assets/audio" -name '*.import' -delete 2>/dev/null || true
  "$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true
}
trap restore_markers EXIT INT TERM

mkdir -p "$OUT"
echo "build: lifting the audio import markers for this run"
for marker in $MARKERS; do rm -f "$PROJECT/$marker"; done
"$GODOT" --headless --path "$PROJECT" --import
echo "build: exporting macOS"
"$GODOT" --headless --path "$PROJECT" --export-release "macOS" "$OUT/PMDEmblem.app"
echo "build: exporting Windows"
"$GODOT" --headless --path "$PROJECT" --export-release "Windows Desktop" "$OUT/PMDEmblem.exe"
echo "build: done, output in $OUT"
