from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from asset_rules import (
    copy_expanded_animation_states,
    copy_portrait,
    copy_sprite_set,
    find_first_complete_sprite_dir,
    find_first_portrait_dir,
    generation_from_dex,
    project_slug,
    read_credit_text,
    _has_required_sprite_sources,
)
from manifest import MANIFEST_PATH, REPORT_JSON_PATH, render_text_report, write_json
from source_config import PROJECT_ROOT, load_config


DEFAULT_DEX_RANGE = (1, 721)
LEVEL_FOR_DEFAULT_MOVES = 50
FALLBACK_ICON_PATH = "res://assets/textures/ui/icons/icon.png"
PREFLIGHT_TEXT_PATH = Path("data/models/pokemon/import_reports/pokemon_batch_preflight_report.txt")


def main() -> int:
    args = _parse_args()
    if not args.dry_run and not args.write:
        args.dry_run = True

    sources = load_config(args)
    errors = _validate_sources(sources)
    if errors:
        for error in errors:
            print(f"error: {error}")
        return 2

    only = _parse_only(args.only)
    generations = _parse_generations(args.generations)
    dex_min, dex_max = _parse_dex_range(args.dex_range)
    filtered = bool(only) or args.limit > 0 or (dex_min, dex_max) != DEFAULT_DEX_RANGE or generations != list(range(1, 7))
    if args.write and filtered and not args.merge and not args.replace_manifest:
        print("error: a filtered --write replaces the full roster manifest; pass --merge to update only the selected entries or --replace-manifest to overwrite")
        return 2
    if args.merge and args.replace_manifest:
        print("error: --merge and --replace-manifest are mutually exclusive")
        return 2

    entries = _discover_entries(sources, only, generations, dex_min, dex_max)
    excluded_unreleased = _discover_excluded_unreleased(sources, only, generations, dex_min, dex_max)
    if args.limit > 0:
        entries = entries[: args.limit]

    manifest_species: list[dict[str, Any]] = []
    for entry in entries:
        manifest_species.append(_package_entry(entry, sources, dry_run=args.dry_run, source_revision=args.source_revision))

    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    payload = {
        "schema_version": 1,
        "generated_at": generated_at,
        "mode": "dry_run" if args.dry_run else "write",
        "target": {
            "generations": generations,
            "dex_min": dex_min,
            "dex_max": dex_max,
            "released_only": True,
            "only": sorted(only),
            "limit": args.limit,
            "excluded_unreleased": excluded_unreleased,
        },
        "species": manifest_species,
    }

    if args.merge:
        existing = _load_existing_manifest(PROJECT_ROOT / MANIFEST_PATH)
        payload = _merge_manifest(existing, manifest_species)
        print(_merge_summary_line(existing, manifest_species, args.dry_run))
    print(_summary_line(manifest_species, args.dry_run))
    if args.diff_manifest:
        _print_manifest_diff(_load_existing_manifest(PROJECT_ROOT / MANIFEST_PATH), manifest_species)

    report = {
        "schema_version": 1,
        "generated_at": generated_at,
        "source": "pokemon_batch_packager",
        "summary": _summary(payload["species"]),
        "excluded_unreleased": payload["target"].get("excluded_unreleased", excluded_unreleased),
        "species": payload["species"],
    }

    if args.write:
        if args.merge:
            _merge_consolidated_credits(entries, sources)
        else:
            _write_consolidated_credits(entries, sources, payload["generated_at"])
        write_json(PROJECT_ROOT / MANIFEST_PATH, payload)
        print(f"wrote {MANIFEST_PATH}")
        if not args.merge:
            write_json(PROJECT_ROOT / REPORT_JSON_PATH, report)
            print(f"wrote {REPORT_JSON_PATH}")
        report_txt = PROJECT_ROOT / PREFLIGHT_TEXT_PATH
        report_txt.parent.mkdir(parents=True, exist_ok=True)
        report_txt.write_text(render_text_report(payload), encoding="utf-8")
        print(f"wrote {PREFLIGHT_TEXT_PATH}")
    return 0


def _load_existing_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as handle:
        loaded = json.load(handle)
    return loaded if isinstance(loaded, dict) else {}


def _merge_manifest(existing: dict[str, Any], species: list[dict[str, Any]]) -> dict[str, Any]:
    merged = dict(existing) if existing else {"schema_version": 1, "target": {}, "species": []}
    by_slug: dict[str, dict[str, Any]] = {}
    for entry in merged.get("species", []):
        if isinstance(entry, dict) and entry.get("slug"):
            by_slug[str(entry["slug"])] = entry
    for entry in species:
        by_slug[str(entry["slug"])] = entry
    merged_species = sorted(by_slug.values(), key=lambda item: (int(item.get("dex_number", 0)), str(item.get("pmdo_slug", ""))))
    merged["species"] = merged_species
    merged["mode"] = "write"
    merged.setdefault("schema_version", 1)
    merged.setdefault("generated_at", datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"))
    merged.setdefault("target", {})
    return merged


def _merge_summary_line(existing: dict[str, Any], species: list[dict[str, Any]], dry_run: bool) -> str:
    existing_slugs = {str(entry.get("slug", "")) for entry in existing.get("species", []) if isinstance(entry, dict)}
    updated = [str(entry["slug"]) for entry in species if str(entry["slug"]) in existing_slugs]
    added = [str(entry["slug"]) for entry in species if str(entry["slug"]) not in existing_slugs]
    preserved = len(existing_slugs) - len(updated)
    mode = "dry-run" if dry_run else "write"
    return "manifest merge %s: existing=%d updated=%d added=%d preserved=%d" % (mode, len(existing_slugs), len(updated), len(added), preserved)


def _print_manifest_diff(existing: dict[str, Any], species: list[dict[str, Any]]) -> None:
    by_slug: dict[str, dict[str, Any]] = {}
    for entry in existing.get("species", []):
        if isinstance(entry, dict) and entry.get("slug"):
            by_slug[str(entry["slug"])] = entry
    for entry in species:
        slug = str(entry["slug"])
        before = by_slug.get(slug)
        if before is None:
            print(f"diff {slug}: new entry")
            continue
        before_states = set((before.get("assets", {}) or {}).get("animation_states", {}).keys())
        after_states = set((entry.get("assets", {}) or {}).get("animation_states", {}).keys())
        added = sorted(after_states - before_states)
        removed = sorted(before_states - after_states)
        before_checks = before.get("checksums", {}) or {}
        after_checks = entry.get("checksums", {}) or {}
        changed = sorted(key for key in after_checks if key in before_checks and before_checks[key] != after_checks[key])
        top_level = sorted(key for key in entry if key not in ("assets", "checksums", "warnings") and before.get(key) != entry.get(key))
        print(f"diff {slug}: states+{added} states-{removed} checksums~{changed} fields~{top_level} warnings={entry.get('warnings', [])}")


def _credit_entries_from_species(species: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for entry in species:
        out.append({
            "slug": str(entry.get("slug", "")),
            "pmdo_slug": str(entry.get("pmdo_slug", "")),
            "dex_number": int(entry.get("dex_number", 0)),
            "display_name": str(entry.get("display_name", "")),
            "default_form_index": int(entry.get("default_form_index", 0)),
        })
    return out


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare PMD Pokemon assets for PMDEmblem batch imports.")
    parser.add_argument("--pmdo-root", dest="pmdo_root")
    parser.add_argument("--raw-asset-root", dest="raw_asset_root")
    parser.add_argument("--sprite-collab-root", dest="sprite_collab_root")
    parser.add_argument("--generations", default="1-6", help="Comma/range list, e.g. 1-6 or 1,3,5")
    parser.add_argument("--dex-range", default=f"{DEFAULT_DEX_RANGE[0]}-{DEFAULT_DEX_RANGE[1]}")
    parser.add_argument("--only", default="", help="Comma-separated bare or project slugs.")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--merge", action="store_true", help="Update only the selected entries inside the existing full manifest/report.")
    parser.add_argument("--replace-manifest", action="store_true", help="Overwrite the manifest with only the selected entries (legacy behavior).")
    parser.add_argument("--diff-manifest", action="store_true", help="Print per-entry differences against the existing manifest.")
    parser.add_argument("--source-revision", default="", help="Source repository revision recorded in per-actor anchor files.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


def _validate_sources(sources: Any) -> list[str]:
    checks = [
        (sources.monster_dir, "PMDODump Monster dir"),
        (sources.skill_dir, "PMDODump Skill dir"),
        (sources.universal_path, "PMDODump Universal.json"),
        (sources.raw_sprite_dir, "RawAsset Sprite dir"),
        (sources.raw_portrait_dir, "RawAsset Portrait dir"),
    ]
    errors = []
    for path, label in checks:
        if not path.exists():
            errors.append(f"{label} missing at {path}")
    return errors


def _discover_entries(sources: Any, only: set[str], generations: list[int], dex_min: int, dex_max: int) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for path in sorted(sources.monster_dir.glob("*.json")):
        raw = _load_json(path)
        obj = raw.get("Object", {}) if isinstance(raw, dict) else {}
        if not isinstance(obj, dict):
            continue
        dex = int(obj.get("IndexNum", 0) or 0)
        bare_slug = path.stem
        pslug = project_slug(dex, bare_slug)
        national_generation = generation_from_dex(dex)
        if only and bare_slug not in only and pslug not in only:
            continue
        if dex < dex_min or dex > dex_max:
            continue
        if national_generation not in generations:
            continue
        if not bool(obj.get("Released", True)):
            continue
        forms = obj.get("Forms", [])
        if not isinstance(forms, list) or not forms:
            continue
        default_form_index = _default_form_index(forms)
        form = forms[default_form_index] if isinstance(forms[default_form_index], dict) else {}
        out.append({
            "pmdo_slug": bare_slug,
            "slug": pslug,
            "dex_number": dex,
            "display_name": _localized(obj.get("Name", {})) or bare_slug.capitalize(),
            "generation": national_generation,
            "released": True,
            "default_form_index": default_form_index,
            "monster_json_abs": str(path),
            "monster_json": f"DumpAsset/Data/Monster/{path.name}",
            "form": form,
            "forms": [
                {
                    "index": form_i,
                    "name": _localized(form_d.get("FormName", {})) if isinstance(form_d, dict) else "",
                    "temporary": bool(form_d.get("Temporary", False)) if isinstance(form_d, dict) else False,
                    "released": bool(form_d.get("Released", True)) if isinstance(form_d, dict) else True,
                }
                for form_i, form_d in enumerate(forms)
            ],
            "level_skills": _level_skills(form),
        })
    out.sort(key=lambda item: (int(item["dex_number"]), str(item["pmdo_slug"])))
    return out


def _write_consolidated_credits(entries: list[dict[str, Any]], sources: Any, generated_at: str) -> None:
    actor_blocks: list[str] = []
    portrait_blocks: list[str] = []
    for entry in entries:
        dex = int(entry["dex_number"])
        slug = str(entry["slug"])
        form_index = int(entry["default_form_index"])
        sprite_source = find_first_complete_sprite_dir(sources.raw_sprite_dir, dex, form_index)
        portrait_source = find_first_portrait_dir(sources.raw_portrait_dir, dex, form_index)
        sprite_collab_source = find_first_complete_sprite_dir(sources.sprite_collab_sprite_dir, dex, form_index) if sources.sprite_collab_sprite_dir else None
        portrait_collab_source = find_first_portrait_dir(sources.sprite_collab_portrait_dir, dex, form_index) if sources.sprite_collab_portrait_dir else None
        actor_blocks.append(_credit_block(entry, "actor", sprite_source, sprite_collab_source, sources))
        portrait_blocks.append(_credit_block(entry, "portrait", portrait_source, portrait_collab_source, sources))

    output = [
        "Pokemon Texture Credits",
        "=======================",
        f"Generated: {generated_at}",
        "",
        "Actor Sprites",
        "-------------",
        *actor_blocks,
        "",
        "Portraits",
        "---------",
        *portrait_blocks,
        "",
    ]
    path = PROJECT_ROOT / "assets/textures/credits.txt"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(output), encoding="utf-8")


def _merge_consolidated_credits(entries: list[dict[str, Any]], sources: Any) -> None:
    path = PROJECT_ROOT / "assets/textures/credits.txt"
    if not path.exists():
        _write_consolidated_credits(entries, sources, datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"))
        return
    lines = path.read_text(encoding="utf-8").split("\n")
    replacements: dict[str, list[str]] = {}
    for entry in entries:
        dex = int(entry["dex_number"])
        form_index = int(entry["default_form_index"])
        sprite_source = find_first_complete_sprite_dir(sources.raw_sprite_dir, dex, form_index)
        portrait_source = find_first_portrait_dir(sources.raw_portrait_dir, dex, form_index)
        sprite_collab_source = find_first_complete_sprite_dir(sources.sprite_collab_sprite_dir, dex, form_index) if sources.sprite_collab_sprite_dir else None
        portrait_collab_source = find_first_portrait_dir(sources.sprite_collab_portrait_dir, dex, form_index) if sources.sprite_collab_portrait_dir else None
        for label, source_dir, fallback_dir in (("actor", sprite_source, sprite_collab_source), ("portrait", portrait_source, portrait_collab_source)):
            block = _credit_block(entry, label, source_dir, fallback_dir, sources).split("\n")
            replacements[block[0]] = block
    out: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if line in replacements:
            block = [entry_line for entry_line in replacements[line] if entry_line != ""]
            out.extend(block)
            index += 1
            while index < len(lines) and lines[index] != "":
                index += 1
            continue
        out.append(line)
        index += 1
    path.write_text("\n".join(out), encoding="utf-8")


def _credit_block(entry: dict[str, Any], label: str, source_dir: Path | None, fallback_dir: Path | None, sources: Any) -> str:
    use_source = source_dir is not None and (source_dir / "credits.txt").exists()
    chosen_dir = source_dir if use_source else fallback_dir
    source_root = sources.raw_asset_root if use_source else sources.sprite_collab_root
    source = _source_rel(source_root, chosen_dir)
    credit_text = read_credit_text(source_dir, fallback_dir) or "No source credits found."
    return "\n".join([
        f"[{entry.get('slug', '?')}] {entry.get('display_name', '?')} ({label})",
        f"source: {source}",
        credit_text,
        "",
    ])


def _discover_excluded_unreleased(sources: Any, only: set[str], generations: list[int], dex_min: int, dex_max: int) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for path in sorted(sources.monster_dir.glob("*.json")):
        raw = _load_json(path)
        obj = raw.get("Object", {}) if isinstance(raw, dict) else {}
        if not isinstance(obj, dict):
            continue
        dex = int(obj.get("IndexNum", 0) or 0)
        bare_slug = path.stem
        pslug = project_slug(dex, bare_slug)
        national_generation = generation_from_dex(dex)
        if only and bare_slug not in only and pslug not in only:
            continue
        if dex < dex_min or dex > dex_max:
            continue
        if national_generation not in generations:
            continue
        if bool(obj.get("Released", True)):
            continue
        out.append({
            "slug": pslug,
            "pmdo_slug": bare_slug,
            "dex_number": dex,
            "display_name": _localized(obj.get("Name", {})) or bare_slug.capitalize(),
            "generation": national_generation,
            "reason": "pmdo_unreleased",
        })
    out.sort(key=lambda item: (int(item["dex_number"]), str(item["pmdo_slug"])))
    return out


def _package_variant(sources: Any, dex: int, form_index: int, slug: str, suffix: str, shiny: bool, female: bool, dry_run: bool, source_revision: str) -> dict[str, Any]:
    return _package_variant_from(
        sources,
        slug,
        suffix,
        find_first_complete_sprite_dir(sources.raw_sprite_dir, dex, form_index, shiny=shiny, female=female),
        find_first_portrait_dir(sources.raw_portrait_dir, dex, form_index, shiny=shiny, female=female),
        find_first_complete_sprite_dir(sources.sprite_collab_sprite_dir, dex, form_index, shiny=shiny, female=female) if sources.sprite_collab_sprite_dir else None,
        find_first_portrait_dir(sources.sprite_collab_portrait_dir, dex, form_index, shiny=shiny, female=female) if sources.sprite_collab_portrait_dir else None,
        dry_run,
        source_revision,
    )


def _package_variant_from(sources: Any, slug: str, suffix: str, sprite_source: Path | None, portrait_source: Path | None, credit_sprite_dir: Path | None, credit_portrait_dir: Path | None, dry_run: bool, source_revision: str) -> dict[str, Any]:
    summary: dict[str, Any] = {"actor": False, "portrait": False}
    if sprite_source is not None:
        dest = PROJECT_ROOT / "assets" / "textures" / "actor" / "pokemon" / f"{slug}{suffix}"
        _assets, _checksums, warnings, _copies = copy_sprite_set(
            project_root=PROJECT_ROOT,
            source_dir=sprite_source,
            destination_dir=dest,
            credits_source_dir=credit_sprite_dir,
            dry_run=dry_run,
        )
        copy_expanded_animation_states(
            project_root=PROJECT_ROOT,
            source_dir=sprite_source,
            destination_dir=dest,
            dry_run=dry_run,
            source_repo="RawAsset",
            source_rel_dir=_source_rel(sources.raw_asset_root, sprite_source),
            source_revision=source_revision,
        )
        summary["actor"] = not any(warning.startswith("missing sprite state") for warning in warnings)
    if portrait_source is not None:
        copy_portrait(
            project_root=PROJECT_ROOT,
            source_dir=portrait_source,
            destination_dir=PROJECT_ROOT / "assets" / "textures" / "pokemon" / "portraits" / f"{slug}{suffix}",
            credits_source_dir=credit_portrait_dir,
            dry_run=dry_run,
        )
        summary["portrait"] = True
    return summary


def _strict_sprite_dir(base: Path | None, dex: int, form_index: int, *parts: str) -> Path | None:
    if base is None:
        return None
    candidate = base / f"{dex:04d}" / f"{form_index:04d}"
    for part in parts:
        candidate = candidate / part
    return candidate if _has_required_sprite_sources(candidate) else None


def _strict_portrait_dir(base: Path | None, dex: int, form_index: int, *parts: str) -> Path | None:
    if base is None:
        return None
    candidate = base / f"{dex:04d}" / f"{form_index:04d}"
    for part in parts:
        candidate = candidate / part
    return candidate if (candidate / "Normal.png").exists() else None


def _package_forms(sources: Any, dex: int, slug: str, default_form_index: int, forms: list[dict[str, Any]], dry_run: bool, source_revision: str) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for form in forms:
        index = int(form.get("index", 0))
        if index == default_form_index or bool(form.get("temporary", False)) or not bool(form.get("released", True)):
            continue
        sprite_source = _strict_sprite_dir(sources.raw_sprite_dir, dex, index)
        portrait_source = _strict_portrait_dir(sources.raw_portrait_dir, dex, index)
        if sprite_source is None and portrait_source is None:
            continue
        suffix = f"_form{index}"
        record: dict[str, Any] = {"index": index, "name": str(form.get("name", ""))}
        record.update(_package_variant_from(
            sources,
            slug,
            suffix,
            sprite_source,
            portrait_source,
            _strict_sprite_dir(sources.sprite_collab_sprite_dir, dex, index),
            _strict_portrait_dir(sources.sprite_collab_portrait_dir, dex, index),
            dry_run,
            source_revision,
        ))
        for variant_name, parts in (("shiny", ("0001",)), ("female", ("0000", "0002")), ("female_shiny", ("0001", "0002"))):
            record[variant_name] = _package_variant_from(
                sources,
                slug,
                f"{suffix}_{variant_name}",
                _strict_sprite_dir(sources.raw_sprite_dir, dex, index, *parts),
                _strict_portrait_dir(sources.raw_portrait_dir, dex, index, *parts),
                _strict_sprite_dir(sources.sprite_collab_sprite_dir, dex, index, *parts),
                _strict_portrait_dir(sources.sprite_collab_portrait_dir, dex, index, *parts),
                dry_run,
                source_revision,
            )
        out.append(record)
    return out


def _package_entry(entry: dict[str, Any], sources: Any, dry_run: bool, source_revision: str = "") -> dict[str, Any]:
    dex = int(entry["dex_number"])
    slug = str(entry["slug"])
    form_index = int(entry["default_form_index"])
    sprite_source = find_first_complete_sprite_dir(sources.raw_sprite_dir, dex, form_index)
    portrait_source = find_first_portrait_dir(sources.raw_portrait_dir, dex, form_index)
    sprite_collab_source = find_first_complete_sprite_dir(sources.sprite_collab_sprite_dir, dex, form_index) if sources.sprite_collab_sprite_dir else None
    portrait_collab_source = find_first_portrait_dir(sources.sprite_collab_portrait_dir, dex, form_index) if sources.sprite_collab_portrait_dir else None

    actor_dest = PROJECT_ROOT / "assets" / "textures" / "actor" / "pokemon" / slug
    portrait_dest = PROJECT_ROOT / "assets" / "textures" / "pokemon" / "portraits" / slug
    sprite_assets, sprite_checksums, sprite_warnings, _sprite_copies = copy_sprite_set(
        project_root=PROJECT_ROOT,
        source_dir=sprite_source,
        destination_dir=actor_dest,
        credits_source_dir=sprite_collab_source,
        dry_run=dry_run,
    )
    expanded_assets, expanded_checksums, expanded_warnings, _expanded_copies, expanded_extras = copy_expanded_animation_states(
        project_root=PROJECT_ROOT,
        source_dir=sprite_source,
        destination_dir=actor_dest,
        dry_run=dry_run,
        source_repo="RawAsset",
        source_rel_dir=_source_rel(sources.raw_asset_root, sprite_source),
        source_revision=source_revision,
    )
    portrait_assets, portrait_checksums, portrait_warnings, _portrait_copies = copy_portrait(
        project_root=PROJECT_ROOT,
        source_dir=portrait_source,
        destination_dir=portrait_dest,
        credits_source_dir=portrait_collab_source,
        dry_run=dry_run,
    )

    variant_summary: dict[str, Any] = {}
    for variant_name, variant_shiny, variant_female in (("shiny", True, False), ("female", False, True), ("female_shiny", True, True)):
        variant_summary[variant_name] = _package_variant(sources, dex, form_index, slug, f"_{variant_name}", variant_shiny, variant_female, dry_run, source_revision)
    shiny_summary = variant_summary["shiny"]
    form_summary = _package_forms(sources, dex, slug, form_index, list(entry.get("forms", [])), dry_run, source_revision)

    import_moves = _move_slugs_at_or_below(entry["level_skills"], LEVEL_FOR_DEFAULT_MOVES)
    usable_moves = [move for move in import_moves if (sources.skill_dir / f"{move}.json").exists()]
    default_moves = usable_moves[-4:]

    if expanded_assets:
        sprite_assets["animation_states"] = expanded_assets
        sprite_assets["animation_schema_version"] = int(expanded_extras.get("schema_version", 1))
        sprite_assets["shadow_size"] = int(expanded_extras.get("shadow_size", 0))
        if expanded_extras.get("anchors"):
            sprite_assets["anchors"] = str(expanded_extras["anchors"])

    warnings = sprite_warnings + expanded_warnings + portrait_warnings
    disabled_reason = ""
    has_required_sprites = all(not warning.startswith("missing sprite state") for warning in sprite_warnings) and "missing AnimData.xml" not in sprite_warnings
    has_full_game_data = bool(entry["released"]) and bool(entry["level_skills"]) and bool(default_moves) and has_required_sprites and "portrait_normal" in portrait_assets
    if not has_required_sprites:
        disabled_reason = "missing_required_sprites"
    elif not default_moves:
        disabled_reason = "missing_usable_move"
    elif "portrait_normal" not in portrait_assets:
        disabled_reason = "missing_normal_portrait"

    status = "battle_ready" if not disabled_reason else "metadata_only"
    assets = {**sprite_assets, **portrait_assets}
    if "portrait_normal" not in assets:
        assets["portrait_fallback"] = FALLBACK_ICON_PATH

    return {
        "shiny": shiny_summary,
        "variants": variant_summary,
        "forms": form_summary,
        "slug": slug,
        "pmdo_slug": entry["pmdo_slug"],
        "dex_number": dex,
        "display_name": entry["display_name"],
        "generation": entry["generation"],
        "released": entry["released"],
        "default_form_index": form_index,
        "status": status,
        "disabled_reason": disabled_reason,
        "full_game_data": has_full_game_data and not disabled_reason,
        "warnings": warnings,
        "source": {
            "monster_json": entry["monster_json"],
            "sprite_dir": _source_rel(sources.raw_asset_root, sprite_source),
            "portrait_dir": _source_rel(sources.raw_asset_root, portrait_source),
            "sprite_collab_dir": _source_rel(sources.sprite_collab_root, sprite_collab_source),
            "portrait_collab_dir": _source_rel(sources.sprite_collab_root, portrait_collab_source),
        },
        "assets": assets,
        "checksums": {**sprite_checksums, **expanded_checksums, **portrait_checksums},
        "moves": {
            "import_moves": import_moves,
            "usable_move_count": len(usable_moves),
            "default_moves": default_moves,
        },
    }


def _source_rel(root: Path | None, path: Path | None) -> str:
    if root is None or path is None:
        return ""
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _summary(species: list[dict[str, Any]]) -> dict[str, int]:
    out = {"total": len(species), "battle_ready": 0, "metadata_only": 0, "disabled": 0}
    for entry in species:
        status = str(entry.get("status", "disabled"))
        out[status] = int(out.get(status, 0)) + 1
    return out


def _summary_line(species: list[dict[str, Any]], dry_run: bool) -> str:
    summary = _summary(species)
    mode = "dry-run" if dry_run else "write"
    return "batch packager %s: total=%d battle_ready=%d metadata_only=%d disabled=%d" % (
        mode,
        summary.get("total", 0),
        summary.get("battle_ready", 0),
        summary.get("metadata_only", 0),
        summary.get("disabled", 0),
    )


def _default_form_index(forms: list[Any]) -> int:
    for index, form in enumerate(forms):
        if isinstance(form, dict) and not bool(form.get("Temporary", False)):
            return index
    return 0


def _level_skills(form: dict[str, Any]) -> list[dict[str, Any]]:
    out = []
    raw = form.get("LevelSkills", [])
    if not isinstance(raw, list):
        return out
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        skill = str(entry.get("Skill", "")).strip()
        if not skill:
            continue
        out.append({"level": int(entry.get("Level", 1) or 1), "skill": skill})
    return out


def _move_slugs_at_or_below(level_skills: list[dict[str, Any]], level: int) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for entry in sorted(level_skills, key=lambda item: (int(item.get("level", 0)), str(item.get("skill", "")))):
        if int(entry.get("level", 0)) > level:
            continue
        slug = str(entry.get("skill", "")).strip()
        if slug and slug not in seen:
            out.append(slug)
            seen.add(slug)
    return out


def _localized(node: Any) -> str:
    if isinstance(node, dict):
        return str(node.get("DefaultText", "") or "")
    if isinstance(node, str):
        return node
    return ""


def _parse_only(raw: str) -> set[str]:
    return {part.strip() for part in raw.split(",") if part.strip()}


def _parse_generations(raw: str) -> list[int]:
    return _parse_int_ranges(raw, 1, 9)


def _parse_dex_range(raw: str) -> tuple[int, int]:
    values = _parse_int_ranges(raw, 1, 2000)
    if not values:
        return DEFAULT_DEX_RANGE
    return min(values), max(values)


def _parse_int_ranges(raw: str, minimum: int, maximum: int) -> list[int]:
    values: set[int] = set()
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            left, right = part.split("-", 1)
            start = int(left)
            end = int(right)
            for value in range(start, end + 1):
                if minimum <= value <= maximum:
                    values.add(value)
        else:
            value = int(part)
            if minimum <= value <= maximum:
                values.add(value)
    return sorted(values)


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


if __name__ == "__main__":
    raise SystemExit(main())
