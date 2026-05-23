@tool
class_name PMDOPaths
extends RefCounted
## Constants shared by the PMDODump importer.
##
## Centralized so the M6 bulk importer can extend the species/move lists
## without scrolling through importer logic.[br][br]
##
## Slug terminology:
## - "bare slug" - the PMDODump / SpriteCollab folder name, e.g. "gallade".
##   Used to look up source JSON and the SpriteCollab sprite folder.
## - "project slug" - the prefixed in-project identifier, e.g. "0475_gallade".
##   Used for every generated file path and every in-project reference.
##   Built as "%04d_%s" % [dex_number, bare_slug].
##
## All importer output paths use the project slug; source file paths
## (`monster_json_path`, `skill_json_path`, SpriteCollab folder layout) use
## the bare slug.

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

## Root directory holding per-species Pokemon sprite folders. Each species
## owns one subfolder named `<dex>_<slug>` (e.g. `0475_gallade`) containing the
## SpriteCollab sheets `idle.png`, `walk.png`, `hurt.png`, `sleep.png`,
## `hop.png`, plus the `AnimData.xml` describing frame dimensions per state.
const POKEMON_SPRITE_DIR: String = "res://assets/textures/actor/pokemon"
const POKEMON_SPRITE_STATES: Dictionary = {
	"idle": "idle.png",
	"walk": "walk.png",
	"hurt": "hurt.png",
	"sleep": "sleep.png",
	"hop": "hop.png",
}
const POKEMON_ANIM_DATA_FILENAME: String = "AnimData.xml"

## Bare PMD slug -> National Dex number. Drives both the prefixed project
## slug and the SpriteCollab folder lookup. Add new species here when
## extending TARGET_SPECIES; the rest of the importer derives everything
## else from this map.
const DEX_NUMBERS: Dictionary = {
	"toxicroak": 454,
	"gardevoir": 282,
	"lucario": 448,
	"gallade": 475,
	"magmortar": 467,
	"dusclops": 356,
	"gengar": 94,
}

## M1 species slice. Bare slugs - the bulk import path translates each to its
## project slug via `project_slug_for()` when writing project files.
const TARGET_SPECIES: Array[String] = [
	"toxicroak",
	"gardevoir",
	"lucario",
	"gallade",
	"magmortar",
	"dusclops",
	"gengar",
]

## Bare slugs whose hand-authored instance defaults to the player team. The
## remainder default to the enemy team.
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
## data slice. Keyed by bare slug.
const LEGACY_MOVEMENT_OVERRIDE: Dictionary = {
	"toxicroak": 4,
	"gardevoir": 4,
	"lucario": 5,
	"gallade": 3,
	"magmortar": 5,
	"dusclops": 3,
	"gengar": 4,
}


## Returns the prefixed in-project identifier for a bare PMD slug.
## Returns the bare slug unchanged if the dex number is unknown so the
## importer still produces a (suboptimally named) file rather than crashing.
static func project_slug_for(bare_slug: String) -> String:
	if not DEX_NUMBERS.has(bare_slug):
		return bare_slug
	return "%04d_%s" % [int(DEX_NUMBERS[bare_slug]), bare_slug]


static func monster_json_path(bare_slug: String) -> String:
	return "%s/%s.json" % [PMDO_MONSTER_DIR, bare_slug]


static func skill_json_path(slug: String) -> String:
	return "%s/%s.json" % [PMDO_SKILL_DIR, slug]


static func generated_species_path(bare_slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_SPECIES_DIR, project_slug_for(bare_slug)]


static func generated_form_path(bare_slug: String, form_index: int) -> String:
	return "%s/%s__%d.tres" % [GENERATED_FORMS_DIR, project_slug_for(bare_slug), form_index]


static func generated_move_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_MOVES_DIR, slug]


static func generated_sprite_path(bare_slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_SPRITES_DIR, project_slug_for(bare_slug)]


static func instance_override_path(bare_slug: String) -> String:
	return "%s/%s.tres" % [OVERRIDE_INSTANCES_DIR, project_slug_for(bare_slug)]


## Per-species sprite folder (project layout: `actor/pokemon/<project_slug>/`).
static func sprite_dir_for(bare_slug: String) -> String:
	return "%s/%s" % [POKEMON_SPRITE_DIR, project_slug_for(bare_slug)]


## Full path to one of a species' state sprites.
static func sprite_state_path(bare_slug: String, state: String) -> String:
	var filename: String = String(POKEMON_SPRITE_STATES.get(state, "%s.png" % state))
	return "%s/%s" % [sprite_dir_for(bare_slug), filename]


## Path to the AnimData.xml sidecar bundled with each species' sprite folder.
static func anim_data_path(bare_slug: String) -> String:
	return "%s/%s" % [sprite_dir_for(bare_slug), POKEMON_ANIM_DATA_FILENAME]
