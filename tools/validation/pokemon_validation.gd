@tool
class_name PokemonValidation
extends RefCounted
## Aggregates findings from the PMDODump importer and writes a flat text
## report to `res://data/models/pokemon/import_reports/pokemon_import_report.txt`.
##
## Required by `plan.md` M1: "Add validation reports for missing data,
## unsupported move effects, missing sprites, and bad sprite dimensions."
## Designed so a developer can scan the report top-to-bottom and answer
## "what didn't import cleanly?" in under a minute.

class SpeciesEntry:
	extends RefCounted
	var slug: String = ""
	var dex: int = 0
	var canonical_name: String = ""
	var type1: String = "none"
	var type2: String = "none"
	var base_stats: PackedInt32Array = PackedInt32Array()
	var signature_move: String = ""
	var sprite_warnings: Array[String] = []
	var notes: Array[String] = []
	var imported: bool = false


class MoveEntry:
	extends RefCounted
	var slug: String = ""
	var index_number: int = 0
	var name: String = ""
	var type: String = "none"
	var category: int = 0
	var base_power: int = 0
	var accuracy: int = -1
	var pp: int = 0
	var range_kind: String = "unsupported"
	var range_value: int = 1
	var target_alignment: int = 0
	var effect_tags: Array[String] = []
	var unsupported_effect_tags: Array[String] = []
	var imported: bool = false


var run_started_at: String = ""
var type_chart_loaded: bool = false
var type_count: int = 0
var matchup_size: int = 0
var effectiveness_buckets: Array[int] = []

var species_entries: Array[SpeciesEntry] = []
var move_entries: Array[MoveEntry] = []
var instance_paths_written: Array[String] = []
var aggregate_warnings: Array[String] = []
var errors: Array[String] = []


func _init() -> void:
	run_started_at = Time.get_datetime_string_from_system()


func add_species(entry: SpeciesEntry) -> void:
	species_entries.append(entry)


func add_move(entry: MoveEntry) -> void:
	move_entries.append(entry)


func record_instance(path: String) -> void:
	instance_paths_written.append(path)


func add_warning(message: String) -> void:
	aggregate_warnings.append(message)


func add_error(message: String) -> void:
	errors.append(message)


func set_type_chart_summary(loaded: bool, count: int, matrix_size: int, buckets: Array[int]) -> void:
	type_chart_loaded = loaded
	type_count = count
	matchup_size = matrix_size
	effectiveness_buckets = buckets


## Persist the report. Returns true on success.
func write(path: String) -> bool:
	var dir_path: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err: int = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("PokemonValidation: failed to create %s (err %d)" % [dir_path, err])
			return false

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PokemonValidation: failed to open %s for writing" % path)
		return false

	file.store_string(_render())
	file.close()
	return true


func _render() -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("Pokemon Import Report")
	out.append("=====================")
	out.append("Started: %s" % run_started_at)
	out.append("Species imported: %d" % _imported_species_count())
	out.append("Moves imported: %d" % _imported_moves_count())
	out.append("Instance overrides written: %d" % instance_paths_written.size())
	out.append("Errors: %d" % errors.size())
	out.append("Aggregate warnings: %d" % aggregate_warnings.size())
	out.append("")

	out.append("Type chart")
	out.append("----------")
	if type_chart_loaded:
		out.append("Loaded: yes")
		out.append("Type count: %d" % type_count)
		out.append("Matchup matrix entries: %d (expected %d for %dx%d)" % [
			matchup_size, type_count * type_count, type_count, type_count
		])
		out.append("Effectiveness bucket counts (index -> count):")
		for i in range(effectiveness_buckets.size()):
			out.append("  [%d] %d" % [i, effectiveness_buckets[i]])
	else:
		out.append("Loaded: NO - check Universal.json source path")
	out.append("")

	out.append("Species")
	out.append("-------")
	for entry in species_entries:
		out.append("- %s (%s, dex %d) %s" % [
			entry.slug,
			entry.canonical_name,
			entry.dex,
			"OK" if entry.imported else "FAILED",
		])
		var types: String = entry.type1
		if entry.type2 != "" and entry.type2 != "none":
			types += "/" + entry.type2
		out.append("    types: %s" % types)
		if entry.base_stats.size() == 6:
			out.append("    base stats: HP=%d Atk=%d Def=%d SpA=%d SpD=%d Spe=%d" % [
				entry.base_stats[0], entry.base_stats[1], entry.base_stats[2],
				entry.base_stats[3], entry.base_stats[4], entry.base_stats[5],
			])
		if not entry.signature_move.is_empty():
			out.append("    signature move: %s" % entry.signature_move)
		for warn in entry.sprite_warnings:
			out.append("    sprite warning: %s" % warn)
		for note in entry.notes:
			out.append("    note: %s" % note)
	out.append("")

	out.append("Moves")
	out.append("-----")
	for move in move_entries:
		out.append("- %s (#%d, %s) %s" % [
			move.slug,
			move.index_number,
			move.name if not move.name.is_empty() else move.slug,
			"OK" if move.imported else "FAILED",
		])
		out.append("    type=%s category=%d power=%d acc=%d pp=%d" % [
			move.type, move.category, move.base_power, move.accuracy, move.pp
		])
		out.append("    range=%s/%d alignment=%d" % [
			move.range_kind, move.range_value, move.target_alignment
		])
		if not move.effect_tags.is_empty():
			out.append("    effect tags: %s" % ", ".join(move.effect_tags))
		if not move.unsupported_effect_tags.is_empty():
			out.append("    UNSUPPORTED effect tags: %s" % ", ".join(move.unsupported_effect_tags))
	out.append("")

	if not instance_paths_written.is_empty():
		out.append("Instance overrides")
		out.append("------------------")
		for inst in instance_paths_written:
			out.append("- %s" % inst)
		out.append("")

	if not aggregate_warnings.is_empty():
		out.append("Warnings")
		out.append("--------")
		for warn in aggregate_warnings:
			out.append("- %s" % warn)
		out.append("")

	if not errors.is_empty():
		out.append("Errors")
		out.append("------")
		for err in errors:
			out.append("- %s" % err)
		out.append("")

	return "\n".join(out)


func _imported_species_count() -> int:
	var n: int = 0
	for entry in species_entries:
		if entry.imported:
			n += 1
	return n


func _imported_moves_count() -> int:
	var n: int = 0
	for move in move_entries:
		if move.imported:
			n += 1
	return n
