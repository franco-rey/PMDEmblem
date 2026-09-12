#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUICK_SMOKES=(gender shiny forms board_skin skirmish_lobby battle_hud border_style)

usage() {
	echo "usage: run_all.sh [--quick] [--list] [name ...]"
	echo "  --quick    run only: ${QUICK_SMOKES[*]}"
	echo "  --list     print the smoke names and exit"
	echo "  name ...   run only the named smokes (bare name, no smoke_test_ prefix)"
	echo "  --no-watchdog  run Godot directly instead of through the timeout watchdog"
	echo "env: GODOT overrides the engine path, PYTHON the interpreter for the watchdog"
}

find_godot() {
	if [[ -n "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
	for candidate in \
		/Applications/Godot.app/Contents/MacOS/Godot \
		"$(command -v godot 2>/dev/null)" \
		"$(command -v godot4 2>/dev/null)"; do
		[[ -x "$candidate" ]] && { echo "$candidate"; return; }
	done
	echo ""
}

all_names() {
	for path in "$PROJECT_ROOT"/tools/validation/smoke_test_*.gd; do
		name="$(basename "$path" .gd)"
		name="${name#smoke_test_}"
		[[ "$name" == "export_pack" ]] && continue
		echo "$name"
	done
}

names=()
use_watchdog=1
while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		--list) all_names; exit 0 ;;
		--quick) names=("${QUICK_SMOKES[@]}") ;;
		--no-watchdog) use_watchdog=0 ;;
		-*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
		*) names+=("$1") ;;
	esac
	shift
done
if [[ ${#names[@]} -eq 0 ]]; then
	while IFS= read -r line; do names+=("$line"); done < <(all_names)
fi

GODOT_BIN="$(find_godot)"
if [[ -z "$GODOT_BIN" ]]; then
	echo "run_all: no Godot binary found; set GODOT=/path/to/godot" >&2
	exit 2
fi

WATCHDOG="${PROJECT_ROOT}/tools/debug/run_godot_watchdog.py"
PYTHON_BIN="${PYTHON:-python3}"
if [[ $use_watchdog -eq 1 ]] && { [[ ! -f "$WATCHDOG" ]] || ! command -v "$PYTHON_BIN" >/dev/null 2>&1; }; then
	use_watchdog=0
fi

LOG_DIR="${PROJECT_ROOT}/logs/validation/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

failed=()
total=${#names[@]}
index=0
started_suite=$SECONDS

for name in "${names[@]}"; do
	index=$((index + 1))
	script="tools/validation/smoke_test_${name}.gd"
	if [[ ! -f "${PROJECT_ROOT}/${script}" ]]; then
		printf '  [%d/%d] %-40s %s\n' "$index" "$total" "$name" "MISSING"
		failed+=("$name")
		continue
	fi
	log="${LOG_DIR}/${name}.log"
	started=$SECONDS
	if [[ $use_watchdog -eq 1 ]]; then
		"$PYTHON_BIN" "$WATCHDOG" --godot "$GODOT_BIN" --project "$PROJECT_ROOT" \
			--script "$script" --timeout 1200 --idle-timeout 600 >"$log" 2>&1
	else
		"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script "$script" >"$log" 2>&1
	fi
	code=$?
	status="FAILED"
	if [[ $code -eq 0 ]] && ! grep -q "smoke: FAIL" "$log" && grep -q " clean" "$log"; then
		status="clean"
	fi
	[[ "$status" == "clean" ]] || failed+=("$name")
	printf '  [%d/%d] %-40s %-7s %4ds\n' "$index" "$total" "$name" "$status" "$((SECONDS - started))"
done

echo
echo "suite: $((total - ${#failed[@]})) clean, ${#failed[@]} failed in $((SECONDS - started_suite))s"
echo "logs:  $LOG_DIR"
if [[ ${#failed[@]} -gt 0 ]]; then
	echo "failed: ${failed[*]}"
	exit 1
fi
