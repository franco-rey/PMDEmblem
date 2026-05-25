from __future__ import annotations

import hashlib
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from xml.etree import ElementTree


SPRITE_STATE_SOURCES: dict[str, tuple[str, ...]] = {
    "idle": ("Idle-Anim.png",),
    "walk": ("Walk-Anim.png",),
    "hurt": ("Hurt-Anim.png",),
    "sleep": ("Laying-Anim.png", "EventSleep-Anim.png", "Sleep-Anim.png"),
    "hop": ("Hop-Anim.png",),
}

SOURCE_STATE_TO_RUNTIME_KEY: dict[str, str] = {
    "Idle": "idle",
    "Walk": "walk",
    "Hurt": "hurt",
    "Sleep": "sleep",
    "Laying": "sleep",
    "EventSleep": "sleep",
    "Hop": "hop",
    "Faint": "faint",
    "Attack": "attack",
}


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


def find_first_complete_sprite_dir(base: Path, dex_number: int, form_index: int = 0) -> Path | None:
    for candidate in candidate_asset_dirs(base, dex_number, form_index):
        if not candidate.is_dir():
            continue
        if (candidate / "AnimData.xml").exists() and _has_required_sprite_sources(candidate):
            return candidate
    return None


def find_first_portrait_dir(base: Path, dex_number: int, form_index: int = 0) -> Path | None:
    for candidate in candidate_asset_dirs(base, dex_number, form_index):
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
        destination = destination_dir / f"{state}.png"
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

    credits_dir = source_dir if source_dir is not None and (source_dir / "credits.txt").exists() else credits_source_dir
    credits = credits_dir / "credits.txt" if credits_dir is not None and (credits_dir / "credits.txt").exists() else None
    if credits is not None:
        result = _copy_optional(project_root, credits, destination_dir / "credits.txt", dry_run)
        copies.append(result)
        assets["sprite_credits"] = result.res_path
        checksums["sprite_credits"] = result.checksum

    if substitutions:
        assets["sprite_substitutions"] = substitutions

    return assets, checksums, warnings, copies


def copy_expanded_animation_states(
    *,
    project_root: Path,
    source_dir: Path | None,
    destination_dir: Path,
    dry_run: bool,
) -> tuple[dict[str, dict[str, object]], dict[str, str], list[str], list[CopyResult]]:
    states: dict[str, dict[str, object]] = {}
    checksums: dict[str, str] = {}
    warnings: list[str] = []
    copies: list[CopyResult] = []

    if source_dir is None:
        warnings.append("missing source animation directory")
        return states, checksums, warnings, copies

    anim_files = sorted(
        path
        for path in source_dir.glob("*-Anim.png")
        if path.is_file() and not path.name.startswith(".")
    )
    if not anim_files:
        warnings.append("no expanded animation states discovered")
        return states, checksums, warnings, copies

    metadata_by_source = parse_anim_data(source_dir / "AnimData.xml")
    for source in anim_files:
        source_name = source.name.removesuffix("-Anim.png")
        state_key = runtime_state_key(source_name)
        destination = destination_dir / "animations" / f"{state_key}.png"
        result = _copy_optional(project_root, source, destination, dry_run)
        copies.append(result)
        if result.source is None:
            warnings.append(f"missing expanded animation state {source_name}")
            continue
        checksums[f"animation:{state_key}"] = result.checksum
        states[state_key] = {
            "path": result.res_path,
            "source_name": source_name,
            "source_filename": source.name,
            "checksum": result.checksum,
            "metadata": metadata_by_source.get(source_name, {}),
        }

    return states, checksums, warnings, copies


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

    credits_dir = source_dir if source_dir is not None and (source_dir / "credits.txt").exists() else credits_source_dir
    credits = credits_dir / "credits.txt" if credits_dir is not None and (credits_dir / "credits.txt").exists() else None
    if credits is not None:
        result = _copy_optional(project_root, credits, destination_dir / "credits.txt", dry_run)
        copies.append(result)
        assets["portrait_credits"] = result.res_path
        checksums["portrait_credits"] = result.checksum

    return assets, checksums, warnings, copies


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
    if not path.exists():
        return {}
    try:
        root = ElementTree.parse(path).getroot()
    except ElementTree.ParseError:
        return {}

    out: dict[str, dict[str, object]] = {}
    for anim in root.findall("./Anims/Anim"):
        name = _child_text(anim, "Name")
        if not name:
            continue
        durations = [
            int(duration.text or 0)
            for duration in anim.findall("./Durations/Duration")
            if (duration.text or "").strip().lstrip("-").isdigit()
        ]
        out[name] = {
            "index": _child_int(anim, "Index"),
            "copy_of": _child_text(anim, "CopyOf"),
            "frame_width": _child_int(anim, "FrameWidth"),
            "frame_height": _child_int(anim, "FrameHeight"),
            "rush_frame": _child_int(anim, "RushFrame"),
            "hit_frame": _child_int(anim, "HitFrame"),
            "return_frame": _child_int(anim, "ReturnFrame"),
            "durations": durations,
            "frame_count": len(durations),
        }
    return out


def _child_text(parent: ElementTree.Element, tag: str) -> str:
    child = parent.find(tag)
    if child is None or child.text is None:
        return ""
    return child.text.strip()


def _child_int(parent: ElementTree.Element, tag: str) -> int:
    text = _child_text(parent, tag)
    if not text or not text.lstrip("-").isdigit():
        return 0
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
