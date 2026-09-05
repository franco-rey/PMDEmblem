class_name BattleActionPresentation
extends RefCounted

const DEFAULT_PROJECTILE_SPEED: float = 10.0
const DEFAULT_HURT_SECONDS: float = 0.5
const DEFAULT_FAINT_SECONDS: float = 0.8
const LUNGE_DISTANCE: float = 0.5


static func enqueue_move_start(runner: BattlePresentationRunner, attacker: TacticsPawn, declared_target: TacticsPawn, targets: Array, move: PokemonMoveResource, entry: Dictionary, chosen_state: String, battle_log: BattleLog) -> Dictionary:
	var summary: Dictionary = {"cues": 0, "hitbox_type": "", "projectile": false, "emitters": 0}
	if runner == null or attacker == null:
		return summary
	var hitbox: Dictionary = entry.get("hitbox", {}) if entry.get("hitbox", null) is Dictionary else {}
	var assets: Dictionary = entry.get("assets", {}) if entry.get("assets", null) is Dictionary else {}
	var hitbox_type: String = String(hitbox.get("type", ""))
	summary["hitbox_type"] = hitbox_type
	var origin: Vector3 = attacker.global_position
	var target_pos: Vector3 = declared_target.global_position if declared_target != null and is_instance_valid(declared_target) else origin
	var direction: Vector3 = target_pos - origin
	direction.y = 0.0
	if direction.length() < 0.001:
		direction = -attacker.global_basis.z if attacker.is_inside_tree() else Vector3.FORWARD
	var label: String = move.move_id if move != null else "action"
	var catalog: ActorActionCatalog = ActorActionCatalog.shared()
	var char_anim: Dictionary = hitbox.get("char_anim", {}) if hitbox.get("char_anim", null) is Dictionary else {}
	var action_name: String = String(char_anim.get("name", ""))
	var is_dash_action: bool = hitbox_type == "DashAction" or (not action_name.is_empty() and catalog.is_dash(action_name))

	runner.begin_sequence(label)
	if declared_target != attacker and direction.length() > 0.001:
		runner.enqueue({"kind": BattlePresentationRunner.KIND_FACE, "pawn": attacker, "direction": direction})
	for fx in hitbox.get("pre_actions", []):
		_enqueue_fx(runner, fx, assets, origin, target_pos, direction, attacker, 0, 0.0, label + ":pre")
	if not chosen_state.is_empty():
		runner.enqueue({
			"kind": BattlePresentationRunner.KIND_ACTOR_ACTION,
			"pawn": attacker,
			"state": chosen_state,
			"direction": direction,
			"lunge": is_dash_action and hitbox_type != "DashAction",
			"lunge_distance": LUNGE_DISTANCE,
		})
		summary["cues"] = int(summary["cues"]) + 1
	var action_fx: Variant = hitbox.get("action_fx", null)
	var range_tiles: int = int(hitbox.get("range", 0))
	match hitbox_type:
		"ProjectileAction", "ThrowAction":
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
			if action_fx is Dictionary:
				_enqueue_fx(runner, action_fx, assets, origin, target_pos, direction, attacker, range_tiles, 0.0, label + ":action")
			var stream_emitter: Variant = hitbox.get("stream_emitter", null)
			if stream_emitter is Dictionary:
				summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, stream_emitter, assets, _launch_point(attacker), target_pos, direction, attacker, range_tiles, 0.0, label + ":stream")
			var anim: Dictionary = hitbox.get("anim", {}) if hitbox.get("anim", null) is Dictionary else {}
			var anim_index: String = String(anim.get("index", ""))
			var asset: Dictionary = _asset(assets, anim_index)
			var item_sprite: String = String(hitbox.get("item_sprite", ""))
			if asset.is_empty() and not item_sprite.is_empty():
				asset = _asset(assets, item_sprite)
			var landing: Vector3 = _projectile_landing(attacker, declared_target, targets, direction, range_tiles, hitbox_type == "ThrowAction")
			var speed: float = float(hitbox.get("speed", DEFAULT_PROJECTILE_SPEED))
			if speed <= 0.0:
				speed = DEFAULT_PROJECTILE_SPEED
			if not asset.is_empty():
				runner.enqueue({
					"kind": BattlePresentationRunner.KIND_PROJECTILE,
					"from": _launch_point(attacker),
					"to": landing,
					"speed": speed,
					"dir": direction,
					"asset": asset,
					"anim": anim if not anim_index.is_empty() else {"index": item_sprite, "frame_time": 1, "start_frame": -1, "end_frame": -1},
					"arc_height": 0.9 if hitbox_type == "ThrowAction" else 0.0,
					"label": label + ":projectile",
					"block": true,
				})
				summary["projectile"] = true
			else:
				runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT, "seconds": clampf((landing - origin).length() / speed, 0.0, 1.5)})
				if not anim_index.is_empty():
					runner.enqueue({"kind": BattlePresentationRunner.KIND_LOG, "event": {"kind": "vfx_skipped", "label": label, "anim": anim_index, "reason": "missing_asset"}})
			var emitter: Variant = hitbox.get("emitter", null)
			if emitter is Dictionary:
				summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, emitter, assets, landing, landing, direction, null, range_tiles, 0.0, label + ":emitter")
			var tile_emitter: Variant = hitbox.get("tile_emitter", null)
			if tile_emitter is Dictionary:
				if hitbox_type == "ThrowAction":
					summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, tile_emitter, assets, landing, landing, direction, null, 0, 0.0, label + ":tile", clampf((landing - origin).length() / speed, 0.0, 1.5))
				else:
					summary["emitters"] = int(summary["emitters"]) + _enqueue_path_emitters(runner, tile_emitter, assets, origin, landing, direction, speed, label + ":tile")
		"WaveMotionAction":
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
			var anim: Dictionary = hitbox.get("anim", {}) if hitbox.get("anim", null) is Dictionary else {}
			var anim_index: String = String(anim.get("index", ""))
			var beam_asset: Dictionary = _asset(assets, anim_index)
			var landing: Vector3 = _projectile_landing(attacker, declared_target, targets, direction, range_tiles, false)
			var speed: float = maxf(float(hitbox.get("speed", DEFAULT_PROJECTILE_SPEED)), 0.5)
			var seconds: float = clampf((landing - origin).length() / speed + 0.35, 0.3, 2.0)
			if not anim_index.is_empty():
				runner.enqueue({"kind": BattlePresentationRunner.KIND_CALLBACK, "callable": Callable(BattleActionPresentation, "_play_beam").bind(runner, beam_asset, origin, landing, direction, int(anim.get("frame_time", 3)), seconds, label)})
			for key in ["emitter", "tile_emitter"]:
				var wave_emitter: Variant = hitbox.get(key, null)
				if wave_emitter is Dictionary:
					summary["emitters"] = int(summary["emitters"]) + _enqueue_path_emitters(runner, wave_emitter, assets, origin, landing, direction, speed, label + ":" + key)
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT, "seconds": clampf((landing - origin).length() / speed, 0.05, 1.5)})
		"DashAction":
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_RUSH})
			var dash_anim: Dictionary = hitbox.get("anim", {}) if hitbox.get("anim", null) is Dictionary else {}
			if not String(dash_anim.get("index", "")).is_empty():
				var attached: Dictionary = {
					"type": "AttachAreaEmitter",
					"anims": [{"type": "StaticAnim", "anim": dash_anim, "cycles": 0, "total_time": 27}],
					"particles_per_burst": 1,
					"burst_time": 60,
					"range": 0,
					"layer": 2,
					"loc_height": 8,
					"add_height": 0,
				}
				summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, attached, assets, origin, target_pos, direction, attacker, 0, 0.45, label + ":dash_anim")
			var emitter: Variant = hitbox.get("emitter", null)
			if emitter is Dictionary:
				summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, emitter, assets, origin, target_pos, direction, attacker, range_tiles, 0.4, label + ":dash")
			var dash_tile_emitter: Variant = hitbox.get("tile_emitter", null)
			if dash_tile_emitter is Dictionary:
				summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, dash_tile_emitter, assets, origin, target_pos, direction, attacker, maxi(range_tiles, 1), 0.4, label + ":tile")
			runner.enqueue({"kind": BattlePresentationRunner.KIND_LUNGE, "pawn": attacker, "direction": direction, "rush": 0.0, "hit": 0.18, "return": 0.3, "total": 0.45, "distance": minf((target_pos - origin).length() * 0.6, 1.2)})
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
			if action_fx is Dictionary:
				_enqueue_fx(runner, action_fx, assets, origin, target_pos, direction, attacker, range_tiles, 0.0, label + ":action")
		"AreaAction", "OffsetAction":
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
			if action_fx is Dictionary:
				_enqueue_fx(runner, action_fx, assets, origin, target_pos, direction, attacker, range_tiles, 0.0, label + ":action")
			var center: Vector3 = origin if hitbox_type == "AreaAction" else target_pos
			for key in ["emitter", "tile_emitter"]:
				var emitter: Variant = hitbox.get(key, null)
				if emitter is Dictionary:
					summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, emitter, assets, center, target_pos, direction, attacker, maxi(range_tiles, 1), 0.0, label + ":" + key)
		"SelfAction":
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
			if action_fx is Dictionary:
				_enqueue_fx(runner, action_fx, assets, origin, origin, direction, attacker, 0, 0.0, label + ":action")
			var tile_emitter: Variant = hitbox.get("tile_emitter", null)
			if tile_emitter is Dictionary:
				summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, tile_emitter, assets, origin, origin, direction, attacker, 0, 0.0, label + ":tile")
		_:
			runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_HIT})
			if action_fx is Dictionary:
				_enqueue_fx(runner, action_fx, assets, origin, target_pos, direction, attacker, 0, 0.0, label + ":action")
			for key in ["emitter", "tile_emitter"]:
				var emitter: Variant = hitbox.get(key, null)
				if emitter is Dictionary:
					summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, emitter, assets, origin + _flat(direction) * 0.5, target_pos, direction, attacker, 0, 0.0, label + ":" + key)
	var explosion: Dictionary = entry.get("explosion", {}) if entry.get("explosion", null) is Dictionary else {}
	if not explosion.is_empty():
		var explosion_range: int = int(explosion.get("range", 0))
		var explosion_center: Vector3 = target_pos if hitbox_type in ["ProjectileAction", "ThrowAction", "OffsetAction", "AttackAction", "DashAction", "WaveMotionAction"] else origin
		for fx in explosion.get("intro_fx", []):
			_enqueue_fx(runner, fx, assets, explosion_center, target_pos, direction, null, explosion_range, 0.0, label + ":explosion_intro")
		for key in ["emitter", "tile_emitter"]:
			var emitter: Variant = explosion.get(key, null)
			if emitter is Dictionary:
				summary["emitters"] = int(summary["emitters"]) + _enqueue_emitter(runner, emitter, assets, explosion_center, target_pos, direction, null, explosion_range, 0.0, label + ":explosion")
		var explode_fx: Variant = explosion.get("explode_fx", null)
		if explode_fx is Dictionary:
			_enqueue_fx(runner, explode_fx, assets, explosion_center, target_pos, direction, null, explosion_range, 0.0, label + ":explode")
	if battle_log != null:
		battle_log.append({"kind": "presentation_scripted", "move_id": label, "hitbox": hitbox_type, "actor_state": chosen_state, "projectile": summary["projectile"], "emitters": summary["emitters"]})
	return summary


static func enqueue_hit_fx(runner: BattlePresentationRunner, entry: Dictionary, attacker: TacticsPawn, target: TacticsPawn, label: String) -> void:
	if runner == null or target == null or entry.is_empty():
		return
	var assets: Dictionary = entry.get("assets", {}) if entry.get("assets", null) is Dictionary else {}
	var origin: Vector3 = target.global_position
	var user_pos: Vector3 = attacker.global_position if attacker != null and is_instance_valid(attacker) else origin
	var direction: Vector3 = origin - user_pos
	direction.y = 0.0
	if direction.length() < 0.001:
		direction = -target.global_basis.z if target.is_inside_tree() else Vector3.FORWARD
	for fx in entry.get("intro_fx", []):
		_enqueue_fx(runner, fx, assets, origin, user_pos, direction, target, 0, 0.0, label + ":intro")
	var hit_fx: Variant = entry.get("hit_fx", null)
	if hit_fx is Dictionary:
		_enqueue_fx(runner, hit_fx, assets, origin, user_pos, direction, target, 0, 0.0, label + ":hit")


static func enqueue_reaction(runner: BattlePresentationRunner, pawn: TacticsPawn, state: String, duration: float, block: bool = false) -> void:
	if runner == null or pawn == null:
		return
	runner.enqueue({"kind": BattlePresentationRunner.KIND_REACTION, "pawn": pawn, "state": state, "duration": duration, "block": block})


static func enqueue_move_end(runner: BattlePresentationRunner) -> void:
	if runner == null:
		return
	runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT_UNTIL_DONE})
	runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT, "seconds": 0.15})
	runner.end_sequence()


static func _enqueue_fx(runner: BattlePresentationRunner, fx: Variant, assets: Dictionary, origin: Vector3, dest: Vector3, direction: Vector3, attach: Node3D, range_tiles: int, duration: float, label: String) -> void:
	if not (fx is Dictionary):
		return
	var dict: Dictionary = fx
	var delay_frames: int = int(dict.get("delay", 0))
	if delay_frames > 0:
		runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT, "seconds": float(delay_frames) / 60.0})
	var emitter: Variant = dict.get("emitter", null)
	if emitter is Dictionary:
		_enqueue_emitter(runner, emitter, assets, origin, dest, direction, attach, range_tiles, duration, label)
	var movement: Variant = dict.get("screen_movement", null)
	if movement is Dictionary and float((movement as Dictionary).get("max_shake", 0)) > 0.0:
		runner.enqueue({"kind": BattlePresentationRunner.KIND_VFX, "shake": movement, "label": label + ":shake"})


static func _enqueue_emitter(runner: BattlePresentationRunner, emitter: Dictionary, assets: Dictionary, origin: Vector3, dest: Vector3, direction: Vector3, attach: Node3D, range_tiles: int, duration: float, label: String, delay: float = 0.0) -> int:
	var type_name: String = String(emitter.get("type", ""))
	if type_name.is_empty() or type_name.begins_with("Empty"):
		return 0
	runner.enqueue({
		"kind": BattlePresentationRunner.KIND_VFX,
		"emitter": emitter,
		"assets": assets,
		"origin": origin,
		"dest": dest,
		"dir": direction,
		"attach": attach,
		"range_tiles": range_tiles,
		"duration": duration,
		"delay": delay,
		"label": label,
	})
	return 1


static func _enqueue_path_emitters(runner: BattlePresentationRunner, emitter: Dictionary, assets: Dictionary, origin: Vector3, landing: Vector3, direction: Vector3, speed: float, label: String) -> int:
	var flat: Vector3 = _flat(direction)
	var steps: int = clampi(int(round((landing - origin).length())), 1, 8)
	if flat.length() < 0.001:
		return _enqueue_emitter(runner, emitter, assets, landing, landing, direction, null, 0, 0.0, label)
	var count: int = 0
	for step in range(1, steps + 1):
		var pos: Vector3 = origin + flat * float(step)
		count += _enqueue_emitter(runner, emitter, assets, pos, pos, direction, null, 0, 0.0, label, clampf(float(step) / maxf(speed, 0.5), 0.0, 1.5))
	return count


static func _play_beam(runner: BattlePresentationRunner, asset: Dictionary, from: Vector3, to: Vector3, direction: Vector3, frame_time: int, seconds: float, label: String) -> void:
	if runner == null or runner.vfx_player == null:
		return
	if asset.is_empty():
		runner.vfx_player._append({"kind": "vfx_skipped", "label": label, "reason": "missing_beam_asset"})
		return
	runner.vfx_player.play_beam(asset, from, to, direction, frame_time, seconds, label)


static func _projectile_landing(attacker: TacticsPawn, declared_target: TacticsPawn, targets: Array, direction: Vector3, range_tiles: int, arc: bool) -> Vector3:
	var origin: Vector3 = attacker.global_position
	if declared_target != null and is_instance_valid(declared_target):
		return declared_target.global_position
	for target in targets:
		if target is TacticsPawn and is_instance_valid(target):
			return (target as TacticsPawn).global_position
	var flat: Vector3 = _flat(direction)
	return origin + flat * float(maxi(range_tiles, 1))


static func _launch_point(attacker: TacticsPawn) -> Vector3:
	var sprite: TacticsPawnSprite = attacker.get_node_or_null("Character") as TacticsPawnSprite
	if sprite != null and not sprite.anchors.is_empty():
		var point: Vector3 = sprite.action_point_world("center")
		return Vector3(attacker.global_position.x, point.y, attacker.global_position.z)
	return attacker.global_position + Vector3.UP * 0.4


static func _asset(assets: Dictionary, index: String) -> Dictionary:
	if index.is_empty():
		return {}
	for prefix in ["particle:", "beam:", "item:"]:
		var record: Variant = assets.get(prefix + index, null)
		if record is Dictionary:
			return record
	return {}


static func _flat(direction: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	return flat.normalized() if flat.length() > 0.001 else Vector3.ZERO
