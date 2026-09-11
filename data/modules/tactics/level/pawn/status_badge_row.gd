class_name StatusBadgeRow
extends Node3D

const BADGES: Dictionary = {
	"burn": ["BRN", Color(0.95, 0.45, 0.2)],
	"poison": ["PSN", Color(0.75, 0.35, 0.85)],
	"poison_toxic": ["TOX", Color(0.6, 0.2, 0.75)],
	"paralyze": ["PAR", Color(0.95, 0.85, 0.2)],
	"sleep": ["SLP", Color(0.7, 0.7, 0.75)],
	"freeze": ["FRZ", Color(0.5, 0.85, 1.0)],
	"confuse": ["CNF", Color(1.0, 0.6, 0.8)],
	"flinch": ["FLN", Color(0.9, 0.9, 0.9)],
	"leech_seed": ["SEED", Color(0.4, 0.85, 0.4)],
	"bind": ["TRAP", Color(0.95, 0.6, 0.25)],
	"wrap": ["TRAP", Color(0.95, 0.6, 0.25)],
	"clamp": ["TRAP", Color(0.95, 0.6, 0.25)],
	"fire_spin": ["TRAP", Color(0.95, 0.6, 0.25)],
	"sand_tomb": ["TRAP", Color(0.95, 0.6, 0.25)],
	"whirlpool": ["TRAP", Color(0.95, 0.6, 0.25)],
	"magma_storm": ["TRAP", Color(0.95, 0.6, 0.25)],
	"infestation": ["TRAP", Color(0.95, 0.6, 0.25)],
	"protect": ["PRT", Color(0.4, 0.7, 1.0)],
	"detect": ["PRT", Color(0.4, 0.7, 1.0)],
	"kings_shield": ["PRT", Color(0.4, 0.7, 1.0)],
	"crafty_shield": ["PRT", Color(0.4, 0.7, 1.0)],
	"wide_guard": ["PRT", Color(0.4, 0.7, 1.0)],
	"endure": ["END", Color(0.9, 0.8, 0.5)],
	"reflect": ["REF", Color(0.8, 0.7, 1.0)],
	"light_screen": ["LSC", Color(0.9, 0.9, 0.5)],
	"safeguard": ["SFG", Color(0.6, 0.9, 0.8)],
	"mist": ["MST", Color(0.8, 0.9, 1.0)],
	"lucky_chant": ["LCK", Color(0.9, 0.9, 0.6)],
	"taunted": ["TNT", Color(0.9, 0.5, 0.5)],
	"disable": ["DIS", Color(0.7, 0.7, 0.9)],
	"encore": ["ENC", Color(0.9, 0.7, 0.9)],
	"torment": ["TRM", Color(0.7, 0.5, 0.5)],
	"heal_block": ["HBL", Color(0.8, 0.5, 0.6)],
	"perish_song": ["PRSH", Color(0.5, 0.5, 0.5)],
	"yawning": ["YWN", Color(0.8, 0.8, 0.9)],
	"nightmare": ["NTM", Color(0.5, 0.4, 0.6)],
	"charging": ["CHG", Color(1.0, 0.9, 0.4)],
	"airborne": ["FLY", Color(0.7, 0.9, 1.0)],
	"underground": ["DIG", Color(0.7, 0.55, 0.35)],
	"underwater": ["DIVE", Color(0.4, 0.6, 1.0)],
	"vanished": ["VAN", Color(0.6, 0.5, 0.8)],
	"recharge": ["RCH", Color(0.8, 0.8, 0.8)],
	"focus_energy": ["FOC", Color(1.0, 0.7, 0.3)],
	"stockpile": ["STK", Color(0.8, 0.7, 0.5)],
	"aqua_ring": ["AQR", Color(0.4, 0.8, 1.0)],
	"ingrain": ["ING", Color(0.5, 0.75, 0.3)],
	"destiny_bond": ["DBND", Color(0.6, 0.4, 0.7)],
	"grudge": ["GRDG", Color(0.6, 0.4, 0.7)],
	"magnet_rise": ["MAGR", Color(0.9, 0.9, 0.5)],
	"telekinesis": ["TELE", Color(0.9, 0.7, 1.0)],
	"outrage": ["RAGE", Color(1.0, 0.4, 0.3)],
	"thrash": ["RAGE", Color(1.0, 0.4, 0.3)],
	"petal_dance": ["RAGE", Color(1.0, 0.6, 0.8)],
	"paused": ["LOAF", Color(0.7, 0.7, 0.7)],
	"immobilized": ["IMMB", Color(0.7, 0.7, 0.7)],
	"wish": ["WISH", Color(1.0, 0.95, 0.7)],
	"future_sight": ["FSGT", Color(0.8, 0.6, 1.0)],
	"sleepless": ["UPR", Color(0.9, 0.7, 0.5)],
	"curse": ["CRS", Color(0.5, 0.3, 0.5)],
	"in_love": ["LOVE", Color(1.0, 0.5, 0.75)],
	"decoy": ["SUB", Color(0.7, 0.9, 0.7)],
	"embargo": ["EMBG", Color(0.6, 0.5, 0.4)],
	"follow_me": ["FLW", Color(1.0, 0.7, 0.8)],
	"rage_powder": ["FLW", Color(1.0, 0.5, 0.4)],
	"rooted": ["ROOT", Color(0.6, 0.45, 0.3)],
	"bide": ["BIDE", Color(0.9, 0.9, 0.9)],
	"mat_block": ["MAT", Color(0.6, 0.8, 0.6)],
	"snatch": ["SNCH", Color(0.5, 0.5, 0.9)],
	"spiky_shield": ["PRT", Color(0.4, 0.7, 1.0)],
}
const EMOTICONS: Dictionary = {
	"poison": "Skull_White", "poison_toxic": "Skull_Purple", "burn": "Burn", "sleep": "Sleep", "confuse": "Confuse", "yawning": "Yawn",
	"protect": "Shield_Green", "detect": "Shield_Brown", "kings_shield": "Shield_Yellow", "crafty_shield": "Shield_Pink", "wide_guard": "Shield_White", "quick_guard": "Shield_Red", "spiky_shield": "Shield_Green", "mat_block": "Shield_Brown", "magic_coat": "Shield_Green",
	"reflect": "Shield_Blue", "light_screen": "Shield_Yellow", "safeguard": "Shield_Tan", "mist": "Shield_White", "grudge": "Shield_Purple",
	"counter": "Sword_Shield_Brown", "mirror_coat": "Sword_Shield_Pink", "metal_burst": "Sword_Shield_White", "focus_energy": "Sword_Pink", "sure_shot": "Sword_LightBlue",
	"aqua_ring": "Cycle_Blue", "conversion": "Cycle_Green", "electrified": "Cycle_Yellow", "magnet_rise": "Cycle_Yellow", "lucky_chant": "Cycle_White",
	"encore": "Exclaim_Pink", "in_love": "Exclaim_Pink", "belch": "Exclaim_Purple", "chasing": "Exclaim_DarkBlue", "torment": "Exclaim_DarkBlue", "endure": "Exclaim_Red", "powder": "Exclaim_Red", "perish_song": "Exclaim_White", "wish": "Exclaim_Yellow", "cud_chew": "Exclaim_Green",
	"enraged": "Fist_Yellow", "taunted": "Fist_DarkBlue", "exposed": "Exposed_Yellow", "sleepless": "Exposed_Red", "miracle_eye": "Sight_Red", "heal_block": "X_Gray", "embargo": "X_Brown", "follow_me": "Exclaim_Pink", "rage_powder": "Fist_Red", "fairy_lock": "X_Purple", "nightmare": "Skull_Pink", "destiny_bond": "Skull_DarkBlue", "snatch": "Question_DarkBlue",
}
const ICON_DIR: String = "res://assets/visuals/raw_asset/Icon/"
const ICON_FPS: float = 8.0
const HIDDEN: Array[String] = ["counter", "mirror_coat", "metal_burst", "roosting", "electrified", "sure_shot", "exposed", "miracle_eye", "defense_curl", "minimized", "enraged", "powder", "magic_coat", "full_paralysis"]
const SPACING: float = 0.34
const FONT_SIZE: int = PmdStyle.FONT_BODY
const PMD_FONT: FontFile = preload("res://assets/fonts/pmd/pmd_text.fnt")

var pawn: TacticsPawn = null
var _signature: String = ""
var _icon_time: float = 0.0
var _icon_sprites: Array[Sprite3D] = []


func _process(delta: float) -> void:
	if pawn == null or pawn.stats == null:
		return
	if not _icon_sprites.is_empty():
		_icon_time += delta
		for sprite in _icon_sprites:
			if sprite.hframes > 1:
				sprite.frame = int(floor(_icon_time * ICON_FPS)) % sprite.hframes
	var ids: Array[String] = []
	for status_id in pawn.stats.battle_statuses.keys():
		var key: String = String(status_id)
		if HIDDEN.has(key):
			continue
		ids.append(key)
	ids.sort()
	var signature: String = ",".join(ids) if pawn.stats.is_active() else ""
	if signature == _signature:
		return
	_signature = signature
	if not pawn.stats.is_active():
		ids.clear()
	_rebuild(ids)


func badge_texts() -> Array[String]:
	var out: Array[String] = []
	for child in get_children():
		if child is Label3D:
			out.append((child as Label3D).text)
		elif child is Sprite3D:
			out.append(String(child.name).trim_prefix("Icon_"))
	return out


func has_icon(status_id: String) -> bool:
	return EMOTICONS.has(status_id) and ResourceLoader.exists("%s%s.None.png" % [ICON_DIR, String(EMOTICONS[status_id])])


func _rebuild(ids: Array[String]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_icon_sprites.clear()
	var count: int = ids.size()
	for i in range(count):
		if has_icon(ids[i]):
			var texture: Texture2D = load("%s%s.None.png" % [ICON_DIR, String(EMOTICONS[ids[i]])]) as Texture2D
			if texture != null:
				var icon := Sprite3D.new()
				icon.texture = texture
				var cell: int = texture.get_height()
				icon.hframes = maxi(1, int(texture.get_width() / maxi(1, cell)))
				icon.vframes = 1
				icon.frame = 0
				icon.pixel_size = 0.02
				icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				icon.no_depth_test = true
				icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				icon.name = "Icon_%s" % ids[i]
				icon.position = Vector3((float(i) - float(count - 1) / 2.0) * SPACING, 0.0, 0.0)
				add_child(icon)
				_icon_sprites.append(icon)
				continue
		var entry: Array = BADGES.get(ids[i], [ids[i].substr(0, 4).to_upper(), Color(0.9, 0.9, 0.9)])
		var label := Label3D.new()
		label.text = String(entry[0])
		label.modulate = entry[1]
		label.font = PMD_FONT
		label.font_size = FONT_SIZE
		label.outline_size = 8
		label.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3((float(i) - float(count - 1) / 2.0) * SPACING, 0.0, 0.0)
		add_child(label)
