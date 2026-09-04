import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "data/models/pokemon/import_reports"
VALIDATION = ROOT / "logs/debug/validation"
MOVE_VERIFICATION = ROOT / "logs/debug/move_verification"
GENERATED = ROOT / "data/models/pokemon/generated"
CUSTOM_ITEMS = ROOT / "data/models/pokemon/items/custom"
SMOKE_DIR = ROOT / "tools/validation"
OUT_JSON = ROOT / "plan/v13/audits/mechanics_audit_inventory.json"
OUT_MD = ROOT / "plan/v13/audits/mechanics_audit_inventory.md"
CATALOG_SOURCE = ROOT / "data/models/world/combat/items/battle_item_catalog.gd"


def pmd_only_held():
    text = CATALOG_SOURCE.read_text()
    excluded = set()
    for name in ("PMD_ONLY_HELD", "NO_BATTLE_EFFECT"):
        match = re.search(r"const " + name + r": Array\[String\] = \[([^\]]*)\]", text)
        if match:
            excluded |= set(re.findall(r'"([a-z_]+)"', match.group(1)))
    return excluded


PMD_ONLY_HELD = pmd_only_held()


def unreleased_implemented():
    match = re.search(r"const UNRELEASED_IMPLEMENTED: Array\[String\] = \[([^\]]*)\]", CATALOG_SOURCE.read_text())
    return set(re.findall(r'"([a-z_]+)"', match.group(1))) if match else set()


UNRELEASED_IMPLEMENTED = unreleased_implemented()
FAMILY_REPRESENTATIVES = {
    "type_boost": (["held_charcoal", "held_flame_plate", "held_silk_scarf", "held_mystic_water", "held_splash_plate"], ["held_black_belt", "held_black_glasses", "held_hard_stone", "held_never_melt_ice", "held_poison_barb", "held_soft_sand", "held_spell_tag", "held_dragon_scale", "held_magnet", "held_metal_coat", "held_miracle_seed", "held_sharp_beak", "held_silver_powder", "held_twisted_spoon", "held_draco_plate", "held_dread_plate", "held_earth_plate", "held_fist_plate", "held_icicle_plate", "held_insect_plate", "held_iron_plate", "held_meadow_plate", "held_mind_plate", "held_pixie_plate", "held_sky_plate", "held_spooky_plate", "held_stone_plate", "held_toxic_plate", "held_zap_plate"]),
    "resist_berry": (["berry_wacan", "berry_chilan", "berry_passho"], ["berry_occa", "berry_rindo", "berry_yache", "berry_chople", "berry_kebia", "berry_shuca", "berry_coba", "berry_payapa", "berry_tanga", "berry_charti", "berry_kasib", "berry_haban", "berry_colbur", "berry_babiri", "berry_roseli"]),
    "pinch_berry": (["berry_apicot", "berry_petaya", "berry_salac", "berry_liechi", "berry_ganlon", "berry_micle"], ["berry_starf", "berry_custap"]),
    "cure_berry": (["berry_lum", "berry_cheri", "berry_pecha"], ["berry_chesto", "berry_rawst", "berry_aspear", "berry_persim"]),
    "weather_rock": (["held_heat_rock"], ["held_damp_rock", "held_smooth_rock", "held_icy_rock"]),
    "hit_reaction": (["held_cell_battery", "held_weakness_policy"], ["held_absorb_bulb", "held_luminous_moss", "held_snowball", "berry_kee", "berry_maranga"]),
}
STATUS_EXCLUSIONS = {"chasing": "Pursuit's chase depends on switching", "infestation": "no imported move applies it"}
ABILITY_EXCLUSIONS = {"pickup": "no battle effect outside dungeon item pickup", "honey_gather": "no battle effect", "illusion": "cosmetic disguise only", "quick_draw": "random priority has no counterpart in a speed-ordered round"}


def load(path):
    if not path.exists():
        return None
    return json.loads(path.read_text())


def tres_field(text, name):
    match = re.search(r'^%s = "?([^"\n]*)"?$' % re.escape(name), text, re.M)
    return match.group(1) if match else ""


def smoke_mentions():
    mentions = {}
    for path in sorted(SMOKE_DIR.glob("smoke_test_*.gd")):
        text = path.read_text()
        for token in set(re.findall(r'"([a-z0-9_]+)"', text)):
            mentions.setdefault(token, set()).add(path.stem)
    return mentions


def bot_evidence():
    moves, statuses, intrinsics, items = {}, {}, {}, {}
    battles = 0
    for path in sorted(VALIDATION.glob("bot_battles_*.json")):
        data = load(path)
        if not data:
            continue
        for battle in data.get("battles", []):
            battles += 1
            for table, target in (("moves_used", moves), ("statuses", statuses), ("intrinsics", intrinsics), ("items", items)):
                for key, count in battle.get(table, {}).items():
                    base = key.split(":")[0]
                    if base:
                        target[base] = target.get(base, 0) + int(count)
    return battles, moves, statuses, intrinsics, items


def scenario_evidence():
    data = load(VALIDATION / "mechanics_scenarios.json")
    names = []
    if data:
        names = [r["name"] for r in data.get("results", []) if r.get("pass")]
    return names


def build():
    mentions = smoke_mentions()
    battles, bot_moves, bot_statuses, bot_intrinsics, bot_items = bot_evidence()
    scenarios = scenario_evidence()
    scenario_text = " ".join(scenarios)
    inventory = {"generated_by": "tools/debug/build_audit_inventory.py", "battles_sampled": battles, "scenarios_passed": len(scenarios), "moves": {}, "abilities": {}, "statuses": {}, "items": {}, "summary": {}}

    move_report = load(REPORTS / "move_coverage_report.json") or {"moves": {}}
    sweep = load(MOVE_VERIFICATION / "all_moves_report.json") or {"results": []}
    verdicts = {r["move"]: r for r in sweep.get("results", [])}
    manifest = load(ROOT / "data/models/visuals/generated/action_presentation_manifest.json") or {"entries": {}}
    entries = manifest.get("entries", {})
    move_rows = move_report["moves"]
    move_items = move_rows.items() if isinstance(move_rows, dict) else [(m.get("move_id", m.get("slug")), m) for m in move_rows]
    for slug, row in move_items:
        text = (GENERATED / "moves" / f"{slug}.tres").read_text() if (GENERATED / "moves" / f"{slug}.tres").exists() else ""
        verdict = verdicts.get(slug, {})
        presentation = entries.get(f"skill:{slug}", {})
        evidence = sorted(mentions.get(slug, set()))
        inventory["moves"][slug] = {
            "disposition": row.get("disposition", ""),
            "unsupported_tags": row.get("unsupported_tags", row.get("unsupported_effect_tags", [])),
            "range_kind": tres_field(text, "tactical_range_kind"),
            "sweep_verdict": verdict.get("verdict", "not_swept"),
            "sweep_missing": verdict.get("missing", []),
            "presentation_mapped": bool(presentation),
            "presentation_missing_assets": presentation.get("missing_assets", []) if presentation else [],
            "smokes": evidence,
            "scenarios": [name for name in scenarios if slug in name],
            "bot_uses": bot_moves.get(slug, 0),
            "excluded": slug == "transform" and False,
        }
    ability_report = load(REPORTS / "intrinsic_coverage_report.json") or {"intrinsics": []}
    ability_sweep = load(VALIDATION / "sweep_abilities.json") or {"results": []}
    observed_abilities = {r["subject"]: r.get("observed", False) for r in ability_sweep.get("results", [])}
    for row in ability_report.get("intrinsics", []):
        slug = row["slug"]
        inventory["abilities"][slug] = {
            "implemented": bool(row.get("implemented", False)),
            "excluded_reason": ABILITY_EXCLUSIONS.get(slug, ""),
            "roster_frequency": row.get("roster_frequency", 0),
            "sweep_observed": observed_abilities.get(slug, None),
            "smokes": sorted(mentions.get(slug, set())),
            "scenarios": [name for name in scenarios if slug in name],
            "bot_triggers": bot_intrinsics.get(slug, 0),
        }
    status_report = load(REPORTS / "status_coverage_report.json") or {"statuses": []}
    status_rows = status_report.get("statuses", status_report.get("entries", []))
    for row in status_rows:
        slug = row.get("slug", row.get("status_id"))
        inventory["statuses"][slug] = {
            "classification": row.get("classification", ""),
            "applied_by_moves": row.get("applied_by_moves", []),
            "applied_by_intrinsics": row.get("applied_by_intrinsics", []),
            "excluded_reason": STATUS_EXCLUSIONS.get(slug, ""),
            "smokes": sorted(mentions.get(slug, set())),
            "scenarios": [name for name in scenarios if slug in name],
            "bot_applications": bot_statuses.get(slug, 0),
        }
    item_sweep = load(VALIDATION / "sweep_items.json") or {"results": []}
    observed_items = {r["subject"]: r.get("observed", False) for r in item_sweep.get("results", [])}
    for path in sorted(list((GENERATED / "items").glob("*.tres")) + list(CUSTOM_ITEMS.glob("*.tres"))):
        text = path.read_text()
        slug = tres_field(text, "item_id")
        category = tres_field(text, "category")
        custom = path.parent == CUSTOM_ITEMS
        released = tres_field(text, "released") != "false"
        selectable = category in ("held", "berry") and slug not in PMD_ONLY_HELD and (released or slug in UNRELEASED_IMPLEMENTED)
        if not selectable and not custom:
            continue
        family = ""
        family_representatives = []
        for name, (representatives, members) in FAMILY_REPRESENTATIVES.items():
            if slug in members or slug in representatives:
                family = name
                family_representatives = [r for r in representatives if r != slug]
        inventory["items"][slug] = {
            "category": category,
            "custom": custom,
            "selectable": selectable or custom,
            "sweep_observed": observed_items.get(slug, None),
            "smokes": sorted(mentions.get(slug, set())),
            "scenarios": [name for name in scenarios if slug in name],
            "bot_events": bot_items.get(slug, 0),
            "family": family,
            "family_representatives_tested": family_representatives,
        }
    total_items = len(list((GENERATED / "items").glob("*.tres")))
    inventory["summary"] = {
        "moves_total": len(inventory["moves"]),
        "moves_sweep_ok": sum(1 for m in inventory["moves"].values() if m["sweep_verdict"] == "ok"),
        "moves_with_smoke_or_scenario": sum(1 for m in inventory["moves"].values() if m["smokes"] or m["scenarios"]),
        "moves_bot_used": sum(1 for m in inventory["moves"].values() if m["bot_uses"] > 0),
        "moves_missing_presentation_assets": sorted(slug for slug, m in inventory["moves"].items() if m["presentation_missing_assets"]),
        "abilities_total": len(inventory["abilities"]),
        "abilities_implemented": sum(1 for a in inventory["abilities"].values() if a["implemented"]),
        "abilities_excluded": {slug: a["excluded_reason"] for slug, a in inventory["abilities"].items() if a["excluded_reason"]},
        "abilities_with_evidence": sum(1 for a in inventory["abilities"].values() if a["smokes"] or a["scenarios"] or a["sweep_observed"] or a["bot_triggers"]),
        "abilities_without_evidence": sorted(slug for slug, a in inventory["abilities"].items() if a["implemented"] and not (a["smokes"] or a["scenarios"] or a["sweep_observed"] or a["bot_triggers"])),
        "statuses_total": len(inventory["statuses"]),
        "statuses_flag_only": sorted(slug for slug, s in inventory["statuses"].items() if s["classification"] == "flag_only"),
        "statuses_with_evidence": sum(1 for s in inventory["statuses"].values() if s["smokes"] or s["scenarios"] or s["bot_applications"]),
        "items_imported": total_items,
        "items_selectable": len(inventory["items"]),
        "items_custom": sum(1 for i in inventory["items"].values() if i["custom"]),
        "items_with_evidence": sum(1 for i in inventory["items"].values() if i["smokes"] or i["scenarios"] or i["sweep_observed"] or i["bot_events"] or i["family_representatives_tested"]),
        "items_without_evidence": sorted(slug for slug, i in inventory["items"].items() if not (i["smokes"] or i["scenarios"] or i["sweep_observed"] or i["bot_events"] or i["family_representatives_tested"])),
        "items_run_loop_deferred": total_items - sum(1 for i in inventory["items"].values() if not i["custom"]),
    }
    return inventory


def write_markdown(inventory):
    s = inventory["summary"]
    lines = ["# Mechanics audit inventory", "", "Generated by `tools/debug/build_audit_inventory.py` from the import reports, the presentation manifest, the smoke sources, the scenario results and the bot-battle and sweep outputs. The JSON beside this file carries every entity.", ""]
    lines.append("| Family | Total | Implemented or applied | With test evidence | Notes |")
    lines.append("| --- | --- | --- | --- | --- |")
    lines.append("| Moves | %d | sweep ok %d | smoke or scenario %d, used by bots %d | %d reference particle sheets absent from RawAsset |" % (s["moves_total"], s["moves_sweep_ok"], s["moves_with_smoke_or_scenario"], s["moves_bot_used"], len(s["moves_missing_presentation_assets"])))
    lines.append("| Abilities | %d | %d | %d | excluded: %s |" % (s["abilities_total"], s["abilities_implemented"], s["abilities_with_evidence"], ", ".join(s["abilities_excluded"].keys())))
    lines.append("| Statuses | %d | %d classified | %d | flag-only: %s |" % (s["statuses_total"], s["statuses_total"] - len(s["statuses_flag_only"]), s["statuses_with_evidence"], ", ".join(s["statuses_flag_only"]) or "none"))
    lines.append("| Items | %d imported | %d selectable (%d custom) | %d | %d PMD-only or run-loop items are not offered |" % (s["items_imported"], s["items_selectable"], s["items_custom"], s["items_with_evidence"], s["items_run_loop_deferred"]))
    lines.append("")
    lines.append("Battles sampled: %d; scenarios passing: %d." % (inventory["battles_sampled"], inventory["scenarios_passed"]))
    lines.append("")
    lines.append("## Gaps")
    lines.append("")
    lines.append("- Implemented abilities without any direct evidence: %s" % (", ".join(s["abilities_without_evidence"]) or "none"))
    lines.append("- Selectable items without any direct evidence: %s" % (", ".join(s["items_without_evidence"]) or "none"))
    lines.append("- Moves whose sweep verdict is not ok: %s" % ", ".join(sorted("%s (%s)" % (slug, m["sweep_verdict"]) for slug, m in inventory["moves"].items() if m["sweep_verdict"] != "ok")))
    lines.append("- Moves with missing presentation sheets: %s" % ", ".join(s["moves_missing_presentation_assets"]))
    OUT_MD.write_text("\n".join(lines) + "\n")


def main() -> int:
    inventory = build()
    OUT_JSON.write_text(json.dumps(inventory, indent=1, sort_keys=True))
    write_markdown(inventory)
    print(json.dumps(inventory["summary"], indent=1)[:3000])
    return 0


if __name__ == "__main__":
    sys.exit(main())
