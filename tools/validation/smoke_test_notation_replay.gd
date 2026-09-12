extends SmokeCase

const CODE: String = "match seed=7 mode=pvp p=0007_squirtle@50:rain_dance,water_gun,withdraw,bite:torrent:berry_sitrus e=0004_charmander@50:ember,scratch,growl,smokescreen:blaze:berry_oran"
const SCRIPT_AFTER_MOVE: Array = [
	"  atk 1 rain_dance self",
	"  end",
	"T2 E1",
	"  atk 1 ember P1",
	"  end",
	"T3 P1",
	"  item use P1 berry_sitrus",
	"  end",
	"T4 E1",
	"  atk 3 growl P1",
	"  end",
	"T5 P1",
	"  atk 2 water_gun E1",
	"  end",
]
const RESULT_VERBS: Array[String] = ["hit", "miss", "nfx", "st", "tick", "stat", "heal", "wx", "fld", "hz", "push", "ko", "skip", "rej", "held"]


func _run() -> void:
	var first := NotationDriver.new(self)
	var launched: bool = await first._launch(CODE)
	_assert_true(launched, "scripted game launches")
	if not launched:
		_finish("notation_replay")
		return
	var level: TacticsLevel = first.level
	var p1: TacticsPawn = level.notation.pawn_for_id("P1")
	var target_label: String = await _reachable_label(level, p1)
	_assert_true(not target_label.is_empty(), "a reachable tile exists for P1 (%s)" % target_label)
	await first._run_command("T1 P1")
	await first._run_command("  mv %s>%s" % [level.notation.label_for_pawn(p1), target_label])
	for line in SCRIPT_AFTER_MOVE:
		await first._run_command(String(line))
	level.notation.save()
	_assert_true(first.failures == 0, "scripted game ran without command failures (%s)" % str(first.log_lines))
	var transcript: String = level.notation.text()
	_assert_true(transcript.contains("[Code \"") and transcript.contains("  atk ") and transcript.contains("  mv ") and transcript.contains("  item use ") and transcript.contains("  end"), "transcript carries code, attack, move, item and end lines")
	var transcript_lines: Array = Array(transcript.split("\n"))
	first.main.queue_free()
	await process_frame
	await process_frame
	var second := NotationDriver.new(self)
	var second_result: Dictionary = await second.run_script(transcript_lines)
	_assert_true(int(second_result.get("failures", 0)) == 0, "replayed transcript ran without command failures (%s)" % str(second_result.get("log", [])))
	var replay: String = String(second_result.get("notation", ""))
	var first_body: Array = _body(transcript)
	var second_body: Array = _body(replay)
	var same: bool = first_body.size() == second_body.size()
	var first_diff: String = ""
	if same:
		for i in range(first_body.size()):
			if first_body[i] != second_body[i]:
				same = false
				first_diff = "line %d: %s | %s" % [i, first_body[i], second_body[i]]
				break
	else:
		first_diff = "%d vs %d lines" % [first_body.size(), second_body.size()]
	_assert_true(same, "replaying the transcript reproduces it exactly (%s)" % first_diff)
	if not same:
		for i in range(maxi(first_body.size(), second_body.size())):
			print("diff %3d | %-46s | %s" % [i, first_body[i] if i < first_body.size() else "", second_body[i] if i < second_body.size() else ""])
	for line in transcript_lines:
		var parsed: Dictionary = NotationParser.parse(String(line))
		if String(parsed.get("kind", "")) == NotationParser.KIND_ACTION and not NotationParser.COMMAND_VERBS.has(String(parsed.get("verb", ""))) and not RESULT_VERBS.has(String(parsed.get("verb", ""))):
			_assert_true(false, "unknown verb in transcript: %s" % String(line))
	_finish("notation_replay")


func _reachable_label(level: TacticsLevel, pawn: TacticsPawn) -> String:
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = pawn
	participant.stage = participant.STAGE_SHOW_MOVEMENTS
	await physics_frame
	await physics_frame
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var own: Vector3i = Targeting._tile_key(pawn.get_tile())
	var best: String = ""
	var best_distance: int = 999
	for key in keys.keys():
		var tile: TacticsTile = keys[key]
		if key == own or not tile.reachable or tile.get_tile_occupier() != null:
			continue
		var distance: int = (key as Vector3i).distance_squared_to(own)
		if distance < best_distance:
			best_distance = distance
			best = level.notation.tile_label(key)
	participant.stage = participant.STAGE_SHOW_ACTIONS
	await physics_frame
	return best


func _body(text: String) -> Array:
	var out: Array = []
	for raw in text.split("\n"):
		var line: String = String(raw)
		if line.is_empty():
			continue
		out.append(line)
	return out
