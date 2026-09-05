class_name TacticsPawnHudService
extends RefCounted

const BAR_PIXEL_SIZE: float = 0.012
const BAR_BACK_SIZE: Vector2i = Vector2i(44, 8)
const BAR_FILL_SIZE: Vector2i = Vector2i(40, 4)
const BAR_OFFSET_Y: float = 1.0
const FREEZE_TINT: Color = Color(0.55, 0.85, 1.0)
const PARALYSIS_TINT: Color = Color(1.0, 1.0, 0.35)
const PARALYSIS_PERIOD_MS: int = 700

static var _back_texture: ImageTexture = null
static var _fill_texture: ImageTexture = null


func update_character_health(pawn: TacticsPawn) -> void:
	var _health_label: Label3D = pawn.get_node("Character/CharacterUI/HealthLabel")
	_health_label.text = str(pawn.stats.curr_health) + "/" + str(pawn.stats.max_health)
	_update_health_bar(pawn)


func tint_when_unable_to_act(pawn: TacticsPawn) -> void:
	var _char_node: TacticsPawnSprite = pawn.get_node("Character")
	var spent: bool = not pawn.is_alive() or pawn.res.has_acted_this_round
	var base: Color = Color(0.5, 0.5, 0.5) if spent else Color(1, 1, 1)
	var tinted: Color = base * status_draw_tint(pawn)
	if not pawn.is_alive():
		var alpha: float = faint_alpha(pawn)
		tinted.a = alpha
		var shadow: Node3D = pawn.get_node_or_null("Shadow") as Node3D
		if shadow != null:
			shadow.visible = alpha > 0.05
	_char_node.modulate = tinted


func faint_alpha(pawn: TacticsPawn) -> float:
	var visuals: PawnStateVisuals = pawn.get_node_or_null("StateVisuals") as PawnStateVisuals
	return visuals.faint_alpha() if visuals != null else 1.0


func status_draw_tint(pawn: TacticsPawn) -> Color:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return Color(1, 1, 1)
	if pawn.stats.battle_statuses.has("freeze"):
		return FREEZE_TINT
	if pawn.stats.battle_statuses.has("paralyze") or pawn.stats.battle_statuses.has("full_paralysis"):
		var phase: int = int(Time.get_ticks_msec() / (PARALYSIS_PERIOD_MS / 2)) % 2
		return PARALYSIS_TINT if phase == 0 else Color(1, 1, 1)
	return Color(1, 1, 1)


func _update_health_bar(pawn: TacticsPawn) -> void:
	var ui: Node3D = pawn.get_node_or_null("Character/CharacterUI") as Node3D
	if ui == null or pawn.stats == null:
		return
	var back: Sprite3D = ui.get_node_or_null("HpBarBack") as Sprite3D
	var fill: Sprite3D = ui.get_node_or_null("HpBarFill") as Sprite3D
	if back == null or fill == null:
		back = _bar_sprite("HpBarBack", _texture_for(BAR_BACK_SIZE, PmdStyle.HP_BACK, true))
		fill = _bar_sprite("HpBarFill", _texture_for(BAR_FILL_SIZE, Color.WHITE, false))
		fill.render_priority = 1
		ui.add_child(back)
		ui.add_child(fill)
		var anchor: Node3D = ui.get_node_or_null("HealthLabel") as Node3D
		var height: float = anchor.position.y if anchor != null else 1.62
		back.position = Vector3(0.0, height, 0.0)
		fill.position = Vector3(0.0, height, 0.01)
	var fraction: float = clampf(float(pawn.stats.curr_health) / float(maxi(1, pawn.stats.max_health)), 0.0, 1.0)
	var width: int = maxi(1, int(round(float(BAR_FILL_SIZE.x) * fraction))) if fraction > 0.0 else 0
	fill.visible = width > 0
	fill.region_enabled = true
	fill.region_rect = Rect2(0.0, 0.0, float(maxi(width, 1)), float(BAR_FILL_SIZE.y))
	fill.offset = Vector2(-float(BAR_FILL_SIZE.x - width) * 0.5, BAR_OFFSET_Y)
	fill.modulate = PmdStyle.hp_color(fraction)
	back.offset = Vector2(0.0, BAR_OFFSET_Y)


func _bar_sprite(node_name: String, texture: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.pixel_size = BAR_PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.layers = 2
	return sprite


static func _texture_for(size: Vector2i, color: Color, back: bool) -> ImageTexture:
	if back and _back_texture != null:
		return _back_texture
	if not back and _fill_texture != null:
		return _fill_texture
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	if back:
		for x in range(size.x):
			image.set_pixel(x, 0, PmdStyle.FRAME_SOFT)
			image.set_pixel(x, size.y - 1, PmdStyle.FRAME_SOFT)
		for y in range(size.y):
			image.set_pixel(0, y, PmdStyle.FRAME_SOFT)
			image.set_pixel(size.x - 1, y, PmdStyle.FRAME_SOFT)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if back:
		_back_texture = texture
	else:
		_fill_texture = texture
	return texture
