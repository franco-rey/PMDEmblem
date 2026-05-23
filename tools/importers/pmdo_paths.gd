@tool
class_name PMDOPaths
extends RefCounted
## Constants shared by the PMDODump importer.
##
## Centralized so the M7 bulk importer can extend the species/move lists
## without scrolling through importer logic.

## Absolute path to the PMDODump checkout. Sibling repo on disk - not part of
## the Godot project.
const PMDO_ROOT: String = "/Users/franco/Documents/GitHub/PMDODump"

const PMDO_MONSTER_DIR: String = "/Users/franco/Documents/GitHub/PMDODump/DumpAsset/Data/Monster"
const PMDO_SKILL_DIR: String = "/Users/franco/Documents/GitHub/PMDODump/DumpAsset/Data/Skill"
const PMDO_UNIVERSAL_PATH: String = "/Users/franco/Documents/GitHub/PMDODump/DumpAsset/Data/Universal.json"

## In-project output roots.
const GENERATED_TYPES_DIR: String = "res://data/models/pokemon/generated/types"
const GENERATED_SPECIES_DIR: String = "res://data/models/pokemon/generated/species"
const GENERATED_FORMS_DIR: String = "res://data/models/pokemon/generated/forms"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves"
const GENERATED_SPRITES_DIR: String = "res://data/models/pokemon/generated/sprites"
const OVERRIDE_INSTANCES_DIR: String = "res://data/models/pokemon/overrides/instances"
const IMPORT_REPORTS_DIR: String = "res://data/models/pokemon/import_reports"

const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"
const REPORT_PATH: String = "res://data/models/pokemon/import_reports/pokemon_import_report.txt"

## Directories holding the existing Pokemon sprite sheets in this project.
const PLAYER_SPRITE_DIR: String = "res://assets/textures/actor/character"
const ENEMY_SPRITE_DIR: String = "res://assets/textures/actor/mob"

## M1 species slice. Order is the same as the M1 plan: 4 player + 3 enemy.
const TARGET_SPECIES: Array[String] = [
	"toxicroak",
	"gardevoir",
	"lucario",
	"gallade",
	"magmortar",
	"dusclops",
	"gengar",
]

## Slugs in `TARGET_SPECIES` whose hand-authored instance defaults to the
## player team. The remainder default to the enemy team.
const PLAYER_TEAM_SPECIES: Array[String] = [
	"gallade",
	"lucario",
	"gardevoir",
	"toxicroak",
]

## Signature move per species, sourced directly from PMDODump Skill files.
const SIGNATURE_MOVES: Dictionary = {
	"toxicroak": "poison_jab",
	"gardevoir": "moonblast",
	"lucario": "aura_sphere",
	"gallade": "psycho_cut",
	"magmortar": "flamethrower",
	"dusclops": "shadow_punch",
	"gengar": "shadow_ball",
}

## Legacy hand-authored tactical movement, preserved as `movement_override` on
## generated instance resources so the M1 demo plays the same as before the
## data slice. Keyed by species slug.
const LEGACY_MOVEMENT_OVERRIDE: Dictionary = {
	"toxicroak": 4,
	"gardevoir": 4,
	"lucario": 5,
	"gallade": 3,
	"magmortar": 5,
	"dusclops": 3,
	"gengar": 4,
}


static func monster_json_path(slug: String) -> String:
	return "%s/%s.json" % [PMDO_MONSTER_DIR, slug]


static func skill_json_path(slug: String) -> String:
	return "%s/%s.json" % [PMDO_SKILL_DIR, slug]


static func generated_species_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_SPECIES_DIR, slug]


static func generated_form_path(slug: String, form_index: int) -> String:
	return "%s/%s__%d.tres" % [GENERATED_FORMS_DIR, slug, form_index]


static func generated_move_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_MOVES_DIR, slug]


static func generated_sprite_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_SPRITES_DIR, slug]


static func instance_override_path(slug: String) -> String:
	return "%s/%s.tres" % [OVERRIDE_INSTANCES_DIR, slug]


## Sprite directory the species' idle sheet lives in - player team sprites are
## under `actor/character/`, enemies under `actor/mob/`. Falls back to the
## player directory for unknown slugs (the importer will warn anyway).
static func sprite_dir_for(slug: String) -> String:
	if slug in PLAYER_TEAM_SPECIES:
		return PLAYER_SPRITE_DIR
	return ENEMY_SPRITE_DIR
