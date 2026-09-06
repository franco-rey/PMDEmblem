from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from source_config import PROJECT_ROOT, load_config


SOUND_CATEGORIES: dict[str, str] = {"Battle": "battle", "Fanfare": "fanfare", "Menu": "menu"}
MUSIC_CATEGORY: tuple[str, str] = ("Music", "music")
ASSET_ROOT = PROJECT_ROOT / "assets" / "audio" / "pmdo"
MANIFEST_PATH = PROJECT_ROOT / "data" / "models" / "audio" / "generated" / "sound_manifest.json"
REPORT_JSON_PATH = PROJECT_ROOT / "data" / "models" / "audio" / "import_reports" / "sound_asset_report.json"
REPORT_TXT_PATH = PROJECT_ROOT / "data" / "models" / "audio" / "import_reports" / "sound_asset_report.txt"
PRESENTATION_MANIFEST = PROJECT_ROOT / "data" / "models" / "visuals" / "generated" / "action_presentation_manifest.json"
CUE_TABLE = PROJECT_ROOT / "data" / "models" / "audio" / "sound_cues.json"
CRIES_ROOT = PROJECT_ROOT / "assets" / "audio" / "cries"
SPECIES_DIR = PROJECT_ROOT / "data" / "models" / "pokemon" / "generated" / "species"
CRY_EXTENSIONS = (".ogg", ".wav", ".mp3")


def main() -> int:
    args = _parse_args()
    if not args.dry_run and not args.write:
        args.dry_run = True
    sources = load_config(args)
    sound_root = sources.pmdo_root / "DumpAsset" / "Content" / "Sound"
    if not sound_root.is_dir():
        print(f"error: PMDO sound folder missing at {sound_root}")
        return 2
    payload = _package_sounds(sources.pmdo_root, sound_root, args.dry_run, not args.skip_music, Path(args.cries_root) if args.cries_root else None)
    summary = payload["summary"]
    print(
        "sound packager %s: files=%d copied=%d cries=%d missing_presentation=%d missing_cues=%d"
        % (
            "dry-run" if args.dry_run else "write",
            int(summary["file_count"]),
            int(summary["copied_count"]),
            int(summary["cry_count"]),
            len(payload["presentation_missing"]),
            len(payload["cue_missing"]),
        )
    )
    if args.dry_run:
        return 0
    _write_json(MANIFEST_PATH, payload["manifest"])
    _write_json(REPORT_JSON_PATH, payload["report"])
    REPORT_TXT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_TXT_PATH.write_text(_render_text_report(payload), encoding="utf-8")
    (ASSET_ROOT / ".gdignore").touch()
    CRIES_ROOT.mkdir(parents=True, exist_ok=True)
    (CRIES_ROOT / ".gdignore").touch()
    print(f"wrote {MANIFEST_PATH}")
    print(f"wrote {REPORT_JSON_PATH}")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Copy PMDODump sound effects into PMDEmblem and write the sound manifest.")
    parser.add_argument("--pmdo-root", dest="pmdo_root")
    parser.add_argument("--raw-asset-root", dest="raw_asset_root")
    parser.add_argument("--sprite-collab-root", dest="sprite_collab_root")
    parser.add_argument("--skip-music", action="store_true")
    parser.add_argument("--cries-root", dest="cries_root")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


def _package_sounds(pmdo_root: Path, sound_root: Path, dry_run: bool, include_music: bool, cries_source: Path | None) -> dict[str, Any]:
    categories = dict(SOUND_CATEGORIES)
    if include_music:
        categories[MUSIC_CATEGORY[0]] = MUSIC_CATEGORY[1]
    sounds: dict[str, dict[str, Any]] = {}
    by_name: dict[str, str] = {}
    counts: dict[str, int] = {}
    copied = 0
    warnings: list[str] = []
    for source_name, folder in categories.items():
        source_dir = sound_root / source_name if source_name != MUSIC_CATEGORY[0] else pmdo_root / "DumpAsset" / "Content" / "Music"
        if not source_dir.is_dir():
            warnings.append(f"missing source folder {source_dir}")
            continue
        destination_dir = ASSET_ROOT / folder
        for source in sorted(source_dir.glob("*.ogg")):
            key = f"{source_name}/{source.stem}"
            destination = destination_dir / source.name
            checksum = _sha256(source)
            if not dry_run:
                destination_dir.mkdir(parents=True, exist_ok=True)
                if not destination.exists() or _sha256(destination) != checksum:
                    shutil.copy2(source, destination)
                    copied += 1
            sounds[key] = {
                "path": "res://" + destination.relative_to(PROJECT_ROOT).as_posix(),
                "category": source_name,
                "bytes": source.stat().st_size,
                "checksum": checksum,
            }
            by_name.setdefault(source.stem, key)
            counts[source_name] = counts.get(source_name, 0) + 1
    cries, cry_unmatched = _package_cries(cries_source, dry_run)
    status_sounds = _status_sounds(pmdo_root / "DumpAsset" / "Data" / "Status")
    map_status_sounds = _status_sounds(pmdo_root / "DumpAsset" / "Data" / "MapStatus")
    presentation_sounds = _presentation_sounds()
    presentation_missing = sorted(name for name in presentation_sounds if name not in by_name)
    cue_missing = sorted(_cue_names() - set(sounds.keys()) - set(by_name.keys()))
    generated_at = datetime.now(timezone.utc).isoformat()
    manifest = {
        "schema_version": 1,
        "generated_at": generated_at,
        "source": {"pmdo_root": str(pmdo_root), "sound_root": str(sound_root)},
        "asset_root": "res://" + ASSET_ROOT.relative_to(PROJECT_ROOT).as_posix(),
        "sounds": sounds,
        "by_name": by_name,
        "status_sounds": status_sounds,
        "map_status_sounds": map_status_sounds,
        "cries": cries,
        "music_included": include_music,
    }
    summary = {
        "file_count": len(sounds),
        "copied_count": copied,
        "categories": counts,
        "presentation_sound_count": len(presentation_sounds),
        "presentation_missing_count": len(presentation_missing),
        "status_sound_count": len(status_sounds),
        "map_status_sound_count": len(map_status_sounds),
        "cry_count": len(cries),
        "cry_unmatched": cry_unmatched,
        "music_included": include_music,
    }
    report = {
        "generated_at": generated_at,
        "source": manifest["source"],
        "summary": summary,
        "presentation_missing": presentation_missing,
        "cue_missing": cue_missing,
        "warnings": warnings,
    }
    return {"manifest": manifest, "report": report, "summary": summary, "presentation_missing": presentation_missing, "cue_missing": cue_missing, "warnings": warnings}


def _species_slugs() -> dict[str, str]:
    by_number: dict[str, str] = {}
    if not SPECIES_DIR.is_dir():
        return by_number
    for path in SPECIES_DIR.glob("*.tres"):
        stem = path.stem
        number, _, name = stem.partition("_")
        if number.isdigit():
            by_number[str(int(number))] = stem
            by_number.setdefault(name, stem)
    return by_number


def _cry_slug(stem: str, species: dict[str, str]) -> str:
    key = stem.lower().strip()
    if key in species:
        return species[key]
    if key.isdigit():
        return species.get(str(int(key)), "")
    number, _, name = key.partition("_")
    if number.isdigit() and name:
        return species.get(str(int(number)), key)
    return species.get(key, key if "_" in key else "")


def _package_cries(source: Path | None, dry_run: bool) -> tuple[dict[str, str], list[str]]:
    species = _species_slugs()
    unmatched: list[str] = []
    if source is not None and source.is_dir():
        for path in sorted(source.iterdir()):
            if path.suffix.lower() not in CRY_EXTENSIONS:
                continue
            slug = _cry_slug(path.stem, species)
            if not slug:
                unmatched.append(path.name)
                continue
            destination = CRIES_ROOT / (slug + path.suffix.lower())
            if not dry_run:
                CRIES_ROOT.mkdir(parents=True, exist_ok=True)
                if not destination.exists() or _sha256(destination) != _sha256(path):
                    shutil.copy2(path, destination)
    cries: dict[str, str] = {}
    if CRIES_ROOT.is_dir():
        for path in sorted(CRIES_ROOT.iterdir()):
            if path.suffix.lower() in CRY_EXTENSIONS:
                cries[path.stem] = "res://" + path.relative_to(PROJECT_ROOT).as_posix()
    return cries, unmatched


def _status_sounds(folder: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not folder.is_dir():
        return out
    for path in sorted(folder.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, ValueError):
            continue
        found = _first_sound(data)
        if found:
            out[path.stem] = found
    return out


def _first_sound(node: Any) -> str:
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "Sound" and isinstance(value, str) and value:
                return value
            found = _first_sound(value)
            if found:
                return found
    elif isinstance(node, list):
        for item in node:
            found = _first_sound(item)
            if found:
                return found
    return ""


def _presentation_sounds() -> set[str]:
    if not PRESENTATION_MANIFEST.is_file():
        return set()
    data = json.loads(PRESENTATION_MANIFEST.read_text(encoding="utf-8"))
    names: set[str] = set()
    _collect_sounds(data.get("entries", {}), names)
    return names


def _collect_sounds(node: Any, names: set[str]) -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "sound" and isinstance(value, str) and value:
                names.add(value)
            else:
                _collect_sounds(value, names)
    elif isinstance(node, list):
        for item in node:
            _collect_sounds(item, names)


def _cue_names() -> set[str]:
    if not CUE_TABLE.is_file():
        return set()
    data = json.loads(CUE_TABLE.read_text(encoding="utf-8"))
    names: set[str] = set()
    for group in data.values():
        if isinstance(group, dict):
            for value in group.values():
                if isinstance(value, str) and value:
                    names.add(value)
    return names


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def _render_text_report(payload: dict[str, Any]) -> str:
    summary = payload["summary"]
    lines = [
        "PMDEmblem sound asset report",
        f"generated_at: {payload['report']['generated_at']}",
        f"files: {summary['file_count']} copied: {summary['copied_count']} music_included: {summary['music_included']}",
        "categories: " + ", ".join(f"{name}={count}" for name, count in sorted(summary["categories"].items())),
        f"presentation sounds: {summary['presentation_sound_count']} missing: {summary['presentation_missing_count']}",
        f"status sounds: {summary['status_sound_count']} map status sounds: {summary['map_status_sound_count']}",
        f"cries: {summary['cry_count']} unmatched: {len(summary['cry_unmatched'])}",
    ]
    if payload["presentation_missing"]:
        lines.append("missing presentation sounds: " + ", ".join(payload["presentation_missing"]))
    if payload["cue_missing"]:
        lines.append("missing cue sounds: " + ", ".join(payload["cue_missing"]))
    for warning in payload["warnings"]:
        lines.append("warning: " + warning)
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
