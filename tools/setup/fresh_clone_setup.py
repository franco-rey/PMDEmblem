from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

sys.dont_write_bytecode = True

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SIBLING_ROOT = PROJECT_ROOT.parent
BATCH = PROJECT_ROOT / "tools" / "importers" / "batch_assets"
PINNED_RAW_ASSET_REVISION = "03c80dad937911572f8fb19903771a47956fc696"
DEX_RANGE = "1-721"
MAX_LEVEL = 100
VERIFY_SMOKES = ("gender", "shiny", "forms", "skirmish_lobby", "battle_hud", "border_style")
STEP_NAMES = ("raw_visuals", "ui_sheets", "roster", "import", "data", "reimport", "presentation", "sounds", "final_import", "verify")
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
        code = _run(step, context)
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
    print("setup: the tree is ready; open the project in Godot 4.7.2 or run the smokes under tools/validation")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a fresh clone of PMD Emblem into a playable tree from the sibling PMDODump, RawAsset and SpriteCollab checkouts.")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or os.environ.get("GODOT") or "", help="Godot 4.7.2 executable (default: GODOT_BIN, GODOT or the platform install)")
    parser.add_argument("--pmdo-root", default=os.environ.get("PMD_EMBLEM_PMDO_ROOT", ""))
    parser.add_argument("--raw-asset-root", default=os.environ.get("PMD_EMBLEM_RAW_ASSET_ROOT", ""))
    parser.add_argument("--sprite-collab-root", default=os.environ.get("PMD_EMBLEM_SPRITE_COLLAB_ROOT", ""))
    parser.add_argument("--from", dest="start", choices=STEP_NAMES, help="resume from this step")
    parser.add_argument("--only", choices=STEP_NAMES, help="run a single step")
    parser.add_argument("--skip", action="append", default=[], choices=STEP_NAMES, help="skip a step (repeatable)")
    parser.add_argument("--no-verify", action="store_true", help="skip the closing smoke tests")
    parser.add_argument("--plan", action="store_true", help="print the steps and exit")
    return parser.parse_args()


def _build_context(args: argparse.Namespace) -> Context | None:
    roots = {
        "PMDODump": Path(args.pmdo_root) if args.pmdo_root else SIBLING_ROOT / "PMDODump",
        "RawAsset": Path(args.raw_asset_root) if args.raw_asset_root else SIBLING_ROOT / "RawAsset",
        "SpriteCollab": Path(args.sprite_collab_root) if args.sprite_collab_root else SIBLING_ROOT / "SpriteCollab",
    }
    missing = [name for name, root in roots.items() if name != "SpriteCollab" and not root.is_dir()]
    if missing:
        print("setup: missing sibling checkouts: " + ", ".join(missing))
        print(f"setup: expected next to the project folder ({SIBLING_ROOT}) as PMDODump, RawAsset and SpriteCollab, or pass --pmdo-root / --raw-asset-root / --sprite-collab-root")
        return None
    if not roots["SpriteCollab"].is_dir():
        print("setup: SpriteCollab checkout not found; credits files will fall back to RawAsset")
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


def _plan(context: Context, args: argparse.Namespace) -> list[Step]:
    py = context.python
    godot = [context.godot, "--headless", "--path", str(PROJECT_ROOT)]
    steps = [
        Step("raw_visuals", "PMDO particles, beams, tiles, backgrounds and fonts into assets/visuals/raw_asset (about 30 s)", [py, str(BATCH / "raw_visual_packager.py"), "--write"]),
        Step("ui_sheets", "PMDO interface sheets and the seven hub scenes (instant)", [py, str(BATCH / "ui_sheet_packager.py"), "--write"]),
        Step("roster", "686 Pokemon with shiny, female and form variants (about 16 min)", [py, str(BATCH / "pokemon_batch_packager.py"), "--dex-range", DEX_RANGE, "--write", "--replace-manifest", "--source-revision", context.source_revision]),
        Step("import", "Godot import of the copied textures (about 2 min)", godot + ["--import"]),
        Step("data", "species, forms, moves, items and instances from PMDO (about 25 s)", godot + ["--script", "tools/importers/pmdo_run.gd"]),
        Step("reimport", "Godot import of the generated resources and class cache", godot + ["--import"]),
        Step("presentation", "move and item presentation manifest (about 1 min)", [py, str(BATCH / "action_presentation_packager.py"), "--dex-range", DEX_RANGE, "--max-level", str(MAX_LEVEL), "--write"]),
        Step("sounds", "PMDO sound effects and music into assets/audio (about 1 min)", [py, str(BATCH / "sound_packager.py"), "--write"]),
        Step("final_import", "Godot import after the manifests landed", godot + ["--import"]),
        Step("verify", "closing smoke tests (" + ", ".join(VERIFY_SMOKES) + ")", []),
    ]
    return steps


def _select(steps: list[Step], args: argparse.Namespace) -> list[Step]:
    if args.only:
        chosen = [step for step in steps if step.name == args.only]
    else:
        start = STEP_NAMES.index(args.start) if args.start else 0
        chosen = [step for step in steps if STEP_NAMES.index(step.name) >= start]
    chosen = [step for step in chosen if step.name not in args.skip]
    if args.no_verify:
        chosen = [step for step in chosen if step.name != "verify"]
    return chosen


def _run(step: Step, context: Context) -> int:
    step.log = context.log_dir / f"{step.name}.log"
    print(f"setup: {step.name}: {step.describe}")
    started = time.time()
    if step.name == "verify":
        code = _verify(step, context)
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


def _verify(step: Step, context: Context) -> int:
    failures = 0
    for smoke in VERIFY_SMOKES:
        script = f"tools/validation/smoke_test_{smoke}.gd"
        if not (PROJECT_ROOT / script).exists():
            continue
        log = context.log_dir / f"verify_{smoke}.log"
        code = _spawn([context.godot, "--headless", "--path", str(PROJECT_ROOT), "--script", script], log, context, echo_tail=0)
        text = log.read_text(encoding="utf-8", errors="replace")
        clean = code == 0 and f"smoke: {smoke} clean" in text
        print(f"    {smoke}: {'clean' if clean else 'FAILED'}")
        if not clean:
            failures += 1
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
