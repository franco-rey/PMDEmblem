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


func select_for_move(pawn: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> String:
	var requested: String = _requested_move_key(move)
	return _select(pawn, move, requested, "move_use", battle_log)


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
	var candidates: Array = FALLBACKS.get(requested, [requested, "idle"])
	if sprite_set != null:
		if purpose == "move_use" and move != null and sprite_set.move_animation_map.has(move.move_id):
			var exact: String = String(sprite_set.move_animation_map[move.move_id])
			if sprite_set.has_animation_state(exact):
				chosen = exact
		if chosen.is_empty():
			for candidate in candidates:
				var key: String = String(candidate)
				if sprite_set.has_animation_state(key):
					chosen = key
					break
	if chosen.is_empty():
		chosen = "idle"

	var visible: bool = _play_visible_state(pawn, chosen, purpose)
	if battle_log != null:
		battle_log.append({
			"kind": "animation_selected" if chosen == requested and visible else "animation_fallback",
			"unit": pawn,
			"move_id": move.move_id if move != null else "",
			"purpose": purpose,
			"requested_key": requested,
			"chosen_key": chosen,
			"reason": _fallback_reason(chosen, requested, visible),
		})
	return chosen


func _sprite_set_for(pawn: TacticsPawn) -> PokemonSpriteSetResource:
	if pawn == null or pawn.stats == null or pawn.stats.pokemon_instance == null:
		return null
	var form: PokemonFormResource = pawn.stats.pokemon_instance.resolved_form()
	return form.sprite_set if form != null else null


func _play_visible_state(pawn: TacticsPawn, state: String, purpose: String) -> bool:
	if pawn == null:
		return false
	var sprite: TacticsPawnSprite = pawn.get_node_or_null("Character") as TacticsPawnSprite
	if sprite == null:
		return true
	if not sprite.can_play_state(state):
		return false
	if pawn.res != null:
		pawn.res.force_animation(state, _duration_for_purpose(purpose))
	return true


func _duration_for_purpose(purpose: String) -> float:
	match purpose:
		"move_use":
			return 0.45
		"faint":
			return 0.8
		"receive_damage":
			return 0.35
		_:
			return 0.35


func _fallback_reason(chosen: String, requested: String, visible: bool) -> String:
	if not visible:
		return "sprite_runtime_unplayable"
	if chosen != requested:
		return "missing_exact_animation"
	return ""
