from __future__ import annotations

import hashlib
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from xml.etree import ElementTree

from anchor_rules import ANCHORS_FILENAME, decode_state_anchors, pil_available, write_anchor_file


SPRITE_STATE_SOURCES: dict[str, tuple[str, ...]] = {
    "idle": ("Idle-Anim.png",),
    "walk": ("Walk-Anim.png",),
    "hurt": ("Hurt-Anim.png",),
    "sleep": ("Sleep-Anim.png", "Laying-Anim.png", "EventSleep-Anim.png"),
    "hop": ("Hop-Anim.png",),
}

SOURCE_STATE_TO_RUNTIME_KEY: dict[str, str] = {
    "Idle": "idle",
    "Walk": "walk",
    "Hurt": "hurt",
    "Sleep": "sleep",
    "Laying": "laying",
    "EventSleep": "event_sleep",
    "Hop": "hop",
    "Faint": "faint",
    "Attack": "attack",
}

ABSENT_FRAME_MARKER: int = -1
ANIM_STATES_SCHEMA_VERSION: int = 2


@dataclass(frozen=True)
class CopyResult:
    source: Path | None
    destination: Path
    res_path: str
    checksum: str
    copied: bool
    missing: bool


def project_slug(dex_number: int, slug: str) -> str:
    return f"{dex_number:04d}_{slug}"


def generation_from_dex(dex_number: int) -> int:
    if dex_number <= 151:
        return 1
    if dex_number <= 251:
        return 2
    if dex_number <= 386:
        return 3
    if dex_number <= 493:
        return 4
    if dex_number <= 649:
        return 5
    if dex_number <= 721:
        return 6
    if dex_number <= 809:
        return 7
    if dex_number <= 905:
        return 8
    return 9


def to_res_path(project_root: Path, path: Path) -> str:
    return "res://" + path.resolve().relative_to(project_root.resolve()).as_posix()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def candidate_asset_dirs(base: Path, dex_number: int, form_index: int = 0) -> list[Path]:
    dex = f"{dex_number:04d}"
    form = f"{form_index:04d}"
    root = base / dex
    candidates = [
        root,
        root / form,
        root / form / "0001",
        root / "0000",
        root / "0000" / "0001",
    ]
    seen: set[Path] = set()
    out: list[Path] = []
    for candidate in candidates:
        if candidate not in seen:
            out.append(candidate)
            seen.add(candidate)
    return out


def candidate_variant_dirs(base: Path, dex_number: int, form_index: int = 0, shiny: bool = False, female: bool = False) -> list[Path]:
    dex = f"{dex_number:04d}"
    form = f"{form_index:04d}"
    root = base / dex
    shiny_dir = "0001" if shiny else "0000"
    candidates: list[Path] = []
    for form_dir in (form, "0000"):
        if female:
            candidates.append(root / form_dir / shiny_dir / "0002")
        elif shiny:
            candidates.append(root / form_dir / "0001")
    seen: set[Path] = set()
    out: list[Path] = []
    for candidate in candidates:
        if candidate not in seen:
            seen.add(candidate)
            out.append(candidate)
    return out


def candidate_shiny_dirs(base: Path, dex_number: int, form_index: int = 0) -> list[Path]:
    return candidate_variant_dirs(base, dex_number, form_index, shiny=True)


def find_first_complete_sprite_dir(base: Path, dex_number: int, form_index: int = 0, shiny: bool = False, female: bool = False) -> Path | None:
    for candidate in (candidate_variant_dirs(base, dex_number, form_index, shiny, female) if (shiny or female) else candidate_asset_dirs(base, dex_number, form_index)):
        if not candidate.is_dir():
            continue
        if (candidate / "AnimData.xml").exists() and _has_required_sprite_sources(candidate):
            return candidate
    return None


def find_first_portrait_dir(base: Path, dex_number: int, form_index: int = 0, shiny: bool = False, female: bool = False) -> Path | None:
    for candidate in (candidate_variant_dirs(base, dex_number, form_index, shiny, female) if (shiny or female) else candidate_asset_dirs(base, dex_number, form_index)):
        if (candidate / "Normal.png").exists():
            return candidate
    return None


def copy_sprite_set(
    *,
    project_root: Path,
    source_dir: Path | None,
    destination_dir: Path,
    credits_source_dir: Path | None = None,
    dry_run: bool,
) -> tuple[dict[str, Any], dict[str, str], list[str], list[CopyResult]]:
    assets: dict[str, Any] = {}
    checksums: dict[str, str] = {}
    warnings: list[str] = []
    copies: list[CopyResult] = []
    substitutions: dict[str, str] = {}

    for state, source_names in SPRITE_STATE_SOURCES.items():
        source = _find_source(source_dir, source_names) if source_dir is not None else None
        if source is None and state == "idle":
            source = _find_source(source_dir, SPRITE_STATE_SOURCES["walk"]) if source_dir is not None else None
            if source is not None:
                substitutions["idle"] = "idle_static_from_walk"
        destination_state = "walk" if state == "idle" and substitutions.get("idle") == "idle_static_from_walk" else state
        destination = destination_dir / "animations" / f"{destination_state}.png"
        result = _copy_optional(project_root, source, destination, dry_run)
        copies.append(result)
        assets[state] = result.res_path
        if result.source is not None:
            checksums[state] = result.checksum
        if result.missing:
            warnings.append(f"missing sprite state {state}")

    source = source_dir / "AnimData.xml" if source_dir is not None and (source_dir / "AnimData.xml").exists() else None
    destination = destination_dir / "AnimData.xml"
    result = _copy_optional(project_root, source, destination, dry_run)
    copies.append(result)
    assets["anim_data"] = result.res_path
    if result.source is not None:
        checksums["anim_data"] = result.checksum
    if result.missing:
        warnings.append("missing AnimData.xml")

    if substitutions:
        assets["sprite_substitutions"] = substitutions

    return assets, checksums, warnings, copies


def copy_expanded_animation_states(
    *,
    project_root: Path,
    source_dir: Path | None,
    destination_dir: Path,
    dry_run: bool,
    decode_anchors: bool = True,
    source_repo: str = "RawAsset",
    source_rel_dir: str = "",
    source_revision: str = "",
) -> tuple[dict[str, dict[str, object]], dict[str, str], list[str], list[CopyResult], dict[str, Any]]:
    states: dict[str, dict[str, object]] = {}
    checksums: dict[str, str] = {}
    warnings: list[str] = []
    copies: list[CopyResult] = []
    extras: dict[str, Any] = {"schema_version": ANIM_STATES_SCHEMA_VERSION}

    if source_dir is None:
        warnings.append("missing source animation directory")
        return states, checksums, warnings, copies, extras

    anim_files = sorted(
        path
        for path in source_dir.glob("*-Anim.png")
        if path.is_file() and not path.name.startswith(".")
    )
    if not anim_files:
        warnings.append("no expanded animation states discovered")
        return states, checksums, warnings, copies, extras

    root_data = parse_anim_root(source_dir / "AnimData.xml")
    metadata_by_source: dict[str, dict[str, object]] = root_data["anims"]
    extras["shadow_size"] = int(root_data.get("shadow_size", 0))
    physical_by_source: dict[str, dict[str, object]] = {}
    key_owner: dict[str, str] = {}
    for source in anim_files:
        source_name = source.name.removesuffix("-Anim.png")
        state_key = runtime_state_key(source_name)
        if state_key in key_owner and key_owner[state_key] != source_name:
            warnings.append(f"animation state key collision {state_key}: {key_owner[state_key]} and {source_name}")
        destination = destination_dir / "animations" / f"{state_key}.png"
        result = _copy_optional(project_root, source, destination, dry_run)
        copies.append(result)
        if result.source is None:
            warnings.append(f"missing expanded animation state {source_name}")
            continue
        checksums[f"animation:{state_key}"] = result.checksum
        entry: dict[str, object] = {
            "path": result.res_path,
            "source_name": source_name,
            "source_filename": source.name,
            "checksum": result.checksum,
            "alias_only": False,
            "metadata": metadata_by_source.get(source_name, {}),
        }
        states[state_key] = entry
        physical_by_source[source_name] = entry
        key_owner[state_key] = source_name

    for source_name, metadata in metadata_by_source.items():
        copy_of = str(metadata.get("copy_of", ""))
        if not copy_of or source_name in physical_by_source:
            continue
        target_name, chain_error = resolve_copy_chain(source_name, metadata_by_source)
        if chain_error:
            warnings.append(chain_error)
            continue
        target_entry = physical_by_source.get(target_name)
        if target_entry is None:
            warnings.append(f"alias {source_name} resolves to {target_name} which has no sheet")
            continue
        state_key = runtime_state_key(source_name)
        if state_key in states:
            warnings.append(f"alias {source_name} collides with existing state key {state_key}")
            continue
        alias_metadata = dict(target_entry["metadata"])
        alias_metadata["index"] = int(metadata.get("index", ABSENT_FRAME_MARKER))
        alias_metadata["copy_of"] = copy_of
        states[state_key] = {
            "path": target_entry["path"],
            "source_name": source_name,
            "source_filename": str(target_entry["source_filename"]),
            "checksum": str(target_entry["checksum"]),
            "alias_only": True,
            "alias_target": target_name,
            "metadata": alias_metadata,
        }

    if decode_anchors:
        if not pil_available():
            warnings.append("anchor decoding skipped: Pillow unavailable")
        else:
            anchor_states: dict[str, Any] = {}
            for source_name, entry in physical_by_source.items():
                metadata = entry["metadata"]
                decoded = decode_state_anchors(
                    source_dir,
                    source_name,
                    int(metadata.get("frame_width", 0)),
                    int(metadata.get("frame_height", 0)),
                )
                if decoded is None:
                    warnings.append(f"anchor sidecars unreadable for {source_name}")
                    continue
                anchor_states[source_name] = decoded
            if anchor_states:
                anchor_result = write_anchor_file(
                    destination=destination_dir / ANCHORS_FILENAME,
                    states=anchor_states,
                    shadow_size=int(root_data.get("shadow_size", 0)),
                    source_repo=source_repo,
                    source_dir=source_rel_dir,
                    source_revision=source_revision,
                    dry_run=dry_run,
                )
                extras["anchors"] = to_res_path(project_root, anchor_result["path"])
                extras["anchor_state_count"] = int(anchor_result["state_count"])

    return states, checksums, warnings, copies, extras


def resolve_copy_chain(source_name: str, metadata_by_source: dict[str, dict[str, object]]) -> tuple[str, str]:
    seen: list[str] = [source_name]
    current = source_name
    while True:
        metadata = metadata_by_source.get(current)
        if metadata is None:
            return current, f"alias chain from {source_name} references unknown state {current}"
        copy_of = str(metadata.get("copy_of", ""))
        if not copy_of:
            return current, ""
        if copy_of in seen:
            return current, f"alias chain from {source_name} is cyclic at {copy_of}"
        seen.append(copy_of)
        current = copy_of


def copy_portrait(
    *,
    project_root: Path,
    source_dir: Path | None,
    destination_dir: Path,
    credits_source_dir: Path | None = None,
    dry_run: bool,
) -> tuple[dict[str, Any], dict[str, str], list[str], list[CopyResult]]:
    assets: dict[str, Any] = {}
    checksums: dict[str, str] = {}
    warnings: list[str] = []
    copies: list[CopyResult] = []
    expressions: dict[str, str] = {}

    if source_dir is not None:
        for source in sorted(source_dir.glob("*.png")):
            if not source.is_file() or source.name.startswith("."):
                continue
            destination = destination_dir / source.name
            result = _copy_optional(project_root, source, destination, dry_run)
            copies.append(result)
            expression = source.stem
            expressions[expression] = result.res_path
            checksums[f"portrait:{expression}"] = result.checksum
            if expression == "Normal":
                assets["portrait_normal"] = result.res_path
                checksums["portrait_normal"] = result.checksum

    if expressions:
        assets["portrait_expressions"] = expressions
    if "portrait_normal" not in assets:
        warnings.append("missing Normal portrait")

    return assets, checksums, warnings, copies


def read_credit_text(source_dir: Path | None, fallback_dir: Path | None = None) -> str:
    credits_dir = source_dir if source_dir is not None and (source_dir / "credits.txt").exists() else fallback_dir
    credits = credits_dir / "credits.txt" if credits_dir is not None and (credits_dir / "credits.txt").exists() else None
    if credits is None:
        return ""
    return credits.read_text(encoding="utf-8", errors="replace").strip()


def _has_required_sprite_sources(candidate: Path) -> bool:
    for state, names in SPRITE_STATE_SOURCES.items():
        source = _find_source(candidate, names)
        if source is not None:
            continue
        if state == "idle" and _find_source(candidate, SPRITE_STATE_SOURCES["walk"]) is not None:
            continue
        return False
    return True


def _find_source(source_dir: Path | None, source_names: tuple[str, ...]) -> Path | None:
    if source_dir is None:
        return None
    for name in source_names:
        candidate = source_dir / name
        if candidate.exists():
            return candidate
    return None


def runtime_state_key(source_name: str) -> str:
    if source_name in SOURCE_STATE_TO_RUNTIME_KEY:
        return SOURCE_STATE_TO_RUNTIME_KEY[source_name]
    with_separators = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", source_name)
    normalized = re.sub(r"[^A-Za-z0-9]+", "_", with_separators).strip("_").lower()
    return normalized or source_name.lower()


def parse_anim_data(path: Path) -> dict[str, dict[str, object]]:
    return parse_anim_root(path)["anims"]


def parse_anim_root(path: Path) -> dict[str, Any]:
    out: dict[str, Any] = {"shadow_size": 0, "anims": {}}
    if not path.exists():
        return out
    try:
        root = ElementTree.parse(path).getroot()
    except ElementTree.ParseError:
        return out

    out["shadow_size"] = _child_int(root, "ShadowSize", 0)
    anims: dict[str, dict[str, object]] = {}
    for anim in root.findall("./Anims/Anim"):
        name = _child_text(anim, "Name")
        if not name:
            continue
        durations = [
            int(duration.text or 0)
            for duration in anim.findall("./Durations/Duration")
            if (duration.text or "").strip().lstrip("-").isdigit()
        ]
        anims[name] = {
            "index": _child_int(anim, "Index", ABSENT_FRAME_MARKER),
            "copy_of": _child_text(anim, "CopyOf"),
            "frame_width": _child_int(anim, "FrameWidth"),
            "frame_height": _child_int(anim, "FrameHeight"),
            "rush_frame": _child_int(anim, "RushFrame", ABSENT_FRAME_MARKER),
            "hit_frame": _child_int(anim, "HitFrame", ABSENT_FRAME_MARKER),
            "return_frame": _child_int(anim, "ReturnFrame", ABSENT_FRAME_MARKER),
            "durations": durations,
            "frame_count": len(durations),
        }
    out["anims"] = anims
    return out


def _child_text(parent: ElementTree.Element, tag: str) -> str:
    child = parent.find(tag)
    if child is None or child.text is None:
        return ""
    return child.text.strip()


def _child_int(parent: ElementTree.Element, tag: str, default: int = 0) -> int:
    text = _child_text(parent, tag)
    if not text or not text.lstrip("-").isdigit():
        return default
    return int(text)


def _copy_optional(project_root: Path, source: Path | None, destination: Path, dry_run: bool) -> CopyResult:
    res_path = to_res_path(project_root, destination)
    if source is None:
        return CopyResult(None, destination, res_path, "", False, True)
    checksum = sha256(source)
    copied = False
    if not dry_run:
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or sha256(destination) != checksum:
            shutil.copy2(source, destination)
            copied = True
    return CopyResult(source, destination, res_path, checksum, copied, False)
