class_name TacticsPawnMovementService
extends RefCounted

const ARRIVAL_DISTANCE: float = 0.15
const WAYPOINT_TIMEOUT: float = 6.0


func look_at_direction(pawn: TacticsPawn, dir: Vector3) -> void:
	if Vector3(dir.x, 0.0, dir.z).length() < 0.0001:
		return
	var _fixed_dir: Vector3 = dir * (Vector3(1, 0, 0) if abs(dir.x) > abs(dir.z) else Vector3(0, 0, 1))
	var _angle: float = Vector3.FORWARD.signed_angle_to(_fixed_dir.normalized(), Vector3.UP) + PI
	var _new_rot: Vector3 = Vector3.UP * _angle
	pawn.set_rotation(_new_rot)


func look_at_direction_8(pawn: TacticsPawn, dir: Vector3) -> Vector3i:
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.0001:
		return Vector3i.ZERO
	var grid: Vector3i = snap_direction_8(flat)
	var facing: Vector3 = Vector3(float(grid.x), 0.0, float(grid.z)).normalized()
	var _angle: float = Vector3.FORWARD.signed_angle_to(facing, Vector3.UP) + PI
	pawn.set_rotation(Vector3.UP * _angle)
	return grid


func facing_direction_8(pawn: TacticsPawn) -> Vector3i:
	if pawn == null:
		return Vector3i.ZERO
	return snap_direction_8(Vector3.FORWARD.rotated(Vector3.UP, pawn.rotation.y - PI))


static func snap_direction_8(dir: Vector3) -> Vector3i:
	var flat: Vector2 = Vector2(dir.x, dir.z)
	if flat.length() < 0.0001:
		return Vector3i.ZERO
	var angle: float = flat.angle()
	var octant: int = int(round(angle / (PI / 4.0)))
	var snapped: Vector2 = Vector2.RIGHT.rotated(float(octant) * PI / 4.0)
	return Vector3i(int(round(snapped.x)), 0, int(round(snapped.y)))


func move_along_path(pawn: TacticsPawn, delta: float) -> void:
	if pawn.res.pathfinding_tilestack.is_empty() or not pawn.res.can_move:
		return

	start_movement(pawn)
	var target: Vector3 = pawn.res.pathfinding_tilestack.front()
	pawn.res.waypoint_elapsed += delta

	if pawn.res.move_direction.length() > 0.5 and pawn.res.waypoint_elapsed <= WAYPOINT_TIMEOUT:
		var remaining: float = pawn.global_position.distance_to(target)
		var step: float = calculate_speed(pawn) * delta
		if remaining > maxf(ARRIVAL_DISTANCE, step):
			perform_movement(pawn, delta)
			var after: Vector3 = target - pawn.global_position
			if after.length() >= ARRIVAL_DISTANCE and after.dot(pawn.res.move_direction) > 0.0:
				return
	elif pawn.res.waypoint_elapsed > WAYPOINT_TIMEOUT:
		_log_timeout(pawn, target)

	pawn.global_position = target
	var tile_ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
	if tile_ray != null:
		tile_ray.force_raycast_update()
	var reached: Variant = pawn.res.pathfinding_tilestack.pop_front()
	reset_movement_state(pawn)
	if reached is Vector3:
		_notify_tile_reached(pawn, reached)
	check_movement_completion(pawn)


func _log_timeout(pawn: TacticsPawn, target: Vector3) -> void:
	var node: Node = pawn.get_parent()
	while node != null and not (node is TacticsLevel):
		node = node.get_parent()
	if node is TacticsLevel:
		(node as TacticsLevel).battle_log.append({"kind": "movement_timeout", "unit": pawn, "target": target, "elapsed": pawn.res.waypoint_elapsed})


func _notify_tile_reached(pawn: TacticsPawn, position: Vector3) -> void:
	var node: Node = pawn.get_parent()
	while node != null and not (node is TacticsLevel):
		node = node.get_parent()
	if node is TacticsLevel:
		(node as TacticsLevel).on_pawn_reached_tile(pawn, position)


func start_movement(pawn: TacticsPawn) -> void:
	pawn.res.set_moving(true)
	if pawn.res.move_direction == Vector3.ZERO:
		pawn.res.move_direction = pawn.res.pathfinding_tilestack.front() - pawn.global_position


func perform_movement(pawn: TacticsPawn, delta: float) -> void:
	look_at_direction(pawn, pawn.res.move_direction)
	var _p_velocity: Vector3 = calculate_velocity(pawn, delta)
	var _curr_speed: float = calculate_speed(pawn)

	pawn.set_velocity(_p_velocity * _curr_speed)
	pawn.set_up_direction(Vector3.UP)
	pawn.move_and_slide()


func calculate_velocity(pawn: TacticsPawn, delta: float) -> Vector3:
	var _p_velocity: Vector3 = pawn.res.move_direction.normalized()

	if pawn.res.move_direction.y < -TacticsPawnResource.MIN_HEIGHT_TO_JUMP:
		var _first_tile_in_stack : Vector3 = pawn.res.pathfinding_tilestack.front()
		if CalcVector.distance_without_y(_first_tile_in_stack, pawn.global_position) <= 0.2:
			pawn.res.gravity += Vector3.DOWN * delta * TacticsPawnResource.GRAVITY_STRENGTH
			_p_velocity = (pawn.res.pathfinding_tilestack.front() - pawn.global_position).normalized() + pawn.res.gravity
		else:
			_p_velocity = CalcVector.remove_y(pawn.res.move_direction).normalized()

	return _p_velocity


func calculate_speed(pawn: TacticsPawn) -> float:
	var _curr_speed: float = pawn.res.walk_speed

	if pawn.res.move_direction.y > TacticsPawnResource.MIN_HEIGHT_TO_JUMP:
		_curr_speed = clamp(abs(pawn.res.move_direction.y) * 2.3, 3, INF)
		pawn.res.is_jumping = true

	return _curr_speed


func reset_movement_state(pawn: TacticsPawn) -> void:
	pawn.res.move_direction = Vector3.ZERO
	pawn.res.is_jumping = false
	pawn.res.gravity = Vector3.ZERO
	pawn.res.waypoint_elapsed = 0.0
	pawn.res.can_move = pawn.res.pathfinding_tilestack.size() > 0


func check_movement_completion(pawn: TacticsPawn) -> void:
	if not pawn.res.can_move:
		pawn.res.set_moving(false)
		pawn.character.adjust_to_center(pawn)
		var node: Node = pawn.get_parent()
		while node != null:
			if node is TacticsLevel:
				(node as TacticsLevel).try_pickup_landed_item(pawn)
				break
			node = node.get_parent()
