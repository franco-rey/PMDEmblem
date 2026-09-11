class_name GenderRules
extends RefCounted

const UNKNOWN: int = -1
const GENDERLESS: int = 0
const MALE: int = 1
const FEMALE: int = 2
const RANDOM_CHOICE: String = "random"
const ROLL_SALT: int = 0x3C6EF372
const IDS: Dictionary = {GENDERLESS: "genderless", MALE: "male", FEMALE: "female"}
const LABELS: Dictionary = {GENDERLESS: "Genderless", MALE: "Male", FEMALE: "Female"}
const GLYPHS: Dictionary = {MALE: "♂", FEMALE: "♀"}
const CODE_SUFFIXES: Dictionary = {MALE: "m", FEMALE: "f"}
const MALE_COLOR: Color = Color(0.45, 0.68, 1.0)
const FEMALE_COLOR: Color = Color(1.0, 0.55, 0.68)


static func weights(form: PokemonFormResource) -> Vector3i:
	return form.gender_weights if form != null else Vector3i.ZERO


static func options(form: PokemonFormResource) -> Array[int]:
	var out: Array[int] = []
	var w: Vector3i = weights(form)
	if w.y > 0:
		out.append(MALE)
	if w.z > 0:
		out.append(FEMALE)
	if out.is_empty():
		out.append(GENDERLESS)
	return out


static func is_choice(form: PokemonFormResource) -> bool:
	return options(form).size() > 1


static func fixed(form: PokemonFormResource) -> int:
	var list: Array[int] = options(form)
	return list[0] if list.size() == 1 else UNKNOWN


static func roll(form: PokemonFormResource, seed: int, side_key: String, slot_index: int) -> int:
	var w: Vector3i = weights(form)
	var total: int = w.x + w.y + w.z
	if total <= 0:
		return GENDERLESS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gender:%d:%s:%d" % [seed ^ ROLL_SALT, side_key, slot_index])
	return _pick(w, rng.randi_range(1, total))


static func roll_for_instance(form: PokemonFormResource, instance: PokemonInstanceResource) -> int:
	var w: Vector3i = weights(form)
	var total: int = w.x + w.y + w.z
	if total <= 0:
		return GENDERLESS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%s:%d:%d" % [instance.species.species_id if instance != null and instance.species != null else "", instance.form_index if instance != null else 0, instance.nickname if instance != null else "", instance.level if instance != null else 0, instance.team if instance != null else 0])
	return _pick(w, rng.randi_range(1, total))


static func _pick(w: Vector3i, value: int) -> int:
	if value <= w.x:
		return GENDERLESS
	if value <= w.x + w.y:
		return MALE
	return FEMALE


static func parse_id(text: String) -> int:
	match text.strip_edges().to_lower():
		"m", "male":
			return MALE
		"f", "female":
			return FEMALE
		"n", "genderless", "none":
			return GENDERLESS
	return UNKNOWN


static func id(gender: int) -> String:
	return String(IDS.get(gender, ""))


static func label(gender: int) -> String:
	return String(LABELS.get(gender, "Unknown"))


static func glyph(gender: int) -> String:
	return String(GLYPHS.get(gender, ""))


static func suffix(gender: int) -> String:
	var mark: String = glyph(gender)
	return " " + mark if not mark.is_empty() else ""


static func code_suffix(gender: int) -> String:
	return String(CODE_SUFFIXES.get(gender, ""))


static func color(gender: int, fallback: Color = Color.WHITE) -> Color:
	if gender == MALE:
		return MALE_COLOR
	if gender == FEMALE:
		return FEMALE_COLOR
	return fallback


static func ratio_label(form: PokemonFormResource) -> String:
	var w: Vector3i = weights(form)
	if w.y > 0 and w.z > 0:
		return "%d%s : %d%s" % [w.y, glyph(MALE), w.z, glyph(FEMALE)]
	if w.y > 0:
		return "Male only"
	if w.z > 0:
		return "Female only"
	return "Genderless"


static func opposite(a: int, b: int) -> bool:
	return a > GENDERLESS and b > GENDERLESS and a != b


static func same(a: int, b: int) -> bool:
	return a > GENDERLESS and a == b


static func choice_error(form: PokemonFormResource, wanted: int, name: String) -> String:
	if options(form).has(wanted):
		return ""
	return "%s cannot be %s (%s)" % [name, label(wanted).to_lower(), ratio_label(form).to_lower()]
