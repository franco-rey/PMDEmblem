class_name TacticsConfig
extends Node3D

static var color: Dictionary = {
	"white": "FFFFFF3F",
	"blue_cola": "008fdbBF",
	"blue_bolt": "0aa9ffBF",
	"rosso_corsa": "d10000BF",
	"coral_red": "ff4242BF",
	"path_cyan": "e6fbffF2",
	"commit_gold": "ffd54aD8",
}

static var mat_color: Dictionary = {
	"hover": create_material(str(color.white)),
	"reachable": create_material(str(color.blue_cola)),
	"reachable_hover": create_material(str(color.blue_bolt)),
	"attackable": create_material(str(color.rosso_corsa)),
	"hover_attackable": create_material(str(color.coral_red)),
	"path": create_material(str(color.path_cyan)),
	"committed": create_material(str(color.commit_gold)),
}

static var pawn: Dictionary = {
	"base_walk_speed": 8,
	"animation_frames": 1,
	"min_height_to_jump": 1,
	"gravity_strength": 6,
	"min_time_for_attack": 1,
}

static var view: Dictionary = {
	"default_t_cam_zoom": 30,
}

static var ui_elem: Array[String] = [
	"%Actions", "%MovePicker", "%ItemPicker",
]

static var hover_controls: Array[Control] = []


static func register_hover_control(control: Control) -> void:
	if control != null and not hover_controls.has(control):
		hover_controls.append(control)


static func hover_controls_contain(point: Vector2) -> bool:
	var keep: Array[Control] = []
	var hit: bool = false
	for control in hover_controls:
		if control == null or not is_instance_valid(control):
			continue
		keep.append(control)
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			hit = true
	hover_controls = keep
	return hit


static func create_material(color_hex: Variant, texture: Texture2D = null, shaded_mode: BaseMaterial3D.ShadingMode = BaseMaterial3D.SHADING_MODE_PER_PIXEL) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(str(color_hex))
	material.albedo_texture = texture
	material.shading_mode = shaded_mode
	return material
