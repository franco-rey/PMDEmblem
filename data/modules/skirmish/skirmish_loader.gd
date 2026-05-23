class_name SkirmishLoader
extends Node
## Runtime assembler for SkirmishDefinitionResource battles.
##
## The loader is the only M4 code that knows how to turn skirmish data into a
## live TacticsLevel: map scene, participant nodes, spawned pawns, and seed.

signal skirmish_loaded(level: TacticsLevel)
signal skirmish_ended(result: int, definition: SkirmishDefinitionResource)

const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"

var current_definition: SkirmishDefinitionResource = null
var current_level: TacticsLevel = null

var _pawn_scene: PackedScene = preload("res://data/modules/tactics/level/pawn/pawn.tscn")
var _expertise_scene: PackedScene = preload("res://data/modules/stats/expertise/expertise.tscn")


func load_skirmish(definition: SkirmishDefinitionResource, battle_parent: Node = null) -> TacticsLevel:
	unload_current()
	if not _validate_definition(definition):
		return null

	var map_scene: PackedScene = load(definition.map.scene_path) as PackedScene
	if map_scene == null:
		push_error("SkirmishLoader: could not load map scene %s" % definition.map.scene_path)
		return null

	var level := TacticsLevel.new()
	level.name = "TacticsLevel"
	level.use_speed_scheduler = true
	level.battle_seed = definition.seed

	var arena: TacticsArena = map_scene.instantiate() as TacticsArena
	if arena == null:
		push_error("SkirmishLoader: map scene root must be a TacticsArena: %s" % definition.map.scene_path)
		level.free()
		return null
	arena.name = "TacticsArena"
	arena.unique_name_in_owner = true
	level.add_child(arena)

	var participant := TacticsParticipant.new()
	participant.name = "TacticsParticipant"
	level.add_child(participant)

	var player := TacticsPlayer.new()
	player.name = "TacticsPlayer"
	player.unique_name_in_owner = true
	participant.add_child(player)

	var opponent := TacticsOpponent.new()
	opponent.name = "TacticsOpponent"
	opponent.unique_name_in_owner = true
	participant.add_child(opponent)

	var player_anchors: Array[Node3D] = _collect_spawn_anchors(arena, "SpawnPlayer")
	var enemy_anchors: Array[Node3D] = _collect_spawn_anchors(arena, "SpawnEnemy")
	if player_anchors.size() < definition.player_team.size():
		push_error("SkirmishLoader: %s needs %d player spawns, found %d" % [
			definition.skirmish_id,
			definition.player_team.size(),
			player_anchors.size(),
		])
		level.free()
		return null
	if enemy_anchors.size() < definition.enemy_team.size():
		push_error("SkirmishLoader: %s needs %d enemy spawns, found %d" % [
			definition.skirmish_id,
			definition.enemy_team.size(),
			enemy_anchors.size(),
		])
		level.free()
		return null

	_spawn_team(definition.player_team, player, player_anchors, level)
	_spawn_team(definition.enemy_team, opponent, enemy_anchors, level)
	_assign_owner(level, level)

	current_definition = definition
	current_level = level
	level.battle_ended.connect(_on_level_battle_ended.bind(definition))

	var parent: Node = battle_parent if battle_parent != null else get_parent()
	if parent == null:
		parent = get_tree().root
	parent.add_child(level)
	skirmish_loaded.emit(level)
	return level


func unload_current() -> void:
	if is_instance_valid(current_level):
		current_level.queue_free()
	current_level = null
	current_definition = null


func _validate_definition(definition: SkirmishDefinitionResource) -> bool:
	if definition == null:
		push_error("SkirmishLoader: definition is null")
		return false
	if definition.map == null:
		push_error("SkirmishLoader: %s has no map" % definition.skirmish_id)
		return false
	if definition.map.scene_path.is_empty():
		push_error("SkirmishLoader: %s map has empty scene_path" % definition.skirmish_id)
		return false
	if definition.player_team.is_empty():
		push_error("SkirmishLoader: %s has empty player_team" % definition.skirmish_id)
		return false
	if definition.enemy_team.is_empty():
		push_error("SkirmishLoader: %s has empty enemy_team" % definition.skirmish_id)
		return false
	if definition.objective != SkirmishDefinitionResource.OBJECTIVE_DEFEAT_ALL_ENEMIES:
		push_warning("SkirmishLoader: objective %d is not implemented yet; using defeat-all checks" % definition.objective)
	return true


func _collect_spawn_anchors(arena: TacticsArena, prefix: String) -> Array[Node3D]:
	var spawn_points: Node = arena.get_node_or_null("SpawnPoints")
	var anchors: Array[Node3D] = []
	if spawn_points == null:
		push_error("SkirmishLoader: %s is missing SpawnPoints" % arena.name)
		return anchors
	for child in spawn_points.get_children():
		if child is Node3D and _matches_spawn_name(child.name, prefix):
			anchors.append(child as Node3D)
	anchors.sort_custom(_is_spawn_anchor_less_than)
	return anchors


func _matches_spawn_name(anchor_name: String, prefix: String) -> bool:
	if anchor_name == prefix:
		return true
	if not anchor_name.begins_with(prefix):
		return false
	var suffix: String = anchor_name.substr(prefix.length())
	return suffix.is_valid_int()


func _is_spawn_anchor_less_than(a: Node3D, b: Node3D) -> bool:
	var order_a: int = _spawn_anchor_order(a.name)
	var order_b: int = _spawn_anchor_order(b.name)
	if order_a != order_b:
		return order_a < order_b
	return a.name < b.name


func _spawn_anchor_order(anchor_name: String) -> int:
	var digits: String = ""
	for i in range(anchor_name.length()):
		var ch: String = anchor_name.substr(i, 1)
		if ch.is_valid_int():
			digits += ch
	return int(digits) if not digits.is_empty() else 0


func _spawn_team(team: Array[PokemonInstanceResource], parent: Node3D, anchors: Array[Node3D], level: TacticsLevel) -> void:
	for i in range(team.size()):
		var instance: PokemonInstanceResource = team[i]
		var pawn: TacticsPawn = _pawn_scene.instantiate() as TacticsPawn
		pawn.name = "Pawn" if i == 0 else "Pawn%d" % (i + 1)

		var expertise: Expertise = _expertise_scene.instantiate() as Expertise
		expertise.name = "Expertise"
		expertise.pokemon_instance = instance
		pawn.add_child(expertise)

		parent.add_child(pawn)
		var anchor_transform: Transform3D = _local_transform_to(anchors[i], level)
		var parent_transform: Transform3D = _local_transform_to(parent, level)
		pawn.transform = parent_transform.affine_inverse() * anchor_transform


func _local_transform_to(node: Node3D, ancestor: Node) -> Transform3D:
	var out: Transform3D = node.transform
	var current: Node = node.get_parent()
	while current != null and current != ancestor:
		if current is Node3D:
			out = (current as Node3D).transform * out
		current = current.get_parent()
	return out


func _assign_owner(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_assign_owner(child, scene_owner)


func _on_level_battle_ended(result: int, definition: SkirmishDefinitionResource) -> void:
	skirmish_ended.emit(result, definition)
