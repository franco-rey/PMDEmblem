class_name PokemonSpriteSetResource
extends Resource
## Bundle of sprite sheet paths and metadata for a single Pokemon form.
##
## The active project's `TacticsPawnSprite` already loads idle + sidecar
## (_walk/_hurt/_sleep/_hop) PNGs via filename convention. This resource just
## records the same paths in a structured form so future systems (turn order
## UI, encyclopedia, etc.) can address them by data instead of by string
## munging. Cell size, frame counts, grounding metadata, and portrait paths
## are reserved for later milestones - M1 only sets the texture paths.

@export_file("*.png") var idle_path: String = ""
@export_file("*.png") var walk_path: String = ""
@export_file("*.png") var hurt_path: String = ""
@export_file("*.png") var sleep_path: String = ""
@export_file("*.png") var hop_path: String = ""

## Path to the SpriteCollab `AnimData.xml` sidecar bundled with each species'
## sprite folder. When present, the runtime sprite reads per-state FrameWidth
## / FrameHeight from it to handle the 8-row directional layout (Sleep is
## single-direction; other states span all 8 facings). Empty falls back to
## the legacy 2-row layout assumption.
@export_file("*.xml") var anim_data_path: String = ""

## World-space size of one source sprite pixel for SpriteCollab sheets. This is
## intentionally one shared pixels-to-world conversion rather than per-species
## normalization, so naturally larger source sprites still render larger.
@export var world_pixel_size: float = 0.04

@export var cell_size: Vector2i = Vector2i.ZERO
@export var frame_counts: Dictionary = {}
@export var grounding_offset: float = 0.0

@export var portrait_paths: Array[String] = []
@export var validation_warnings: Array[String] = []


## Returns the list of (label, path) pairs in the standard pawn order so
## reports and UIs can iterate animations consistently.
func iter_animation_paths() -> Array:
	return [
		["idle", idle_path],
		["walk", walk_path],
		["hurt", hurt_path],
		["sleep", sleep_path],
		["hop", hop_path],
	]


## True if every animation slot is populated. Missing files surface as
## entries in `validation_warnings` instead of failing import.
func is_complete() -> bool:
	for pair in iter_animation_paths():
		if String(pair[1]).is_empty():
			return false
	return true
