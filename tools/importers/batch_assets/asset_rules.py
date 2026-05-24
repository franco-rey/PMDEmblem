from __future__ import annotations

import hashlib
import shutil
from dataclasses import dataclass
from pathlib import Path


SPRITE_STATE_SOURCES: dict[str, tuple[str, ...]] = {
    "idle": ("Idle-Anim.png",),
    "walk": ("Walk-Anim.png",),
    "hurt": ("Hurt-Anim.png",),
    "sleep": ("Laying-Anim.png", "EventSleep-Anim.png", "Sleep-Anim.png"),
    "hop": ("Hop-Anim.png",),
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
        if (candidate / "AnimData.xml").exists() and all(_find_source(candidate, names) for names in SPRITE_STATE_SOURCES.values()):
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
) -> tuple[dict[str, str], dict[str, str], list[str], list[CopyResult]]:
    assets: dict[str, str] = {}
    checksums: dict[str, str] = {}
    warnings: list[str] = []
    copies: list[CopyResult] = []

    for state, source_names in SPRITE_STATE_SOURCES.items():
        source = _find_source(source_dir, source_names) if source_dir is not None else None
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

    return assets, checksums, warnings, copies


def copy_portrait(
    *,
    project_root: Path,
    source_dir: Path | None,
    destination_dir: Path,
    credits_source_dir: Path | None = None,
    dry_run: bool,
) -> tuple[dict[str, str], dict[str, str], list[str], list[CopyResult]]:
    assets: dict[str, str] = {}
    checksums: dict[str, str] = {}
    warnings: list[str] = []
    copies: list[CopyResult] = []

    source = source_dir / "Normal.png" if source_dir is not None and (source_dir / "Normal.png").exists() else None
    destination = destination_dir / "Normal.png"
    result = _copy_optional(project_root, source, destination, dry_run)
    copies.append(result)
    if result.source is not None:
        assets["portrait_normal"] = result.res_path
        checksums["portrait_normal"] = result.checksum
    else:
        warnings.append("missing Normal portrait")

    credits_dir = source_dir if source_dir is not None and (source_dir / "credits.txt").exists() else credits_source_dir
    credits = credits_dir / "credits.txt" if credits_dir is not None and (credits_dir / "credits.txt").exists() else None
    if credits is not None:
        result = _copy_optional(project_root, credits, destination_dir / "credits.txt", dry_run)
        copies.append(result)
        assets["portrait_credits"] = result.res_path
        checksums["portrait_credits"] = result.checksum

    return assets, checksums, warnings, copies


def _find_source(source_dir: Path | None, source_names: tuple[str, ...]) -> Path | None:
    if source_dir is None:
        return None
    for name in source_names:
        candidate = source_dir / name
        if candidate.exists():
            return candidate
    return None


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
