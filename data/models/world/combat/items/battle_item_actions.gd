class_name BattleItemActions
extends RefCounted

const EXCLUDED_EVENTS: Dictionary = {
	"RestoreBellyEvent": "hunger",
	"RemoveItemEvent": "dungeon_floor_item",
	"RemoveTrapEvent": "dungeon_trap",
	"RemoveTerrainStateEvent": "dungeon_terrain",
}
const SOURCE_TICK_SECONDS: float = 1.0 / 60.0
const ALIGN_SELF: int = 1
const ALIGN_FRIEND: int = 2
const ALIGN_FOE: int = 4

var resolver: BattleActionResolver = null
var damage_resolver := DamageResolver.new()
var presentation_catalog: ActionPresentationCatalog = ActionPresentationCatalog.shared()


func _init(owner: BattleActionResolver = null) -> void:
	resolver = owner


func execute(intent: BattleActionIntent, battle_level: TacticsLevel) -> Dictionary:
	var result: Dictionary = {"ok": false, "kind": intent.kind if intent != null else "", "reason": ""}
	if intent == null or intent.actor == null or intent.actor.stats == null or not intent.actor.is_alive():
		result["reason"] = "invalid_actor"
		return result
	var actor: TacticsPawn = intent.actor
	var battle_log: BattleLog = battle_level.battle_log if battle_level != null else null
	var held: PokemonItemResource = PokemonItemService.held_item_for(actor.stats)
	if held == null or held.item_id != intent.item_id:
		result["reason"] = "item_not_held"
		_append(battle_log, {"kind": "item_action_rejected", "unit": actor, "item_id": intent.item_id, "reason": result["reason"]})
		return result
	var entry: Dictionary = BattleItemCatalog.entry_for(held.item_id)
	match intent.kind:
		BattleActionIntent.KIND_USE_ITEM:
			if not bool(entry.get("can_use", false)):
				result["reason"] = "item_not_usable"
				_append(battle_log, {"kind": "item_action_rejected", "unit": actor, "item_id": held.item_id, "reason": result["reason"]})
				return result
			return _execute_use(actor, held, entry, battle_level, battle_log)
		BattleActionIntent.KIND_THROW_ITEM:
			if intent.direction == Vector3i.ZERO:
				result["reason"] = "no_direction"
				_append(battle_log, {"kind": "item_action_rejected", "unit": actor, "item_id": held.item_id, "reason": result["reason"]})
				return result
			return _execute_throw(actor, held, entry, intent.direction, battle_level, battle_log)
	result["reason"] = "unsupported_intent"
	return result


func _execute_use(actor: TacticsPawn, item: PokemonItemResource, entry: Dictionary, battle_level: TacticsLevel, battle_log: BattleLog) -> Dictionary:
	var presentation: Dictionary = presentation_catalog.item(item.item_id)
	var runner: BattlePresentationRunner = battle_level.presentation_runner if battle_level != null else null
	_append(battle_log, {"kind": "item_use_started", "unit": actor, "item_id": item.item_id, "verb": String(entry.get("use_verb", "Use"))})
	PokemonItemService.consume_held_item(actor.stats, battle_log, "use")
	if runner != null:
		runner.begin_sequence("item_use:%s" % item.item_id)
		_enqueue_use_action(runner, actor, presentation, item.item_id, battle_log)
	var outcome: Dictionary = _apply_use_event(actor, actor, item, presentation, battle_level, battle_log, "use")
	if runner != null:
		BattleActionPresentation.enqueue_move_end(runner)
	actor.stats.record_move_use("item:%s" % item.item_id, -1)
	return {"ok": true, "kind": BattleActionIntent.KIND_USE_ITEM, "item_id": item.item_id, "effects": outcome}


func _execute_throw(actor: TacticsPawn, item: PokemonItemResource, entry: Dictionary, direction: Vector3i, battle_level: TacticsLevel, battle_log: BattleLog) -> Dictionary:
	var presentation: Dictionary = presentation_catalog.item(item.item_id)
	var throw_spec: Dictionary = presentation.get("throw", {}) if presentation.get("throw", null) is Dictionary else {}
	var params: Dictionary = throw_spec.get("params", {}) if throw_spec.get("params", null) is Dictionary else {}
	var defaults: Dictionary = presentation_catalog.throw_defaults
	var mode: String = String(throw_spec.get("mode", "projectile"))
	if params.is_empty():
		var default_params: Variant = defaults.get("arc" if mode == "arc" else "projectile", {})
		params = default_params if default_params is Dictionary else {"range": 8, "speed": 14, "stop_at_hit": true, "stop_at_wall": true}
	var max_range: int = int(params.get("range", 8))
	var speed: float = float(params.get("speed", 14))
	var units: Array[TacticsPawn] = _all_units(actor, battle_level)
	var ray: Dictionary = Targeting.ray_from(actor, direction, max_range, units, Targeting.arena_tile_keys(battle_level), bool(params.get("stop_at_hit", true)), bool(params.get("stop_at_wall", true)))
	var hit_unit: TacticsPawn = ray.get("hit_unit", null) as TacticsPawn
	var landing: Vector3i = ray.get("landing", Vector3i.ZERO)
	var path: Array = ray.get("path", [])
	if path.is_empty():
		_append(battle_log, {"kind": "item_action_rejected", "unit": actor, "item_id": item.item_id, "reason": "no_path", "direction": direction})
		return {"ok": false, "kind": BattleActionIntent.KIND_THROW_ITEM, "reason": "no_path"}
	_append(battle_log, {"kind": "item_throw_started", "unit": actor, "item_id": item.item_id, "direction": direction, "distance": path.size(), "target": hit_unit, "landing": landing, "mode": mode})
	PokemonItemService.consume_held_item(actor.stats, battle_log, "throw")
	var runner: BattlePresentationRunner = battle_level.presentation_runner if battle_level != null else null
	var landing_world: Vector3 = _world_for_key(landing, battle_level, hit_unit)
	if runner != null:
		runner.begin_sequence("item_throw:%s" % item.item_id)
		_enqueue_throw_presentation(runner, actor, item, presentation, throw_spec, direction, landing_world, speed, mode, battle_log)
	var outcome: Dictionary = {}
	if hit_unit != null:
		outcome = _resolve_thrown_hit(actor, hit_unit, item, entry, presentation, throw_spec, battle_level, battle_log)
	else:
		battle_level.land_item(item.item_id, landing, landing_world, "throw_missed", runner != null)
		if runner != null:
			runner.enqueue({"kind": BattlePresentationRunner.KIND_CALLBACK, "callable": Callable(battle_level, "show_landed_item").bind(landing)})
		outcome = {"result": "landed", "tile": landing}
	if runner != null:
		BattleActionPresentation.enqueue_move_end(runner)
	actor.stats.record_move_use("item:%s" % item.item_id, -1)
	return {"ok": true, "kind": BattleActionIntent.KIND_THROW_ITEM, "item_id": item.item_id, "hit_unit": hit_unit, "landing": landing, "outcome": outcome}


func _resolve_thrown_hit(actor: TacticsPawn, target: TacticsPawn, item: PokemonItemResource, entry: Dictionary, presentation: Dictionary, throw_spec: Dictionary, battle_level: TacticsLevel, battle_log: BattleLog) -> Dictionary:
	var catch_result: Dictionary = _catch_decision(actor, target, item, entry, throw_spec)
	if bool(catch_result.get("caught", false)):
		PokemonItemService.give_held_item(target.stats, item, battle_log, "catch")
		_append(battle_log, {"kind": "item_caught", "unit": target, "item_id": item.item_id, "thrower": actor})
		return {"result": "caught", "target": target}
	_append(battle_log, {"kind": "item_hit_unit", "unit": target, "item_id": item.item_id, "thrower": actor, "catch_blocked": String(catch_result.get("reason", ""))})
	if bool(throw_spec.get("default_damage", false)):
		var power: int = int(throw_spec.get("default_damage_power", 30))
		var damage: int = _thrown_default_damage(actor, target, power, battle_level)
		var applied: int = resolver._apply_damage(actor, target, _synthetic_move(item, power), damage, battle_log, {"kind": "damage_dealt", "source": "thrown_item", "item_id": item.item_id})
		_after_damage(actor, target, battle_log, battle_level)
		return {"result": "damage", "amount": applied}
	var effects: Dictionary = _apply_use_event(actor, target, item, presentation, battle_level, battle_log, "throw")
	return {"result": "applied", "effects": effects}


func _catch_decision(actor: TacticsPawn, target: TacticsPawn, item: PokemonItemResource, entry: Dictionary, throw_spec: Dictionary) -> Dictionary:
	if not bool(throw_spec.get("catchable", true)):
		return {"caught": false, "reason": "recruit_item"}
	var target_instance: PokemonInstanceResource = target.stats.pokemon_instance if target.stats != null else null
	if target_instance == null:
		return {"caught": false, "reason": "no_instance"}
	if target_instance.held_item != null:
		return {"caught": false, "reason": "holding_item"}
	var edible: bool = bool(entry.get("edible", false))
	var ammo: bool = bool(entry.get("ammo", false))
	if edible or ammo:
		return {"caught": false, "reason": "wild_team_edible_or_ammo"}
	return {"caught": true, "reason": ""}


func _apply_use_event(actor: TacticsPawn, eater: TacticsPawn, item: PokemonItemResource, presentation: Dictionary, battle_level: TacticsLevel, battle_log: BattleLog, mode: String) -> Dictionary:
	var applied: Array = []
	var excluded: Array = []
	var runner: BattlePresentationRunner = battle_level.presentation_runner if battle_level != null else null
	var use_events: Dictionary = presentation.get("use_events", {}) if presentation.get("use_events", null) is Dictionary else {}
	var on_hits: Array = use_events.get("on_hits", []) if use_events.get("on_hits", null) is Array else []
	var handled_custom: bool = false
	var ordered: Array = on_hits.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Array = a.get("priority", [])
		var pb: Array = b.get("priority", [])
		var ka: int = int(pa[0]) if not pa.is_empty() else 0
		var kb: int = int(pb[0]) if not pb.is_empty() else 0
		if ka != kb:
			return ka < kb
		return int(a.get("entry_order", 0)) < int(b.get("entry_order", 0)))
	if runner != null and presentation.get("use_hit_fx", null) is Dictionary and mode == "use":
		BattleActionPresentation.enqueue_hit_fx(runner, {"assets": presentation.get("assets", {}), "hit_fx": presentation.get("use_hit_fx", {}), "intro_fx": presentation.get("use_intro_fx", [])}, actor, eater, "item:%s" % item.item_id)
	for event in ordered:
		if not (event is Dictionary):
			continue
		var type_name: String = String((event as Dictionary).get("type", ""))
		if EXCLUDED_EVENTS.has(type_name):
			excluded.append({"event": type_name, "reason": EXCLUDED_EVENTS[type_name]})
			_append(battle_log, {"kind": "effect_excluded_by_owner", "unit": eater, "item_id": item.item_id, "source_event": type_name, "component": EXCLUDED_EVENTS[type_name], "decision": "2026-09-02"})
			continue
		if type_name == "InvokeCustomBattleEvent":
			handled_custom = true
			applied.append(_invoke_custom_action(eater, item, event, presentation, battle_level, battle_log))
	if not handled_custom:
		var service_result: Dictionary = PokemonItemService.use_item(item, eater.stats, null, battle_log, {"consume_from_bag": false})
		applied.append({"family": "item_service", "used": bool(service_result.get("used", false)), "effects": service_result.get("effects", []), "unsupported": service_result.get("unsupported", [])})
		if runner != null and eater != actor:
			BattleActionPresentation.enqueue_hit_fx(runner, {"assets": presentation.get("assets", {}), "hit_fx": presentation.get("use_hit_fx", {}), "intro_fx": presentation.get("use_intro_fx", [])}, actor, eater, "item:%s" % item.item_id)
	return {"applied": applied, "excluded": excluded}


func _invoke_custom_action(user: TacticsPawn, item: PokemonItemResource, event: Dictionary, presentation: Dictionary, battle_level: TacticsLevel, battle_log: BattleLog) -> Dictionary:
	var hitbox: Dictionary = event.get("hitbox_action", {}) if event.get("hitbox_action", null) is Dictionary else {}
	var explosion: Dictionary = event.get("explosion", {}) if event.get("explosion", null) is Dictionary else {}
	var new_data: Dictionary = event.get("new_data", {}) if event.get("new_data", null) is Dictionary else {}
	var affect_target: bool = bool(event.get("affect_target", true))
	var runner: BattlePresentationRunner = battle_level.presentation_runner if battle_level != null else null
	var facing: Vector3i = Targeting.facing_direction_8(user)
	var origin: Vector3i = Targeting._tile_key(user.get_tile())
	var units: Array[TacticsPawn] = _all_units(user, battle_level)
	var tile_keys: Dictionary = Targeting.arena_tile_keys(battle_level)
	var hit_tiles: Array[Vector3i] = _custom_action_tiles(hitbox, origin, facing, tile_keys)
	var explosion_range: int = int(explosion.get("range", 0))
	var alignments: int = int(explosion.get("target_alignments", int(hitbox.get("target_alignments", ALIGN_FOE))))
	var affected: Array[TacticsPawn] = []
	for tile in hit_tiles:
		for other in units:
			if other == null or not other.is_alive() or affected.has(other):
				continue
			var other_key: Vector3i = Targeting._tile_key(other.get_tile())
			var distance: int = maxi(absi(other_key.x - tile.x), absi(other_key.z - tile.z))
			if distance > explosion_range:
				continue
			if not _alignment_allows(user, other, alignments):
				continue
			affected.append(other)
	var char_anim: Dictionary = hitbox.get("char_anim", {}) if hitbox.get("char_anim", null) is Dictionary else {}
	var action_name: String = String(char_anim.get("name", ""))
	var chosen_state: String = ""
	if not action_name.is_empty() and action_name != "None":
		chosen_state = resolver.animation_resolver.select_for_source_action(user, action_name, "item:%s" % item.item_id, battle_log, true)
	if runner != null:
		var world_tiles: Array = []
		for tile in hit_tiles:
			world_tiles.append(_world_for_key(tile, battle_level, null))
		if not chosen_state.is_empty():
			runner.enqueue({"kind": BattlePresentationRunner.KIND_ACTOR_ACTION, "pawn": user, "state": chosen_state, "direction": Vector3(float(facing.x), 0.0, float(facing.z))})
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
		var assets: Dictionary = presentation.get("assets", {}) if presentation.get("assets", null) is Dictionary else {}
		for world_tile in world_tiles:
			for key in ["emitter", "tile_emitter"]:
				var emitter: Variant = explosion.get(key, null)
				if emitter is Dictionary and not String((emitter as Dictionary).get("type", "")).begins_with("Empty"):
					runner.enqueue({"kind": BattlePresentationRunner.KIND_VFX, "emitter": emitter, "assets": assets, "origin": world_tile, "dest": world_tile, "dir": Vector3(float(facing.x), 0.0, float(facing.z)), "range_tiles": explosion_range, "label": "item:%s:explosion" % item.item_id})
			var explode_fx: Variant = explosion.get("explode_fx", null)
			if explode_fx is Dictionary and (explode_fx as Dictionary).get("emitter", null) is Dictionary:
				var fx_emitter: Dictionary = (explode_fx as Dictionary)["emitter"]
				if not String(fx_emitter.get("type", "")).begins_with("Empty"):
					runner.enqueue({"kind": BattlePresentationRunner.KIND_VFX, "emitter": fx_emitter, "assets": assets, "origin": world_tile, "dest": world_tile, "dir": Vector3(float(facing.x), 0.0, float(facing.z)), "range_tiles": explosion_range, "label": "item:%s:explode_fx" % item.item_id})
	_append(battle_log, {"kind": "item_custom_action", "unit": user, "item_id": item.item_id, "hitbox": String(hitbox.get("type", "")), "tiles": hit_tiles, "explosion_range": explosion_range, "targets": affected.size(), "actor_state": chosen_state})
	var results: Array = []
	var events: Dictionary = new_data.get("events", {}) if new_data.get("events", null) is Dictionary else {}
	var on_hits: Array = events.get("on_hits", []) if events.get("on_hits", null) is Array else []
	for target in affected:
		for raw in on_hits:
			if not (raw is Dictionary):
				continue
			var hit_event: Dictionary = raw
			var type_name: String = String(hit_event.get("type", ""))
			match type_name:
				"LevelDamageEvent":
					var level_source: TacticsPawn = target if bool(hit_event.get("affect_target", false)) else user
					var level_value: int = maxi(1, level_source.stats.level)
					var amount: int = maxi(1, level_value * int(hit_event.get("numerator", 1)) / maxi(1, int(hit_event.get("denominator", 1))))
					var applied: int = resolver._apply_damage(user, target, _synthetic_move(item, 0), amount, battle_log, {"kind": "damage_dealt", "source": "item_custom_action", "item_id": item.item_id, "source_event": "PMDC.Dungeon.LevelDamageEvent, PMDC"})
					_after_damage(user, target, battle_log, battle_level)
					results.append({"target": target, "family": "level_damage", "amount": applied})
				"DamageFormulaEvent":
					var power: int = _base_power(new_data)
					var damage: int = _thrown_default_damage(user, target, power, battle_level)
					var applied: int = resolver._apply_damage(user, target, _synthetic_move(item, power), damage, battle_log, {"kind": "damage_dealt", "source": "item_custom_action", "item_id": item.item_id})
					_after_damage(user, target, battle_log, battle_level)
					results.append({"target": target, "family": "damage", "amount": applied})
				_:
					if EXCLUDED_EVENTS.has(type_name):
						_append(battle_log, {"kind": "effect_excluded_by_owner", "unit": target, "item_id": item.item_id, "source_event": type_name, "component": EXCLUDED_EVENTS[type_name], "decision": "2026-09-02"})
					else:
						_append(battle_log, {"kind": "effect_unsupported", "unit": target, "item_id": item.item_id, "source_event": type_name, "context": "item_custom_action"})
	for raw in events.get("on_hit_tiles", []) if events.get("on_hit_tiles", null) is Array else []:
		if raw is Dictionary:
			var type_name: String = String((raw as Dictionary).get("type", ""))
			if EXCLUDED_EVENTS.has(type_name):
				_append(battle_log, {"kind": "effect_excluded_by_owner", "unit": user, "item_id": item.item_id, "source_event": type_name, "component": EXCLUDED_EVENTS[type_name], "decision": "2026-09-02"})
	return {"family": "custom_action", "user": user, "tiles": hit_tiles, "targets": affected, "results": results}


func _custom_action_tiles(hitbox: Dictionary, origin: Vector3i, facing: Vector3i, tile_keys: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var type_name: String = String(hitbox.get("type", ""))
	match type_name:
		"AttackAction":
			var coverage: int = int(hitbox.get("wide_angle", 0))
			var front: Vector3i = origin + facing
			if _tile_exists(front, tile_keys):
				out.append(front)
			if coverage >= 2:
				var left: Vector3i = origin + _rotate_dir(facing, -1)
				var right: Vector3i = origin + _rotate_dir(facing, 1)
				for key in [left, right]:
					if _tile_exists(key, tile_keys) and not out.has(key):
						out.append(key)
			if coverage >= 3:
				for step in range(2, 7):
					var key: Vector3i = origin + _rotate_dir(facing, step)
					if _tile_exists(key, tile_keys) and not out.has(key):
						out.append(key)
		"SelfAction":
			out.append(origin)
		"AreaAction":
			var radius: int = int(hitbox.get("range", 1))
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var key: Vector3i = origin + Vector3i(x, 0, z)
					if _tile_exists(key, tile_keys):
						out.append(key)
		_:
			var front: Vector3i = origin + facing
			if _tile_exists(front, tile_keys):
				out.append(front)
	return out


func _rotate_dir(direction: Vector3i, steps: int) -> Vector3i:
	var index: int = Targeting.DIRECTIONS_8.find(direction)
	if index < 0:
		return direction
	return Targeting.DIRECTIONS_8[posmod(index + steps, 8)]


func _tile_exists(key: Vector3i, tile_keys: Dictionary) -> bool:
	return tile_keys.is_empty() or tile_keys.has(key)


func _alignment_allows(user: TacticsPawn, other: TacticsPawn, alignments: int) -> bool:
	if other == user:
		return (alignments & ALIGN_SELF) != 0
	var same_team: bool = Targeting._team_key(user) == Targeting._team_key(other)
	if same_team:
		return (alignments & ALIGN_FRIEND) != 0
	return (alignments & ALIGN_FOE) != 0


func _enqueue_use_action(runner: BattlePresentationRunner, actor: TacticsPawn, presentation: Dictionary, item_id: String, battle_log: BattleLog) -> void:
	var use_action: Dictionary = presentation.get("use_action", {}) if presentation.get("use_action", null) is Dictionary else {}
	var char_anim: Dictionary = use_action.get("char_anim", {}) if use_action.get("char_anim", null) is Dictionary else {}
	var kind: String = String(char_anim.get("kind", "none"))
	var action_name: String = ""
	if kind == "frame_type":
		action_name = String(char_anim.get("name", ""))
	elif kind == "process":
		action_name = String(char_anim.get("anim_override_name", ""))
	if action_name.is_empty() or action_name == "None":
		runner.enqueue({"kind": BattlePresentationRunner.KIND_LOG, "event": {"kind": "item_use_pose", "unit": actor, "item_id": item_id, "source_process": "None"}})
		return
	var state: String = resolver.animation_resolver.select_for_source_action(actor, action_name, "item:%s" % item_id, battle_log, true)
	if not state.is_empty():
		runner.enqueue({"kind": BattlePresentationRunner.KIND_ACTOR_ACTION, "pawn": actor, "state": state})
		runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})


func _enqueue_throw_presentation(runner: BattlePresentationRunner, actor: TacticsPawn, item: PokemonItemResource, presentation: Dictionary, throw_spec: Dictionary, direction: Vector3i, landing_world: Vector3, speed: float, mode: String, battle_log: BattleLog) -> void:
	var world_dir: Vector3 = Vector3(float(direction.x), 0.0, float(direction.z))
	runner.enqueue({"kind": BattlePresentationRunner.KIND_FACE, "pawn": actor, "direction": world_dir})
	var char_anim: Dictionary = throw_spec.get("char_anim", {}) if throw_spec.get("char_anim", null) is Dictionary else {}
	var action_name: String = String(char_anim.get("name", "Rotate"))
	var state: String = resolver.animation_resolver.select_for_source_action(actor, action_name, "item:%s" % item.item_id, battle_log, true)
	if not state.is_empty():
		runner.enqueue({"kind": BattlePresentationRunner.KIND_ACTOR_ACTION, "pawn": actor, "state": state, "direction": world_dir})
		runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
	var assets: Dictionary = presentation.get("assets", {}) if presentation.get("assets", null) is Dictionary else {}
	var throw_anim: Dictionary = presentation.get("throw_anim", {}) if presentation.get("throw_anim", null) is Dictionary else {}
	var anim_index: String = String(throw_anim.get("index", ""))
	var asset: Dictionary = {}
	if not anim_index.is_empty():
		asset = presentation_catalog.asset(presentation, "particle", anim_index)
	if asset.is_empty():
		asset = presentation_catalog.asset(presentation, "item", item.sprite_key)
		anim_index = item.sprite_key
	if asset.is_empty() and not item.icon_path.is_empty():
		asset = {"category": "Item", "key": item.sprite_key, "path": item.icon_path, "layout": {"kind": "None", "rotate": "None", "cell": [16, 16], "frames": 1, "rows": 1}}
	runner.enqueue({
		"kind": BattlePresentationRunner.KIND_PROJECTILE,
		"from": BattleActionPresentation._launch_point(actor),
		"to": landing_world,
		"speed": maxf(speed, 1.0),
		"dir": world_dir,
		"asset": asset,
		"anim": {"index": anim_index, "frame_time": int(throw_anim.get("frame_time", 1)), "start_frame": -1, "end_frame": -1},
		"arc_height": 1.0 if mode == "arc" else 0.35,
		"loc_height": 10,
		"label": "item:%s:throw" % item.item_id,
		"block": true,
	})


func _thrown_default_damage(user: TacticsPawn, target: TacticsPawn, power: int, battle_level: TacticsLevel) -> int:
	var rng: RandomNumberGenerator = battle_level.battle_rng if battle_level != null else RandomNumberGenerator.new()
	var type_chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else null
	var move: PokemonMoveResource = _synthetic_move(null, power)
	return damage_resolver.calculate_damage(user.stats, target.stats, move, 1.0, false, 1.0, rng, {})


func _synthetic_move(item: PokemonItemResource, power: int) -> PokemonMoveResource:
	var move := PokemonMoveResource.new()
	move.move_id = "item:%s" % (item.item_id if item != null else "thrown")
	move.name = item.display_name() if item != null else "Thrown item"
	move.type = "none"
	move.category = PokemonMoveResource.CATEGORY_PHYSICAL
	move.base_power = power
	move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	move.tactical_range_kind = PokemonMoveResource.TacticalRangeKind.PROJECTILE
	move.target_alignment = ALIGN_FRIEND | ALIGN_FOE | ALIGN_SELF
	return move


func _base_power(new_data: Dictionary) -> int:
	for state in new_data.get("skill_states", []):
		if state is Dictionary and String((state as Dictionary).get("type", "")) == "BasePowerState":
			return int((state as Dictionary).get("power", 0))
	return 0


func _after_damage(user: TacticsPawn, target: TacticsPawn, battle_log: BattleLog, battle_level: TacticsLevel) -> void:
	if target != null and target.stats != null and not target.stats.is_active():
		_append(battle_log, {"kind": "unit_fainted", "unit": target, "source": "item"})
		resolver.animation_resolver.select_reaction(target, _synthetic_move(null, 0), "faint", battle_log)


func _world_for_key(key: Vector3i, battle_level: TacticsLevel, unit: TacticsPawn) -> Vector3:
	if unit != null and is_instance_valid(unit):
		return unit.global_position
	var tiles: Dictionary = Targeting.arena_tile_keys(battle_level)
	var tile: Variant = tiles.get(key, null)
	if tile is TacticsTile:
		return (tile as TacticsTile).global_position
	return Vector3(float(key.x), 0.0, float(key.z))


func _all_units(actor: TacticsPawn, battle_level: TacticsLevel) -> Array[TacticsPawn]:
	return resolver._all_units_for(actor, battle_level)


func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
