class_name EnetLink
extends NetLink

const DEFAULT_PORT: int = 24555
const CONNECT_TIMEOUT: float = 10.0

var peer: ENetMultiplayerPeer = null
var server: bool = false
var remote_id: int = 0
var address: String = ""
var port: int = DEFAULT_PORT
var _elapsed: float = 0.0
var _connecting: bool = false
var _pending_close: String = ""
var _opened: bool = false


func host(listen_port: int = DEFAULT_PORT) -> String:
	close("rehost")
	port = listen_port
	server = true
	peer = ENetMultiplayerPeer.new()
	var error: int = peer.create_server(port, 1)
	if error != OK:
		peer = null
		return "could not listen on port %d (error %d)" % [port, error]
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	open = true
	_connecting = false
	_opened = false
	return ""


func join(host_address: String, host_port: int = DEFAULT_PORT) -> String:
	close("rejoin")
	address = host_address
	port = host_port
	server = false
	peer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(address, port)
	if error != OK:
		peer = null
		return "could not reach %s:%d (error %d)" % [address, port, error]
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	open = true
	_connecting = true
	_opened = false
	_elapsed = 0.0
	return ""


func poll(delta: float = 0.0) -> void:
	if peer == null:
		return
	peer.poll()
	if _connecting:
		_elapsed += delta
		var status: int = peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			_connecting = false
			remote_id = 1
			_emit_opened()
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			close("refused")
			return
		elif _elapsed > CONNECT_TIMEOUT:
			close("timeout")
			return
	while peer != null and peer.get_available_packet_count() > 0:
		var from: int = peer.get_packet_peer()
		var bytes: PackedByteArray = peer.get_packet()
		var value: Variant = bytes_to_var(bytes)
		if value is Dictionary:
			if server and remote_id == 0:
				remote_id = from
			received.emit(value as Dictionary)
	if not _pending_close.is_empty():
		var reason: String = _pending_close
		_pending_close = ""
		close(reason)


func _on_peer_connected(id: int) -> void:
	if server:
		remote_id = id
	else:
		remote_id = 1
		_connecting = false
	_emit_opened()


func _emit_opened() -> void:
	if _opened:
		return
	_opened = true
	opened.emit()


func _on_peer_disconnected(_id: int) -> void:
	_pending_close = "peer_lost"


func send(message: Dictionary) -> bool:
	if peer == null or not open:
		return false
	var target: int = remote_id if server else 1
	if target == 0:
		return false
	peer.set_target_peer(target)
	peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	return peer.put_packet(var_to_bytes(message)) == OK


func close(reason: String = "closed") -> void:
	var was_open: bool = open
	open = false
	_connecting = false
	_pending_close = ""
	remote_id = 0
	if peer != null:
		peer.close()
		peer = null
	if was_open:
		closed.emit(reason)


func round_trip_ms() -> int:
	if peer == null or not open or remote_id == 0 or _connecting:
		return -1
	var remote: ENetPacketPeer = peer.get_peer(remote_id)
	if remote == null:
		return -1
	return int(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func local_addresses() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry in IP.get_local_addresses():
		var text: String = String(entry)
		if text.contains(":") or text.begins_with("127."):
			continue
		out.append(text)
	return out


func describe() -> String:
	return "enet:%s:%d" % ["host" if server else address, port]
