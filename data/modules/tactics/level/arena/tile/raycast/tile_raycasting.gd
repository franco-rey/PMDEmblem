class_name TacticsTileRaycast
extends Node3D


func get_all_neighbors(height: float) -> Array[Node3D]:
	var neighbors: Array[Node3D] = []

	for ray: RayCast3D in $Neighbors.get_children() as Array[RayCast3D]:
		var obj: Node3D = ray.get_collider()

		if (obj and abs(obj.global_position.y - get_parent().global_position.y)
				<= height):
			neighbors.append(obj)

	return neighbors


func get_object_above() -> Object:
	return $Above.get_collider()
