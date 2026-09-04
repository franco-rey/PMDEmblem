class_name MoveVFXPlayer
extends Node3D

const LEGACY_LIFETIME: float = 0.6

const MOVE_VFX_MAP: Dictionary = {
	"aura_sphere": {"asset_path": "res://assets/visuals/raw_asset/Particle/Aura_Sphere_Shot.Dir8.png", "anchor": "path", "kind": "particle", "hit_frame": 0},
	"confusion": {"asset_path": "res://assets/visuals/raw_asset/Particle/Confuse_Ray.None.png", "anchor": "target", "kind": "particle", "hit_frame": 0},
	"hyper_beam": {"asset_path": "res://assets/visuals/raw_asset/Beam/Beam/Body.png", "anchor": "path", "kind": "beam", "hit_frame": 0},
	"lava_plume": {"asset_path": "res://assets/visuals/raw_asset/Particle/Lava_Plume_Fire.None.png", "anchor": "target", "kind": "particle", "hit_frame": 0},
	"mud_slap": {"asset_path": "res://assets/visuals/raw_asset/Particle/Mud.None.png", "anchor": "target", "kind": "particle", "hit_frame": 0},
	"protect": {"asset_path": "res://assets/visuals/raw_asset/Particle/Protect.None.png", "anchor": "source", "kind": "particle", "hit_frame": 0},
	"psycho_cut": {"asset_path": "res://assets/visuals/raw_asset/Particle/Psycho_Cut_Shot.Dir8.png", "anchor": "path", "kind": "particle", "hit_frame": 0},
	"smokescreen": {"asset_path": "res://assets/visuals/raw_asset/Particle/Smoke_Black.None.png", "anchor": "target", "kind": "particle", "hit_frame": 0},
	"thunder_punch": {"asset_path": "res://assets/visuals/raw_asset/Particle/Spark.None.png", "anchor": "target", "kind": "particle", "hit_frame": 0},
	"water_gun": {"asset_path": "res://assets/visuals/raw_asset/Particle/Water_Spout_Drop.None.png", "anchor": "path", "kind": "particle", "hit_frame": 0},
}


func config_for_move(move_id: String) -> Dictionary:
	return (MOVE_VFX_MAP.get(move_id, {}) as Dictionary).duplicate(true)


func play_for_move(move: PokemonMoveResource, source: Node3D, target: Node3D, battle_log: BattleLog = null) -> Node3D:
	var move_id: String = move.move_id if move != null else ""
	var config: Dictionary = config_for_move(move_id)
	if config.is_empty():
		_append(battle_log, {"kind": "move_vfx_skipped", "move_id": move_id, "reason": "unmapped"})
		return null
	var texture: Texture2D = load(String(config.get("asset_path", ""))) as Texture2D
	if texture == null:
		_append(battle_log, {"kind": "move_vfx_skipped", "move_id": move_id, "reason": "missing_asset", "asset_path": config.get("asset_path", "")})
		return null
	var sprite := Sprite3D.new()
	sprite.name = "MoveVFX_%s" % move_id
	sprite.texture = texture
	sprite.position = _anchor_position(String(config.get("anchor", "target")), source, target)
	sprite.set_meta("move_id", move_id)
	sprite.set_meta("asset_path", String(config.get("asset_path", "")))
	sprite.set_meta("anchor", String(config.get("anchor", "target")))
	sprite.set_meta("hit_frame", int(config.get("hit_frame", 0)))
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.04
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_schedule_release(sprite, LEGACY_LIFETIME)
	_append(battle_log, {
		"kind": "move_vfx_spawned",
		"move_id": move_id,
		"asset_path": config.get("asset_path", ""),
		"anchor": config.get("anchor", "target"),
		"hit_frame": int(config.get("hit_frame", 0)),
	})
	return sprite


func release_vfx(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _schedule_release(node: Node, seconds: float) -> void:
	if node == null or not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void: release_vfx(node))


func coverage_report() -> Dictionary:
	var moves: Array[String] = []
	for key in MOVE_VFX_MAP.keys():
		moves.append(String(key))
	moves.sort()
	return {
		"mapped_move_count": moves.size(),
		"mapped_moves": moves,
		"schema_version": 1,
		"source": "MoveVFXPlayer",
	}


func _anchor_position(anchor: String, source: Node3D, target: Node3D) -> Vector3:
	var source_pos: Vector3 = source.global_position if source != null and source.is_inside_tree() else (source.position if source != null else Vector3.ZERO)
	var target_pos: Vector3 = target.global_position if target != null and target.is_inside_tree() else (target.position if target != null else source_pos)
	match anchor:
		"source":
			return source_pos
		"path":
			return source_pos.lerp(target_pos, 0.5)
		_:
			return target_pos


func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
