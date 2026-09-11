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
OUT="$(cd "$OUT" && pwd)"
echo "build: lifting the audio import markers for this run"
for marker in $MARKERS; do rm -f "$PROJECT/$marker"; done
"$GODOT" --headless --path "$PROJECT" --import
echo "build: exporting macOS"
"$GODOT" --headless --path "$PROJECT" --export-release "macOS" "$OUT/PMDEmblem.app"
echo "build: exporting Windows"
"$GODOT" --headless --path "$PROJECT" --export-release "Windows Desktop" "$OUT/PMDEmblem.exe"
echo "build: checking the packs"
CHECK_DIR="$OUT/.pack_check"
mkdir -p "$CHECK_DIR"
printf '[application]\nconfig/name="PackCheck"\n' > "$CHECK_DIR/project.godot"
for pack in "$OUT"/PMDEmblem.app/Contents/Resources/*.pck "$OUT/PMDEmblem.exe"; do
  "$GODOT" --headless --path "$CHECK_DIR" --script "$PROJECT/tools/validation/smoke_test_export_pack.gd" -- "--pack=$pack" 2>&1 | grep -E "smoke:" || true
  "$GODOT" --headless --path "$CHECK_DIR" --script "$PROJECT/tools/validation/smoke_test_export_pack.gd" -- "--pack=$pack" >/dev/null 2>&1 || { echo "build: pack check FAILED for $pack"; exit 1; }
done
echo "build: done, output in $OUT"
