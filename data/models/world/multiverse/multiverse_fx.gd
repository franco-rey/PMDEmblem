class_name MultiverseFx
extends CanvasLayer

const LAYER_INDEX: int = 21
const TRAVEL_SECONDS: float = 1.1
const SWITCH_SECONDS: float = 0.55
const RIPPLE_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.62, 0.45, 0.88, 1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float r = length(d);
	float fade = 1.0 - progress;
	float wave = sin((r - progress * 1.3) * 42.0) * 0.014 * fade * smoothstep(0.0, 0.12, progress);
	vec2 sample_uv = clamp(uv + normalize(d + vec2(0.00001)) * wave, vec2(0.001), vec2(0.999));
	vec3 col = texture(screen_tex, sample_uv).rgb;
	float ring = smoothstep(0.07, 0.0, abs(r - progress * 0.95)) * fade;
	float split = 0.006 * fade;
	col.r = texture(screen_tex, clamp(sample_uv + vec2(split, 0.0), vec2(0.001), vec2(0.999))).r;
	col.b = texture(screen_tex, clamp(sample_uv - vec2(split, 0.0), vec2(0.001), vec2(0.999))).b;
	col = mix(col, tint.rgb, ring * 0.75 + fade * 0.16);
	COLOR = vec4(col, 1.0);
}
"""

var ripple: ColorRect = null
var pulse: ColorRect = null
var travels_played: int = 0
var switches_played: int = 0
var _material: ShaderMaterial = null
var _tween: Tween = null


func _init() -> void:
	name = "MultiverseFx"
	layer = LAYER_INDEX


func _ready() -> void:
	var shader := Shader.new()
	shader.code = RIPPLE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	ripple = ColorRect.new()
	ripple.name = "Ripple"
	ripple.set_anchors_preset(Control.PRESET_FULL_RECT)
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple.material = _material
	ripple.visible = false
	add_child(ripple)
	pulse = ColorRect.new()
	pulse.name = "Pulse"
	pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.color = Color(0.70, 0.55, 0.95, 0.0)
	pulse.visible = false
	add_child(pulse)


func is_playing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func play_travel(immediate: bool = false) -> void:
	travels_played += 1
	if immediate or not is_inside_tree():
		return
	_stop()
	_material.set_shader_parameter("progress", 0.0)
	ripple.visible = true
	pulse.visible = false
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("progress", value), 0.0, 1.0, TRAVEL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: ripple.visible = false)


func play_switch(immediate: bool = false) -> void:
	switches_played += 1
	if immediate or not is_inside_tree():
		return
	_stop()
	ripple.visible = false
	pulse.color.a = 0.32
	pulse.visible = true
	_tween = create_tween()
	_tween.tween_property(pulse, "color:a", 0.0, SWITCH_SECONDS).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: pulse.visible = false)


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if ripple != null:
		ripple.visible = false
	if pulse != null:
		pulse.visible = false
