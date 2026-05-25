class_name SpriteAnimData
extends RefCounted

class AnimEntry extends RefCounted:
	var name: String = ""
	var frame_width: int = 0
	var frame_height: int = 0
	var frames_per_direction: int = 1
	var copy_of: String = ""


static func parse(path: String) -> Dictionary:
	var out: Dictionary = {}
	if path.is_empty() or not FileAccess.file_exists(path):
		return out
	var xml: XMLParser = XMLParser.new()
	if xml.open(path) != OK:
		return out

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
			if pending != null:
				match ending:
					"Name": pending.name = text_buf.strip_edges()
					"FrameWidth": pending.frame_width = int(text_buf.strip_edges())
					"FrameHeight": pending.frame_height = int(text_buf.strip_edges())
					"CopyOf": pending.copy_of = text_buf.strip_edges()
					"Duration": pending.frames_per_direction += 1
					"Anim":
						if not pending.name.is_empty():
							pending.frames_per_direction = maxi(1, pending.frames_per_direction - 1)
							out[pending.name] = pending
						pending = null
			text_buf = ""

	for anim_name in out.keys():
		var anim: AnimEntry = out[anim_name]
		if anim.copy_of.is_empty() or anim.frame_width > 0:
			continue
		var source: AnimEntry = out.get(anim.copy_of)
		if source != null:
			anim.frame_width = source.frame_width
			anim.frame_height = source.frame_height
			anim.frames_per_direction = source.frames_per_direction
	return out
