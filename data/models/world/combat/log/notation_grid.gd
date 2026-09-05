class_name NotationGrid
extends RefCounted

var origin: Vector3i = Vector3i.ZERO
var columns: int = 0
var rows: int = 0
var base_height: float = 0.0
var heights: Dictionary = {}


func setup(keys: Dictionary) -> void:
	heights.clear()
	origin = Vector3i.ZERO
	columns = 0
	rows = 0
	base_height = 0.0
	if keys.is_empty():
		return
	var first: bool = true
	var min_x: int = 0
	var max_x: int = 0
	var min_z: int = 0
	var max_z: int = 0
	var min_y: float = 0.0
	var raw_heights: Dictionary = {}
	for key in keys.keys():
		var k: Vector3i = flat(key)
		var y: float = _tile_height(keys[key])
		if first:
			min_x = k.x
			max_x = k.x
			min_z = k.z
			max_z = k.z
			min_y = y
			first = false
		min_x = mini(min_x, k.x)
		max_x = maxi(max_x, k.x)
		min_z = mini(min_z, k.z)
		max_z = maxi(max_z, k.z)
		min_y = minf(min_y, y)
		raw_heights[k] = y
	origin = Vector3i(min_x, 0, min_z)
	columns = max_x - min_x + 1
	rows = max_z - min_z + 1
	base_height = min_y
	for key in raw_heights.keys():
		heights[key] = snappedf(float(raw_heights[key]) - base_height, 0.5)


func has(key: Vector3i) -> bool:
	return heights.has(flat(key))


func height(key: Vector3i) -> float:
	return float(heights.get(flat(key), 0.0))


func label(key: Vector3i) -> String:
	var k: Vector3i = flat(key)
	return "%s%d" % [column_letters(k.x - origin.x), k.z - origin.z + 1]


func key_for_label(text: String) -> Vector3i:
	var letters: String = ""
	var digits: String = ""
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		if ch.to_upper() >= "A" and ch.to_upper() <= "Z":
			letters += ch.to_upper()
		else:
			digits += ch
	if letters.is_empty() or not digits.is_valid_int():
		return Vector3i(-1, -1, -1)
	return origin + Vector3i(column_index(letters), 0, int(digits) - 1)


func grid_span() -> String:
	if columns <= 0 or rows <= 0:
		return "A1 A1"
	return "%s %s" % [label(origin), label(origin + Vector3i(columns - 1, 0, rows - 1))]


func terrain_lines() -> Array[String]:
	var out: Array[String] = []
	for row in range(rows):
		var tokens: Array[String] = []
		for column in range(columns):
			var key: Vector3i = origin + Vector3i(column, 0, row)
			if heights.has(key):
				tokens.append("%s:%s" % [column_letters(column), format_height(float(heights[key]))])
		if not tokens.is_empty():
			out.append("terrain %d %s" % [row + 1, " ".join(tokens)])
	return out


static func flat(key: Vector3i) -> Vector3i:
	return Vector3i(key.x, 0, key.z)


static func format_height(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value


static func is_label(text: String) -> bool:
	if text.length() < 2:
		return false
	var i: int = 0
	while i < text.length() and text.substr(i, 1) >= "A" and text.substr(i, 1) <= "Z":
		i += 1
	return i > 0 and i < text.length() and text.substr(i).is_valid_int()


static func column_letters(index: int) -> String:
	var letters: String = ""
	var n: int = index
	while true:
		letters = String.chr(65 + (n % 26)) + letters
		n = int(n / 26) - 1
		if n < 0:
			break
	return letters


static func column_index(letters: String) -> int:
	var col: int = 0
	for i in range(letters.length()):
		col = col * 26 + (letters.unicode_at(i) - 64)
	return col - 1


static func _tile_height(tile: Variant) -> float:
	if tile is Node3D:
		var node: Node3D = tile
		return node.global_position.y if node.is_inside_tree() else node.position.y
	return 0.0
