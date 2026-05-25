class_name CalcVector
extends Node


static func remove_y(vector: Vector3) -> Vector3:
	return vector * Vector3(1,0,1)


static func distance_without_y(b: Vector3, a: Vector3) -> float:
	return remove_y(b).distance_to(remove_y(a))
