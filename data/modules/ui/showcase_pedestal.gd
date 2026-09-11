class_name ShowcasePedestal
extends ShowcaseStage

const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"
const TILE_LIGHT: Color = Color(0.87, 0.82, 0.68, 1.0)
const TILE_FRAME: Color = Color(0.22, 0.17, 0.12, 1.0)
const BLOCK_SIZE: Vector3 = Vector3(1.0, 0.5, 1.0)
const SLAB_SIZE: Vector3 = Vector3(1.4, 0.3, 1.4)
const BOOT_ZOOM: float = DEFAULT_ZOOM - ZOOM_SPEED
const HIT_CUE: String = "battle.hit_neutral"
const ATTACK_STATES: Array[String] = ["attack", "strike", "physical_attack", "special_attack", "shoot", "charge", "cast", "hop"]

var _pawn: Node3D = null
var _character: Node3D = null
var _pawn_scene: PackedScene = null
var _expertise_scene: PackedScene = null
var _action_playing: bool = false


func _ready() -> void:
	_target_fov = BOOT_ZOOM
	_current_fov = BOOT_ZOOM
	_pawn_scene = load(PAWN_SCENE_PATH) as PackedScene
	_expertise_scene = load(EXPERTISE_SCENE_PATH) as PackedScene
	super()


func _build_scene() -> void:
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
	if FormRules.is_choice(instance.species) and instance.form_index == FormRules.default_index(instance.species):
		instance = instance.duplicate() as PokemonInstanceResource
		instance.form_index = FormRules.roll(instance.species, randi(), "showcase", 0)
	if instance.gender == GenderRules.UNKNOWN and GenderRules.is_choice(instance.resolved_form()):
		instance = instance.duplicate() as PokemonInstanceResource
		instance.gender = GenderRules.roll(instance.resolved_form(), randi(), "showcase", 0)
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
	_action_playing = false


func play_attack() -> void:
	if _character == null or not is_instance_valid(_character):
		return
	for state in ATTACK_STATES:
		if _character.can_play_state(state):
			_character.play_action(state)
			_action_playing = true
			var phases: Dictionary = _character.state_phase_seconds(state)
			var hit_at: float = clampf(float(phases.get("hit", 0.0)), 0.0, float(phases.get("total", 0.0)))
			if hit_at <= 0.01:
				SoundPlayer.cue(HIT_CUE)
			else:
				get_tree().create_timer(hit_at).timeout.connect(func() -> void: SoundPlayer.cue(HIT_CUE))
			return


func _after_frame() -> void:
	if _action_playing and _character != null and is_instance_valid(_character) and _character.is_one_shot_finished():
		_action_playing = false
		_character.set_anim_state(_character.ANIM_IDLE)
	if _character != null and is_instance_valid(_character) and _pawn != null:
		_character.rotate_sprite(_pawn.global_basis)
