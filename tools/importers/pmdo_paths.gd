@tool
class_name PMDOPaths
extends RefCounted
## Path helpers shared by the PMDODump importer.
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

const PMDO_ROOT_ENV: String = "PMD_EMBLEM_PMDO_ROOT"
const PMDO_ROOT_FALLBACK: String = "res://../PMDODump"

## In-project output roots.
const GENERATED_TYPES_DIR: String = "res://data/models/pokemon/generated/types"
const GENERATED_SPECIES_DIR: String = "res://data/models/pokemon/generated/species"
const GENERATED_FORMS_DIR: String = "res://data/models/pokemon/generated/forms"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves"
const GENERATED_STATUSES_DIR: String = "res://data/models/pokemon/generated/statuses"
const GENERATED_INTRINSICS_DIR: String = "res://data/models/pokemon/generated/intrinsics"
const GENERATED_ITEMS_DIR: String = "res://data/models/pokemon/generated/items"
const GENERATED_SPRITES_DIR: String = "res://data/models/pokemon/generated/sprites"
const GENERATED_INSTANCES_DIR: String = "res://data/models/pokemon/generated/instances"
const GENERATED_MANIFESTS_DIR: String = "res://data/models/pokemon/generated/manifests"
const OVERRIDE_INSTANCES_DIR: String = "res://data/models/pokemon/overrides/instances"
const IMPORT_REPORTS_DIR: String = "res://data/models/pokemon/import_reports"

const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"
const IMPORT_MANIFEST_PATH: String = "res://data/models/pokemon/generated/manifests/pokemon_import_manifest.json"
const REPORT_PATH: String = "res://data/models/pokemon/import_reports/pokemon_import_report.txt"
const REPORT_JSON_PATH: String = "res://data/models/pokemon/import_reports/pokemon_import_report.json"
const VISUAL_ASSET_MANIFEST_PATH: String = "res://data/models/visuals/generated/visual_asset_manifest.json"

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

## Returns the prefixed in-project identifier for a bare PMD slug and dex.
## Returns the bare slug unchanged if the dex number is unknown so callers can
## still produce a file rather than crashing on malformed input.
static func project_slug_for(bare_slug: String, dex_number: int = 0) -> String:
	if dex_number <= 0:
		return bare_slug
	return "%04d_%s" % [dex_number, bare_slug]


static func pmdo_root() -> String:
	var configured: String = OS.get_environment(PMDO_ROOT_ENV)
	if not configured.is_empty():
		return configured
	return ProjectSettings.globalize_path(PMDO_ROOT_FALLBACK)


static func pmdo_monster_dir() -> String:
	return "%s/DumpAsset/Data/Monster" % pmdo_root()


static func pmdo_skill_dir() -> String:
	return "%s/DumpAsset/Data/Skill" % pmdo_root()


static func pmdo_item_dir() -> String:
	return "%s/DumpAsset/Data/Item" % pmdo_root()


static func pmdo_growth_dir() -> String:
	return "%s/DumpAsset/Data/GrowthGroup" % pmdo_root()


static func pmdo_universal_path() -> String:
	return "%s/DumpAsset/Data/Universal.json" % pmdo_root()


static func monster_json_path(bare_slug: String) -> String:
	return "%s/%s.json" % [pmdo_monster_dir(), bare_slug]


static func skill_json_path(slug: String) -> String:
	return "%s/%s.json" % [pmdo_skill_dir(), slug]


static func generated_species_path(bare_slug: String, dex_number: int = 0) -> String:
	return "%s/%s.tres" % [GENERATED_SPECIES_DIR, project_slug_for(bare_slug, dex_number)]


static func generated_species_path_for_project_slug(project_slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_SPECIES_DIR, project_slug]


static func generated_form_path(bare_slug: String, form_index: int, dex_number: int = 0) -> String:
	return "%s/%s__%d.tres" % [GENERATED_FORMS_DIR, project_slug_for(bare_slug, dex_number), form_index]


static func generated_form_path_for_project_slug(project_slug: String, form_index: int) -> String:
	return "%s/%s__%d.tres" % [GENERATED_FORMS_DIR, project_slug, form_index]


static func generated_move_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_MOVES_DIR, slug]


static func generated_status_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_STATUSES_DIR, slug]


static func generated_intrinsic_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_INTRINSICS_DIR, slug]


static func generated_item_path(slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_ITEMS_DIR, slug]


static func generated_sprite_path(bare_slug: String, dex_number: int = 0) -> String:
	return "%s/%s.tres" % [GENERATED_SPRITES_DIR, project_slug_for(bare_slug, dex_number)]


static func generated_sprite_path_for_project_slug(project_slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_SPRITES_DIR, project_slug]


static func generated_instance_path_for_project_slug(project_slug: String) -> String:
	return "%s/%s.tres" % [GENERATED_INSTANCES_DIR, project_slug]


static func instance_override_path(bare_slug: String, dex_number: int = 0) -> String:
	return "%s/%s.tres" % [OVERRIDE_INSTANCES_DIR, project_slug_for(bare_slug, dex_number)]


## Per-species sprite folder (project layout: `actor/pokemon/<project_slug>/`).
static func sprite_dir_for(bare_slug: String, dex_number: int = 0) -> String:
	return "%s/%s" % [POKEMON_SPRITE_DIR, project_slug_for(bare_slug, dex_number)]


static func sprite_dir_for_project_slug(project_slug: String) -> String:
	return "%s/%s" % [POKEMON_SPRITE_DIR, project_slug]


## Full path to one of a species' state sprites.
static func sprite_state_path(bare_slug: String, state: String, dex_number: int = 0) -> String:
	var filename: String = String(POKEMON_SPRITE_STATES.get(state, "%s.png" % state))
	return "%s/%s" % [sprite_dir_for(bare_slug, dex_number), filename]


static func sprite_state_path_for_project_slug(project_slug: String, state: String) -> String:
	var filename: String = String(POKEMON_SPRITE_STATES.get(state, "%s.png" % state))
	return "%s/%s" % [sprite_dir_for_project_slug(project_slug), filename]


## Path to the AnimData.xml sidecar bundled with each species' sprite folder.
static func anim_data_path(bare_slug: String, dex_number: int = 0) -> String:
	return "%s/%s" % [sprite_dir_for(bare_slug, dex_number), POKEMON_ANIM_DATA_FILENAME]


static func anim_data_path_for_project_slug(project_slug: String) -> String:
	return "%s/%s" % [sprite_dir_for_project_slug(project_slug), POKEMON_ANIM_DATA_FILENAME]
