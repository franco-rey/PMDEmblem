class_name SkirmishControlMode
extends RefCounted


static func normalize(mode: String) -> String:
	var key: String = mode.strip_edges().to_lower()
	match key:
		"pvp", "player_vs_player", "player-player":
			return SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
		"bots", "-bots", "cpu_vs_cpu", "cpu-cpu":
			return SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU
		_:
			return SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU


static func is_valid(mode: String) -> bool:
	var key: String = mode.strip_edges().to_lower()
	return [
		"",
		"pvc",
		"player_vs_cpu",
		"player-cpu",
		"pvp",
		"player_vs_player",
		"player-player",
		"bots",
		"-bots",
		"cpu_vs_cpu",
		"cpu-cpu",
	].has(key)


static func player_control_type(mode: String) -> int:
	match normalize(mode):
		SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU:
			return PokemonInstanceResource.ControlType.AI
		_:
			return PokemonInstanceResource.ControlType.PLAYER


static func enemy_control_type(mode: String) -> int:
	match normalize(mode):
		SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER:
			return PokemonInstanceResource.ControlType.PLAYER
		_:
			return PokemonInstanceResource.ControlType.AI


static func label(mode: String) -> String:
	match normalize(mode):
		SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER:
			return "Player vs Player"
		SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU:
			return "CPU vs CPU"
		_:
			return "Player vs CPU"


static func apply_to_definition(definition: SkirmishDefinitionResource, mode: String) -> void:
	if definition == null:
		return
	var normalized: String = normalize(mode)
	definition.control_mode = normalized
	for instance in definition.player_team:
		if instance == null:
			continue
		instance.team = PokemonInstanceResource.Team.PLAYER
		instance.control_type = player_control_type(normalized)
	for instance in definition.enemy_team:
		if instance == null:
			continue
		instance.team = PokemonInstanceResource.Team.ENEMY
		instance.control_type = enemy_control_type(normalized)
	var meta: Dictionary = definition.generation_metadata.duplicate(true)
	meta["control_mode"] = normalized
	definition.generation_metadata = meta
