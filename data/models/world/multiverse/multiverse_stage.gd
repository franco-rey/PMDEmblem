class_name MultiverseStage
extends Node3D

const PITCH: float = 11.0
const BAND_WIDTH: float = 2.4
const BAND_Y: float = -0.62
const MARKER_Y: float = -0.36
const HALO_Y: float = -0.30
const ARC_HEIGHT: float = 4.5
const ARC_WIDTH: float = 0.45
const ARC_SAMPLES: int = 40
const CONNECTOR_SAMPLES: int = 40
const COLOR_BAND: Color = Color(0.56, 0.42, 0.74, 1.0)
const COLOR_BAND_FROZEN: Color = Color(0.42, 0.42, 0.48, 1.0)
const COLOR_PAST: Color = Color(0.76, 0.66, 0.94, 0.75)
const COLOR_PAST_FROZEN: Color = Color(0.55, 0.55, 0.60, 0.55)
const COLOR_PLAYED: Color = Color(0.56, 0.56, 0.60, 0.9)
const COLOR_PENDING: Color = Color(1.0, 0.85, 0.28, 0.95)
const COLOR_CURRENT: Color = Color(1.0, 0.96, 0.72, 0.9)
const COLOR_FROZEN: Color = Color(0.40, 0.40, 0.46, 0.85)
const COLOR_COVER: Color = Color(0.05, 0.05, 0.10, 0.45)
const COLOR_PRESENT: Color = Color(0.22, 0.18, 0.34, 0.92)
const COLOR_ARC_PLAYER: Color = Color(0.45, 0.65, 1.0, 0.8)
const COLOR_ARC_ENEMY: Color = Color(1.0, 0.45, 0.45, 0.8)
const STATUS_CURRENT: String = "current"
const STATUS_PENDING: String = "pending"
const STATUS_PLAYED: String = "played"
const STATUS_PAST: String = "past"
const STATUS_FROZEN: String = "frozen"
const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"

var level: TacticsLevel = null
var boards: Dictionary = {}
var bands: Dictionary = {}
var past_markers: Dictionary = {}
var connectors: Dictionary = {}
var arcs: Array[Dictionary] = []
var board_size: Vector3 = Vector3(8.6, 0.5, 8.6)
var board_base: float = 0.0
var board_top: float = 0.5
var board_centre: Vector3 = Vector3.ZERO
var refreshes: int = 0
var field_visible: bool = false
var _templates: Array[Dictionary] = []
var _present_wall: MeshInstance3D = null
var _present_label: Label3D = null
var _live_halo: MeshInstance3D = null
var _halo_mesh: Mesh = null
var _cover_mesh: BoxMesh = null
var _marker_mesh: BoxMesh = null
var _materials: Dictionary = {}
var _pawn_scene: PackedScene = null
var _expertise_scene: PackedScene = null
var _pulse: float = 0.0
var _camera: TacticsCamera = null
var _pan_tween: Tween = null
var _preview_root: Node3D = null
var _preview_groups: Array[Array] = []
var _preview_overview: float = -1.0
var preview_option_count: int = 0


func setup(battle_level: TacticsLevel) -> void:
	level = battle_level
	name = "MultiverseStage"
	_pawn_scene = load(PAWN_SCENE_PATH) as PackedScene
	_expertise_scene = load(EXPERTISE_SCENE_PATH) as PackedScene
	_build_templates()
	_halo_mesh = _frame_mesh(board_size.x + 1.2, board_size.z + 1.2, 0.7)
	_cover_mesh = BoxMesh.new()
	_cover_mesh.size = Vector3(board_size.x + 0.2, 0.04, board_size.z + 0.2)
	_marker_mesh = BoxMesh.new()
	_marker_mesh.size = Vector3(board_size.x * 0.82, 0.05, board_size.z * 0.82)
	_live_halo = MeshInstance3D.new()
	_live_halo.name = "LiveHalo"
	_live_halo.mesh = _halo_mesh
	_live_halo.position = board_centre + Vector3(0.0, board_base + HALO_Y, 0.0)
	_live_halo.material_override = _flat_material(COLOR_CURRENT, true)
	add_child(_live_halo)
	_present_wall = MeshInstance3D.new()
	_present_wall.name = "PresentWall"
	_present_wall.mesh = BoxMesh.new()
	_present_wall.material_override = _flat_material(COLOR_PRESENT, true)
	add_child(_present_wall)
	_present_label = Label3D.new()
	_present_label.name = "PresentLabel"
	_present_label.text = "The Present"
	_present_label.font_size = 40
	_present_label.pixel_size = 0.012
	_present_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_present_label.modulate = Color(0.85, 0.75, 1.0, 0.9)
	_present_label.outline_size = 8
	add_child(_present_label)
	set_process(true)


static func slot(coords: Vector2i) -> Vector3:
	return Vector3(float(coords.y - 1) * PITCH, 0.0, -float(coords.x) * PITCH)


func offset_for(coords: Vector2i) -> Vector3:
	if level == null or level.multiverse == null:
		return slot(coords)
	return slot(coords) - slot(level.multiverse.state.focus)


func world_point(coords: Vector2i, local: Vector3) -> Vector3:
	return offset_for(coords) + local


func board_status(coords: Vector2i) -> String:
	var state: MultiverseState = level.multiverse.state
	if coords == state.focus:
		return STATUS_CURRENT
	if not state.is_active(coords.x):
		return STATUS_FROZEN
	var latest: BoardSnapshot = state.latest(coords.x)
	if latest == null or latest.turn != coords.y:
		return STATUS_PAST
	if state.owed_boards().has(coords):
		return STATUS_PENDING
	return STATUS_PLAYED


static func status_color(status: String) -> Color:
	match status:
		STATUS_CURRENT:
			return COLOR_CURRENT
		STATUS_PENDING:
			return COLOR_PENDING
		STATUS_PLAYED:
			return COLOR_PLAYED
		STATUS_FROZEN:
			return COLOR_FROZEN
	return COLOR_PAST


func refresh() -> void:
	if level == null or level.multiverse == null or level.multiverse.state.timelines.is_empty():
		return
	refreshes += 1
	var state: MultiverseState = level.multiverse.state
	var ids: Array[int] = state.timeline_ids()
	field_visible = ids.size() > 1
	if not field_visible:
		_hide_field()
		return
	var keep: Dictionary = {}
	for l in ids:
		var latest: BoardSnapshot = state.latest(l)
		if latest == null:
			continue
		var coords: Vector2i = latest.coords()
		if coords != state.focus:
			keep[coords] = true
			_ensure_board(coords, latest)
		_refresh_band(l, state)
		_refresh_past_markers(l, state)
		_refresh_connector(l, state)
	for coords in boards.keys():
		if not keep.has(coords):
			(boards[coords]["node"] as Node3D).queue_free()
			boards.erase(coords)
	_refresh_present(state, ids)
	_refresh_arcs()
	_live_halo.visible = true


func _hide_field() -> void:
	for coords in boards.keys():
		(boards[coords]["node"] as Node3D).queue_free()
	boards.clear()
	for table in [bands, past_markers, connectors]:
		for key in table.keys():
			(table[key]["node"] as Node).queue_free()
		table.clear()
	_present_wall.visible = false
	_present_label.visible = false
	_live_halo.visible = false


func recentre_camera(old_focus: Vector2i, new_focus: Vector2i) -> void:
	if not field_visible:
		return
	if old_focus == new_focus:
		return
	var camera: TacticsCamera = camera_node()
	if camera == null:
		return
	camera.global_position += slot(old_focus) - slot(new_focus)
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	if level.presentation_runner != null and level.presentation_runner.immediate_mode:
		camera.global_position = Vector3(board_centre.x, camera.global_position.y, board_centre.z)
		return
	_pan_tween = create_tween()
	_pan_tween.tween_property(camera, "global_position", Vector3(board_centre.x, camera.global_position.y, board_centre.z), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func camera_node() -> TacticsCamera:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	if level == null or not level.is_inside_tree():
		return null
	_camera = level.get_tree().root.find_child("TacticsCamera", true, false) as TacticsCamera
	return _camera


func add_travel_arc(from: Vector2i, from_local: Vector3, to: Vector2i, to_local: Vector3, side: int, animate: bool) -> Dictionary:
	var node := MeshInstance3D.new()
	node.name = "Arc%d" % (arcs.size() + 1)
	node.material_override = _flat_material(COLOR_ARC_PLAYER if side == MultiverseState.SIDE_PLAYER else COLOR_ARC_ENEMY, true, true)
	add_child(node)
	var arc: Dictionary = {"from": from, "from_local": from_local, "to": to, "to_local": to_local, "side": side, "node": node, "progress": 0.0 if animate else 1.0}
	arcs.append(arc)
	_place_arc(arc)
	if animate:
		var tween: Tween = create_tween()
		tween.tween_method(func(value: float) -> void: _set_arc_progress(arc, value), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
		tween.tween_interval(0.8)
		tween.tween_property(node.material_override, "albedo_color:a", 0.42, 0.9)
	else:
		(node.material_override as StandardMaterial3D).albedo_color.a = 0.42
	return arc


func _set_arc_progress(arc: Dictionary, value: float) -> void:
	arc["progress"] = value
	_place_arc(arc)


func _place_arc(arc: Dictionary) -> void:
	var node: MeshInstance3D = arc["node"]
	if node == null or not is_instance_valid(node):
		return
	node.position = offset_for(arc["from"])
	var start: Vector3 = arc["from_local"]
	var finish: Vector3 = slot(arc["to"]) - slot(arc["from"]) + (arc["to_local"] as Vector3)
	var control: Vector3 = (start + finish) * 0.5 + Vector3(0.0, ARC_HEIGHT + start.distance_to(finish) * 0.12, 0.0)
	var points := PackedVector3Array()
	var steps: int = maxi(2, int(round(float(ARC_SAMPLES) * clampf(float(arc["progress"]), 0.0, 1.0))))
	for i in range(steps + 1):
		var t: float = float(i) / float(ARC_SAMPLES)
		if t > float(arc["progress"]):
			t = float(arc["progress"])
		points.append(_quadratic(start, control, finish, t))
	node.mesh = ribbon_mesh(points, ARC_WIDTH, false)


func _refresh_arcs() -> void:
	for arc in arcs:
		_place_arc(arc)


func _process(delta: float) -> void:
	_pulse += delta
	if _live_halo != null:
		var material: StandardMaterial3D = _live_halo.material_override as StandardMaterial3D
		material.albedo_color.a = 0.45 + 0.4 * (0.5 + 0.5 * sin(_pulse * 5.5))


func _ensure_board(coords: Vector2i, board: BoardSnapshot) -> void:
	var entry: Dictionary = boards.get(coords, {})
	var node: Node3D = entry.get("node", null)
	if node == null or not is_instance_valid(node) or entry.get("board", null) != board:
		if node != null and is_instance_valid(node):
			node.queue_free()
		node = _build_board(coords, board)
		add_child(node)
		entry = {"node": node, "board": board}
		boards[coords] = entry
	node.position = offset_for(coords)
	var status: String = board_status(coords)
	node.visible = status != STATUS_CURRENT
	(node.get_node("Halo") as MeshInstance3D).material_override = _status_material(status)
	(node.get_node("Cover") as MeshInstance3D).visible = status == STATUS_FROZEN
	entry["status"] = status


func _build_board(coords: Vector2i, board: BoardSnapshot) -> Node3D:
	var node := Node3D.new()
	node.name = "Board_L%d_T%d" % [coords.x, coords.y]
	for template in _templates:
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = template["multimesh"]
		if template["material"] != null:
			instance.material_override = template["material"]
		node.add_child(instance)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = _halo_mesh
	halo.position = board_centre + Vector3(0.0, board_base + HALO_Y, 0.0)
	node.add_child(halo)
	var cover := MeshInstance3D.new()
	cover.name = "Cover"
	cover.mesh = _cover_mesh
	cover.position = board_centre + Vector3(0.0, board_top + 0.04, 0.0)
	cover.material_override = _flat_material(COLOR_COVER, true)
	cover.visible = false
	node.add_child(cover)
	var units := Node3D.new()
	units.name = "Units"
	node.add_child(units)
	for unit in board.units:
		if not bool(unit.get("alive", true)):
			continue
		var ghost: TacticsPawn = _spawn_ghost(unit, units)
		if ghost != null:
			ghost.position = unit["position"]
			ghost.rotation = unit["rotation"]
	return node


func _spawn_ghost(entry: Dictionary, parent: Node3D) -> TacticsPawn:
	if _pawn_scene == null or _expertise_scene == null:
		return null
	var source: PokemonInstanceResource = entry.get("instance", null)
	if source == null:
		return null
	var instance: PokemonInstanceResource = source.duplicate()
	var held: String = String(entry.get("held_item_id", ""))
	instance.held_item = PokemonItemService.load_item(held) if not held.is_empty() else null
	instance.team = int(entry["team"])
	instance.control_type = int(entry["control"])
	var pawn: TacticsPawn = _pawn_scene.instantiate() as TacticsPawn
	pawn.name = "Ghost_%s" % String(entry["id"]).replace("'", "p")
	var expertise: Expertise = _expertise_scene.instantiate() as Expertise
	expertise.name = "Expertise"
	expertise.pokemon_instance = instance
	pawn.add_child(expertise)
	pawn.collision_layer = 0
	pawn.collision_mask = 0
	parent.add_child(pawn)
	pawn.set_physics_process(false)
	var ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
	if ray != null:
		ray.enabled = false
	return pawn


func ghost_count() -> int:
	var count: int = 0
	for coords in boards:
		var node: Node3D = boards[coords]["node"]
		if node != null and is_instance_valid(node):
			count += (node.get_node("Units") as Node3D).get_child_count()
	return count


func _refresh_band(l: int, state: MultiverseState) -> void:
	var first: int = state.first_turn(l)
	var latest: BoardSnapshot = state.latest(l)
	var span: Vector2i = Vector2i(first, latest.turn)
	var active: bool = state.is_active(l)
	var entry: Dictionary = bands.get(l, {})
	var node: MeshInstance3D = entry.get("node", null)
	if node == null or not is_instance_valid(node) or entry.get("span", Vector2i.ZERO) != span or bool(entry.get("active", true)) != active:
		if node != null and is_instance_valid(node):
			node.queue_free()
		node = MeshInstance3D.new()
		node.name = "Band_L%d" % l
		var length: float = float(span.y - span.x) * PITCH + PITCH
		var points := PackedVector3Array([board_centre + Vector3(-PITCH * 0.5, BAND_Y, 0.0), board_centre + Vector3(length - PITCH * 0.5, BAND_Y, 0.0)])
		node.mesh = ribbon_mesh(points, BAND_WIDTH, true)
		node.material_override = _flat_material(COLOR_BAND if active else COLOR_BAND_FROZEN, false)
		add_child(node)
		entry = {"node": node, "span": span, "active": active}
		bands[l] = entry
	node.position = offset_for(Vector2i(l, first))


func _refresh_past_markers(l: int, state: MultiverseState) -> void:
	var first: int = state.first_turn(l)
	var latest: BoardSnapshot = state.latest(l)
	var count: int = maxi(0, latest.turn - first)
	var active: bool = state.is_active(l)
	var entry: Dictionary = past_markers.get(l, {})
	var node: MultiMeshInstance3D = entry.get("node", null)
	if node == null or not is_instance_valid(node) or int(entry.get("count", -1)) != count or bool(entry.get("active", true)) != active:
		if node != null and is_instance_valid(node):
			node.queue_free()
		node = MultiMeshInstance3D.new()
		node.name = "Past_L%d" % l
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _marker_mesh
		multimesh.instance_count = count
		for i in range(count):
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, board_centre + Vector3(float(i) * PITCH, board_base + MARKER_Y, 0.0)))
		node.multimesh = multimesh
		node.material_override = _flat_material(COLOR_PAST if active else COLOR_PAST_FROZEN, true)
		add_child(node)
		entry = {"node": node, "count": count, "active": active}
		past_markers[l] = entry
	node.position = offset_for(Vector2i(l, first))
	node.visible = count > 0


func _refresh_connector(l: int, state: MultiverseState) -> void:
	if not state.origins.has(l):
		return
	var origin: Vector2i = state.origins[l]
	var entry: Dictionary = connectors.get(l, {})
	var node: MeshInstance3D = entry.get("node", null)
	var active: bool = state.is_active(l)
	if node == null or not is_instance_valid(node) or bool(entry.get("active", true)) != active:
		if node != null and is_instance_valid(node):
			node.queue_free()
		node = MeshInstance3D.new()
		node.name = "Connector_L%d" % l
		var target: Vector3 = slot(Vector2i(l, origin.y)) - slot(origin)
		var start: Vector3 = board_centre + Vector3(0.0, BAND_Y - 0.03, 0.0)
		var finish: Vector3 = board_centre + Vector3(target.x - PITCH * 0.5, BAND_Y - 0.03, target.z)
		var c1: Vector3 = board_centre + Vector3(0.0, BAND_Y - 0.03, target.z * 0.75)
		var c2: Vector3 = board_centre + Vector3(target.x - PITCH * 0.9, BAND_Y - 0.03, target.z)
		var points := PackedVector3Array()
		for i in range(CONNECTOR_SAMPLES + 1):
			points.append(_cubic(start, c1, c2, finish, float(i) / float(CONNECTOR_SAMPLES)))
		node.mesh = ribbon_mesh(points, BAND_WIDTH * 0.8, false)
		node.material_override = _flat_material(COLOR_BAND if active else COLOR_BAND_FROZEN, false)
		add_child(node)
		entry = {"node": node, "active": active}
		connectors[l] = entry
	node.position = offset_for(origin)


func _refresh_present(state: MultiverseState, ids: Array[int]) -> void:
	if ids.is_empty():
		_present_wall.visible = false
		_present_label.visible = false
		return
	var now: int = state.present()
	var low: int = ids.min()
	var high: int = ids.max()
	var x: float = offset_for(Vector2i(0, now)).x
	var z_low: float = offset_for(Vector2i(high, now)).z - PITCH * 0.6
	var z_high: float = offset_for(Vector2i(low, now)).z + PITCH * 0.6
	var mesh: BoxMesh = _present_wall.mesh as BoxMesh
	mesh.size = Vector3(1.6, 0.05, absf(z_high - z_low))
	_present_wall.position = board_centre + Vector3(x - PITCH * 0.5, board_base + BAND_Y + 0.08, (z_low + z_high) * 0.5)
	_present_wall.visible = true
	_present_label.position = board_centre + Vector3(x - PITCH * 0.5, board_base + 0.35, z_low - 1.2)
	_present_label.visible = true


func _build_templates() -> void:
	_templates.clear()
	if level == null or level.arena == null:
		return
	var groups: Dictionary = {}
	var order: Array[String] = []
	var bounds: AABB = AABB()
	var first: bool = true
	var inverse: Transform3D = level.arena.global_transform.affine_inverse()
	for mesh_node in _visual_meshes(level.arena):
		var material: Material = mesh_node.material_override
		if material == null:
			material = mesh_node.get_surface_override_material(0)
		if material == null and mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
			material = mesh_node.mesh.surface_get_material(0)
		var key: String = "%d:%d" % [mesh_node.mesh.get_instance_id(), material.get_instance_id() if material != null else 0]
		if not groups.has(key):
			groups[key] = {"mesh": mesh_node.mesh, "material": material, "transforms": []}
			order.append(key)
		var local: Transform3D = inverse * mesh_node.global_transform
		(groups[key]["transforms"] as Array).append(local)
		var box: AABB = local * mesh_node.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	for key in order:
		var group: Dictionary = groups[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group["mesh"]
		var transforms: Array = group["transforms"]
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])
		_templates.append({"multimesh": multimesh, "material": group["material"]})
	if not first:
		board_size = Vector3(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 0.1), maxf(bounds.size.z, 1.0))
		board_base = bounds.position.y
		board_top = bounds.end.y
		board_centre = Vector3(bounds.get_center().x, 0.0, bounds.get_center().z)


func _visual_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var tiles: Node = root.get_node_or_null("Tiles")
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == tiles:
			continue
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and node.visible and not (node.get_parent() is TacticsTile):
			out.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)
	return out


func _status_material(status: String) -> StandardMaterial3D:
	if not _materials.has(status):
		_materials[status] = _flat_material(status_color(status), true)
	return _materials[status]


static func _flat_material(color: Color, translucent: bool, no_depth: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if translucent or color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if no_depth:
		material.no_depth_test = true
	return material


static func _frame_mesh(width: float, depth: float, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = width * 0.5
	var hz: float = depth * 0.5
	var ix: float = hx - thickness
	var iz: float = hz - thickness
	var outer: Array[Vector3] = [Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz)]
	var inner: Array[Vector3] = [Vector3(-ix, 0.0, -iz), Vector3(ix, 0.0, -iz), Vector3(ix, 0.0, iz), Vector3(-ix, 0.0, iz)]
	for i in range(4):
		var j: int = (i + 1) % 4
		st.set_normal(Vector3.UP)
		st.add_vertex(outer[i])
		st.add_vertex(outer[j])
		st.add_vertex(inner[j])
		st.add_vertex(outer[i])
		st.add_vertex(inner[j])
		st.add_vertex(inner[i])
	return st.commit()


static func ribbon_mesh(points: PackedVector3Array, width: float, arrow: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = width * 0.5
	var path: PackedVector3Array = PackedVector3Array()
	for point in points:
		if path.is_empty() or path[path.size() - 1].distance_to(point) > 0.0001:
			path.append(point)
	if path.size() < 2:
		return st.commit()
	var sides: Array[Vector3] = []
	var last_dir: Vector3 = Vector3.RIGHT
	for i in range(path.size()):
		var incoming: Vector3 = (path[i] - path[i - 1]) if i > 0 else (path[i + 1] - path[i])
		var outgoing: Vector3 = (path[i + 1] - path[i]) if i < path.size() - 1 else incoming
		incoming.y = 0.0
		outgoing.y = 0.0
		var tangent: Vector3 = (incoming.normalized() + outgoing.normalized())
		if tangent.length() < 0.0001:
			tangent = outgoing
		tangent = tangent.normalized()
		var normal: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		var turn: float = maxf(0.35, absf(normal.dot(Vector3(-outgoing.normalized().z, 0.0, outgoing.normalized().x))))
		sides.append(normal * (half / turn))
		if i == path.size() - 1:
			last_dir = incoming.normalized()
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		st.set_normal(Vector3.UP)
		st.add_vertex(a - sides[i])
		st.add_vertex(a + sides[i])
		st.add_vertex(b + sides[i + 1])
		st.add_vertex(a - sides[i])
		st.add_vertex(b + sides[i + 1])
		st.add_vertex(b - sides[i + 1])
	if arrow:
		var tip_base: Vector3 = path[path.size() - 1]
		var side: Vector3 = Vector3(-last_dir.z, 0.0, last_dir.x) * (half * 1.9)
		st.set_normal(Vector3.UP)
		st.add_vertex(tip_base - side)
		st.add_vertex(tip_base + side)
		st.add_vertex(tip_base + last_dir * (width * 1.4))
	return st.commit()


static func _quadratic(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return a * (u * u) + c * (2.0 * u * t) + b * (t * t)


static func _cubic(a: Vector3, c1: Vector3, c2: Vector3, b: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return a * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + b * (t * t * t)


func show_travel_preview(pending: Dictionary) -> void:
	clear_travel_preview()
	if level == null or level.multiverse == null or pending.is_empty():
		return
	var state: MultiverseState = level.multiverse.state
	var options: Array = pending.get("options", [])
	var travellers: Array[TacticsPawn] = level.multiverse.travellers_for(String(pending.get("move_id", "")), pending.get("user", null), pending.get("target", null))
	if options.is_empty() or travellers.is_empty():
		return
	_preview_root = Node3D.new()
	_preview_root.name = "TravelPreview"
	add_child(_preview_root)
	var reach: float = 0.0
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var kind: String = String(option.get("kind", ""))
		var dest: Vector2i = Vector2i.ZERO
		var board: BoardSnapshot = option.get("board", null)
		if kind == "branch":
			dest = option["from"]
		elif kind == "hop":
			dest = Vector2i(int(option["to"]), state.latest(int(option["to"])).turn)
		else:
			dest = Vector2i(state.next_timeline_index(int(pending.get("side", MultiverseState.SIDE_PLAYER))), level.round_index)
		var offset: Vector3 = offset_for(dest)
		reach = maxf(reach, maxf(absf(offset.x), absf(offset.z)))
		var group: Array = []
		if kind == "branch" and board != null:
			var replica: Node3D = _build_board(dest, board)
			replica.name = "Preview_%d" % i
			replica.position = offset
			(replica.get_node("Halo") as MeshInstance3D).material_override = _flat_material(Color(1.0, 1.0, 1.0, 0.85), true)
			for ghost in (replica.get_node("Units") as Node3D).get_children():
				if ghost is TacticsPawn and (ghost as TacticsPawn).character != null:
					(ghost as TacticsPawn).character.modulate.a = 0.55
			_preview_root.add_child(replica)
		else:
			var halo := MeshInstance3D.new()
			halo.name = "PreviewHalo_%d" % i
			halo.mesh = _halo_mesh
			halo.position = offset + board_centre + Vector3(0.0, board_base + HALO_Y, 0.0)
			halo.material_override = _flat_material(Color(1.0, 1.0, 1.0, 0.55), true)
			_preview_root.add_child(halo)
		var material: StandardMaterial3D = _flat_material(Color(1.0, 1.0, 1.0, 0.9), true, true)
		for pawn in travellers:
			var id: String = level.multiverse._base_id(level.notation.unit_id(pawn))
			var landing: Vector3 = pawn.global_position
			if kind == "branch" and board != null and board.has_unit(id):
				landing = board.unit(id)["position"]
			var arc := MeshInstance3D.new()
			arc.name = "PreviewArc_%d_%s" % [i, id]
			arc.material_override = material
			var start: Vector3 = pawn.global_position + Vector3(0.0, 0.6, 0.0)
			var finish: Vector3 = offset + landing + Vector3(0.0, 0.6, 0.0)
			var control: Vector3 = (start + finish) * 0.5 + Vector3(0.0, ARC_HEIGHT * 0.6 + start.distance_to(finish) * 0.1, 0.0)
			var points := PackedVector3Array()
			for k in range(ARC_SAMPLES + 1):
				points.append(_quadratic(start, control, finish, float(k) / float(ARC_SAMPLES)))
			arc.mesh = ribbon_mesh(points, ARC_WIDTH * 0.8, true)
			_preview_root.add_child(arc)
			group.append(arc)
		_preview_groups.append(group)
	preview_option_count = options.size()
	var camera: TacticsCamera = camera_node()
	if camera != null and reach > PITCH * 0.5 and camera.res.max_overview > 0.0:
		_preview_overview = camera.res.overview_distance
		camera.res.overview_distance = clampf(reach * 1.15, camera.res.overview_distance, camera.res.max_overview)
	highlight_travel_option(0)


func highlight_travel_option(index: int) -> void:
	for i in range(_preview_groups.size()):
		for arc in _preview_groups[i]:
			if arc is MeshInstance3D and is_instance_valid(arc):
				var material: StandardMaterial3D = (arc as MeshInstance3D).material_override as StandardMaterial3D
				material.albedo_color.a = 0.95 if i == index else 0.32


func clear_travel_preview() -> void:
	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.queue_free()
	_preview_root = null
	_preview_groups.clear()
	preview_option_count = 0
	if _preview_overview >= 0.0:
		var camera: TacticsCamera = camera_node()
		if camera != null:
			camera.res.overview_distance = _preview_overview
		_preview_overview = -1.0
