class_name PawnStateVisuals
extends Node

const LIFT_HEIGHT: float = 0.9
const LIFT_SECONDS: float = 0.35
const VANISH_ALPHA: float = 0.25
const MARKER_LIFETIME: float = 3600.0
const MARKERS: Dictionary = {"underground": ["dig", "Dig"], "underwater": ["dive", "Dive"]}
const STATES: Array[String] = ["airborne", "underground", "underwater", "vanished"]
const FAINT_HOLD_SECONDS: float = 1.4
const FAINT_FADE_SECONDS: float = 0.7

var pawn: TacticsPawn = null
var state: String = ""
var faint_seconds: float = 0.0
var _labels_hidden_for_faint: bool = false
var _marker: Node3D = null
var _tween: Tween = null
var _retired: bool = false
var _hidden: bool = false
var _collision_layer: int = 0
var _collision_mask: int = 0


func _ready() -> void:
	if pawn != null:
		_collision_layer = pawn.collision_layer
		_collision_mask = pawn.collision_mask


func _process(delta: float) -> void:
	if pawn == null or pawn.stats == null:
		return
	if pawn.stats.is_active():
		faint_seconds = 0.0
		_labels_hidden_for_faint = false
		if _retired:
			_restore_presence()
	else:
		faint_seconds += delta
		if not _labels_hidden_for_faint:
			_labels_hidden_for_faint = true
			pawn.show_pawn_stats(false)
			pawn.res.pawn_hud_enabled = false
		if not _retired:
			_retire_presence()
		if not _hidden and faint_seconds >= FAINT_HOLD_SECONDS + FAINT_FADE_SECONDS:
			_hide_remains()
	var next: String = ""
	if pawn.stats.is_active():
		for candidate in STATES:
			if pawn.stats.battle_statuses.has(candidate):
				next = candidate
				break
	if next != state:
		_apply(next)


func _apply(next: String) -> void:
	var sprite: TacticsPawnSprite = pawn.get_node_or_null("Character") as TacticsPawnSprite
	if sprite == null:
		return
	_clear_marker()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	sprite.visible = true
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var target_lift: float = 0.0
	match next:
		"airborne":
			target_lift = LIFT_HEIGHT
		"underground", "underwater":
			sprite.visible = false
			_marker = _spawn_marker(next)
		"vanished":
			sprite.modulate = Color(1.0, 1.0, 1.0, VANISH_ALPHA)
	if not is_equal_approx(sprite.lift_world, target_lift):
		_tween = create_tween()
		_tween.tween_method(sprite.set_lift, sprite.lift_world, target_lift, LIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	state = next


func settle_faint() -> void:
	if pawn == null or pawn.stats == null or pawn.stats.is_active():
		return
	faint_seconds = FAINT_HOLD_SECONDS + FAINT_FADE_SECONDS
	_labels_hidden_for_faint = true
	pawn.show_pawn_stats(false)
	pawn.res.pawn_hud_enabled = false
	_retire_presence()
	_hide_remains()


func is_retired() -> bool:
	return _retired


func _retire_presence() -> void:
	_retired = true
	pawn.collision_layer = 0
	pawn.collision_mask = 0


func _hide_remains() -> void:
	_hidden = true
	pawn.visible = false
	_clear_marker()


func _restore_presence() -> void:
	_retired = false
	_hidden = false
	pawn.collision_layer = _collision_layer
	pawn.collision_mask = _collision_mask
	pawn.visible = true


func faint_alpha() -> float:
	if pawn == null or pawn.stats == null or pawn.stats.is_active():
		return 1.0
	return clampf(1.0 - (faint_seconds - FAINT_HOLD_SECONDS) / FAINT_FADE_SECONDS, 0.0, 1.0)


func _spawn_marker(next: String) -> Node3D:
	var level: TacticsLevel = _level()
	if level == null or level.vfx_player == null or not MARKERS.has(next):
		return null
	var entry: Dictionary = ActionPresentationCatalog.shared().skill(String(MARKERS[next][0]))
	var asset: Dictionary = ActionPresentationCatalog.shared().asset(entry, "particle", String(MARKERS[next][1]))
	if asset.is_empty():
		return null
	var anim: Dictionary = {"index": String(MARKERS[next][1]), "frame_time": 6, "start_frame": -1, "end_frame": -1, "alpha": 255, "flip": 0, "dir": -1}
	var marker: Node3D = level.vfx_player.spawn_static(asset, anim, pawn.global_position, Vector3.FORWARD, 0, 0, 0, 2, "state_%s" % next)
	if marker != null:
		marker.set("lifetime", MARKER_LIFETIME)
	return marker


func _clear_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func _level() -> TacticsLevel:
	var node: Node = pawn
	while node != null:
		if node is TacticsLevel:
			return node as TacticsLevel
		node = node.get_parent()
	return null
