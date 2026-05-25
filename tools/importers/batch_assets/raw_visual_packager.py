#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from source_config import PROJECT_ROOT, load_config


CATEGORIES: dict[str, int] = {
    "BG": 25,
    "Beam": 60,
    "Icon": 109,
    "Item": 287,
    "Object": 89,
    "Particle": 749,
    "Tile": 23,
    "TileDtef": 4884,
    "font": 78295,
}

ASSET_ROOT = PROJECT_ROOT / "assets" / "visuals" / "raw_asset"
MANIFEST_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "generated" / "visual_asset_manifest.json"
REPORT_JSON_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "import_reports" / "visual_asset_report.json"
REPORT_TXT_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "import_reports" / "visual_asset_report.txt"


def main() -> int:
    args = _parse_args()
    if not args.dry_run and not args.write:
        args.dry_run = True
    sources = load_config(args)
    if not sources.raw_asset_root.exists():
        print(f"error: RawAsset root missing at {sources.raw_asset_root}")
        return 2

    payload = _package_visuals(sources.raw_asset_root, args.dry_run)
    summary = payload["summary"]
    print(
        "raw visual packager %s: files=%d copied=%d warnings=%d"
        % (
            "dry-run" if args.dry_run else "write",
            int(summary.get("file_count", 0)),
            int(summary.get("copied_count", 0)),
            len(payload.get("warnings", [])),
        )
    )
    if args.write:
        _write_json(MANIFEST_PATH, payload)
        _write_json(REPORT_JSON_PATH, payload)
        REPORT_TXT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_TXT_PATH.write_text(_render_text_report(payload), encoding="utf-8")
        print(f"wrote {MANIFEST_PATH.relative_to(PROJECT_ROOT)}")
        print(f"wrote {REPORT_JSON_PATH.relative_to(PROJECT_ROOT)}")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Copy RawAsset visual categories into PMDEmblem.")
    parser.add_argument("--pmdo-root", dest="pmdo_root")
    parser.add_argument("--raw-asset-root", dest="raw_asset_root")
    parser.add_argument("--sprite-collab-root", dest="sprite_collab_root")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


def _package_visuals(raw_root: Path, dry_run: bool) -> dict[str, Any]:
    categories: dict[str, Any] = {}
    lookup: dict[str, dict[str, str]] = {}
    warnings: list[str] = []
    copied_count = 0
    file_count = 0

    for category, expected_count in CATEGORIES.items():
        source_dir = raw_root / category
        dest_dir = ASSET_ROOT / category
        entries: list[dict[str, str]] = []
        category_lookup: dict[str, str] = {}
        if not source_dir.exists():
            warnings.append(f"{category}: missing source directory")
            categories[category] = {"expected_count": expected_count, "actual_count": 0, "entries": []}
            lookup[category] = {}
            continue

        for source in sorted(path for path in source_dir.rglob("*") if path.is_file() and path.name != ".DS_Store"):
            relative = source.relative_to(source_dir)
            destination = dest_dir / relative
            checksum = _sha256(source)
            copied = False
            if not dry_run:
                destination.parent.mkdir(parents=True, exist_ok=True)
                if not destination.exists() or _sha256(destination) != checksum:
                    shutil.copy2(source, destination)
                    copied = True
            if copied:
                copied_count += 1
            file_count += 1
            res_path = "res://" + destination.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix()
            key = _lookup_key(relative)
            if key in category_lookup and category_lookup[key] != res_path:
                warnings.append(f"{category}: duplicate lookup key {key}")
            else:
                category_lookup[key] = res_path
            entries.append({
                "source": f"{category}/{relative.as_posix()}",
                "path": res_path,
                "checksum": checksum,
                "lookup_key": key,
            })

        actual_count = len(entries)
        if actual_count != expected_count:
            warnings.append(f"{category}: expected {expected_count} files, found {actual_count}")
        categories[category] = {
            "expected_count": expected_count,
            "actual_count": actual_count,
            "entries": entries,
        }
        lookup[category] = category_lookup

    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "mode": "dry_run" if dry_run else "write",
        "source": "raw_visual_packager",
        "asset_root": "res://assets/visuals/raw_asset",
        "summary": {
            "file_count": file_count,
            "copied_count": copied_count,
            "category_count": len(CATEGORIES),
            "expected_file_count": sum(CATEGORIES.values()),
        },
        "categories": categories,
        "lookup": lookup,
        "warnings": warnings,
    }


def _lookup_key(relative: Path) -> str:
    raw = relative.as_posix()
    if raw.endswith(".None.png"):
        raw = raw.removesuffix(".None.png")
    elif "." in relative.name:
        raw = str(relative.with_suffix("")).replace("\\", "/")
    return raw


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
        "RawAsset Visual Import Report",
        "=============================",
        f"Generated: {payload.get('generated_at', '')}",
        f"Files: {payload.get('summary', {}).get('file_count', 0)}",
        f"Expected files: {payload.get('summary', {}).get('expected_file_count', 0)}",
        "",
    ]
    categories: dict[str, Any] = payload.get("categories", {})
    for category in sorted(categories.keys()):
        item: dict[str, Any] = categories[category]
        lines.append(
            "%s: %d / %d"
            % (
                category,
                int(item.get("actual_count", 0)),
                int(item.get("expected_count", 0)),
            )
        )
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
