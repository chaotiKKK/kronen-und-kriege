extends RefCounted
## Lokale UDP-Suche: Sucher mit Port 0, Antwort ausschließlich an den Absender.

const MARKER := "BQ-LAN"
const PORT := 28740
const TTL_MS := 12000
var rooms: Array = []
var _listener: PacketPeerUDP
var _searcher: PacketPeerUDP
var _room: Dictionary = {}

func start_host(room: Dictionary, port: int = PORT) -> bool:
	if _listener != null:
		_listener.close()
	_listener = PacketPeerUDP.new()
	if _listener.bind(port, "0.0.0.0") != OK:
		_listener = null
		return false
	_room = room.duplicate(true)
	return true

func update_room(room: Dictionary) -> void:
	_room = room.duplicate(true)

func search(port: int = PORT, address: String = "255.255.255.255") -> void:
	if _searcher == null:
		_searcher = PacketPeerUDP.new()
		if _searcher.bind(0, "0.0.0.0") != OK:
			_searcher = null
			return
		_searcher.set_broadcast_enabled(true)
	if _searcher.set_dest_address(address, port) == OK:
		_searcher.put_packet(JSON.stringify({"marker":MARKER, "v":1, "type":"query"}).to_utf8_buffer())

func poll() -> void:
	if _listener != null:
		for _i in 32:
			if _listener.get_available_packet_count() <= 0:
				break
			var raw := _listener.get_packet()
			var sender_ip := _listener.get_packet_ip()
			var sender_port := _listener.get_packet_port()
			var message := _decode(raw)
			if message.get("type") == "query":
				var answer := _room.duplicate(true)
				answer.merge({"marker":MARKER, "v":1, "type":"room"}, true)
				if _listener.set_dest_address(sender_ip, sender_port) == OK:
					_listener.put_packet(JSON.stringify(answer).to_utf8_buffer())
	if _searcher != null:
		for _i in 32:
			if _searcher.get_available_packet_count() <= 0:
				break
			var raw := _searcher.get_packet()
			var sender_ip := _searcher.get_packet_ip()
			var message := _decode(raw)
			if message.get("type") != "room" or not message.get("name") is String or str(message.name).length() > 48:
				continue
			var port = message.get("port")
			if not port is float and not port is int:
				continue
			if float(port) != floor(float(port)) or int(port) < 1024 or int(port) > 65535:
				continue
			if not message.get("players") is float and not message.get("players") is int:
				continue
			if int(message.players) < 1 or int(message.players) > 4 or not message.get("open") is bool:
				continue
			message["address"] = sender_ip
			message["port"] = int(port)
			message["last_seen"] = Time.get_ticks_msec()
			var replaced := false
			for i in rooms.size():
				if rooms[i].address == sender_ip and int(rooms[i].port) == int(port):
					rooms[i] = message
					replaced = true
					break
			if not replaced and rooms.size() < 64:
				rooms.append(message)
	var fresh: Array = []
	for room in rooms:
		if Time.get_ticks_msec() - int(room.last_seen) < TTL_MS:
			fresh.append(room)
	rooms = fresh

func _decode(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty() or raw.size() > 4096:
		return {}
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary or parsed.size() > 12 or parsed.get("marker") != MARKER or parsed.get("v") != 1:
		return {}
	return parsed

func close() -> void:
	if _listener != null:
		_listener.close()
	if _searcher != null:
		_searcher.close()
	_listener = null
	_searcher = null
	rooms = []
