class_name PokemonSpeciesResource
extends Resource

@export var species_id: String = ""
@export var dex_number: int = 0
@export var canonical_name: String = ""
@export var released: bool = true

@export var default_form_index: int = 0
@export var forms: Array[PokemonFormResource] = []

@export var level_skills: Array[Dictionary] = []
@export var teach_skills: Array[String] = []
@export var shared_skills: Array[String] = []
@export var secret_skills: Array[String] = []

@export var evolution_from: String = ""
@export var evolutions: Array[Dictionary] = []
@export var skill_group1: String = ""
@export var skill_group2: String = ""


func default_form() -> PokemonFormResource:
	if forms.is_empty():
		return null
	if default_form_index < 0 or default_form_index >= forms.size():
		return forms[0]
	return forms[default_form_index]


func first_level_move() -> String:
	for entry in level_skills:
		if int(entry.get("level", 0)) <= 1:
			return String(entry.get("skill", ""))
	if not level_skills.is_empty():
		return String(level_skills[0].get("skill", ""))
	return ""
