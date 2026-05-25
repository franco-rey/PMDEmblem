extends Container

const ANIMATION_DURATION: float = 0.3
const FOLDED_OFFSET: float = -514.0

var res: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")
@onready var controller_hints: Control = $ControllerHints


func _ready() -> void:
	res.input_hints_folded = true
	update_hints_visibility(true)

	controller_hints.mouse_entered.connect(on_mouse_entered)
	controller_hints.mouse_exited.connect(on_mouse_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("controller_hints"):
		on_mouse_entered()
	elif event.is_action_released("controller_hints"):
		on_mouse_exited()


func on_mouse_entered() -> void:
	res.input_hints_folded = false
	update_hints_visibility()


func on_mouse_exited() -> void:
	res.input_hints_folded = true
	update_hints_visibility()


func update_hints_visibility(force_immediate: bool = false) -> void:
	var target_x: float = FOLDED_OFFSET if res.input_hints_folded else 0.0
	var target_alpha: float = 0.3 if res.input_hints_folded else 1.0

	if force_immediate:
		controller_hints.position.x = target_x
		controller_hints.modulate.a = target_alpha
	else:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(controller_hints, "position:x", target_x, ANIMATION_DURATION)
		tween.tween_property(controller_hints, "modulate:a", target_alpha, ANIMATION_DURATION)
