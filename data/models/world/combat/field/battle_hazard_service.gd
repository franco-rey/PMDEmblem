class_name BattleHazardService
extends RefCounted

const RULES: Dictionary = {
	"spikes": {"max_layers": 3, "grounded": true, "color": Color(0.55, 0.55, 0.6)},
	"toxic_spikes": {"max_layers": 2, "grounded": true, "color": Color(0.6, 0.25, 0.7)},
	"stealth_rock": {"max_layers": 1, "grounded": false, "color": Color(0.5, 0.36, 0.22)},
	"sticky_web": {"max_layers": 1, "grounded": true, "color": Color(0.95, 0.95, 0.9, 0.65)},
}
const SPIKE_FRACTIONS: Array[int] = [8, 6, 4]

var battle_level: TacticsLevel = null
var tiles: Dictionary = {}
var markers: Dictionary = {}


func _init(level: TacticsLevel) -> void:
	battle_level = level


static func key_for_position(position: Vector3) -> Vector3i:
	return Vector3i(floori(position.x + 0.5), 0, floori(position.z + 0.5))


func strip_keys(source: TacticsPawn, tile_keys: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if source == null or source.get_tile() == null:
		return out
	var facing: Vector3i = TacticsPawnMovementService.snap_direction_8(Vector3.FORWARD.rotated(Vector3.UP, source.rotation.y - PI))
	if facing == Vector3i.ZERO:
		facing = Vector3i(0, 0, 1)
	var origin: Vector3i = Targeting._tile_key(source.get_tile())
	var front: Vector3i = origin + facing
	var perpendicular: Vector3i = Vector3i(facing.z, 0, -facing.x)
	for offset in [-1, 0, 1]:
		var key: Vector3i = front + perpendicular * offset
		if tile_keys.has(key):
			out.append(key)
	return out


func place(source: TacticsPawn, hazard_id: String, battle_log: BattleLog) -> Array[Vector3i]:
	var placed: Array[Vector3i] = []
	if not RULES.has(hazard_id) or source == null:
		return placed
	var tile_keys: Dictionary = Targeting.arena_tile_keys(battle_level)
	var rule: Dictionary = RULES[hazard_id]
	for key in strip_keys(source, tile_keys):
		var entry: Dictionary = tiles.get(key, {})
		var current: Dictionary = entry.get(hazard_id, {})
		var layers: int = int(current.get("layers", 0))
		if layers >= int(rule["max_layers"]):
			continue
		entry[hazard_id] = {"layers": layers + 1, "source": source}
		tiles[key] = entry
		placed.append(key)
		_refresh_marker(key, hazard_id, layers + 1, tile_keys[key])
	if battle_log != null:
		battle_log.append({"kind": "hazard_placed", "unit": source, "hazard_id": hazard_id, "tiles": placed, "count": placed.size()})
	return placed


func threatens(pawn: TacticsPawn, key: Vector3i) -> bool:
	if pawn == null or not tiles.has(key) or battle_level == null:
		return false
	for hazard_id in (tiles[key] as Dictionary).keys():
		var source: Variant = (tiles[key] as Dictionary)[hazard_id].get("source", null)
		if source is TacticsPawn and is_instance_valid(source) and battle_level.are_foes(pawn, source):
			return true
	return false


func layers_at(key: Vector3i, hazard_id: String) -> int:
	return int((tiles.get(key, {}) as Dictionary).get(hazard_id, {}).get("layers", 0))


func on_pawn_reached(pawn: TacticsPawn, position: Vector3) -> void:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active() or battle_level == null:
		return
	if PokemonItemService.ignores_hazards(pawn.stats):
		return
	var key: Vector3i = key_for_position(position)
	if not tiles.has(key):
		return
	var entry: Dictionary = tiles[key]
	for hazard_id in entry.keys():
		var data: Dictionary = entry[hazard_id]
		var source: Variant = data.get("source", null)
		if source is TacticsPawn and is_instance_valid(source) and not battle_level.are_foes(pawn, source):
			continue
		_trigger(pawn, String(hazard_id), int(data.get("layers", 1)), source if source is TacticsPawn and is_instance_valid(source) else null, key)
		if not pawn.stats.is_active():
			return


func clear(source: TacticsPawn, foes_only: bool, battle_log: BattleLog, move_id: String) -> int:
	var removed: int = 0
	for key in tiles.keys():
		var entry: Dictionary = tiles[key]
		for hazard_id in entry.keys():
			var owner: Variant = (entry[hazard_id] as Dictionary).get("source", null)
			if foes_only and owner is TacticsPawn and is_instance_valid(owner) and not battle_level.are_foes(source, owner):
				continue
			entry.erase(hazard_id)
			_remove_marker(key, String(hazard_id))
			removed += 1
		if entry.is_empty():
			tiles.erase(key)
	if removed > 0 and battle_log != null:
		battle_log.append({"kind": "hazards_cleared", "unit": source, "move_id": move_id, "count": removed})
	return removed


func _trigger(pawn: TacticsPawn, hazard_id: String, layers: int, source: TacticsPawn, key: Vector3i) -> void:
	var rule: Dictionary = RULES[hazard_id]
	var ops: BattleStateOps = battle_level._ops()
	var log: BattleLog = battle_level.battle_log
	if bool(rule["grounded"]) and not _is_grounded(pawn):
		return
	match hazard_id:
		"spikes":
			var fraction: int = SPIKE_FRACTIONS[clampi(layers, 1, 3) - 1]
			ops.damage(pawn, maxi(1, int(floor(float(pawn.stats.max_health) / float(fraction)))), {"kind": "status_tick", "status_id": "spikes", "attacker": source})
		"toxic_spikes":
			if pawn.stats.types.has("poison"):
				_remove_hazard(key, hazard_id)
				log.append({"kind": "hazard_absorbed", "unit": pawn, "hazard_id": hazard_id})
				return
			ops.apply_status(pawn, "poison_toxic" if layers >= 2 else "poison", {"source": "toxic_spikes"}, {"kind": "status", "attacker": source, "source": "toxic_spikes"})
		"stealth_rock":
			var chart: TypeChartResource = battle_level.get_type_chart()
			var type_a: String = pawn.stats.types[0] if pawn.stats.types.size() > 0 else "none"
			var type_b: String = pawn.stats.types[1] if pawn.stats.types.size() > 1 else "none"
			var effectiveness: float = chart.get_effectiveness_dual("rock", type_a, type_b) if chart != null else 1.0
			var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) * effectiveness / 8.0)))
			ops.damage(pawn, amount, {"kind": "status_tick", "status_id": "stealth_rock", "attacker": source})
		"sticky_web":
			ops.change_stat_stage(pawn, "speed", -1, {"kind": "status", "attacker": source, "event": {"source": "sticky_web"}})
	log.append({"kind": "hazard_triggered", "unit": pawn, "hazard_id": hazard_id, "layers": layers})


func _is_grounded(pawn: TacticsPawn) -> bool:
	if PokemonItemService.grounds_holder(pawn.stats):
		return true
	if PokemonItemService.floats(pawn.stats):
		return false
	if pawn.stats.types.has("flying"):
		return false
	if pawn.stats.battle_statuses.has("magnet_rise") or pawn.stats.battle_statuses.has("telekinesis"):
		return false
	if battle_level.intrinsic_service != null and battle_level.intrinsic_service.intrinsic_slugs_for(pawn.stats).has("levitate"):
		return false
	return true


func _remove_hazard(key: Vector3i, hazard_id: String) -> void:
	var entry: Dictionary = tiles.get(key, {})
	entry.erase(hazard_id)
	if entry.is_empty():
		tiles.erase(key)
	else:
		tiles[key] = entry
	_remove_marker(key, hazard_id)


func _refresh_marker(key: Vector3i, hazard_id: String, layers: int, tile: TacticsTile) -> void:
	_remove_marker(key, hazard_id)
	if tile == null:
		return
	var marker: Node3D = _build_marker(hazard_id, layers)
	marker.name = "Hazard_%s" % hazard_id
	tile.add_child(marker)
	var per_tile: Dictionary = markers.get(key, {})
	per_tile[hazard_id] = marker
	markers[key] = per_tile


func _remove_marker(key: Vector3i, hazard_id: String) -> void:
	var per_tile: Dictionary = markers.get(key, {})
	var marker: Variant = per_tile.get(hazard_id, null)
	if marker is Node and is_instance_valid(marker):
		var parent: Node = (marker as Node).get_parent()
		if parent != null:
			parent.remove_child(marker)
		(marker as Node).queue_free()
	per_tile.erase(hazard_id)
	if per_tile.is_empty():
		markers.erase(key)
	else:
		markers[key] = per_tile


func _build_marker(hazard_id: String, layers: int) -> Node3D:
	var root := Node3D.new()
	var color: Color = RULES[hazard_id]["color"]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match hazard_id:
		"spikes", "toxic_spikes":
			var count: int = 3 * layers
			for i in range(count):
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.045
				cone.height = 0.16
				var mesh := MeshInstance3D.new()
				mesh.mesh = cone
				mesh.material_override = material
				var angle: float = TAU * float(i) / float(count)
				var radius: float = 0.16 if i % 2 == 0 else 0.28
				mesh.position = Vector3(cos(angle) * radius, 0.08, sin(angle) * radius)
				root.add_child(mesh)
		"stealth_rock":
			for i in range(4):
				var box := BoxMesh.new()
				box.size = Vector3(0.09, 0.09, 0.09)
				var mesh := MeshInstance3D.new()
				mesh.mesh = box
				mesh.material_override = material
				var angle: float = TAU * float(i) / 4.0 + 0.4
				mesh.position = Vector3(cos(angle) * 0.26, 0.32 + 0.05 * float(i % 2), sin(angle) * 0.26)
				mesh.rotation = Vector3(0.6, angle, 0.4)
				root.add_child(mesh)
		"sticky_web":
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.82, 0.82)
			var mesh := MeshInstance3D.new()
			mesh.mesh = plane
			mesh.material_override = material
			mesh.position = Vector3(0.0, 0.03, 0.0)
			root.add_child(mesh)
	return root
