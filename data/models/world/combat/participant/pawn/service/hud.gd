class_name TacticsPawnHudService
extends RefCounted


func update_character_health(pawn: TacticsPawn) -> void:
	var _health_label: Label3D = pawn.get_node("Character/CharacterUI/HealthLabel")
	_health_label.text = str(pawn.stats.curr_health) + "/" + str(pawn.stats.max_health)


const FREEZE_TINT: Color = Color(0.55, 0.85, 1.0)
const PARALYSIS_TINT: Color = Color(1.0, 1.0, 0.35)
const PARALYSIS_PERIOD_MS: int = 700


func tint_when_unable_to_act(pawn: TacticsPawn) -> void:
	var _char_node: TacticsPawnSprite = pawn.get_node("Character")
	var spent: bool = not pawn.is_alive() or pawn.res.has_acted_this_round
	var base: Color = Color(0.5, 0.5, 0.5) if spent else Color(1, 1, 1)
	_char_node.modulate = base * status_draw_tint(pawn)


func status_draw_tint(pawn: TacticsPawn) -> Color:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return Color(1, 1, 1)
	if pawn.stats.battle_statuses.has("freeze"):
		return FREEZE_TINT
	if pawn.stats.battle_statuses.has("paralyze") or pawn.stats.battle_statuses.has("full_paralysis"):
		var phase: int = int(Time.get_ticks_msec() / (PARALYSIS_PERIOD_MS / 2)) % 2
		return PARALYSIS_TINT if phase == 0 else Color(1, 1, 1)
	return Color(1, 1, 1)
