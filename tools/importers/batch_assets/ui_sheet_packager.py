from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from source_config import PROJECT_ROOT, load_config


SOURCE_SUBDIR = Path("DumpAsset") / "Content" / "UI"
DEST_DIR = PROJECT_ROOT / "assets" / "visuals" / "raw_asset" / "UI"
MANIFEST_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "generated" / "ui_sheet_manifest.json"
REPORT_TXT_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "import_reports" / "ui_sheet_report.txt"
REQUIRED_FILES = ("MenuBorder.png", "PortraitBorder.png", "MenuBG.png")
BACKDROP_SUBDIR = Path("Tile") / "24x24"
BACKDROP_DEST_DIR = PROJECT_ROOT / "assets" / "visuals" / "raw_asset" / "Backdrop"
BACKDROP_SCENES = ("BaseCamp", "ForestCamp", "ForestCampSecret", "GardenEnd", "GuildPath", "SnowCamp", "LuminousSpring", "CaveStop")


def main() -> int:
    args = _parse_args()
    if not args.dry_run and not args.write:
        args.dry_run = True
    sources = load_config(args)
    source_dir = sources.pmdo_root / SOURCE_SUBDIR
    if not source_dir.exists():
        print(f"error: PMDO UI sheets missing at {source_dir}")
        return 2

    payload = _package_sheets(source_dir, sources.raw_asset_root / BACKDROP_SUBDIR, args.dry_run)
    summary = payload["summary"]
    print(
        "ui sheet packager %s: files=%d copied=%d warnings=%d"
        % (
            "dry-run" if args.dry_run else "write",
            int(summary.get("file_count", 0)),
            int(summary.get("copied_count", 0)),
            len(payload.get("warnings", [])),
        )
    )
    for warning in payload.get("warnings", []):
        print(f"warning: {warning}")
    if args.write:
        _write_json(MANIFEST_PATH, payload)
        REPORT_TXT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_TXT_PATH.write_text(_render_text_report(payload), encoding="utf-8")
        print(f"wrote {MANIFEST_PATH.relative_to(PROJECT_ROOT)}")
        print(f"wrote {REPORT_TXT_PATH.relative_to(PROJECT_ROOT)}")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Copy the PMDO interface sheets (menu and portrait borders, menu background, cursor, HP digits) and the RawAsset hub scenes used as menu backdrops into PMDEmblem.")
    parser.add_argument("--pmdo-root", dest="pmdo_root")
    parser.add_argument("--raw-asset-root", dest="raw_asset_root")
    parser.add_argument("--sprite-collab-root", dest="sprite_collab_root")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


def _copy_file(source: Path, destination: Path, dry_run: bool) -> tuple[str, bool]:
    checksum = _sha256(source)
    copied = False
    if not dry_run:
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or _sha256(destination) != checksum:
            shutil.copy2(source, destination)
            copied = True
    return checksum, copied


def _package_sheets(source_dir: Path, backdrop_dir: Path, dry_run: bool) -> dict[str, Any]:
    entries: list[dict[str, str]] = []
    warnings: list[str] = []
    copied_count = 0
    for source in sorted(path for path in source_dir.iterdir() if path.is_file() and path.suffix.lower() == ".png"):
        destination = DEST_DIR / source.name
        checksum, copied = _copy_file(source, destination, dry_run)
        if copied:
            copied_count += 1
        entries.append({
            "source": f"UI/{source.name}",
            "path": "res://" + destination.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix(),
            "checksum": checksum,
        })
    names = {entry["source"].split("/", 1)[1] for entry in entries}
    for required in REQUIRED_FILES:
        if required not in names:
            warnings.append(f"UI: required sheet {required} not found")
    for scene in BACKDROP_SCENES:
        source = backdrop_dir / f"{scene}.png"
        if not source.exists():
            warnings.append(f"Backdrop: hub scene {scene}.png not found under {backdrop_dir}")
            continue
        destination = BACKDROP_DEST_DIR / f"{scene}.png"
        checksum, copied = _copy_file(source, destination, dry_run)
        if copied:
            copied_count += 1
        entries.append({
            "source": f"Tile/24x24/{scene}.png",
            "path": "res://" + destination.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix(),
            "checksum": checksum,
        })
    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "mode": "dry_run" if dry_run else "write",
        "source": "ui_sheet_packager",
        "asset_root": "res://assets/visuals/raw_asset/UI",
        "summary": {"file_count": len(entries), "copied_count": copied_count},
        "entries": entries,
        "warnings": warnings,
    }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def _render_text_report(payload: dict[str, Any]) -> str:
    lines = [
        "PMDO Interface Sheet Import Report",
        "==================================",
        f"Generated: {payload.get('generated_at', '')}",
        f"Files: {payload.get('summary', {}).get('file_count', 0)}",
        "",
    ]
    for entry in payload.get("entries", []):
        lines.append(f"{entry['source']} -> {entry['path']}")
    warnings = payload.get("warnings", [])
    if warnings:
        lines.append("")
        lines.append("Warnings")
        lines.append("--------")
        for warning in warnings:
            lines.append(f"- {warning}")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
