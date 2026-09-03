class_name BattleAnimationResolver
extends RefCounted

const FALLBACKS: Dictionary = {
	"physical_attack": ["physical_attack", "attack", "hop", "idle"],
	"special_attack": ["special_attack", "cast", "attack", "hop", "idle"],
	"status_attack": ["status_attack", "buff", "attack", "idle", "hop"],
	"heal": ["heal", "buff", "status_attack", "idle"],
	"buff": ["buff", "status_attack", "idle"],
	"debuff": ["debuff", "status_attack", "idle"],
	"receive_damage": ["hurt", "idle"],
	"miss": ["miss", "idle"],
	"faint": ["faint", "sleep", "hurt", "idle"],
}
const REACTION_DURATIONS: Dictionary = {
	"move_use": 0.45,
	"faint": 0.8,
	"receive_damage": 0.5,
}

var runner: BattlePresentationRunner = null
var presentation_catalog: ActionPresentationCatalog = null
var last_selection: Dictionary = {}


func select_for_move(pawn: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> String:
	var requested: String = _requested_move_key(move)
	return _select(pawn, move, requested, "move_use", battle_log)


func select_for_source_action(pawn: TacticsPawn, action_name: String, move_id: String, battle_log: BattleLog, enqueue: bool = false) -> String:
	var sprite: TacticsPawnSprite = _sprite_for(pawn)
	var resolved: Dictionary = {}
	if sprite != null:
		resolved = sprite.resolve_source_state(action_name)
	elif _sprite_set_for(pawn) != null:
		resolved = ActorActionCatalog.shared().resolve_source_state(_sprite_set_for(pawn), action_name)
	var chosen: String = String(resolved.get("state_key", ""))
	var tier: String = String(resolved.get("tier", "missing"))
	if chosen.is_empty():
		chosen = _fallback_for_source_action(pawn, action_name)
		tier = "category" if not chosen.is_empty() and chosen != "idle" else "idle"
		if chosen.is_empty():
			chosen = "idle"
	last_selection = {
		"requested": action_name,
		"chosen_key": chosen,
		"source_name": String(resolved.get("source_name", "")),
		"tier": tier,
	}
	var visible: bool = _play_visible_state(pawn, chosen, "move_use", enqueue)
	if battle_log != null:
		battle_log.append({
			"kind": "animation_selected" if visible and tier in ["exact", "source_fallback"] else "animation_fallback",
			"unit": pawn,
			"move_id": move_id,
			"purpose": "move_use",
			"requested_key": action_name,
			"chosen_key": chosen,
			"source_state": String(resolved.get("source_name", "")),
			"selection_tier": tier,
			"reason": "" if tier in ["exact", "source_fallback"] else ("sprite_runtime_unplayable" if not visible else "missing_source_action"),
		})
	return chosen


func select_reaction(pawn: TacticsPawn, move: PokemonMoveResource, purpose: String, battle_log: BattleLog) -> String:
	return _select(pawn, move, purpose, purpose, battle_log)


func _requested_move_key(move: PokemonMoveResource) -> String:
	if move == null:
		return "physical_attack"
	if not move.animation_key.is_empty():
		return move.animation_key
	match move.category:
		PokemonMoveResource.CATEGORY_PHYSICAL:
			return "physical_attack"
		PokemonMoveResource.CATEGORY_SPECIAL:
			return "special_attack"
		_:
			return "status_attack"


func _select(pawn: TacticsPawn, move: PokemonMoveResource, requested: String, purpose: String, battle_log: BattleLog) -> String:
	var sprite_set: PokemonSpriteSetResource = _sprite_set_for(pawn)
	var chosen: String = ""
	var tier: String = "idle"
	var source_state: String = ""
	var candidates: Array = FALLBACKS.get(requested, [requested, "idle"])
	if sprite_set != null:
		if purpose == "move_use" and move != null:
			var source_action: String = _source_action_for_move(move)
			if not source_action.is_empty():
				var sprite: TacticsPawnSprite = _sprite_for(pawn)
				var resolved: Dictionary = sprite.resolve_source_state(source_action) if sprite != null else ActorActionCatalog.shared().resolve_source_state(sprite_set, source_action)
				if not resolved.is_empty():
					chosen = String(resolved.get("state_key", ""))
					source_state = String(resolved.get("source_name", ""))
					tier = "exact" if String(resolved.get("tier", "")) == "exact" else "source_fallback"
			if chosen.is_empty():
				var exact: String = _exact_animation_key(move, sprite_set)
				if not exact.is_empty():
					chosen = exact
					tier = "exact"
		if chosen.is_empty():
			for candidate in candidates:
				var key: String = String(candidate)
				if sprite_set.has_animation_state(key):
					chosen = key
					tier = "category" if key == requested or key == String(candidates[0]) else "fallback"
					break
	if chosen.is_empty():
		chosen = "idle"
		tier = "idle"

	last_selection = {"requested": requested, "chosen_key": chosen, "source_name": source_state, "tier": tier, "purpose": purpose}
	var visible: bool = _play_visible_state(pawn, chosen, purpose, purpose != "move_use")
	if battle_log != null:
		battle_log.append({
			"kind": "animation_selected" if visible and tier in ["exact", "category", "source_fallback"] else "animation_fallback",
			"unit": pawn,
			"move_id": move.move_id if move != null else "",
			"purpose": purpose,
			"requested_key": requested,
			"chosen_key": chosen,
			"source_state": source_state,
			"selection_tier": tier,
			"reason": _fallback_reason(chosen, requested, visible, tier),
		})
	return chosen


func _source_action_for_move(move: PokemonMoveResource) -> String:
	if move == null:
		return ""
	var catalog: ActionPresentationCatalog = presentation_catalog if presentation_catalog != null else ActionPresentationCatalog.shared()
	var entry: Dictionary = catalog.skill(move.move_id)
	if entry.is_empty():
		return ""
	var hitbox: Variant = entry.get("hitbox", null)
	if not (hitbox is Dictionary):
		return ""
	var char_anim: Variant = (hitbox as Dictionary).get("char_anim", null)
	if not (char_anim is Dictionary):
		return ""
	var kind: String = String((char_anim as Dictionary).get("kind", ""))
	if kind == "frame_type":
		return String((char_anim as Dictionary).get("name", ""))
	if kind == "process":
		var override_name: String = String((char_anim as Dictionary).get("anim_override_name", ""))
		if not override_name.is_empty():
			return override_name
		return "None"
	return ""


func _fallback_for_source_action(pawn: TacticsPawn, action_name: String) -> String:
	var sprite_set: PokemonSpriteSetResource = _sprite_set_for(pawn)
	if sprite_set == null:
		return ""
	var candidates: Array[String] = []
	match action_name:
		"None":
			return "idle"
		"Shoot", "Charge", "SpAttack", "Emit", "Shock", "Gas", "Sound", "Sing", "Rumble", "Swell", "RearUp", "Withdraw", "Hover", "FlapAround":
			candidates = ["shoot", "charge", "special_attack", "status_attack", "attack", "idle"]
		"Rotate", "Twirl", "TailWhip", "Dance", "Appeal", "Shake":
			candidates = ["rotate", "shake", "charge", "status_attack", "idle"]
		_:
			candidates = ["attack", "strike", "physical_attack", "swing", "hop", "idle"]
	for key in candidates:
		if sprite_set.has_animation_state(key):
			return key
	return "idle"


func _exact_animation_key(move: PokemonMoveResource, sprite_set: PokemonSpriteSetResource) -> String:
	if move == null or sprite_set == null:
		return ""
	if sprite_set.move_animation_map.has(move.move_id):
		var mapped: String = String(sprite_set.move_animation_map[move.move_id])
		if _is_exact_key(mapped) and sprite_set.has_animation_state(mapped):
			return mapped
	var candidates: Array[String] = _exact_candidates_for_move(move)
	for key in candidates:
		if sprite_set.has_animation_state(key):
			return key
	return ""


func _exact_candidates_for_move(move: PokemonMoveResource) -> Array[String]:
	var id: String = move.move_id
	if id.contains("beam") or id.contains("pulse") or id.contains("sphere") or id.contains("gun") or id.contains("shot") or id.contains("bomb") or id.contains("seed") or id.contains("shuriken") or id.contains("wave"):
		return ["shoot", "cast", "charge"]
	if id.contains("slash") or id.contains("cut") or id.contains("blade") or id.contains("claw") or id.contains("cutter"):
		return ["swing", "strike", "physical_attack"]
	if id.contains("punch") or id.contains("kick") or id.contains("combat") or id.contains("tackle") or id.contains("edge"):
		return ["strike", "physical_attack", "attack"]
	if move.category == PokemonMoveResource.CATEGORY_STATUS or id.contains("protect") or id.contains("dance") or id.contains("mind") or id.contains("synthesis"):
		return ["cast", "charge", "buff", "status_attack"]
	return []


func _is_exact_key(key: String) -> bool:
	return not ["physical_attack", "special_attack", "status_attack", "attack", "idle", "hop"].has(key)


func _sprite_set_for(pawn: TacticsPawn) -> PokemonSpriteSetResource:
	if pawn == null or pawn.stats == null or pawn.stats.pokemon_instance == null:
		return null
	var form: PokemonFormResource = pawn.stats.pokemon_instance.resolved_form()
	return form.sprite_set if form != null else null


func _sprite_for(pawn: TacticsPawn) -> TacticsPawnSprite:
	if pawn == null:
		return null
	return pawn.get_node_or_null("Character") as TacticsPawnSprite


func _play_visible_state(pawn: TacticsPawn, state: String, purpose: String, deferred_to_runner: bool) -> bool:
	if pawn == null:
		return false
	var sprite: TacticsPawnSprite = _sprite_for(pawn)
	if sprite == null:
		return true
	if not sprite.can_play_state(state):
		return false
	if runner != null and runner.is_inside_tree():
		if purpose == "move_use":
			return true
		if deferred_to_runner:
			BattleActionPresentation.enqueue_reaction(runner, pawn, state, _duration_for_purpose(purpose))
			return true
	if pawn.res != null:
		if purpose == "receive_damage" and state == TacticsPawnSprite.ANIM_HURT:
			pawn.res.hurt_remaining = maxf(pawn.res.hurt_remaining, _duration_for_purpose(purpose))
		else:
			pawn.res.force_animation(state, _duration_for_purpose(purpose), purpose != "receive_damage")
	return true


func _duration_for_purpose(purpose: String) -> float:
	return float(REACTION_DURATIONS.get(purpose, 0.35))


func _fallback_reason(chosen: String, requested: String, visible: bool, tier: String) -> String:
	if not visible:
		return "sprite_runtime_unplayable"
	if tier == "exact" or tier == "category" or tier == "source_fallback":
		return ""
	if chosen != requested:
		return "missing_exact_animation"
	return ""
