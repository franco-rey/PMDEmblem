extends SceneTree
## M6 smoke: intrinsic resources resolve and hooks report deterministically.

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"
const CURRENT_SEVEN: Array[String] = [
	"res://data/models/pokemon/overrides/instances/0475_gallade.tres",
	"res://data/models/pokemon/overrides/instances/0448_lucario.tres",
	"res://data/models/pokemon/overrides/instances/0282_gardevoir.tres",
	"res://data/models/pokemon/overrides/instances/0454_toxicroak.tres",
	"res://data/models/pokemon/overrides/instances/0467_magmortar.tres",
	"res://data/models/pokemon/overrides/instances/0094_gengar.tres",
	"res://data/models/pokemon/overrides/instances/0356_dusclops.tres",
]

class FakePawn:
	extends TacticsPawn

var failures: int = 0


func _init() -> void:
	var service := BattleIntrinsicService.new()
	for path in CURRENT_SEVEN:
		var stats: Stats = _stats(path)
		for slug in service.intrinsic_slugs_for(stats):
			var res_path: String = "res://data/models/pokemon/generated/intrinsics/%s.tres" % slug
			_assert_true(ResourceLoader.exists(res_path), "intrinsic resource exists for %s" % slug)
		stats.free()

	var bulba_stats: Stats = _stats(BULBASAUR_PATH)
	bulba_stats.curr_health = 1
	var move := PokemonMoveResource.new()
	move.move_id = "grass_test"
	move.type = "grass"
	var log := BattleLog.new()
	var multiplier: float = service.before_damage_multiplier(bulba_stats, move, log, null)
	_assert_true(is_equal_approx(multiplier, 1.5), "Overgrow low-HP damage hook applies")
	_assert_true(_log_has(log, "intrinsic_triggered"), "intrinsic trigger logged")
	bulba_stats.free()

	if failures > 0:
		push_error("smoke: intrinsics failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: intrinsics clean")
		quit(0)


func _stats(path: String) -> Stats:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	var stats := Stats.new()
	stats.init_from_pokemon(instance)
	return stats


func _log_has(log: BattleLog, kind: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind:
			return true
	return false


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
