class_name LanBeacon
extends Node

const BEACON_PORT: int = 24556
const INTERVAL: float = 1.0
const STALE_SECONDS: float = 5.0

signal hosts_changed(hosts: Array)

var broadcasting: bool = false
var listening: bool = false
var host_port: int = EnetLink.DEFAULT_PORT
var host_name: String = "Player"
var hosts: Array[Dictionary] = []

var _send_socket: PacketPeerUDP = null
var _listen_socket: PacketPeerUDP = null
var _timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func start_broadcast(port: int, player_name: String) -> void:
	host_port = port
	host_name = player_name
	_send_socket = PacketPeerUDP.new()
	_send_socket.set_broadcast_enabled(true)
	_send_socket.set_dest_address("255.255.255.255", BEACON_PORT)
	broadcasting = true
	_timer = INTERVAL


func stop_broadcast() -> void:
	broadcasting = false
	if _send_socket != null:
		_send_socket.close()
	_send_socket = null


func start_listening() -> void:
	if listening:
		return
	_listen_socket = PacketPeerUDP.new()
	if _listen_socket.bind(BEACON_PORT) != OK:
		_listen_socket = null
		return
	listening = true
	hosts.clear()


func stop_listening() -> void:
	listening = false
	if _listen_socket != null:
		_listen_socket.close()
	_listen_socket = null
	hosts.clear()


func _process(delta: float) -> void:
	if broadcasting and _send_socket != null:
		_timer += delta
		if _timer >= INTERVAL:
			_timer = 0.0
			_send_socket.put_packet(JSON.stringify({
				"k": "beacon",
				"name": host_name,
				"port": host_port,
				"version": GameSettings.GAME_VERSION,
			}).to_utf8_buffer())
	if not listening or _listen_socket == null:
		return
	var changed: bool = false
	while _listen_socket.get_available_packet_count() > 0:
		var from: String = _listen_socket.get_packet_ip()
		var text: String = _listen_socket.get_packet().get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Dictionary) or String((parsed as Dictionary).get("k", "")) != "beacon":
			continue
		var entry: Dictionary = parsed
		if String(entry.get("version", "")) != GameSettings.GAME_VERSION:
			continue
		changed = _remember(from, String(entry.get("name", "Player")), int(entry.get("port", EnetLink.DEFAULT_PORT))) or changed
	var now: float = Time.get_ticks_msec() / 1000.0
	var kept: Array[Dictionary] = []
	for entry in hosts:
		if now - float(entry.get("seen", 0.0)) <= STALE_SECONDS:
			kept.append(entry)
		else:
			changed = true
	hosts = kept
	if changed:
		hosts_changed.emit(hosts)


func _remember(address: String, player_name: String, port: int) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	for entry in hosts:
		if String(entry.get("address", "")) == address and int(entry.get("port", 0)) == port:
			entry["seen"] = now
			entry["name"] = player_name
			return false
	hosts.append({"address": address, "name": player_name, "port": port, "seen": now})
	return true
