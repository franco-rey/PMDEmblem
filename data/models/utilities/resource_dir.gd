class_name ResourceDir
extends RefCounted

const REMAP_SUFFIX: String = ".remap"


static func file_names(directory: String, extension: String = ".tres") -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			var name: String = entry.trim_suffix(REMAP_SUFFIX)
			if name.ends_with(extension) and not out.has(name):
				out.append(name)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func paths(directory: String, extension: String = ".tres") -> Array[String]:
	var out: Array[String] = []
	var base: String = directory if directory.ends_with("/") else directory + "/"
	for name in file_names(directory, extension):
		out.append(base + name)
	return out
