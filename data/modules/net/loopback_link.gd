class_name LoopbackLink
extends NetLink

var partner: LoopbackLink = null
var inbox: Array[Dictionary] = []
var label: String = "loopback"
var delay_frames: int = 0
var _tick: int = 0


static func pair(first_label: String = "host", second_label: String = "guest") -> Array:
	var a := LoopbackLink.new()
	var b := LoopbackLink.new()
	a.label = first_label
	b.label = second_label
	a.partner = b
	b.partner = a
	a.open = true
	b.open = true
	return [a, b]


func send(message: Dictionary) -> bool:
	if not open or partner == null:
		return false
	partner.inbox.append({"at": partner._tick + partner.delay_frames, "message": message.duplicate(true)})
	return true


func poll(_delta: float = 0.0) -> void:
	_tick += 1
	while not inbox.is_empty() and int(inbox[0].get("at", 0)) <= _tick:
		var entry: Dictionary = inbox.pop_front()
		received.emit(entry.get("message", {}) as Dictionary)


func close(reason: String = "closed") -> void:
	if not open:
		return
	open = false
	var other: LoopbackLink = partner
	partner = null
	closed.emit(reason)
	if other != null:
		other.partner = null
		if other.open:
			other.open = false
			other.closed.emit("peer_closed")


func describe() -> String:
	return "loopback:%s" % label
