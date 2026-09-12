extends SmokeCase

const FONT_DIR: String = "res://assets/fonts/pmd/"
const FONT_NAMES: Array[String] = ["text", "banner", "system", "simple", "blue", "green", "yellow"]
const THEME_PATH: String = "res://assets/ui/pmd_theme.tres"
const REPORT_PATH: String = "res://data/models/visuals/import_reports/font_report.json"


func _run() -> void:
	for name in FONT_NAMES:
		var font: FontFile = load("%spmd_%s.fnt" % [FONT_DIR, name]) as FontFile
		_assert_true(font != null, "pmd_%s loads as a FontFile" % name)
		if font == null:
			continue
		var sizes: Array[Vector2i] = font.get_size_cache_list(0)
		_assert_true(sizes.size() == 1 and sizes[0].x > 0, "pmd_%s has one fixed size (%s)" % [name, str(sizes)])
		if name == "text" or name == "banner":
			_assert_true(font.has_char(65) and font.has_char(97) and font.has_char(48) and font.has_char(33), "pmd_%s covers A, a, 0 and !" % name)
			_assert_true(font.get_string_size("Charizard used Ember!").x > 0.0, "pmd_%s measures a sentence" % name)
		elif name == "system" or name == "simple":
			_assert_true(font.has_char(65) and font.has_char(97) and font.has_char(48) and font.has_char(35), "pmd_%s covers A, a, 0 and #" % name)
		else:
			_assert_true(font.has_char(48) and font.has_char(57), "pmd_%s covers the digits" % name)
	var text_font: FontFile = load(FONT_DIR + "pmd_text.fnt") as FontFile
	if text_font != null:
		_assert_true(text_font.get_height(12) == 13 and text_font.get_ascent(12) == 10, "pmd_text keeps the 12px cell: height 13, ascent 10 (%d, %d)" % [text_font.get_height(12), text_font.get_ascent(12)])
		_assert_true(text_font.get_char_size(32, 12).x == 4.0, "pmd_text space advance is the source SpaceWidth (%s)" % str(text_font.get_char_size(32, 12)))
	var theme: Theme = load(THEME_PATH) as Theme
	_assert_true(theme != null and theme.default_font != null and theme.default_font.resource_path.ends_with("pmd_text.fnt") and theme.default_font_size == 36, "project theme uses pmd_text at 36px")
	_assert_true(String(ProjectSettings.get_setting("gui/theme/custom", "")) == THEME_PATH, "gui/theme/custom points at the PMD theme")
	var scene: PackedScene = load("res://data/modules/tactics/level/pawn/pawn.tscn")
	var pawn: Node = scene.instantiate()
	for label_path in ["Character/CharacterUI/NameLabel", "Character/CharacterUI/HealthLabel"]:
		var label: Label3D = pawn.get_node(label_path) as Label3D
		_assert_true(label != null and label.font != null and label.font.resource_path.ends_with("pmd_text.fnt") and label.font_size % 12 == 0, "%s uses pmd_text at an integer multiple" % label_path)
	pawn.free()
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.READ)
	if file != null:
		var report: Dictionary = JSON.parse_string(file.get_as_text())
		var fonts: Array = report.get("fonts", [])
		_assert_true(fonts.size() == FONT_NAMES.size(), "font report lists %d fonts" % FONT_NAMES.size())
	else:
		_assert_true(false, "font report exists")
	_finish("pmd_font")
