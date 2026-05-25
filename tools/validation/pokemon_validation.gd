@tool
class_name PokemonValidation
extends RefCounted

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
	var status: String = ""
	var disabled_reason: String = ""
	var generation: int = 0


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


class ItemEntry:
	extends RefCounted
	var slug: String = ""
	var name: String = ""
	var category: String = "unknown"
	var sprite_key: String = ""
	var icon_path: String = ""
	var use_kind: int = 0
	var effect_count: int = 0
	var passive_effect_count: int = 0
	var unsupported_effect_count: int = 0
	var imported: bool = false


var run_started_at: String = ""
var type_chart_loaded: bool = false
var type_count: int = 0
var matchup_size: int = 0
var effectiveness_buckets: Array[int] = []

var species_entries: Array[SpeciesEntry] = []
var move_entries: Array[MoveEntry] = []
var item_entries: Array[ItemEntry] = []
var instance_paths_written: Array[String] = []
var aggregate_warnings: Array[String] = []
var errors: Array[String] = []


func _init() -> void:
	run_started_at = Time.get_datetime_string_from_system()


func add_species(entry: SpeciesEntry) -> void:
	species_entries.append(entry)


func add_move(entry: MoveEntry) -> void:
	move_entries.append(entry)


func add_item(entry: ItemEntry) -> void:
	item_entries.append(entry)


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


func write_json(path: String) -> bool:
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

	file.store_string(JSON.stringify(_json_payload(), "\t"))
	file.store_string("\n")
	file.close()
	return true


func _render() -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("Pokemon Import Report")
	out.append("=====================")
	out.append("Started: %s" % run_started_at)
	out.append("Species imported: %d" % _imported_species_count())
	out.append("Moves imported: %d" % _imported_moves_count())
	out.append("Items imported: %d" % _imported_items_count())
	out.append("Instance templates written: %d" % instance_paths_written.size())
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
		if not entry.status.is_empty():
			out.append("    status: %s" % entry.status)
		if not entry.disabled_reason.is_empty():
			out.append("    disabled reason: %s" % entry.disabled_reason)
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

	out.append("Items")
	out.append("-----")
	out.append("Imported: %d" % _imported_items_count())
	out.append("Categories: %s" % JSON.stringify(_item_category_counts()))
	out.append("Mapped RawAsset icons: %d" % _item_icon_mapped_count())
	out.append("Unmapped RawAsset icons: %d" % _item_icon_unmapped_count())
	out.append("Supported runtime effect records: %d" % _item_effect_record_count())
	out.append("Passive held effect records: %d" % _item_passive_record_count())
	out.append("Unsupported/report-only item effect tags: %d" % _item_unsupported_count())
	for item in _unmapped_icon_items():
		out.append("    unmapped icon: %s sprite_key=%s" % [String(item.get("slug", "")), String(item.get("sprite_key", ""))])
	out.append("")

	if not instance_paths_written.is_empty():
		out.append("Instance templates")
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


func _imported_items_count() -> int:
	var n: int = 0
	for item in item_entries:
		if item.imported:
			n += 1
	return n


func _json_payload() -> Dictionary:
	return {
		"schema_version": 1,
		"generated_at": run_started_at,
		"summary": {
			"species_imported": _imported_species_count(),
			"moves_imported": _imported_moves_count(),
			"items_imported": _imported_items_count(),
			"instances_written": instance_paths_written.size(),
			"errors": errors.size(),
			"warnings": aggregate_warnings.size(),
			"status_counts": _status_counts(),
		},
		"type_chart": {
			"loaded": type_chart_loaded,
			"type_count": type_count,
			"matchup_size": matchup_size,
			"effectiveness_buckets": effectiveness_buckets,
		},
		"species": _species_json(),
		"moves": _moves_json(),
		"items": _items_json(),
		"item_summary": {
			"categories": _item_category_counts(),
			"mapped_icons": _item_icon_mapped_count(),
			"unmapped_icons": _item_icon_unmapped_count(),
			"unmapped_icon_items": _unmapped_icon_items(),
			"supported_effect_records": _item_effect_record_count(),
			"passive_effect_records": _item_passive_record_count(),
			"unsupported_effect_tags": _item_unsupported_count(),
		},
		"instance_paths_written": instance_paths_written,
		"warnings": aggregate_warnings,
		"errors": errors,
	}


func _species_json() -> Array:
	var out: Array = []
	for entry in species_entries:
		var stats: Array[int] = []
		for value in entry.base_stats:
			stats.append(int(value))
		out.append({
			"slug": entry.slug,
			"dex": entry.dex,
			"canonical_name": entry.canonical_name,
			"generation": entry.generation,
			"type1": entry.type1,
			"type2": entry.type2,
			"base_stats": stats,
			"signature_move": entry.signature_move,
			"sprite_warnings": entry.sprite_warnings,
			"notes": entry.notes,
			"imported": entry.imported,
			"status": entry.status,
			"disabled_reason": entry.disabled_reason,
		})
	return out


func _moves_json() -> Array:
	var out: Array = []
	for move in move_entries:
		out.append({
			"slug": move.slug,
			"index_number": move.index_number,
			"name": move.name,
			"type": move.type,
			"category": move.category,
			"base_power": move.base_power,
			"accuracy": move.accuracy,
			"pp": move.pp,
			"range_kind": move.range_kind,
			"range_value": move.range_value,
			"target_alignment": move.target_alignment,
			"effect_tags": move.effect_tags,
			"unsupported_effect_tags": move.unsupported_effect_tags,
			"imported": move.imported,
		})
	return out


func _items_json() -> Array:
	var out: Array = []
	for item in item_entries:
		out.append({
			"slug": item.slug,
			"name": item.name,
			"category": item.category,
			"sprite_key": item.sprite_key,
			"icon_path": item.icon_path,
			"icon_mapped": not item.icon_path.is_empty(),
			"use_kind": item.use_kind,
			"effect_count": item.effect_count,
			"passive_effect_count": item.passive_effect_count,
			"unsupported_effect_count": item.unsupported_effect_count,
			"imported": item.imported,
		})
	return out


func _status_counts() -> Dictionary:
	var out: Dictionary = {}
	for entry in species_entries:
		var status: String = entry.status if not entry.status.is_empty() else ("imported" if entry.imported else "failed")
		out[status] = int(out.get(status, 0)) + 1
	return out


func _item_category_counts() -> Dictionary:
	var out: Dictionary = {}
	for item in item_entries:
		if item.imported:
			out[item.category] = int(out.get(item.category, 0)) + 1
	return out


func _item_effect_record_count() -> int:
	var count: int = 0
	for item in item_entries:
		count += item.effect_count
	return count


func _item_passive_record_count() -> int:
	var count: int = 0
	for item in item_entries:
		count += item.passive_effect_count
	return count


func _item_unsupported_count() -> int:
	var count: int = 0
	for item in item_entries:
		count += item.unsupported_effect_count
	return count


func _item_icon_mapped_count() -> int:
	var count: int = 0
	for item in item_entries:
		if item.imported and not item.icon_path.is_empty():
			count += 1
	return count


func _item_icon_unmapped_count() -> int:
	var count: int = 0
	for item in item_entries:
		if item.imported and item.icon_path.is_empty():
			count += 1
	return count


func _unmapped_icon_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in item_entries:
		if not item.imported or not item.icon_path.is_empty():
			continue
		out.append({
			"slug": item.slug,
			"name": item.name,
			"sprite_key": item.sprite_key,
		})
	return out
