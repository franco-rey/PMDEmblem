class_name NetPortOpener
extends Node

signal finished(result: Dictionary)

const DISCOVER_TIMEOUT_MS: int = 2000
const DESCRIPTION: String = "PMD Emblem"
const STATE_IDLE: String = "idle"
const STATE_WORKING: String = "working"
const STATE_OPEN: String = "open"
const STATE_FAILED: String = "failed"
const STATE_CLOSED: String = "closed"

var port: int = 0
var state: String = STATE_IDLE
var external_address: String = ""
var detail: String = ""
var _thread: Thread = null
var _closer: Thread = null
var _upnp: UPNP = null
var _mapped: bool = false
var _close_requested: bool = false


func open(listen_port: int) -> void:
	if _thread != null and _thread.is_alive():
		_close_requested = true
		return
	close()
	_close_requested = false
	port = listen_port
	state = STATE_WORKING
	external_address = ""
	detail = "Asking the router to open UDP %d..." % port
	_thread = Thread.new()
	_thread.start(_work.bind(listen_port))


func _work(listen_port: int) -> void:
	var upnp := UPNP.new()
	var result: Dictionary = {"ok": false, "port": listen_port}
	var code: int = upnp.discover(DISCOVER_TIMEOUT_MS, 2, "InternetGatewayDevice")
	var gateway: UPNPDevice = upnp.get_gateway() if code == UPNP.UPNP_RESULT_SUCCESS else null
	if gateway == null or not gateway.is_valid_gateway():
		result["error"] = "no UPnP gateway answered (%d)" % code
	else:
		var mapped: int = upnp.add_port_mapping(listen_port, listen_port, DESCRIPTION, "UDP", 0)
		if mapped != UPNP.UPNP_RESULT_SUCCESS:
			result["error"] = "the router refused the mapping (%d)" % mapped
		else:
			result["ok"] = true
			result["address"] = upnp.query_external_address()
			result["upnp"] = upnp
	call_deferred("_apply_result", result)


func _apply_result(result: Dictionary) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if int(result.get("port", 0)) != port and port != 0:
		return
	if bool(result.get("ok", false)):
		_upnp = result.get("upnp", null)
		_mapped = _upnp != null
		state = STATE_OPEN
		external_address = String(result.get("address", ""))
		detail = "Router opened UDP %d. Public address %s" % [port, external_address] if not external_address.is_empty() else "Router opened UDP %d." % port
	else:
		_upnp = null
		_mapped = false
		state = STATE_FAILED
		detail = "Router did not open UDP %d (%s). Forward it manually for internet play." % [port, String(result.get("error", "unknown"))]
	finished.emit(result)
	if _close_requested:
		_close_requested = false
		close()


func close() -> void:
	if _thread != null and _thread.is_alive():
		_close_requested = true
		return
	if _mapped and _upnp != null:
		_join_closer()
		var upnp: UPNP = _upnp
		var mapped_port: int = port
		_closer = Thread.new()
		_closer.start(func() -> void: upnp.delete_port_mapping(mapped_port, "UDP"))
	_upnp = null
	_mapped = false
	if state != STATE_IDLE:
		state = STATE_CLOSED
	detail = ""
	external_address = ""


func is_open() -> bool:
	return state == STATE_OPEN


func _join_closer() -> void:
	if _closer != null:
		_closer.wait_to_finish()
		_closer = null


func _exit_tree() -> void:
	if _thread != null and _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	close()
	_join_closer()
