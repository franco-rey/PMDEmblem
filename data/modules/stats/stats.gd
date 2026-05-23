class_name Stats
extends Node
## Runtime stat container attached to each pawn.
##
## Two ways to populate it:
##
## - `init(stats: StatsResource)` for legacy class/mob `.tres` files.
## - `init_from_pokemon(instance: PokemonInstanceResource)` for the M1 Pokemon
##   data slice. The legacy fields (`max_health`, `attack_power`, `movement`,
##   `sprite`, `expertise`) are derived from the species/form so the existing
##   pawn pipeline keeps working unchanged. The Pokemon-specific fields
##   (`hp_max`, six base stats, `types`, `move_slots`, `current_pp`) are
##   exposed for M2's combat slice.

enum BattleStatus { ACTIVE, FAINTED }

## Dictionary to store modifiers
var modifiers: Dictionary = {}
## Override name for the character
var override_name: String
## Expertise of the character (display label - "Lucario", "Cleric", etc.)
var expertise: String
## Current level of the character
var level: int = 1

#region Base Stats
## Movement Points (The radius the pawn can move)
var movement: int
## Jump height
var jump: int
## Maximum health
var max_health: int
## Current health
var curr_health: int
## Sprite path
var sprite: String
#endregion

#region Offensive Stats
## Attack power
var attack_power: int
## Attack range
var attack_range: int
#endregion

#region Pokemon (M1+)
## Pokemon canonical species name when initialized from a PokemonInstanceResource.
var species_name: String = ""
## Pokemon types (lowercase slugs). Empty for legacy-stat pawns.
var types: Array[String] = []
## Mirror of `max_health` named per the M1 spec, kept distinct so future code
## can tell "hp at full" from "max hp" if temporary boosts are added later.
var hp_max: int = 0
## Six PMD base stats. Equal to the form's BaseHP/Atk/Def/MAtk/MDef/Speed
## scaled to the unit's level (M1 just keeps the raw bases - level scaling and
## the real PMD damage formula land in M2).
var attack: int = 0
var defense: int = 0
var special_attack: int = 0
var special_defense: int = 0
var speed: int = 0
## Up to four `PokemonMoveResource`s populated from the instance.
var move_slots: Array[PokemonMoveResource] = []
## PP remaining per move slot, indexed parallel to `move_slots`.
var current_pp: Array[int] = []
## Source of truth for derived legacy fields - kept around so debug tooling
## can inspect the underlying instance.
var pokemon_instance: PokemonInstanceResource = null
## Runtime battle state. Fainting is explicit so future schedulers do not have
## to infer action eligibility from HP alone.
var battle_status: int = BattleStatus.ACTIVE
#endregion


## Initialize stats from a StatsResource (legacy demo path).
func init(stats: StatsResource) -> void:
	override_name = stats.override_name
	expertise = stats.expertise
	level = stats.level
	movement = stats.movement
	stats.set_jump()
	max_health = stats.max_health
	curr_health = max_health
	sprite = stats.sprite
	attack_power = stats.attack_power
	attack_range = stats.attack_range
	hp_max = max_health
	pokemon_instance = null
	battle_status = BattleStatus.ACTIVE


## Initialize stats from a PokemonInstanceResource (M1 Pokemon data slice).
##
## Derives the legacy fields (`max_health`, `attack_power`, `movement`, etc.)
## from the species/form so the existing pawn / combat / sprite code keeps
## working without modification, and exposes the full Pokemon stat block for
## M2's damage resolver.
func init_from_pokemon(instance: PokemonInstanceResource) -> void:
	pokemon_instance = instance
	if instance == null:
		push_error("Stats.init_from_pokemon called with null instance")
		return
	battle_status = BattleStatus.ACTIVE

	var species: PokemonSpeciesResource = instance.species
	var form: PokemonFormResource = instance.resolved_form() if species != null else null

	level = max(1, instance.level)
	override_name = instance.nickname
	species_name = species.canonical_name if species != null else ""
	expertise = species_name if not species_name.is_empty() else (
		species.species_id.capitalize() if species != null else ""
	)

	if form != null:
		types = form.types()
		hp_max = form.base_hp + level * 2
		max_health = hp_max
		attack = form.base_atk
		defense = form.base_def
		special_attack = form.base_spa
		special_defense = form.base_spd
		speed = form.base_speed
		# Rough legacy parity for the existing direct-damage attack (M2 swaps in
		# a real damage formula).
		attack_power = int(maxi(form.base_atk, form.base_spa) / 5.0)
		sprite = form.sprite_set.idle_path if form.sprite_set != null else ""
	else:
		types = []
		hp_max = 1
		max_health = 1
		attack = 0
		defense = 0
		special_attack = 0
		special_defense = 0
		speed = 0
		attack_power = 1
		sprite = ""
	curr_health = hp_max if instance.current_hp == PokemonInstanceResource.CURRENT_HP_AUTO else instance.current_hp
	if curr_health <= 0:
		battle_status = BattleStatus.FAINTED

	movement = instance.movement_override if instance.movement_override > 0 else 4
	jump = int(floor(movement / 2.0))

	move_slots = []
	current_pp = []
	for i in range(instance.move_slots.size()):
		var move: PokemonMoveResource = instance.move_slots[i]
		if move == null:
			continue
		move_slots.append(move)
		var pp: int = move.pp
		if i < instance.pp_state.size():
			pp = int(instance.pp_state[i])
		current_pp.append(pp)

	if not move_slots.is_empty():
		attack_range = max(1, move_slots[0].tactical_range_value)
	else:
		attack_range = 1


func has_pp(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= current_pp.size():
		return false
	return current_pp[slot_index] > 0


func consume_pp(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= current_pp.size():
		return
	current_pp[slot_index] = maxi(0, current_pp[slot_index] - 1)


func refill_all_pp() -> void:
	current_pp.clear()
	for move: PokemonMoveResource in move_slots:
		current_pp.append(move.pp if move != null else 0)


func first_usable_move_index(require_damaging: bool = false) -> int:
	for i in range(move_slots.size()):
		var move: PokemonMoveResource = move_slots[i]
		if move == null:
			continue
		if require_damaging and not move.is_damaging():
			continue
		if has_pp(i):
			return i
	return -1


func is_active() -> bool:
	return battle_status == BattleStatus.ACTIVE


## Provided a health operation as a parameter (e.g. "-2", "1"), adds the value to current health. As a consequence, this function serves for both damage and healing.
func apply_to_curr_health(new: int) -> void:
	print("Target initial health: ", curr_health, " - Applying damage: ", new)
	curr_health = clamp(curr_health + new, 0, max_health) # Apply health change and clamp to valid range
	if curr_health <= 0:
		battle_status = BattleStatus.FAINTED
	elif battle_status == BattleStatus.FAINTED:
		battle_status = BattleStatus.ACTIVE
	print("Target final health: ", curr_health)
