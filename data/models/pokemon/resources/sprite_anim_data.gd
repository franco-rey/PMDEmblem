class_name SpriteAnimData
extends RefCounted
## Lightweight parser for SpriteCollab `AnimData.xml` sidecars.
##
## Each species' sprite folder ships an `AnimData.xml` that lists per-animation
## `FrameWidth` and `FrameHeight` plus the frame `Durations`. The runtime
## sprite uses these to slice the sheets correctly: most animations are 4-8
## cols x 8 rows (one row per facing direction), but Sleep is a single-row
## (single-direction) layout.
##
## This class only extracts the few fields needed to render at runtime:
##   - frame width / height per anim state
##   - frame count per row (the rest of the XML is shadow / offsets / sprite
##     metadata we don't consume in the tactical view)

class AnimEntry extends RefCounted:
	var name: String = ""
	var frame_width: int = 0
	var frame_height: int = 0
	var frames_per_direction: int = 1
	## Resolved CopyOf reference name (some anims defer their layout to another
	## entry; the parser resolves this in `parse`).
	var copy_of: String = ""


## Parses the XML at `path` and returns a dict {anim_name: AnimEntry}. Returns
## an empty dict if the file is missing or malformed - callers should fall
## back to texture-aspect heuristics in that case.
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
							# Durations counter started at 1 to avoid an explicit
							# init in the loop; the +1 is corrected here.
							pending.frames_per_direction = maxi(1, pending.frames_per_direction - 1)
							out[pending.name] = pending
						pending = null
			text_buf = ""

	# Resolve CopyOf references in a second pass so layout-deferred anims
	# (e.g. Strike CopyOf="Attack") still report sensible frame dimensions.
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
