class_name MapDefinitionResource
extends Resource
## Minimal map definition used by M4 skirmishes.
##
## M6.5 expands the authored map pool; this resource shape is already the API
## the skirmish loader consumes.

@export var map_id: String = ""
@export var display_name: String = ""
@export var scene_path: String = ""
@export var biome: String = ""
@export var recommended_team_size: int = 1
@export var recommended_elevation: String = ""
@export var default_seed: int = 0
