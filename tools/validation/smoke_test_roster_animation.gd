extends SceneTree

const SPRITES_DIR: String = "res://data/models/pokemon/generated/sprites/"
const INSTANCES_DIR: String = "res://data/models/pokemon/generated/instances/"
const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"
const CORE_STATES: Array[String] = ["idle", "walk", "hurt", "attack"]
const OPTIONAL_STATES: Array[String] = ["faint", "hop", "sleep", "charge", "shoot"]
const SOURCE_ACTIONS: Array[String] = ["Attack", "Shoot", "Charge"]
const SAMPLE_EVERY: int = 40

var failures: int = 0
var checked: int = 0
var optional_missing: Dictionary = {}
var sampled: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var range_arg: PackedStringArray = _arg("dex-range").split("-", false)
	var low: int = int(range_arg[0]) if range_arg.size() >= 1 and not range_arg[0].is_empty() else 1
	var high: int = int(range_arg[1]) if range_arg.size() >= 2 else 9999
	var scene: PackedScene = load(PAWN_SCENE_PATH)
	var expertise_scene: PackedScene = load(EXPERTISE_SCENE_PATH)
	var slugs: Array[String] = []
	var dir := DirAccess.open(SPRITES_DIR)
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var slug: String = file.get_basename()
		var dex: int = int(slug.get_slice("_", 0))
		if dex < low or dex > high:
			continue
		slugs.append(slug)
	slugs.sort()
	for i in range(slugs.size()):
		_check_resource(slugs[i])
		if i % SAMPLE_EVERY == 0:
			await _check_sample(scene, expertise_scene, slugs[i])
	var optional_summary: Array[String] = []
	for key in optional_missing.keys():
		optional_summary.append("%s:%d" % [key, optional_missing[key]])
	print("smoke: roster_animation checked %d sprite sets (%d sampled live), optional states missing %s" % [checked, sampled, ", ".join(optional_summary) if not optional_summary.is_empty() else "none"])
	if failures > 0:
		push_error("smoke: roster_animation failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: roster_animation clean")
	quit(0)


func _check_resource(slug: String) -> void:
	var sprite_set: PokemonSpriteSetResource = load(SPRITES_DIR + slug + ".tres") as PokemonSpriteSetResource
	checked += 1
	if sprite_set == null:
		_fail("%s sprite set loads" % slug)
		return
	if sprite_set.animation_schema_version < 2:
		_fail("%s uses schema 2 (found %d)" % [slug, sprite_set.animation_schema_version])
	if sprite_set.anchors_path.is_empty() or not FileAccess.file_exists(sprite_set.anchors_path):
		_fail("%s anchors file present (%s)" % [slug, sprite_set.anchors_path])
	if sprite_set.anim_data_path.is_empty() or not FileAccess.file_exists(sprite_set.anim_data_path):
		_fail("%s AnimData present" % slug)
	for state in CORE_STATES:
		if not sprite_set.has_animation_state(state):
			_fail("%s has core state %s" % [slug, state])
	for state in OPTIONAL_STATES:
		if not sprite_set.has_animation_state(state):
			optional_missing[state] = int(optional_missing.get(state, 0)) + 1
	var catalog: ActorActionCatalog = ActorActionCatalog.shared()
	for action in SOURCE_ACTIONS:
		var resolved: Dictionary = catalog.resolve_source_state(sprite_set, action)
		if String(resolved.get("state_key", "")).is_empty():
			_fail("%s resolves source action %s" % [slug, action])
	for state in sprite_set.animation_states.keys():
		var entry: Dictionary = sprite_set.state_entry(state)
		if bool(entry.get("alias_only", false)) and String(entry.get("alias_target", "")).is_empty():
			_fail("%s alias state %s names its target" % [slug, state])


func _check_sample(scene: PackedScene, expertise_scene: PackedScene, slug: String) -> void:
	var path: String = INSTANCES_DIR + slug + ".tres"
	if not ResourceLoader.exists(path):
		return
	var pawn: TacticsPawn = scene.instantiate() as TacticsPawn
	var expertise: Expertise = expertise_scene.instantiate() as Expertise
	expertise.name = "Expertise"
	expertise.pokemon_instance = load(path)
	pawn.add_child(expertise)
	root.add_child(pawn)
	await process_frame
	sampled += 1
	var sprite: TacticsPawnSprite = pawn.get_node("Character") as TacticsPawnSprite
	if sprite == null:
		_fail("%s live sprite node" % slug)
		pawn.queue_free()
		return
	if sprite.grounding_mode != TacticsPawnSprite.GROUNDING_SOURCE:
		_fail("%s uses source shadow grounding" % slug)
	if sprite.ground_shadow_px <= 0 or sprite.ground_shadow_px > 12:
		_fail("%s idle shadow anchor within range (%d px)" % [slug, sprite.ground_shadow_px])
	for state in CORE_STATES:
		if not sprite.can_play_state(state):
			_fail("%s can play %s live" % [slug, state])
	var phases: Dictionary = sprite.state_phase_seconds("attack")
	if float(phases.get("total", 0.0)) <= 0.0 or float(phases.get("hit", 0.0)) < 0.0 or float(phases.get("hit", 0.0)) > float(phases.get("total", 0.0)):
		_fail("%s attack phases sane (%s)" % [slug, str(phases)])
	var total: float = sprite.play_action("attack")
	var steps: int = int(ceil((total + 0.1) / (1.0 / 60.0)))
	for i in range(steps):
		sprite._process(1.0 / 60.0)
	if not sprite.is_one_shot_finished():
		_fail("%s attack one-shot finishes" % slug)
	pawn.queue_free()
	await process_frame


func _fail(label: String) -> void:
	failures += 1
	push_error("smoke: FAIL - %s" % label)


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
