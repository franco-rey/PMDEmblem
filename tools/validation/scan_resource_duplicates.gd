extends SceneTree

var root_dir := "res://"
var duplicate_mode := "both"
var extensions: Array[String] = ["tres", "tscn", "res"]
var limit := 0
var start := 0
var progress_every := 100
var fail_on_load_error := false

var scanned := 0
var load_errors := 0
var duplicate_errors := 0


func _initialize() -> void:
	_parse_args()
	print("resource-scan: start root=%s mode=%s extensions=%s start=%d limit=%d" % [
		root_dir,
		duplicate_mode,
		",".join(extensions),
		start,
		limit,
	])
	var paths := _collect_paths(root_dir)
	paths.sort()
	print("resource-scan: collected count=%d" % paths.size())
	var stop := paths.size()
	if limit > 0:
		stop = mini(paths.size(), start + limit)
	for i in range(start, stop):
		_scan_path(paths[i], i)
	print("resource-scan: done scanned=%d load_errors=%d duplicate_errors=%d" % [
		scanned,
		load_errors,
		duplicate_errors,
	])
	quit(1 if duplicate_errors > 0 or (fail_on_load_error and load_errors > 0) else 0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):
			root_dir = arg.trim_prefix("--root=")
		elif arg.begins_with("--mode="):
			duplicate_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--extensions="):
			extensions.clear()
			for ext in arg.trim_prefix("--extensions=").split(",", false):
				var normalized := String(ext).strip_edges().trim_prefix(".").to_lower()
				if not normalized.is_empty():
					extensions.append(normalized)
		elif arg.begins_with("--limit="):
			limit = maxi(0, int(arg.trim_prefix("--limit=")))
		elif arg.begins_with("--start="):
			start = maxi(0, int(arg.trim_prefix("--start=")))
		elif arg.begins_with("--progress-every="):
			progress_every = maxi(1, int(arg.trim_prefix("--progress-every=")))
		elif arg == "--fail-on-load-error":
			fail_on_load_error = true
	if duplicate_mode not in ["shallow", "deep", "both"]:
		push_error("Unsupported --mode=%s; expected shallow, deep, or both" % duplicate_mode)
		quit(2)


func _collect_paths(path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Could not open scan root: %s" % path)
		return out
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			out.append_array(_collect_paths(child))
		else:
			var ext := child.get_extension().to_lower()
			if extensions.has(ext):
				out.append(child)
	dir.list_dir_end()
	return out


func _scan_path(path: String, index: int) -> void:
	if scanned % progress_every == 0:
		print("resource-scan: progress scanned=%d index=%d path=%s" % [scanned, index, path])
	print("resource-scan: load index=%d path=%s" % [index, path])
	var resource := ResourceLoader.load(path)
	if not (resource is Resource):
		load_errors += 1
		push_error("resource-scan: load failed path=%s" % path)
		return
	if duplicate_mode in ["shallow", "both"]:
		_duplicate_resource(resource, path, "shallow")
	if duplicate_mode in ["deep", "both"]:
		_duplicate_resource(resource, path, "deep")
	scanned += 1


func _duplicate_resource(resource: Resource, path: String, mode: String) -> void:
	print("resource-scan: duplicate mode=%s path=%s" % [mode, path])
	var duplicate := resource.duplicate(mode == "deep")
	if duplicate == null:
		duplicate_errors += 1
		push_error("resource-scan: duplicate returned null mode=%s path=%s" % [mode, path])
