class_name TacticsCameraZoomService
extends RefCounted

const DELTA_SMOOTHING: int = 10
const OVERVIEW_STEP: float = 9.0

var res: TacticsCameraResource


func _init(_res: TacticsCameraResource) -> void:
	res = _res


func zoom_camera(zoom_increment: float) -> void:
	if zoom_increment > 0.0 and res.max_overview > 0.0 and res.target_fov >= res.max_zoom - 0.001:
		res.overview_distance = minf(res.max_overview, res.overview_distance + OVERVIEW_STEP)
		return
	if zoom_increment < 0.0 and res.overview_distance > 0.0:
		res.overview_distance = maxf(0.0, res.overview_distance - OVERVIEW_STEP)
		return
	res.target_fov = clamp(res.target_fov + zoom_increment, res.min_zoom, res.max_zoom)


func apply_zoom_smoothing(camera: TacticsCamera, delta: float) -> void:
	if res.current_fov != res.target_fov:
		res.current_fov = lerp(res.current_fov, res.target_fov, (res.zoom_smoothness * DELTA_SMOOTHING) * delta)
		camera.cam_node.fov = res.current_fov
	if not is_equal_approx(res.current_distance, res.overview_distance):
		res.current_distance = lerp(res.current_distance, res.overview_distance, (res.zoom_smoothness * DELTA_SMOOTHING) * delta)
		if absf(res.current_distance - res.overview_distance) < 0.01:
			res.current_distance = res.overview_distance
		camera.cam_node.position.z = res.base_distance + res.current_distance


func reset_cam_zoom(cam_node: Camera3D, camera: TacticsCamera) -> void:
	res.target_fov = TacticsConfig.view.default_t_cam_zoom
	res.overview_distance = 0.0

	var tween: Tween = camera.create_tween()
	tween.tween_property(cam_node, "fov", res.target_fov, res.zoom_duration).set_trans(Tween.TRANS_SINE)
