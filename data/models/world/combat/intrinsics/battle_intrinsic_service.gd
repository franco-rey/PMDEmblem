class_name BattleIntrinsicService
extends RefCounted
## Lightweight M6 intrinsic resolver/reporting surface.

const SUPPORTED_DAMAGE_BOOSTS: Dictionary = {
	"blaze": "fire",
	"overgrow": "grass",
	"torrent": "water",
}


func log_battle_start(units: Array[BattleUnit], battle_log: BattleLog) -> void:
	if battle_log == null:
		return
	for unit in units:
		if unit == null or unit.pawn == null or unit.stats == null:
			continue
		for slug in intrinsic_slugs_for(unit.stats):
			if SUPPORTED_DAMAGE_BOOSTS.has(slug):
				battle_log.append({
					"kind": "intrinsic_triggered",
					"hook": "battle_start",
					"unit": unit.pawn,
					"intrinsic_id": slug,
					"supported": true,
				})
			else:
				battle_log.append({
					"kind": "intrinsic_unsupported",
					"hook": "battle_start",
					"unit": unit.pawn,
					"intrinsic_id": slug,
				})


func before_damage_multiplier(attacker: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> float:
	if attacker == null or move == null:
		return 1.0
	for slug in intrinsic_slugs_for(attacker):
		if not SUPPORTED_DAMAGE_BOOSTS.has(slug):
			continue
		if String(SUPPORTED_DAMAGE_BOOSTS[slug]) != move.type:
			continue
		if attacker.curr_health > int(floor(float(attacker.max_health) / 3.0)):
			continue
		if battle_log != null:
			battle_log.append({
				"kind": "intrinsic_triggered",
				"hook": "before_damage",
				"unit": pawn,
				"intrinsic_id": slug,
				"move_id": move.move_id,
				"multiplier": 1.5,
			})
		return 1.5
	return 1.0


func intrinsic_slugs_for(stats: Stats) -> Array[String]:
	var out: Array[String] = []
	if stats == null or stats.pokemon_instance == null:
		return out
	var form: PokemonFormResource = stats.pokemon_instance.resolved_form()
	if form == null:
		return out
	for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
		var key: String = String(slug)
		if key.is_empty() or key == "none" or out.has(key):
			continue
		out.append(key)
	return out
