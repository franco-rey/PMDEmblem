class_name SpriteAnimData
extends RefCounted

const ABSENT_FRAME: int = -1

class AnimEntry extends RefCounted:
	var name: String = ""
	var index: int = ABSENT_FRAME
	var frame_width: int = 0
	var frame_height: int = 0
	var frames_per_direction: int = 1
	var copy_of: String = ""
	var durations: Array[int] = []
	var rush_frame: int = ABSENT_FRAME
	var hit_frame: int = ABSENT_FRAME
	var return_frame: int = ABSENT_FRAME


static func parse(path: String) -> Dictionary:
	return parse_root(path).get("anims", {})


static func parse_root(path: String) -> Dictionary:
	var out: Dictionary = {}
	var root: Dictionary = {"shadow_size": 0, "anims": out}
	if path.is_empty() or not FileAccess.file_exists(path):
		return root
	var xml: XMLParser = XMLParser.new()
	if xml.open(path) != OK:
		return root

	var pending: AnimEntry = null
	var current_tag: String = ""
	var text_buf: String = ""
	while xml.read() == OK:
		var node_type: int = xml.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			current_tag = xml.get_node_name()
			text_buf = ""
			if current_tag == "Anim":
				pending = AnimEntry.new()
		elif node_type == XMLParser.NODE_TEXT:
			text_buf += xml.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var ending: String = xml.get_node_name()
			var text: String = text_buf.strip_edges()
			if pending != null:
				match ending:
					"Name": pending.name = text
					"Index": pending.index = int(text) if text.is_valid_int() else ABSENT_FRAME
					"FrameWidth": pending.frame_width = int(text)
					"FrameHeight": pending.frame_height = int(text)
					"CopyOf": pending.copy_of = text
					"RushFrame": pending.rush_frame = int(text) if text.is_valid_int() else ABSENT_FRAME
					"HitFrame": pending.hit_frame = int(text) if text.is_valid_int() else ABSENT_FRAME
					"ReturnFrame": pending.return_frame = int(text) if text.is_valid_int() else ABSENT_FRAME
					"Duration":
						if text.is_valid_int():
							pending.durations.append(int(text))
					"Anim":
						if not pending.name.is_empty():
							pending.frames_per_direction = maxi(1, pending.durations.size())
							out[pending.name] = pending
						pending = null
			elif ending == "ShadowSize" and text.is_valid_int():
				root["shadow_size"] = int(text)
			text_buf = ""

	for anim_name in out.keys():
		var anim: AnimEntry = out[anim_name]
		if anim.copy_of.is_empty() or anim.frame_width > 0:
			continue
		var target: AnimEntry = resolve_alias(out, anim_name)
		if target != null and target != anim:
			anim.frame_width = target.frame_width
			anim.frame_height = target.frame_height
			anim.frames_per_direction = target.frames_per_direction
			anim.durations = target.durations.duplicate()
			anim.rush_frame = target.rush_frame
			anim.hit_frame = target.hit_frame
			anim.return_frame = target.return_frame
	return root


static func resolve_alias(anims: Dictionary, anim_name: String) -> AnimEntry:
	var seen: Array[String] = []
	var current: String = anim_name
	while anims.has(current):
		var entry: AnimEntry = anims[current]
		if entry.copy_of.is_empty():
			return entry
		if seen.has(current):
			return null
		seen.append(current)
		current = entry.copy_of
	return null
