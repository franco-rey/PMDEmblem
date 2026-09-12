extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(1280, 800), Vector2i(1440, 900),
	Vector2i(1680, 1050), Vector2i(1920, 1200), Vector2i(2560, 1600), Vector2i(3024, 1964), Vector2i(1512, 982), Vector2i(1280, 960), Vector2i(1600, 1200), Vector2i(2048, 1536),
	Vector2i(1500, 1000), Vector2i(2256, 1504), Vector2i(2880, 1920), Vector2i(1280, 1024), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(1280, 1280), Vector2i(1600, 1600),
	Vector2i(2000, 2000), Vector2i(1280, 1920), Vector2i(1440, 2560), Vector2i(1300, 760), Vector2i(1400, 1050), Vector2i(1720, 880), Vector2i(1900, 1000), Vector2i(2200, 1100),
	Vector2i(2100, 1300), Vector2i(1700, 1300), Vector2i(2400, 1000), Vector2i(1650, 920), Vector2i(2000, 1125), Vector2i(2736, 1824), Vector2i(1280, 730), Vector2i(1290, 740),
	Vector2i(1350, 800), Vector2i(1480, 820), Vector2i(1800, 720), Vector2i(2200, 760), Vector2i(3000, 900), Vector2i(1366, 1366), Vector2i(1920, 1440), Vector2i(2560, 1200), Vector2i(1600, 720), Vector2i(3840, 1600),
]
const TOLERANCE: float = 1.0

var problems: Array[String] = []


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=42 mode=pvp team=6 map=chessboard")
	_assert_true(ok, "6v6 chessboard match launches for the layout sweep")
	if not ok:
		_finish("layout_sweep")
		return
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await process_frame
		frames += 1
	var hud: BattleHud = level.hud
	var res: TacticsParticipantResource = level.participant.res
	var enemy: TacticsPawn = level.opponent.get_child(0)
	if res.curr_pawn == null or res.curr_pawn == enemy:
		enemy = level.opponent.get_child(1)
	res.stage = res.STAGE_SELECT_ATTACK_TARGET
	res.attackable_pawn = enemy
	hud.pin(enemy)
	hud.weather_text = "Rain (5)"
	hud._weather_label.text = hud.weather_text
	hud._weather_chip.visible = true
	var speed_panel: Control = main.speed_bar._panel
	var actions: Control = main.get_node("TacticsControls/HBox/Actions")
	var tactics_controls: Control = main.get_node("TacticsControls")
	var checked: int = 0
	var passes: Array = []
	for style in [0, 3]:
		for size in SIZES:
			passes.append([style, size])
	var current_style: int = -1
	for entry in passes:
		var style_index: int = int(entry[0])
		var size: Vector2i = entry[1]
		if style_index != current_style:
			current_style = style_index
			PmdStyle.set_border_style(style_index)
			for i in range(3):
				await process_frame
		for pass_index in range(2):
			var cpu_pass: bool = pass_index == 1
			tactics_controls.visible = not cpu_pass
			main.speed_bar.visible = cpu_pass
			root.size = size
			UiScale.override_factor = 0.0
			var factor: float = UiScale.apply(root)
			for i in range(5):
				await process_frame
			var logical: Vector2 = Vector2(size) / factor
			var menu_rect := Rect2()
			for child in actions.get_children():
				if child is Control and (child as Control).visible:
					menu_rect = (child as Control).get_global_rect() if menu_rect.size == Vector2.ZERO else menu_rect.merge((child as Control).get_global_rect())
			var rects: Dictionary = {
				"active panel": hud._active_panel.get_global_rect(),
				"target panel": hud._target_panel.get_global_rect(),
				"queue box": hud._queue_strip.get_global_rect(),
				"inspector": hud._inspector.get_global_rect(),
				"status dock": hud._status_dock.get_global_rect(),
				"weather chip": hud._weather_chip.get_global_rect(),
				"battle log": level.message_log._dock.get_global_rect(),
				"speed bar": speed_panel.get_global_rect(),
				"action menu": menu_rect,
			}
			var visible_now: Dictionary = {
				"active panel": hud._active_panel.visible, "target panel": hud._target_panel.visible, "queue box": hud._queue_strip.visible,
				"inspector": hud._inspector.visible, "status dock": true, "weather chip": hud._weather_chip.visible, "battle log": true, "speed bar": cpu_pass, "action menu": not cpu_pass and actions.visible,
			}
			var pass_label: String = ("cpu turn" if cpu_pass else "human turn") + (" border %d" % style_index)
			var settled_top: float = hud._queue_column.offset_top
			var settled_scale: float = hud.queue_tile_scale
			var settled_width: float = hud._queue_strip.size.x
			for i in range(6):
				await process_frame
			if not is_equal_approx(hud._queue_column.offset_top, settled_top) or not is_equal_approx(hud.queue_tile_scale, settled_scale) or absf(hud._queue_strip.size.x - settled_width) > 0.5:
				problems.append("%dx%d %s (scale %.1f, logical %dx%d): queue box jitters (top %.0f -> %.0f, scale %.2f -> %.2f, width %.0f -> %.0f)" % [size.x, size.y, factor, int(logical.x), int(logical.y), pass_label, settled_top, hud._queue_column.offset_top, settled_scale, hud.queue_tile_scale, settled_width, hud._queue_strip.size.x])
			var names: Array = rects.keys()
			for i in range(names.size()):
				var a: String = names[i]
				if not visible_now[a]:
					continue
				var ra: Rect2 = rects[a]
				if ra.position.x < -TOLERANCE or ra.position.y < -TOLERANCE or ra.end.x > logical.x + TOLERANCE or ra.end.y > logical.y + TOLERANCE:
					problems.append("%dx%d %s (scale %.1f, logical %dx%d): %s leaves the window %s" % [size.x, size.y, pass_label, factor, int(logical.x), int(logical.y), a, str(ra)])
				for j in range(i + 1, names.size()):
					var b: String = names[j]
					if not visible_now[b]:
						continue
					if a == "inspector" and (b == "action menu" or b == "speed bar"):
						continue
					var rb: Rect2 = rects[b]
					var shrunk: Rect2 = Rect2(ra.position + Vector2(TOLERANCE, TOLERANCE), ra.size - Vector2(2.0 * TOLERANCE, 2.0 * TOLERANCE))
					if shrunk.size.x > 0.0 and shrunk.size.y > 0.0 and shrunk.intersects(rb):
						problems.append("%dx%d %s (scale %.1f, logical %dx%d): %s overlaps %s (%s vs %s)" % [size.x, size.y, pass_label, factor, int(logical.x), int(logical.y), a, b, str(ra), str(rb)])
			checked += 1
	tactics_controls.visible = true
	main.speed_bar.visible = false
	PmdStyle.set_border_style(0)
	print("smoke: sweep checked %d size passes, %d problems" % [checked, problems.size()])
	for problem in problems:
		print("smoke: layout - %s" % problem)
	_assert_true(problems.is_empty(), "no HUD element overlaps another or leaves the window across %d size passes (%d problems)" % [checked, problems.size()])
	_finish("layout_sweep")
