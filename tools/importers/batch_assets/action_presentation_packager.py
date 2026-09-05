from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any
from xml.etree import ElementTree

from source_config import PROJECT_ROOT, load_config
from visual_layouts import resolve_beam_layout, resolve_frame_directory_layout, resolve_sheet_layout


PRESENTATION_MANIFEST_PATH = Path("data/models/visuals/generated/action_presentation_manifest.json")
GFX_ACTIONS_PATH = Path("data/models/visuals/generated/gfx_actions.json")
VISUAL_MANIFEST_PATH = Path("data/models/visuals/generated/visual_asset_manifest.json")
SCHEMA_VERSION = 1
THROW_DEFAULTS = {
    "char_anim_action": 42,
    "projectile": {"range": 8, "speed": 14, "stop_at_hit": True, "stop_at_wall": True, "hit_tiles": True, "target_alignments": 6},
    "arc": {"range": 6, "speed": 10, "coverage": "WideAngle", "target_alignments": 4},
    "default_damage_power": 30,
    "default_damage_usage_types": [0, 8, 1, 6, 7, 2],
}
BATTLE_EVENT_KEYS = (
    "BeforeTryActions",
    "BeforeActions",
    "OnActions",
    "BeforeExplosions",
    "BeforeHits",
    "OnHits",
    "OnHitTiles",
    "AfterActions",
    "ElementEffects",
)


def main() -> int:
    args = _parse_args()
    if not args.dry_run and not args.write:
        args.dry_run = True
    sources = load_config(args)
    gfx_path = sources.pmdo_root / "DumpAsset" / "Base" / "GFXParams.xml"
    if not gfx_path.exists():
        print(f"error: GFXParams.xml missing at {gfx_path}")
        return 2
    visual_manifest = _load_json(PROJECT_ROOT / VISUAL_MANIFEST_PATH)
    if not visual_manifest:
        print(f"error: visual asset manifest missing at {VISUAL_MANIFEST_PATH}")
        return 2
    actions = parse_gfx_actions(gfx_path)
    action_names = {int(action["id"]): str(action["name"]) for action in actions["actions"]}

    skills = _parse_list(args.skills)
    items = _parse_list(args.items)
    dex_min, dex_max = _parse_dex_range(args.dex_range)
    if dex_min > 0:
        skills |= _skills_for_dex_range(sources, dex_min, dex_max, args.max_level)
    if not skills and not items:
        print("error: nothing selected; pass --skills, --items or --dex-range")
        return 2

    resolver = AssetResolver(visual_manifest, PROJECT_ROOT)
    entries: dict[str, dict[str, Any]] = {}
    problems: list[str] = []
    for skill in sorted(skills):
        path = sources.skill_dir / f"{skill}.json"
        if not path.exists():
            problems.append(f"missing skill json {skill}")
            continue
        entries[f"skill:{skill}"] = build_skill_entry(skill, _load_json(path), action_names, resolver)
    item_dir = sources.pmdo_root / "DumpAsset" / "Data" / "Item"
    for item in sorted(items):
        path = item_dir / f"{item}.json"
        if not path.exists():
            problems.append(f"missing item json {item}")
            continue
        entries[f"item:{item}"] = build_item_entry(item, _load_json(path), action_names, resolver)

    payload = {
        "schema_version": SCHEMA_VERSION,
        "source": "action_presentation_packager",
        "gfx_actions_path": "res://" + GFX_ACTIONS_PATH.as_posix(),
        "throw_defaults": THROW_DEFAULTS,
        "entries": entries,
    }
    existing = _load_json(PROJECT_ROOT / PRESENTATION_MANIFEST_PATH)
    if args.merge and existing:
        merged_entries = dict(existing.get("entries", {}))
        merged_entries.update(entries)
        payload["entries"] = {key: merged_entries[key] for key in sorted(merged_entries)}
    print(_summary_line(entries, problems, args.dry_run))
    for key in sorted(entries):
        missing = entries[key].get("missing_assets", [])
        if missing:
            print(f"warning {key}: unresolved assets {missing}")
    for problem in problems:
        print(f"warning: {problem}")
    if args.write:
        _write_json(PROJECT_ROOT / PRESENTATION_MANIFEST_PATH, payload)
        _write_json(PROJECT_ROOT / GFX_ACTIONS_PATH, actions)
        print(f"wrote {PRESENTATION_MANIFEST_PATH}")
        print(f"wrote {GFX_ACTIONS_PATH}")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract PMDO action/emitter presentation data for PMDEmblem playback.")
    parser.add_argument("--pmdo-root", dest="pmdo_root")
    parser.add_argument("--raw-asset-root", dest="raw_asset_root")
    parser.add_argument("--sprite-collab-root", dest="sprite_collab_root")
    parser.add_argument("--skills", default="", help="Comma-separated skill slugs.")
    parser.add_argument("--items", default="", help="Comma-separated item slugs.")
    parser.add_argument("--dex-range", default="", help="Add every level-up skill of the released base forms in this dex range.")
    parser.add_argument("--max-level", type=int, default=50)
    parser.add_argument("--merge", action="store_true", help="Keep entries already present in the manifest.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


def parse_gfx_actions(path: Path) -> dict[str, Any]:
    root = ElementTree.parse(path).getroot()
    names: list[str] = []
    raw_actions: list[dict[str, Any]] = []
    for node in root.findall("./Actions/Action"):
        name = (node.findtext("Name") or "").strip()
        dash = (node.findtext("Dash") or "false").strip().lower() == "true"
        fallbacks = [(fallback.text or "").strip() for fallback in node.findall("Fallback")]
        names.append(name)
        raw_actions.append({"name": name, "dash": dash, "fallback_names": fallbacks})
    actions: list[dict[str, Any]] = []
    for index, action in enumerate(raw_actions):
        fallback_ids = [names.index(fallback) for fallback in action["fallback_names"] if fallback in names]
        actions.append({
            "id": index,
            "name": action["name"],
            "dash": action["dash"],
            "fallbacks": action["fallback_names"],
            "fallback_ids": fallback_ids,
        })
    return {
        "schema_version": SCHEMA_VERSION,
        "source": "DumpAsset/Base/GFXParams.xml",
        "tile_size": int((root.findtext("TileSize") or "24").strip()),
        "actions": actions,
        "hurt_action": int((root.findtext("HurtAction") or "4").strip()),
        "walk_action": int((root.findtext("WalkAction") or "2").strip()),
        "idle_action": int((root.findtext("IdleAction") or "1").strip()),
        "sleep_action": int((root.findtext("SleepAction") or "3").strip()),
        "charge_action": int((root.findtext("ChargeAction") or "6").strip()),
    }


class AssetResolver:
    def __init__(self, visual_manifest: dict[str, Any], project_root: Path) -> None:
        self.lookup: dict[str, dict[str, str]] = visual_manifest.get("lookup", {})
        self.project_root = project_root
        self._cache: dict[tuple[str, str], dict[str, Any] | None] = {}

    def resolve(self, category: str, key: str) -> dict[str, Any] | None:
        cache_key = (category, key)
        if cache_key in self._cache:
            return self._cache[cache_key]
        resolved = self._resolve_uncached(category, key)
        self._cache[cache_key] = resolved
        return resolved

    def _resolve_uncached(self, category: str, key: str) -> dict[str, Any] | None:
        if not key:
            return None
        table = self.lookup.get(category, {})
        if category == "Beam":
            if f"{key}/Body" not in table:
                return None
            directory = self._abs(table[f"{key}/Body"]).parent
            layout = resolve_beam_layout(directory)
            paths = {name: table.get(f"{key}/{name.capitalize()}", "") for name in ("head", "body", "tail")}
            return {"category": category, "key": key, "paths": paths, "layout": layout}
        if key in table:
            res_path = table[key]
            abs_path = self._abs(res_path)
            if abs_path.is_dir():
                return {"category": category, "key": key, "path": res_path, "layout": resolve_frame_directory_layout(abs_path)}
            return {"category": category, "key": key, "path": res_path, "layout": resolve_sheet_layout(abs_path)}
        if f"{key}/0" in table:
            directory = self._abs(table[f"{key}/0"]).parent
            return {"category": category, "key": key, "path": "res://" + directory.resolve().relative_to(self.project_root.resolve()).as_posix(), "layout": resolve_frame_directory_layout(directory)}
        candidates = sorted(entry for entry in table if entry.split(".")[0] == key and "/" not in entry)
        if candidates:
            res_path = table[candidates[0]]
            return {"category": category, "key": key, "lookup_key": candidates[0], "path": res_path, "layout": resolve_sheet_layout(self._abs(res_path))}
        return None

    def _abs(self, res_path: str) -> Path:
        return self.project_root / res_path.removeprefix("res://")


def build_skill_entry(slug: str, raw: dict[str, Any], action_names: dict[int, str], resolver: AssetResolver) -> dict[str, Any]:
    obj = raw.get("Object", {}) if isinstance(raw, dict) else {}
    data = obj.get("Data", {}) if isinstance(obj, dict) else {}
    entry: dict[str, Any] = {
        "kind": "skill",
        "id": slug,
        "source": {"file": f"DumpAsset/Data/Skill/{slug}.json", "version": str(raw.get("Version", ""))},
        "strikes": int(obj.get("Strikes", 1) or 1),
        "hitbox": normalize_hitbox(obj.get("HitboxAction"), action_names),
        "explosion": normalize_node(obj.get("Explosion"), action_names),
        "hit_fx": normalize_node(data.get("HitFX"), action_names),
        "intro_fx": [normalize_node(fx, action_names) for fx in data.get("IntroFX", []) if isinstance(fx, dict)],
        "hit_char_action": normalize_char_anim(data.get("HitCharAction"), action_names),
        "events": normalize_event_buckets(data, action_names),
    }
    _attach_assets(entry, resolver)
    return entry


def build_item_entry(slug: str, raw: dict[str, Any], action_names: dict[int, str], resolver: AssetResolver) -> dict[str, Any]:
    obj = raw.get("Object", {}) if isinstance(raw, dict) else {}
    use_event = obj.get("UseEvent", {}) if isinstance(obj, dict) else {}
    usage_type = int(obj.get("UsageType", 0) or 0)
    item_states = [_short_type(state.get("$type", "")) for state in obj.get("ItemStates", []) if isinstance(state, dict)]
    throw_defaults = THROW_DEFAULTS
    arc = bool(obj.get("ArcThrow", False))
    entry: dict[str, Any] = {
        "kind": "item",
        "id": slug,
        "source": {"file": f"DumpAsset/Data/Item/{slug}.json", "version": str(raw.get("Version", ""))},
        "usage_type": usage_type,
        "item_states": item_states,
        "sprite": str(obj.get("Sprite", "")),
        "arc_throw": arc,
        "break_on_throw": bool(obj.get("BreakOnThrow", False)),
        "throw_anim": normalize_anim(obj.get("ThrowAnim")),
        "use_action": normalize_hitbox(obj.get("UseAction"), action_names),
        "explosion": normalize_node(obj.get("Explosion"), action_names),
        "use_hit_fx": normalize_node(use_event.get("HitFX"), action_names),
        "use_intro_fx": [normalize_node(fx, action_names) for fx in use_event.get("IntroFX", []) if isinstance(fx, dict)],
        "use_hit_char_action": normalize_char_anim(use_event.get("HitCharAction"), action_names),
        "use_events": normalize_event_buckets(use_event, action_names),
        "throw": {
            "char_anim": {"kind": "frame_type", "action": throw_defaults["char_anim_action"], "name": action_names.get(int(throw_defaults["char_anim_action"]), "")},
            "mode": "arc" if arc else "projectile",
            "params": dict(throw_defaults["arc"] if arc else throw_defaults["projectile"]),
            "default_damage": usage_type in throw_defaults["default_damage_usage_types"],
            "default_damage_power": throw_defaults["default_damage_power"],
            "catchable": "RecruitState" not in item_states,
            "edible": "EdibleState" in item_states,
            "ammo": "AmmoState" in item_states,
        },
    }
    _attach_assets(entry, resolver)
    if entry["sprite"]:
        resolved = resolver.resolve("Item", entry["sprite"])
        if resolved is not None:
            entry.setdefault("assets", {})[f"item:{entry['sprite']}"] = resolved
        else:
            entry.setdefault("missing_assets", []).append(f"item:{entry['sprite']}")
    return entry


def normalize_hitbox(node: Any, action_names: dict[int, str]) -> dict[str, Any]:
    if not isinstance(node, dict):
        return {}
    out = normalize_node(node, action_names)
    if "char_anim" in node or "CharAnim" in node:
        raw_index = int(node.get("CharAnim", 0) or 0)
        out["char_anim"] = {"kind": "frame_type", "action": raw_index, "name": action_names.get(raw_index, "")}
    elif isinstance(node.get("CharAnimData"), dict):
        out["char_anim"] = normalize_char_anim(node.get("CharAnimData"), action_names)
    else:
        out["char_anim"] = {"kind": "none"}
    out.pop("char_anim_data", None)
    return out


def normalize_char_anim(node: Any, action_names: dict[int, str]) -> dict[str, Any]:
    if not isinstance(node, dict):
        return {"kind": "none"}
    type_name = _short_type(node.get("$type", ""))
    if type_name == "CharAnimFrameType":
        action = int(node.get("ActionType", 0) or 0)
        return {"kind": "frame_type", "action": action, "name": action_names.get(action, "")}
    if type_name == "CharAnimProcess":
        process = int(node.get("Process", 0) or 0)
        override = int(node.get("AnimOverride", 0) or 0)
        return {
            "kind": "process",
            "process": process,
            "process_name": ["None", "Spin", "Drop", "Fly", "Kidnap"][process] if 0 <= process < 5 else str(process),
            "anim_override": override,
            "anim_override_name": action_names.get(override, "") if override > 0 else "",
        }
    return {"kind": type_name or "none"}


def normalize_event_buckets(data: Any, action_names: dict[int, str]) -> dict[str, list[dict[str, Any]]]:
    out: dict[str, list[dict[str, Any]]] = {}
    if not isinstance(data, dict):
        return out
    for key in BATTLE_EVENT_KEYS:
        bucket = data.get(key, [])
        if not isinstance(bucket, list) or not bucket:
            continue
        events: list[dict[str, Any]] = []
        for position, element in enumerate(bucket):
            if not isinstance(element, dict):
                continue
            priority = element.get("Key", {}).get("str", []) if isinstance(element.get("Key"), dict) else []
            value = element.get("Value", element)
            normalized = normalize_node(value, action_names)
            normalized["priority"] = [int(part) for part in priority] if isinstance(priority, list) else []
            normalized["entry_order"] = position
            events.append(normalized)
        out[_snake(key)] = events
    return out


def normalize_anim(node: Any) -> dict[str, Any]:
    if not isinstance(node, dict):
        return {}
    return {
        "index": str(node.get("AnimIndex", "") or ""),
        "frame_time": int(node.get("FrameTime", 1) or 1),
        "start_frame": int(node.get("StartFrame", -1) if node.get("StartFrame") is not None else -1),
        "end_frame": int(node.get("EndFrame", -1) if node.get("EndFrame") is not None else -1),
        "dir": int(node.get("AnimDir", -1) if node.get("AnimDir") is not None else -1),
        "alpha": int(node.get("Alpha", 255) or 255),
        "flip": int(node.get("AnimFlip", 0) or 0),
    }


def normalize_node(node: Any, action_names: dict[int, str]) -> Any:
    if isinstance(node, dict):
        if "AnimIndex" in node and "$type" not in node:
            return normalize_anim(node)
        out: dict[str, Any] = {}
        type_name = _short_type(node.get("$type", ""))
        if type_name:
            out["type"] = type_name
        for key, value in node.items():
            if key == "$type":
                continue
            snake_key = _snake(key)
            if key in ("HitboxAction", "UseAction"):
                out[snake_key] = normalize_hitbox(value, action_names)
            elif key in ("CharAnimData", "HitCharAction"):
                out[snake_key] = normalize_char_anim(value, action_names)
            elif key == "NewData" and isinstance(value, dict):
                out[snake_key] = {
                    "element": str(value.get("Element", "")),
                    "category": int(value.get("Category", 0) or 0),
                    "hit_rate": int(value.get("HitRate", -1) if value.get("HitRate") is not None else -1),
                    "skill_states": [normalize_node(state, action_names) for state in value.get("SkillStates", []) if isinstance(state, dict)],
                    "hit_fx": normalize_node(value.get("HitFX"), action_names),
                    "intro_fx": [normalize_node(fx, action_names) for fx in value.get("IntroFX", []) if isinstance(fx, dict)],
                    "hit_char_action": normalize_char_anim(value.get("HitCharAction"), action_names),
                    "events": normalize_event_buckets(value, action_names),
                }
            elif key in BATTLE_EVENT_KEYS:
                continue
            else:
                out[snake_key] = normalize_node(value, action_names)
        return out
    if isinstance(node, list):
        return [normalize_node(item, action_names) for item in node]
    return node


def _attach_assets(entry: dict[str, Any], resolver: AssetResolver) -> None:
    keys: set[str] = set()
    beam_keys: set[str] = set()
    overlay_keys: set[str] = set()
    _collect_anim_keys(entry, keys, beam_keys, overlay_keys, False, False)
    assets: dict[str, Any] = dict(entry.get("assets", {}))
    missing: list[str] = list(entry.get("missing_assets", []))
    for key in sorted(keys):
        resolved = resolver.resolve("Particle", key)
        if resolved is None:
            missing.append(f"particle:{key}")
        else:
            assets[f"particle:{key}"] = resolved
    for key in sorted(overlay_keys):
        resolved = resolver.resolve("BG", key)
        if resolved is None:
            resolved = resolver.resolve("Particle", key)
        if resolved is None:
            missing.append(f"bg:{key}")
        else:
            assets[f"bg:{key}"] = resolved
    for key in sorted(beam_keys):
        resolved = resolver.resolve("Beam", key)
        if resolved is None:
            resolved = resolver.resolve("Particle", key)
        if resolved is None:
            missing.append(f"beam:{key}")
        else:
            assets[f"beam:{key}"] = resolved
    if assets:
        entry["assets"] = {key: assets[key] for key in sorted(assets)}
    if missing:
        entry["missing_assets"] = sorted(set(missing))


def _collect_anim_keys(node: Any, keys: set[str], beam_keys: set[str], overlay_keys: set[str], in_beam: bool, in_overlay: bool) -> None:
    if isinstance(node, dict):
        node_type = str(node.get("type", ""))
        next_in_beam = in_beam or node_type in ("WaveMotionAction", "BeamSweepHitbox", "ColumnAnim", "BeamAnimData")
        next_in_overlay = in_overlay or node_type == "FiniteOverlayEmitter"
        if "index" in node and "frame_time" in node and isinstance(node.get("index"), str):
            index = str(node["index"])
            if index:
                if next_in_overlay:
                    overlay_keys.add(index)
                elif next_in_beam:
                    beam_keys.add(index)
                else:
                    keys.add(index)
        for key, value in node.items():
            if key in ("assets", "missing_assets"):
                continue
            nested_fx = key in ("emitter", "tile_emitter", "hit_fx", "explosion", "intro_fx", "action_fx", "pre_actions")
            _collect_anim_keys(value, keys, beam_keys, overlay_keys, next_in_beam and not nested_fx, next_in_overlay and not nested_fx)
    elif isinstance(node, list):
        for item in node:
            _collect_anim_keys(item, keys, beam_keys, overlay_keys, in_beam, in_overlay)


def _skills_for_dex_range(sources: Any, dex_min: int, dex_max: int, max_level: int) -> set[str]:
    out: set[str] = set()
    for path in sorted(sources.monster_dir.glob("*.json")):
        raw = _load_json(path)
        obj = raw.get("Object", {}) if isinstance(raw, dict) else {}
        dex = int(obj.get("IndexNum", 0) or 0)
        if dex < dex_min or dex > dex_max or not bool(obj.get("Released", True)):
            continue
        forms = obj.get("Forms", [])
        if not isinstance(forms, list) or not forms:
            continue
        form = next((candidate for candidate in forms if isinstance(candidate, dict) and not bool(candidate.get("Temporary", False))), forms[0])
        for skill in form.get("LevelSkills", []) if isinstance(form, dict) else []:
            if isinstance(skill, dict) and int(skill.get("Level", 1) or 1) <= max_level and skill.get("Skill"):
                out.add(str(skill["Skill"]))
    return out


def _summary_line(entries: dict[str, dict[str, Any]], problems: list[str], dry_run: bool) -> str:
    skills = sum(1 for key in entries if key.startswith("skill:"))
    items = sum(1 for key in entries if key.startswith("item:"))
    missing = sum(len(entry.get("missing_assets", [])) for entry in entries.values())
    return "presentation packager %s: skills=%d items=%d unresolved_assets=%d problems=%d" % ("dry-run" if dry_run else "write", skills, items, missing, len(problems))


def _short_type(value: Any) -> str:
    text = str(value or "")
    if not text:
        return ""
    return text.split(",")[0].split(".")[-1]


def _snake(name: str) -> str:
    text = re.sub(r"(?<=[a-z0-9])([A-Z])", r"_\1", name)
    text = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", text)
    return text.replace("$", "").lower()


def _parse_list(raw: str) -> set[str]:
    return {part.strip() for part in raw.split(",") if part.strip()}


def _parse_dex_range(raw: str) -> tuple[int, int]:
    text = raw.strip()
    if not text:
        return (0, 0)
    if "-" in text:
        left, right = text.split("-", 1)
        return (int(left), int(right))
    return (int(text), int(text))


def _load_json(path: Path) -> Any:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=1, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    raise SystemExit(main())
