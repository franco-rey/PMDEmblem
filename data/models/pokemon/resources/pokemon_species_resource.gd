class_name PokemonSpeciesResource
extends Resource
## Top-level Pokemon species record imported from PMDODump's `Monster/<slug>.json`.
##
## Owns one or more `PokemonFormResource`s and points at one as the default.
## Species-level metadata (dex number, name, learnsets, evolution chain) lives
## here; per-form combat data lives on the form resources.

@export var species_id: String = ""
@export var dex_number: int = 0
@export var canonical_name: String = ""
@export var released: bool = true

## Index into `forms` for the form M1 spawns by default. Almost always 0
## (Mega/Gigantamax forms are catalogued but not picked).
@export var default_form_index: int = 0
@export var forms: Array[PokemonFormResource] = []

## Each entry is `{ "level": int, "skill": String }`, ordered by the PMD JSON.
@export var level_skills: Array[Dictionary] = []
## Move slugs that can be taught via TM/tutor.
@export var teach_skills: Array[String] = []
## Move slugs shared across the species' egg group (PMD `SharedSkills`).
@export var shared_skills: Array[String] = []
## Move slugs from PMD's `SecretSkills` (rare/event tutors).
@export var secret_skills: Array[String] = []

## Slug of the species this one evolves from, empty if base.
@export var evolution_from: String = ""
## Egg / skill groups from PMD.
@export var skill_group1: String = ""
@export var skill_group2: String = ""


func default_form() -> PokemonFormResource:
	if forms.is_empty():
		return null
	if default_form_index < 0 or default_form_index >= forms.size():
		return forms[0]
	return forms[default_form_index]


## Returns the move slug a freshly-recruited level-1 Pokemon would know first,
## or an empty string if no level-1 entry exists. Useful as a fallback when the
## importer can't find a curated signature move.
func first_level_move() -> String:
	for entry in level_skills:
		if int(entry.get("level", 0)) <= 1:
			return String(entry.get("skill", ""))
	if not level_skills.is_empty():
		return String(level_skills[0].get("skill", ""))
	return ""
