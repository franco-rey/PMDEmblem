#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import pokemon_batch_packager as packager
from source_config import load_config


EXPECTED_TOTAL = 686
EXPECTED_EXCLUDED_UNRELEASED = 35
STATIC_IDLE_SPECIES = {
    "0015_beedrill",
    "0148_dragonair",
    "0266_silcoon",
    "0268_cascoon",
    "0345_lileep",
    "0414_mothim",
}


def main() -> int:
    args = argparse.Namespace(
        pmdo_root=None,
        raw_asset_root=None,
        sprite_collab_root=None,
        generations="1-6",
        dex_range="1-721",
        only="",
        limit=0,
        dry_run=True,
        write=False,
    )
    sources = load_config(args)
    errors = packager._validate_sources(sources)
    if errors:
        for error in errors:
            print(f"smoke: fail - {error}", file=sys.stderr)
        return 1

    generations = packager._parse_generations(args.generations)
    dex_min, dex_max = packager._parse_dex_range(args.dex_range)
    entries = packager._discover_entries(sources, set(), generations, dex_min, dex_max)
    excluded = packager._discover_excluded_unreleased(sources, set(), generations, dex_min, dex_max)
    manifest_species = [packager._package_entry(entry, sources, dry_run=True) for entry in entries]
    summary = packager._summary(manifest_species)

    failures: list[str] = []
    if summary.get("total") != EXPECTED_TOTAL:
        failures.append(f"expected total={EXPECTED_TOTAL}, got {summary.get('total')}")
    if summary.get("battle_ready") != EXPECTED_TOTAL:
        failures.append(f"expected battle_ready={EXPECTED_TOTAL}, got {summary.get('battle_ready')}")
    if summary.get("metadata_only") != 0:
        failures.append(f"expected metadata_only=0, got {summary.get('metadata_only')}")
    if summary.get("disabled") != 0:
        failures.append(f"expected disabled=0, got {summary.get('disabled')}")
    if len(excluded) != EXPECTED_EXCLUDED_UNRELEASED:
        failures.append(f"expected excluded unreleased={EXPECTED_EXCLUDED_UNRELEASED}, got {len(excluded)}")

    by_slug = {str(entry.get("slug", "")): entry for entry in manifest_species}
    for slug in sorted(STATIC_IDLE_SPECIES):
        entry = by_slug.get(slug)
        if entry is None:
            failures.append(f"{slug} missing from dry-run manifest")
            continue
        substitutions = entry.get("assets", {}).get("sprite_substitutions", {})
        if substitutions.get("idle") != "idle_static_from_walk":
            failures.append(f"{slug} missing idle_static_from_walk substitution")
        if entry.get("status") != "battle_ready":
            failures.append(f"{slug} status={entry.get('status')} expected battle_ready")

    if failures:
        for failure in failures:
            print(f"smoke: fail - {failure}", file=sys.stderr)
        return 1

    print("smoke: pre_v13_batch_readiness clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
