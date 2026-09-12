class_name InputCapture
extends Node3D


func project_mouse_position(collision_mask: int, is_joystick: bool) -> Object:
	var ray_length: int = 1_000_000
	var camera: Camera3D = get_viewport().get_camera_3d()
	var mouse_pointer_origin: Vector2 = get_viewport().get_mouse_position() if not is_joystick else get_viewport().get_visible_rect().size / 2.0
	var from: Vector3 = camera.project_ray_origin(mouse_pointer_origin)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pointer_origin) * ray_length
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, [])
	return get_world_3d().direct_space_state.intersect_ray(ray_query).get("collider")
