import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PMDO = Path(os.environ.get("PMD_EMBLEM_PMDO_ROOT", str(ROOT.parent / "PMDODump"))) / "DumpAsset"
MANIFEST = ROOT / "data/models/visuals/generated/action_presentation_manifest.json"
VISUAL = ROOT / "data/models/visuals/generated/visual_asset_manifest.json"
GFX = ROOT / "data/models/visuals/generated/gfx_actions.json"
SPECIES_DIR = ROOT / "data/models/pokemon/generated/species"
SPRITES_DIR = ROOT / "data/models/pokemon/generated/sprites"
FORMS_DIR = ROOT / "data/models/pokemon/generated/forms"
OUT_JSON = ROOT / "plan/v13/audits/animation_extraction_audit.json"
OUT_MD = ROOT / "plan/v13/audits/animation_extraction_audit.md"


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def walk_anim_indices(node, acc):
    if isinstance(node, dict):
        if "AnimIndex" in node and isinstance(node["AnimIndex"], str) and node["AnimIndex"]:
            acc.add(node["AnimIndex"])
        for value in node.values():
            walk_anim_indices(value, acc)
    elif isinstance(node, list):
        for value in node:
            walk_anim_indices(value, acc)


def raw_skill(slug):
    path = PMDO / "Data/Skill" / f"{slug}.json"
    if not path.exists():
        return None
    data = load_json(path)
    return data.get("Object", data)


def hitbox_of(obj):
    hitbox = obj.get("HitboxAction", {})
    return hitbox.get("$type", "").split(".")[-1].split(",")[0]


def char_action_of(obj, actions_by_id):
    hitbox = obj.get("HitboxAction", {})
    data = hitbox.get("CharAnimData", {})
    if "ActionType" in data:
        return actions_by_id.get(int(data["ActionType"]), str(data["ActionType"]))
    if "CharAnim" in hitbox:
        return actions_by_id.get(int(hitbox["CharAnim"]), str(hitbox["CharAnim"]))
    return ""


def sprite_states(slug):
    path = SPRITES_DIR / f"{slug}.tres"
    if not path.exists():
        return set()
    text = path.read_text()
    start = text.find("animation_states = {")
    if start < 0:
        return set()
    end = text.find("\nmove_animation_map = ", start)
    block = text[start:end if end > 0 else len(text)]
    names = set(re.findall(r'^"([a-z_]+)": \{', block, re.M))
    for source_name in re.findall(r'"source_name": "([A-Za-z0-9_]+)"', block):
        names.add(source_name.lower())
    return names


def learnset(path):
    text = path.read_text()
    return re.findall(r'"skill": "([a-z0-9_]+)"', text)


def main() -> int:
    manifest = load_json(MANIFEST)["entries"]
    visual = load_json(VISUAL)
    gfx = load_json(GFX)
    actions_by_id = {int(a["id"]): a["name"] for a in gfx.get("actions", [])}
    fallbacks = {a["name"]: [actions_by_id.get(int(f), str(f)) for f in a.get("fallback_ids", [])] for a in gfx.get("actions", [])}
    lookup = visual.get("lookup", {})
    present = set()
    for category, table in lookup.items():
        for key in table.keys():
            present.add((category, key.split(".")[0]))
    skills = {}
    for entry_id, entry in manifest.items():
        if not entry_id.startswith("skill:"):
            continue
        slug = entry_id[6:]
        raw = raw_skill(slug)
        if raw is None:
            skills[slug] = {"source_missing": True}
            continue
        source_indices = set()
        walk_anim_indices(raw.get("HitboxAction", {}), source_indices)
        walk_anim_indices(raw.get("Explosion", {}), source_indices)
        walk_anim_indices(raw.get("Data", {}), source_indices)
        manifest_keys = set()
        for asset_key in entry.get("assets", {}).keys():
            manifest_keys.add(asset_key.split(":", 1)[1])
        unresolved = sorted(idx for idx in source_indices if idx not in manifest_keys and not any(cat_key[1] == idx for cat_key in present))
        absent_sheets = sorted(entry.get("missing_assets", []))
        skills[slug] = {
            "source_hitbox": hitbox_of(raw),
            "manifest_hitbox": entry.get("hitbox", {}).get("type", ""),
            "source_char_action": char_action_of(raw, actions_by_id),
            "manifest_char_action": entry.get("hitbox", {}).get("char_anim", {}).get("name", ""),
            "source_anim_indices": sorted(source_indices),
            "manifest_assets": sorted(manifest_keys),
            "unresolved_indices": unresolved,
            "absent_sheets": absent_sheets,
            "hitbox_match": hitbox_of(raw) == entry.get("hitbox", {}).get("type", ""),
            "char_action_match": char_action_of(raw, actions_by_id) == entry.get("hitbox", {}).get("char_anim", {}).get("name", ""),
        }
    species = {}
    for path in sorted(SPECIES_DIR.glob("*.tres")):
        slug = path.stem
        states = sprite_states(slug)
        if not states:
            continue
        needed = {}
        for move in set(learnset(path)):
            info = skills.get(move)
            if not info or info.get("source_missing"):
                continue
            action = info["source_char_action"]
            if action and action != "None":
                needed.setdefault(action, []).append(move)
        unresolved_actions = {}
        for action, moves in needed.items():
            chain = [action] + fallbacks.get(action, [])
            if not any(step.lower() in states for step in chain):
                unresolved_actions[action] = sorted(moves)
        species[slug] = {
            "states": sorted(states),
            "needed_actions": sorted(needed.keys()),
            "unresolved_actions": unresolved_actions,
        }
    summary = {
        "skills": len(skills),
        "hitbox_mismatches": sorted(s for s, v in skills.items() if not v.get("source_missing") and not v["hitbox_match"]),
        "char_action_mismatches": sorted(s for s, v in skills.items() if not v.get("source_missing") and not v["char_action_match"]),
        "skills_with_unresolved_indices": {s: v["unresolved_indices"] for s, v in skills.items() if not v.get("source_missing") and v["unresolved_indices"]},
        "skills_with_absent_sheets": sorted(s for s, v in skills.items() if not v.get("source_missing") and v["absent_sheets"]),
        "species": len(species),
        "species_with_unresolved_actions": {s: v["unresolved_actions"] for s, v in species.items() if v["unresolved_actions"]},
    }
    OUT_JSON.write_text(json.dumps({"summary": summary, "skills": skills, "species": species}, indent=1, sort_keys=True))
    lines = ["# Animation extraction audit", "", "Generated by `tools/debug/audit_animation_extraction.py`: PMDO source hitbox types, character actions and animation indices per skill against the presentation manifest and the visual asset manifest, and per-species imported sprite states against the character actions their learnsets need (through the actor action fallback chains).", ""]
    lines.append("- Skills compared: %d; hitbox type mismatches: %d; character action mismatches: %d." % (summary["skills"], len(summary["hitbox_mismatches"]), len(summary["char_action_mismatches"])))
    lines.append("- Skills whose source animation indices resolve to no imported sheet: %d (%s)." % (len(summary["skills_with_unresolved_indices"]), ", ".join(sorted(summary["skills_with_unresolved_indices"].keys()))))
    lines.append("- Skills with sheets absent from RawAsset (blank by owner rule): %d." % len(summary["skills_with_absent_sheets"]))
    lines.append("- Species compared: %d; species with a needed character action that no imported state or fallback covers: %d." % (summary["species"], len(summary["species_with_unresolved_actions"])))
    if summary["hitbox_mismatches"]:
        lines.append("- Hitbox mismatches: " + ", ".join("%s (%s vs %s)" % (s, skills[s]["source_hitbox"], skills[s]["manifest_hitbox"]) for s in summary["hitbox_mismatches"][:40]))
    if summary["char_action_mismatches"]:
        lines.append("- Character action mismatches: " + ", ".join("%s (%s vs %s)" % (s, skills[s]["source_char_action"], skills[s]["manifest_char_action"]) for s in summary["char_action_mismatches"][:40]))
    if summary["species_with_unresolved_actions"]:
        sample = list(summary["species_with_unresolved_actions"].items())[:20]
        lines.append("- Unresolved species actions (first 20): " + "; ".join("%s: %s" % (s, ", ".join(v.keys())) for s, v in sample))
    OUT_MD.write_text("\n".join(lines) + "\n")
    print(json.dumps({k: (v if not isinstance(v, dict) else len(v)) for k, v in summary.items()}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
