class_name RandomSkirmishGenerator
extends RefCounted

const MIN_TEAM_SIZE: int = 1
const MAX_TEAM_SIZE: int = 8
const DEFAULT_REWARD_PROFILE: String = "default"
const GENERATION_SEED_SALT: int = 0x9E3779B1
const PLAYER_SPAWN_SALT: int = 0x13579BDF
const ENEMY_SPAWN_SALT: int = 0x5A5A5A5A
const ANCHOR_POOL_SIZE: int = 8
const TRAVELLER_SEED_SALT: int = 0x2C1D5E7B
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

const DIFFICULTY_TIERS: Array[Dictionary] = [
	{"tier": 0, "min_level": 1, "max_level": 5, "enemy_budget": 3},
	{"tier": 1, "min_level": 5, "max_level": 15, "enemy_budget": 5},
	{"tier": 2, "min_level": 15, "max_level": 25, "enemy_budget": 7},
	{"tier": 3, "min_level": 25, "max_level": 40, "enemy_budget": 9},
	{"tier": 4, "min_level": 40, "max_level": 50, "enemy_budget": 12},
]


class GeneratorInputs:
	extends RefCounted

	var seed: int = 0
	var biome: String = ""
	var difficulty_tier: int = 0
	var player_party: Array[PokemonInstanceResource] = []
	var enemy_team_size: int = 0
	var enemy_budget: int = 0
	var map_pool: Array[MapDefinitionResource] = []
	var roster_templates: Array[PokemonInstanceResource] = []
	var reward_profile: String = DEFAULT_REWARD_PROFILE
	var max_team_size: int = MAX_TEAM_SIZE
	var require_travellers: bool = false


static func generate(inputs: GeneratorInputs) -> SkirmishDefinitionResource:
	if inputs == null:
		push_error("RandomSkirmishGenerator: inputs are null")
		return null
	if inputs.player_party.is_empty():
		push_error("RandomSkirmishGenerator: player_party is empty")
		return null
	if inputs.map_pool.is_empty():
		push_error("RandomSkirmishGenerator: map_pool is empty")
		return null
	if inputs.roster_templates.is_empty():
		push_error("RandomSkirmishGenerator: roster_templates is empty")
		return null

	var tier: Dictionary = tier_config(inputs.difficulty_tier)
	var rng := RandomNumberGenerator.new()
	rng.seed = _salt_seed(inputs.seed, GENERATION_SEED_SALT)

	var map: MapDefinitionResource = _pick_map(inputs.map_pool, inputs.biome, rng)
	if map == null:
		push_error("RandomSkirmishGenerator: no map matched biome '%s'" % inputs.biome)
		return null

	var enemy_size: int = _resolve_enemy_size(inputs, tier, map, rng)
	var cap: int = maxi(MIN_TEAM_SIZE, inputs.max_team_size)
	if enemy_size < MIN_TEAM_SIZE or enemy_size > cap:
		push_error("RandomSkirmishGenerator: enemy team size %d outside %d-%d" % [enemy_size, MIN_TEAM_SIZE, cap])
		return null

	var enemy_team: Array[PokemonInstanceResource] = _build_enemy_team(inputs.roster_templates, enemy_size, tier, rng, inputs.require_travellers)
	if enemy_team.size() != enemy_size:
		push_error("RandomSkirmishGenerator: generated %d enemies, expected %d" % [enemy_team.size(), enemy_size])
		return null

	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = _skirmish_id(inputs.seed, inputs.biome, int(tier["tier"]), enemy_size)
	definition.display_name = _display_name(inputs.biome, int(tier["tier"]), enemy_size)
	definition.map = map
	definition.seed = inputs.seed
	definition.player_team = inputs.player_party.duplicate()
	definition.enemy_team = enemy_team
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU
	definition.objective = SkirmishDefinitionResource.OBJECTIVE_DEFEAT_ALL_ENEMIES
	definition.reward_profile = inputs.reward_profile if not inputs.reward_profile.is_empty() else DEFAULT_REWARD_PROFILE
	definition.generation_metadata = _metadata(inputs, tier, map, enemy_team)
	return definition


static func tier_config(tier_index: int) -> Dictionary:
	var clamped: int = clampi(tier_index, 0, DIFFICULTY_TIERS.size() - 1)
	return DIFFICULTY_TIERS[clamped].duplicate(true)


static func attach_spawn_orders(definition: SkirmishDefinitionResource, player_anchor_count: int, enemy_anchor_count: int, anchor_pool_size: int = ANCHOR_POOL_SIZE) -> bool:
	if definition == null:
		push_error("RandomSkirmishGenerator: cannot attach spawn orders to null definition")
		return false
	var player_pool: int = mini(player_anchor_count, anchor_pool_size)
	var enemy_pool: int = mini(enemy_anchor_count, anchor_pool_size)
	if player_pool < definition.player_team.size():
		push_error("RandomSkirmishGenerator: map has %d player anchors in pool; need %d" % [player_pool, definition.player_team.size()])
		return false
	if enemy_pool < definition.enemy_team.size():
		push_error("RandomSkirmishGenerator: map has %d enemy anchors in pool; need %d" % [enemy_pool, definition.enemy_team.size()])
		return false
	var metadata: Dictionary = definition.generation_metadata.duplicate(true)
	metadata["player_spawn_order"] = build_spawn_order(definition.seed ^ PLAYER_SPAWN_SALT, definition.player_team.size(), player_pool)
	metadata["enemy_spawn_order"] = build_spawn_order(definition.seed ^ ENEMY_SPAWN_SALT, definition.enemy_team.size(), enemy_pool)
	definition.generation_metadata = metadata
	return true


static func build_spawn_order(seed: int, team_size: int, pool_size: int) -> Array[int]:
	var out: Array[int] = []
	if team_size <= 0 or pool_size <= 0 or team_size > pool_size:
		return out
	var pool: Array[int] = []
	for i in range(pool_size):
		pool.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(pool.size() - 1, 0, -1):
		var j: int = int(rng.randi_range(0, i))
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in range(team_size):
		out.append(pool[i])
	return out


static func _pick_map(map_pool: Array[MapDefinitionResource], biome: String, rng: RandomNumberGenerator) -> MapDefinitionResource:
	var candidates: Array[MapDefinitionResource] = []
	for map in map_pool:
		if map == null:
			continue
		if biome.is_empty() or map.biome == biome:
			candidates.append(map)
	if candidates.is_empty():
		return null
	candidates.sort_custom(_is_map_less_than)
	return candidates[int(rng.randi_range(0, candidates.size() - 1))]


static func _is_map_less_than(a: MapDefinitionResource, b: MapDefinitionResource) -> bool:
	return a.map_id < b.map_id


static func _resolve_enemy_size(inputs: GeneratorInputs, tier: Dictionary, map: MapDefinitionResource, rng: RandomNumberGenerator) -> int:
	if inputs.enemy_team_size > 0:
		return clampi(inputs.enemy_team_size, MIN_TEAM_SIZE, maxi(MIN_TEAM_SIZE, inputs.max_team_size))
	if map.recommended_team_size > 0:
		return clampi(map.recommended_team_size, MIN_TEAM_SIZE, MAX_TEAM_SIZE)
	return clampi(inputs.player_party.size(), MIN_TEAM_SIZE, MAX_TEAM_SIZE)


static func _build_enemy_team(roster_templates: Array[PokemonInstanceResource], enemy_size: int, tier: Dictionary, rng: RandomNumberGenerator, require_travellers: bool = false) -> Array[PokemonInstanceResource]:
	var out: Array[PokemonInstanceResource] = []
	var pool: Array[PokemonInstanceResource] = []
	for template in roster_templates:
		if template != null and template.species != null:
			pool.append(template)
	pool.sort_custom(_is_template_less_than)
	if pool.is_empty():
		return out
	var allow_duplicates: bool = enemy_size > pool.size()
	var available: Array[PokemonInstanceResource] = pool.duplicate()
	if require_travellers:
		for slug in MultiverseRoster.required_slugs(enemy_size, [], _salt_seed(rng.seed, TRAVELLER_SEED_SALT)):
			if out.size() >= enemy_size:
				break
			var forced: PokemonInstanceResource = _template_for_slug(available, String(slug))
			if forced == null:
				continue
			if not allow_duplicates:
				available.erase(forced)
			out.append(_make_enemy_instance(forced, tier, rng, out.size()))
	for i in range(out.size(), enemy_size):
		if available.is_empty():
			if not allow_duplicates:
				break
			available = pool.duplicate()
		var pick_index: int = int(rng.randi_range(0, available.size() - 1))
		var template: PokemonInstanceResource = available[pick_index]
		if not allow_duplicates:
			available.remove_at(pick_index)
		out.append(_make_enemy_instance(template, tier, rng, i))
	return out


static func _template_for_slug(pool: Array[PokemonInstanceResource], slug: String) -> PokemonInstanceResource:
	for template in pool:
		if template != null and template.species != null and String(template.species.species_id) == slug:
			return template
	return null


static func _is_template_less_than(a: PokemonInstanceResource, b: PokemonInstanceResource) -> bool:
	return a.species.species_id < b.species.species_id


static func _make_enemy_instance(template: PokemonInstanceResource, tier: Dictionary, rng: RandomNumberGenerator, slot_index: int) -> PokemonInstanceResource:
	var instance := PokemonInstanceResource.new()
	instance.species = template.species
	instance.form_index = template.form_index
	instance.level = int(rng.randi_range(int(tier["min_level"]), int(tier["max_level"])))
	instance.experience = PokemonExperienceService.xp_for_level(instance.resolved_form(), instance.level)
	instance.current_hp = PokemonInstanceResource.CURRENT_HP_AUTO
	instance.team = PokemonInstanceResource.Team.ENEMY
	instance.control_type = PokemonInstanceResource.ControlType.AI
	instance.movement_override = template.movement_override
	instance.recruited = false
	instance.nature_id = template.nature_id
	instance.permanent_modifiers = template.permanent_modifiers.duplicate(true)
	instance.held_item = template.held_item
	instance.runtime_modifiers = {}
	instance.temporary_statuses = []
	instance.move_slots = _moves_for_level(template, instance.level)
	instance.pp_state = []
	for move in instance.move_slots:
		instance.pp_state.append(move.pp if move != null else 0)
	SkirmishMoveLoadout.assign_loadout(instance, int(rng.seed), "enemy", slot_index)
	return instance


static func _moves_for_level(template: PokemonInstanceResource, level: int) -> Array[PokemonMoveResource]:
	var moves: Array[PokemonMoveResource] = []
	var species: PokemonSpeciesResource = template.species
	if species != null:
		var learned: Array[Dictionary] = []
		for entry in species.level_skills:
			if int(entry.get("level", 0)) <= level:
				learned.append(entry)
		var seen: Dictionary = {}
		for i in range(learned.size() - 1, -1, -1):
			var slug: String = String(learned[i].get("skill", ""))
			if slug.is_empty() or seen.has(slug):
				continue
			var move: PokemonMoveResource = _load_move(slug)
			if move == null:
				continue
			seen[slug] = true
			moves.push_front(move)
			if moves.size() >= PokemonInstanceResource.MAX_MOVE_SLOTS:
				break
	if moves.is_empty():
		for move in template.move_slots:
			if move != null:
				moves.append(move)
			if moves.size() >= PokemonInstanceResource.MAX_MOVE_SLOTS:
				break
	return moves


static func _load_move(slug: String) -> PokemonMoveResource:
	if slug.is_empty():
		return null
	var path: String = "%s%s.tres" % [GENERATED_MOVES_DIR, slug]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PokemonMoveResource


static func _metadata(inputs: GeneratorInputs, tier: Dictionary, map: MapDefinitionResource, enemy_team: Array[PokemonInstanceResource]) -> Dictionary:
	var enemy_species: Array[String] = []
	var enemy_levels: Array[int] = []
	var enemy_moves: Array[Array] = []
	for instance in enemy_team:
		enemy_species.append(instance.species.species_id if instance != null and instance.species != null else "?")
		enemy_levels.append(instance.level if instance != null else 0)
		var moves: Array[String] = []
		if instance != null:
			for move in instance.move_slots:
				moves.append(move.move_id if move != null else "?")
		enemy_moves.append(moves)
	return {
		"source": "random_generator",
		"control_mode": SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU,
		"seed": inputs.seed,
		"biome": inputs.biome,
		"difficulty_tier": int(tier["tier"]),
		"enemy_budget": inputs.enemy_budget if inputs.enemy_budget > 0 else int(tier["enemy_budget"]),
		"enemy_team_size": enemy_team.size(),
		"picked_map": map.map_id if map != null else "",
		"picked_species_slugs": enemy_species,
		"enemy_levels": enemy_levels,
		"enemy_moves": enemy_moves,
	}


static func _skirmish_id(seed: int, biome: String, tier: int, team_size: int) -> String:
	var biome_part: String = "any" if biome.is_empty() else biome
	return "random_%s_t%d_%dv%d_%d" % [biome_part, tier, team_size, team_size, seed]


static func _display_name(biome: String, tier: int, team_size: int) -> String:
	var biome_part: String = "Any" if biome.is_empty() else biome.capitalize()
	return "Random %s %dv%d (tier %d)" % [biome_part, team_size, team_size, tier]


static func _salt_seed(seed: int, salt: int) -> int:
	return int((seed ^ salt) & 0x7FFFFFFF)
