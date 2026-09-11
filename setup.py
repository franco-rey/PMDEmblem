from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

sys.dont_write_bytecode = True

PROJECT_ROOT = Path(__file__).resolve().parent
SIBLING_ROOT = PROJECT_ROOT.parent
BATCH = PROJECT_ROOT / "tools" / "importers" / "batch_assets"
PINNED_RAW_ASSET_REVISION = "03c80dad937911572f8fb19903771a47956fc696"
DEX_RANGE = "1-721"
MAX_LEVEL = 100
QUICK_SMOKES = ("gender", "shiny", "forms", "board_skin", "skirmish_lobby", "battle_hud", "border_style")
LOCAL_SOURCES_PATH = PROJECT_ROOT / "logs" / "local_sources.json"
MIN_PYTHON = (3, 10)
STEP_NAMES = ("raw_visuals", "ui_sheets", "board_skins", "roster", "import", "data", "reimport", "presentation", "sounds", "final_import", "verify")
GODOT_CANDIDATES = {
    "Darwin": ["/Applications/Godot.app/Contents/MacOS/Godot"],
    "Windows": [r"C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe", r"C:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe", r"C:\Program Files\Godot\godot.exe"],
    "Linux": ["/usr/local/bin/godot", "/usr/bin/godot", "/usr/bin/godot4"],
}


@dataclass
class Step:
    name: str
    describe: str
    command: list[str]
    expect: str = ""
    seconds: float = 0.0
    status: str = "pending"
    log: Path | None = None


@dataclass
class Context:
    godot: str
    python: str
    log_dir: Path
    env: dict[str, str] = field(default_factory=dict)
    source_revision: str = PINNED_RAW_ASSET_REVISION


def main() -> int:
    args = _parse_args()
    context = _build_context(args)
    if context is None:
        return 2
    steps = _plan(context, args)
    selected = _select(steps, args)
    if args.plan:
        for step in steps:
            marker = "run " if step in selected else "skip"
            print(f"{marker} {step.name:14s} {step.describe}")
            print(f"     {' '.join(_display(step.command))}")
        return 0
    print(f"setup: project {PROJECT_ROOT}")
    print(f"setup: godot {context.godot}")
    print(f"setup: logs in {context.log_dir}")
    print(f"setup: RawAsset revision {context.source_revision}" + ("" if context.source_revision == PINNED_RAW_ASSET_REVISION else f" (pipeline was verified against {PINNED_RAW_ASSET_REVISION})"))
    started = time.time()
    failed: Step | None = None
    for step in steps:
        if step not in selected:
            step.status = "skipped"
            continue
        if step.name == "presentation":
            items = _presentation_items(context)
            if not items:
                step.status = "failed"
                failed = step
                print("setup: presentation step could not list the applicable items; run the data step first")
                break
            step.command = step.command + ["--items", ",".join(items)]
            print(f"setup: presentation covers {len(items)} items")
        code = _run(step, context, args.verify)
        if code != 0:
            failed = step
            break
    _restore_credits_timestamp()
    total = time.time() - started
    print()
    print(f"{'step':14s} {'status':8s} {'time':>8s}")
    for step in steps:
        print(f"{step.name:14s} {step.status:8s} {_fmt(step.seconds):>8s}")
    print(f"{'total':14s} {'':8s} {_fmt(total):>8s}")
    if failed is not None:
        print(f"setup: stopped at {failed.name}; see {failed.log}")
        print(f"setup: resume with --from {failed.name}")
        return 1
    print("setup: the tree is ready; open the project in Godot 4.7.2 or export builds with tools/build/export_builds.sh")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a fresh clone of PMD Emblem into a playable tree from the PMDODump, RawAsset and SpriteCollab checkouts next to it, then run the smoke tests.")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or os.environ.get("GODOT") or "", help="Godot 4.7.2 executable (default: GODOT_BIN, GODOT or the platform install)")
    parser.add_argument("--pmdo-root", default=os.environ.get("PMD_EMBLEM_PMDO_ROOT", ""))
    parser.add_argument("--raw-asset-root", default=os.environ.get("PMD_EMBLEM_RAW_ASSET_ROOT", ""))
    parser.add_argument("--sprite-collab-root", default=os.environ.get("PMD_EMBLEM_SPRITE_COLLAB_ROOT", ""))
    parser.add_argument("--from", dest="start", choices=STEP_NAMES, help="resume from this step")
    parser.add_argument("--only", choices=STEP_NAMES, help="run a single step")
    parser.add_argument("--skip", action="append", default=[], choices=STEP_NAMES, help="skip a step (repeatable)")
    parser.add_argument("--verify", choices=("full", "quick", "none"), default="full", help="closing tests: the full smoke suite (default), a quick set, or none")
    parser.add_argument("--no-verify", action="store_true", help="same as --verify none")
    parser.add_argument("--plan", action="store_true", help="print the steps and exit")
    return parser.parse_args()


def _build_context(args: argparse.Namespace) -> Context | None:
    if sys.version_info < MIN_PYTHON:
        print(f"setup: Python {MIN_PYTHON[0]}.{MIN_PYTHON[1]} or newer is required; this is {sys.version.split()[0]}")
        return None
    try:
        import PIL
    except ImportError:
        print("setup: Pillow is required by the importers; install it with: python3 -m pip install pillow")
        return None
    local = _local_sources()
    roots = {
        "PMDODump": _resolve_root(args.pmdo_root, local.get("pmdo_root", ""), SIBLING_ROOT / "PMDODump"),
        "RawAsset": _resolve_root(args.raw_asset_root, local.get("raw_asset_root", ""), SIBLING_ROOT / "RawAsset"),
        "SpriteCollab": _resolve_root(args.sprite_collab_root, local.get("sprite_collab_root", ""), SIBLING_ROOT / "SpriteCollab"),
    }
    for name in ("PMDODump", "RawAsset"):
        if not roots[name].is_dir():
            roots[name] = _ask_root(name, roots[name])
    missing = [name for name, root in roots.items() if name != "SpriteCollab" and not root.is_dir()]
    if missing:
        print("setup: missing resource checkouts: " + ", ".join(missing))
        print(f"setup: clone them next to the project folder ({SIBLING_ROOT}) as PMDODump, RawAsset and SpriteCollab, or pass --pmdo-root / --raw-asset-root / --sprite-collab-root")
        return None
    if not roots["SpriteCollab"].is_dir():
        print("setup: SpriteCollab checkout not found; credits files will fall back to RawAsset")
    _remember_sources(roots)
    godot = _find_godot(args.godot)
    if not godot:
        print("setup: Godot 4.7.2 not found; pass --godot or set GODOT_BIN")
        return None
    version = _godot_version(godot)
    if not version.startswith("4.7"):
        print(f"setup: {godot} reports version {version or 'unknown'}; the project needs Godot 4.7.x")
        return None
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PMD_EMBLEM_PMDO_ROOT"] = str(roots["PMDODump"])
    env["PMD_EMBLEM_RAW_ASSET_ROOT"] = str(roots["RawAsset"])
    if roots["SpriteCollab"].is_dir():
        env["PMD_EMBLEM_SPRITE_COLLAB_ROOT"] = str(roots["SpriteCollab"])
    log_dir = PROJECT_ROOT / "logs" / "setup" / time.strftime("%Y%m%d_%H%M%S")
    log_dir.mkdir(parents=True, exist_ok=True)
    return Context(godot=godot, python=sys.executable, log_dir=log_dir, env=env, source_revision=_git_head(roots["RawAsset"]) or PINNED_RAW_ASSET_REVISION)


def _resolve_root(explicit: str, remembered: str, default: Path) -> Path:
    for candidate in (explicit, remembered):
        if candidate:
            return Path(candidate).expanduser()
    return default


def _ask_root(name: str, guess: Path) -> Path:
    if not sys.stdin.isatty():
        return guess
    print(f"setup: {name} was not found at {guess}")
    answer = input(f"setup: path to your {name} checkout (blank to stop): ").strip()
    return Path(answer).expanduser() if answer else guess


def _local_sources() -> dict[str, str]:
    if not LOCAL_SOURCES_PATH.exists():
        return {}
    try:
        loaded = json.loads(LOCAL_SOURCES_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return loaded if isinstance(loaded, dict) else {}


def _remember_sources(roots: dict[str, Path]) -> None:
    payload = {"pmdo_root": str(roots["PMDODump"]), "raw_asset_root": str(roots["RawAsset"])}
    if roots["SpriteCollab"].is_dir():
        payload["sprite_collab_root"] = str(roots["SpriteCollab"])
    if _local_sources() == payload:
        return
    LOCAL_SOURCES_PATH.parent.mkdir(parents=True, exist_ok=True)
    LOCAL_SOURCES_PATH.write_text(json.dumps(payload, indent=1) + "\n", encoding="utf-8")


def _plan(context: Context, args: argparse.Namespace) -> list[Step]:
    py = context.python
    godot = [context.godot, "--headless", "--path", str(PROJECT_ROOT)]
    steps = [
        Step("raw_visuals", "PMDO particles, beams, tiles, backgrounds and fonts into assets/visuals/raw_asset (about 30 s)", [py, str(BATCH / "raw_visual_packager.py"), "--write"]),
        Step("ui_sheets", "PMDO interface sheets and the seven hub scenes (instant)", [py, str(BATCH / "ui_sheet_packager.py"), "--write"]),
        Step("board_skins", "24 board floor and wall tiles plus the decoration sheets from the imported dungeon sets (instant)", [py, str(BATCH / "board_skin_packager.py"), "--write"]),
        Step("roster", "686 Pokemon with shiny, female and form variants (about 16 min)", [py, str(BATCH / "pokemon_batch_packager.py"), "--dex-range", DEX_RANGE, "--write", "--replace-manifest", "--source-revision", context.source_revision]),
        Step("import", "Godot import of the copied textures (about 2 min)", godot + ["--import"]),
        Step("data", "species, forms, moves, items and instances from PMDO (about 25 s)", godot + ["--script", "tools/importers/pmdo_run.gd"]),
        Step("reimport", "Godot import of the generated resources and class cache", godot + ["--import"]),
        Step("presentation", "move and item presentation manifest (about 1 min)", [py, str(BATCH / "action_presentation_packager.py"), "--dex-range", DEX_RANGE, "--max-level", str(MAX_LEVEL), "--write"]),
        Step("sounds", "PMDO sound effects and music into assets/audio (about 1 min)", [py, str(BATCH / "sound_packager.py"), "--write"]),
        Step("final_import", "Godot import after the manifests landed", godot + ["--import"]),
        Step("verify", "every smoke test under tools/validation (about 45 min)" if args.verify == "full" else "quick smoke tests (" + ", ".join(QUICK_SMOKES) + ")", []),
    ]
    return steps


def _select(steps: list[Step], args: argparse.Namespace) -> list[Step]:
    if args.only:
        chosen = [step for step in steps if step.name == args.only]
    else:
        start = STEP_NAMES.index(args.start) if args.start else 0
        chosen = [step for step in steps if STEP_NAMES.index(step.name) >= start]
    chosen = [step for step in chosen if step.name not in args.skip]
    if args.no_verify or args.verify == "none":
        chosen = [step for step in chosen if step.name != "verify"]
    return chosen


def _run(step: Step, context: Context, args_verify: str = "full") -> int:
    step.log = context.log_dir / f"{step.name}.log"
    print(f"setup: {step.name}: {step.describe}")
    started = time.time()
    if step.name == "verify":
        code = _verify(step, context, args_verify)
    else:
        code = _spawn(step.command, step.log, context)
    step.seconds = time.time() - started
    step.status = "ok" if code == 0 else "failed"
    print(f"setup: {step.name} {step.status} in {_fmt(step.seconds)}")
    return code


def _spawn(command: list[str], log: Path, context: Context, echo_tail: int = 3) -> int:
    with log.open("w", encoding="utf-8") as handle:
        handle.write(" ".join(command) + "\n\n")
        handle.flush()
        process = subprocess.Popen(command, cwd=str(PROJECT_ROOT), env=context.env, stdout=handle, stderr=subprocess.STDOUT)
        code = process.wait()
    lines = [line.rstrip() for line in log.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]
    for line in lines[-echo_tail:]:
        print(f"    {line[:160]}")
    return code


def _verify(step: Step, context: Context, mode: str) -> int:
    if mode == "quick":
        names = list(QUICK_SMOKES)
    else:
        names = sorted(path.stem[len("smoke_test_"):] for path in (PROJECT_ROOT / "tools" / "validation").glob("smoke_test_*.gd") if path.stem != "smoke_test_export_pack")
    watchdog = PROJECT_ROOT / "tools" / "debug" / "run_godot_watchdog.py"
    failures: list[str] = []
    summary = context.log_dir / "suite.txt"
    lines: list[str] = []
    for index, smoke in enumerate(names, 1):
        script = f"tools/validation/smoke_test_{smoke}.gd"
        if not (PROJECT_ROOT / script).exists():
            continue
        log = context.log_dir / f"verify_{smoke}.log"
        started = time.time()
        if watchdog.exists():
            command = [context.python, str(watchdog), "--godot", context.godot, "--project", str(PROJECT_ROOT), "--script", script, "--timeout", "1200", "--idle-timeout", "600"]
        else:
            command = [context.godot, "--headless", "--path", str(PROJECT_ROOT), "--script", script]
        code = _spawn(command, log, context, echo_tail=0)
        text = log.read_text(encoding="utf-8", errors="replace")
        clean = code == 0 and "smoke: FAIL" not in text and " clean" in text
        status = "clean" if clean else "FAILED"
        line = f"{smoke:40s} {status:7s} {_fmt(time.time() - started):>7s}"
        lines.append(line)
        print(f"    [{index}/{len(names)}] {line}")
        if not clean:
            failures.append(smoke)
    lines.append(f"suite: {len(names) - len(failures)} clean, {len(failures)} failed")
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if failures:
        print("    failed: " + ", ".join(failures))
    return 1 if failures else 0


def _presentation_items(context: Context) -> list[str]:
    log = context.log_dir / "presentation_items.log"
    code = _spawn([context.godot, "--headless", "--path", str(PROJECT_ROOT), "--script", "tools/setup/print_presentation_items.gd"], log, context, echo_tail=0)
    if code != 0:
        return []
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("presentation_items: "):
            return [item for item in line[len("presentation_items: "):].strip().split(",") if item]
    return []


def _find_godot(explicit: str) -> str:
    candidates: list[str] = []
    if explicit:
        candidates.append(explicit)
    candidates.extend(GODOT_CANDIDATES.get(platform.system(), []))
    for name in ("godot", "godot4", "Godot"):
        found = shutil.which(name)
        if found:
            candidates.append(found)
    for candidate in candidates:
        path = Path(candidate)
        if path.is_dir() and path.suffix == ".app":
            path = path / "Contents" / "MacOS" / "Godot"
        if path.is_file():
            return str(path)
    return ""


def _godot_version(godot: str) -> str:
    try:
        result = subprocess.run([godot, "--version"], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    for line in (result.stdout + result.stderr).splitlines():
        line = line.strip()
        if line and line[0].isdigit():
            return line
    return ""


def _git_head(root: Path) -> str:
    if not shutil.which("git"):
        return ""
    try:
        result = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    head = result.stdout.strip()
    return head if result.returncode == 0 and len(head) == 40 else ""


def _restore_credits_timestamp() -> None:
    credits = PROJECT_ROOT / "assets" / "textures" / "credits.txt"
    if not shutil.which("git") or not credits.exists():
        return
    diff = subprocess.run(["git", "-C", str(PROJECT_ROOT), "diff", "--numstat", "--", str(credits)], capture_output=True, text=True)
    if diff.returncode == 0 and diff.stdout.strip().startswith("1\t1\t"):
        subprocess.run(["git", "-C", str(PROJECT_ROOT), "checkout", "--", str(credits)], capture_output=True, text=True)


def _display(command: list[str]) -> list[str]:
    out: list[str] = []
    for part in command:
        out.append(part[:80] + "..." if len(part) > 80 else part)
    return out


def _fmt(seconds: float) -> str:
    if seconds >= 60:
        return f"{int(seconds // 60)}m{int(seconds % 60):02d}s"
    return f"{seconds:.0f}s"


if __name__ == "__main__":
    sys.exit(main())
