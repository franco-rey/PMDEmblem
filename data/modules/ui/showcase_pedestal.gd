class_name ShowcasePedestal
extends SubViewportContainer

const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"
const VIEW_SIZE: Vector2i = Vector2i(440, 360)
const TILE_LIGHT: Color = Color(0.87, 0.82, 0.68, 1.0)
const TILE_FRAME: Color = Color(0.22, 0.17, 0.12, 1.0)
const BLOCK_SIZE: Vector3 = Vector3(1.0, 0.5, 1.0)
const SLAB_SIZE: Vector3 = Vector3(1.4, 0.3, 1.4)
const ROTATE_STEP_DEGREES: float = 45.0
const ZOOM_STEPS: Array[float] = [1.5, 1.9, 2.4, 3.0, 3.8]
const DEFAULT_ZOOM: int = 3
const TURN_SPEED: float = 9.0
const ORBIT_SPEED: float = 28.0
const ISO_PITCH: float = 34.0
const TOP_PITCH: float = 78.0

var _viewport: SubViewport = null
var _stage: Node3D = null
var _camera: Camera3D = null
var _pawn: Node3D = null
var _character: Node3D = null
var _pawn_scene: PackedScene = null
var _expertise_scene: PackedScene = null
var _yaw: float = 45.0
var _yaw_target: float = 45.0
var _pitch: float = ISO_PITCH
var _pitch_target: float = ISO_PITCH
var _zoom: int = DEFAULT_ZOOM
var _orbit: int = 0
var _top_down: bool = false


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(VIEW_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pawn_scene = load(PAWN_SCENE_PATH) as PackedScene
	_expertise_scene = load(EXPERTISE_SCENE_PATH) as PackedScene
	_viewport = SubViewport.new()
	_viewport.name = "ShowcaseViewport"
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_stage = Node3D.new()
	_stage.name = "Stage"
	_viewport.add_child(_stage)
	_build_tile()
	_build_sun()
	_build_camera()
	set_process(true)


func show_entry(entry: Dictionary) -> void:
	var instance: PokemonInstanceResource = entry.get("instance", null) as PokemonInstanceResource
	if _pawn != null and is_instance_valid(_pawn):
		_pawn.queue_free()
		_pawn = null
	if instance == null or _pawn_scene == null or _expertise_scene == null:
		return
	var pawn: TacticsPawn = _pawn_scene.instantiate() as TacticsPawn
	if pawn == null:
		return
	pawn.name = "ShowcasePawn"
	var expertise: Expertise = _expertise_scene.instantiate() as Expertise
	expertise.name = "Expertise"
	expertise.pokemon_instance = instance
	pawn.add_child(expertise)
	pawn.collision_layer = 0
	pawn.collision_mask = 0
	_stage.add_child(pawn)
	pawn.set_physics_process(false)
	var ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
	if ray != null:
		ray.enabled = false
	pawn.position = Vector3.ZERO
	_pawn = pawn
	_character = pawn.get_node_or_null("Character") as Node3D


func _process(delta: float) -> void:
	_read_camera_actions()
	if _orbit != 0:
		_yaw_target += float(_orbit) * ORBIT_SPEED * delta
	_yaw = rad_to_deg(lerp_angle(deg_to_rad(_yaw), deg_to_rad(_yaw_target), clampf(delta * TURN_SPEED, 0.0, 1.0)))
	_pitch = lerpf(_pitch, _pitch_target, clampf(delta * TURN_SPEED, 0.0, 1.0))
	_place_camera()
	if _character != null and is_instance_valid(_character) and _pawn != null:
		_character.rotate_sprite(_pawn.global_basis)


func _read_camera_actions() -> void:
	if Input.is_action_just_pressed("camera_zoom_in"):
		_zoom = clampi(_zoom - 1, 0, ZOOM_STEPS.size() - 1)
	elif Input.is_action_just_pressed("camera_zoom_out"):
		_zoom = clampi(_zoom + 1, 0, ZOOM_STEPS.size() - 1)
	if Input.is_action_just_pressed("camera_perspective"):
		_top_down = not _top_down
		_pitch_target = TOP_PITCH if _top_down else ISO_PITCH
		_orbit = 0
		return
	if Input.is_action_just_pressed("camera_orbit_left"):
		_orbit = 0 if _orbit == -1 else -1
	elif Input.is_action_just_pressed("camera_orbit_right"):
		_orbit = 0 if _orbit == 1 else 1
	elif Input.is_action_just_pressed("camera_rotate_left"):
		_orbit = 0
		_yaw_target -= ROTATE_STEP_DEGREES
	elif Input.is_action_just_pressed("camera_rotate_right"):
		_orbit = 0
		_yaw_target += ROTATE_STEP_DEGREES


func _place_camera() -> void:
	if _camera == null:
		return
	var radius: float = 3.4
	var yaw: float = deg_to_rad(_yaw)
	var pitch: float = deg_to_rad(_pitch)
	var flat: float = cos(pitch) * radius
	_camera.size = ZOOM_STEPS[_zoom]
	_camera.position = Vector3(sin(yaw) * flat, sin(pitch) * radius, cos(yaw) * flat)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.05, 0.0), Vector3.UP)


func _build_tile() -> void:
	var block := MeshInstance3D.new()
	block.name = "Square"
	var box := BoxMesh.new()
	box.size = BLOCK_SIZE
	block.mesh = box
	block.material_override = _matte(TILE_LIGHT)
	block.position = Vector3(0.0, -BLOCK_SIZE.y * 0.5, 0.0)
	_stage.add_child(block)
	var slab := MeshInstance3D.new()
	slab.name = "Frame"
	var base := BoxMesh.new()
	base.size = SLAB_SIZE
	slab.mesh = base
	slab.material_override = _matte(TILE_FRAME)
	slab.position = Vector3(0.0, -BLOCK_SIZE.y - SLAB_SIZE.y * 0.5 + 0.02, 0.0)
	_stage.add_child(slab)


func _matte(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic_specular = 0.0
	material.roughness = 0.9
	return material


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(0.0, 4.0, 0.0)
	sun.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	sun.light_indirect_energy = 0.0
	sun.light_volumetric_fog_energy = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_viewport.add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "ShowcaseEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.86, 1.0)
	env.ambient_light_energy = 1.25
	world.environment = env
	_viewport.add_child(world)


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "ShowcaseCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ZOOM_STEPS[DEFAULT_ZOOM]
	camera.current = true
	_viewport.add_child(camera)
	_camera = camera
	_place_camera()
