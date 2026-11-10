extends Node
## Privater ENet-Kanal. Keine SceneTree-RPCs, Spawns oder Objektdekodierung.

signal lobby_changed
signal game_started
signal game_updated
signal status_changed
signal command_finished(result: Dictionary)

const Protocol = preload("res://scripts/LanProtocol.gd")
const Authority = preload("res://scripts/LanAuthority.gd")
const GameScript = preload("res://scripts/Game.gd")
const DataScript = preload("res://scripts/Data.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Discovery = preload("res://scripts/LanDiscovery.gd")
const TIMEOUT_MS := 8000
static var _cached_fingerprint := ""

var phase := "idle"
var is_host := false
var game = null
var players: Dictionary = {}
var local_peer_id := 0
var status := ""
var game_port := Protocol.GAME_PORT
var discovery_enabled := true
var discovered_rooms: Array = []
var pending_command := false
var revision := 0
var all_houses_over := false
var _data
var _fingerprint := ""
var _app := ""
var _transport: SceneMultiplayer
var _peer: ENetMultiplayerPeer
var _discovery
var _authority
var _room_name := ""
var _player_name := ""
var _last_seen: Dictionary = {}
var _closing_peers: Dictionary = {}
var _last_heartbeat := 0
var _connect_started := 0
var _sequence := 0
var _pending_sequence := 0
var _pending_started := 0
var _accum := 0.0
var _missing_peer := false
var _resume_state: Dictionary = {}
var _expected_houses: Array = []
var _discovered_digest := ""
var _packet_count: Dictionary = {}
var _packet_second := -1

func _init(data_script = null, fingerprint_override: String = "") -> void:
	_data = data_script if data_script != null else DataScript
	_app = str(ProjectSettings.get_setting("application/config/version", ""))
	_fingerprint = fingerprint_override if fingerprint_override != "" else _content_fingerprint()

func _content_fingerprint() -> String:
	if _cached_fingerprint != "":
		return _cached_fingerprint
	var content := {"schema":Save.CURRENT_VERSION, "protocol":Protocol.VERSION,
		"houses":_data.houses(), "provinces":_data.provinces(), "adjacency":_data.adjacency()}
	for path in ["res://data/atlas.json", "res://data/atlas_geometry.bin", "res://data/europe_geometry.json"]:
		var digest := FileAccess.get_sha256(path)
		if digest == "":
			return ""
		content[path] = digest
	_cached_fingerprint = JSON.stringify(Save.canonical(content)).sha256_text()
	return _cached_fingerprint

func _new_transport() -> void:
	_transport = SceneMultiplayer.new()
	_transport.allow_object_decoding = false
	_transport.server_relay = false
	_transport.root_path = get_path()
	_transport.peer_connected.connect(_peer_connected)
	_transport.peer_disconnected.connect(_peer_disconnected)
	_transport.connected_to_server.connect(_connected_to_server)
	_transport.connection_failed.connect(func(): _disconnected("Verbindung zum Gastgeber fehlgeschlagen. IP-Adresse und WLAN prüfen."))
	_transport.server_disconnected.connect(func(): _disconnected("Die Verbindung zum Gastgeber wurde beendet."))
	_transport.peer_packet.connect(_receive_packet)
	_peer = ENetMultiplayerPeer.new()

func host(room_name: String, player_name: String, house: int, port: int = -1) -> Dictionary:
	if not _valid_name(room_name, 48) or not _valid_name(player_name, 32) or house < 0 or house >= _data.houses().size():
		return _failure("Bitte Raum, Spielernamen und ein gültiges Haus wählen.")
	if _fingerprint == "":
		return _failure("Die vollständigen Spieldaten fehlen. Bitte die vollständige Fassung verwenden.")
	var requested_port := Protocol.GAME_PORT if port == -1 else port
	if requested_port < 1024 or requested_port > 65535:
		return _failure("Ungültiger WLAN-Spielport.")
	close_session()
	_new_transport()
	var error := _peer.create_server(requested_port, Protocol.MAX_PLAYERS - 1, 1)
	if error != OK:
		_reset_transport()
		return _failure("Der Spielport ist belegt oder nicht verfügbar. Anderen Port wählen.")
	_transport.multiplayer_peer = _peer
	is_host = true
	local_peer_id = 1
	game_port = requested_port
	_room_name = room_name.strip_edges()
	_player_name = player_name.strip_edges()
	players = {1:{"name":_player_name, "house":house, "ready":true}}
	phase = "lobby"
	if discovery_enabled:
		_ensure_discovery()
		_discovery.start_host(_room_info())
	_set_status("WLAN-Lobby geöffnet. Gäste können über die IP-Adresse beitreten.")
	lobby_changed.emit()
	return _success()

func join(address: String, player_name: String, port: int = -1) -> Dictionary:
	if not address.strip_edges().is_valid_ip_address() or not _valid_name(player_name, 32):
		return _failure("Bitte eine gültige IP-Adresse und einen Spielernamen eingeben.")
	if _fingerprint == "":
		return _failure("Die vollständigen Spieldaten fehlen. Bitte die vollständige Fassung verwenden.")
	var requested_port := Protocol.GAME_PORT if port == -1 else port
	if requested_port < 1024 or requested_port > 65535:
		return _failure("Ungültiger WLAN-Spielport.")
	close_session()
	_new_transport()
	var error := _peer.create_client(address.strip_edges(), requested_port, 1)
	if error != OK:
		_reset_transport()
		return _failure("Verbindung konnte nicht geöffnet werden.")
	_transport.multiplayer_peer = _peer
	game_port = requested_port
	_player_name = player_name.strip_edges()
	phase = "connecting"
	_connect_started = Time.get_ticks_msec()
	_set_status("Verbindung zum Gastgeber wird hergestellt …")
	return _success()

func local_house() -> int:
	return int(players[local_peer_id].house) if players.has(local_peer_id) else -1

func choose_house(house: int) -> Dictionary:
	if phase != "lobby" or house < 0 or house >= _data.houses().size():
		return _failure("In dieser Phase kann kein Haus gewählt werden.")
	if is_host:
		return _choose_house(1, house)
	return _send_request({"type":"house", "house":house})

func set_ready(value: bool) -> Dictionary:
	if phase != "lobby":
		return _failure("Bereitschaft kann nur in der Lobby geändert werden.")
	if is_host:
		players[1].ready = value
		_broadcast_lobby()
		return _success()
	return _send_request({"type":"ready", "ready":value})

func start_match() -> Dictionary:
	if not is_host or phase != "lobby":
		return _failure("Nur der Gastgeber kann die Lobby starten.")
	if players.size() < 2 or players.size() > 4:
		return _failure("Zum Spielen werden zwei bis vier Personen benötigt.")
	var seats: Dictionary = {}
	var houses: Array = []
	for id in players:
		var seat: Dictionary = players[id]
		if not bool(seat.ready) or houses.has(int(seat.house)):
			return _failure("Alle Personen müssen bereit sein und verschiedene Häuser wählen.")
		houses.append(int(seat.house))
		seats[int(id)] = int(seat.house)
	if not _resume_state.is_empty():
		var expected := _expected_houses.duplicate()
		expected.sort()
		var chosen := houses.duplicate()
		chosen.sort()
		if expected != chosen:
			return _failure("Zur Fortsetzung müssen alle gespeicherten Menschenhäuser wieder besetzt sein.")
		game = GameScript.new(_data, int(players[1].house))
		if not game.restore(_resume_state):
			return _failure("Der gespeicherte WLAN-Spielstand ist beschädigt.")
		game.select_player_context(int(players[1].house))
	else:
		game = GameScript.new(_data, int(players[1].house))
		if not game.configure_human_houses(houses):
			return _failure("Die Menschenhäuser konnten nicht eingerichtet werden.")
	game.speed = 0
	_authority = Authority.new(game, seats)
	all_houses_over = game.all_human_houses_over()
	_expected_houses = game.human_houses.duplicate()
	_missing_peer = false
	_accum = 0.0
	_sequence = 0
	phase = "playing"
	revision += 1
	_broadcast_snapshot()
	_set_status("WLAN-Partie gestartet. Die gemeinsame Zeit ist pausiert.")
	game_started.emit()
	return _success()

func submit(command: Dictionary) -> Dictionary:
	if phase != "playing" or game == null:
		return _failure("Es läuft keine WLAN-Partie.")
	if _missing_peer:
		return _failure("Ein Spieler fehlt. Bitte zuerst gemeinsam in die Lobby zurückkehren.")
	var validated := Protocol.validate_command(command)
	if not validated.ok:
		return validated
	if is_host:
		_sequence += 1
		return _execute(1, _sequence, validated.command)
	if pending_command:
		return _failure("Der vorherige Spielbefehl wird noch bestätigt.", "pending")
	_sequence += 1
	_pending_sequence = _sequence
	pending_command = true
	_pending_started = Time.get_ticks_msec()
	var sent := _send_request({"type":"command", "sequence":_sequence, "command":validated.command})
	if not sent.ok:
		pending_command = false
	return sent

func needs_lobby_return() -> bool:
	return phase == "playing" and _missing_peer

func return_to_lobby() -> Dictionary:
	if not is_host or phase != "playing" or game == null:
		return _failure("Nur der Gastgeber kann eine laufende Partie in die Lobby führen.")
	game.speed = 0
	_resume_state = game.snapshot()
	_expected_houses = game.human_houses.duplicate()
	phase = "lobby"
	_authority = null
	_missing_peer = false
	_accum = 0.0
	for id in players:
		players[id].ready = int(id) == 1
	_broadcast_lobby()
	_set_status("Lobby zur Fortsetzung: Alle gespeicherten Menschenhäuser müssen besetzt sein.")
	return _success()

func save_host(path: String = "user://lan_partie.json") -> Dictionary:
	if not is_host or game == null or not phase in ["playing", "lobby"]:
		return _failure("Nur der Gastgeber kann die WLAN-Partie speichern.")
	var state: Dictionary = game.snapshot() if phase == "playing" else _resume_state
	if state.is_empty():
		return _failure("Es gibt noch keine WLAN-Partie zum Speichern.")
	var envelope := {"kind":"BQ-LAN-SAVE", "v":Protocol.VERSION, "app":_app, "fingerprint":_fingerprint, "state":state}
	var raw := Protocol.encode_packet(envelope)
	if raw.is_empty():
		return _failure("Der WLAN-Spielstand ist zu groß.")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("WLAN-Spielstand konnte nicht gespeichert werden.")
	file.store_buffer(raw)
	file.close()
	_set_status("WLAN-Partie gespeichert.")
	return _success("WLAN-Partie gespeichert.")

func load_host_lobby(path: String = "user://lan_partie.json") -> Dictionary:
	if not is_host or phase != "lobby":
		return _failure("WLAN-Spielstände können nur in einer geöffneten Gastgeberlobby geladen werden.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Protocol.MAX_PACKET_BYTES:
		return _failure("WLAN-Spielstand fehlt oder ist zu groß.")
	var envelope = JSON.parse_string(file.get_as_text())
	file.close()
	if not envelope is Dictionary or envelope.get("kind") != "BQ-LAN-SAVE" or not envelope.get("state") is Dictionary:
		return _failure("Der WLAN-Spielstand ist beschädigt.")
	var error := Protocol.handshake_error(envelope, _app, _fingerprint)
	if error != "":
		return _failure(error)
	var restored = GameScript.new(_data, 0)
	if not restored.restore(envelope.state) or restored.human_houses.size() < 2:
		return _failure("Der WLAN-Spielstand enthält keine gültige gemeinsame Partie.")
	game = restored
	game.speed = 0
	_resume_state = game.snapshot()
	_expected_houses = game.human_houses.duplicate()
	players[1].house = game.player
	var occupied: Array = [game.player]
	for id in players:
		if int(id) == 1:
			continue
		var selected := int(players[id].house)
		if occupied.has(selected) or not _expected_houses.has(selected):
			for house in _expected_houses:
				if not occupied.has(int(house)):
					selected = int(house)
					break
		players[id].house = selected
		players[id].ready = false
		occupied.append(selected)
	_broadcast_lobby()
	_set_status("WLAN-Spielstand geladen. Alle gespeicherten Häuser müssen wieder besetzt werden.")
	return _success()

func search_rooms() -> void:
	if not discovery_enabled:
		return
	_ensure_discovery()
	_discovery.search()
	_set_status("Suche nach WLAN-Lobbys … Direkte IP-Eingabe bleibt möglich.")

func close_session(reason: String = "") -> void:
	if _transport != null and _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if is_host:
			for id in _last_seen.keys():
				_send(int(id), {"type":"closed", "reason":reason if reason != "" else "Der Gastgeber hat die WLAN-Partie beendet."})
		else:
			_send(1, {"type":"leave"})
		if _peer.host != null:
			_peer.host.flush()
	_reset_transport()
	if _discovery != null:
		_discovery.close()
	_discovery = null
	discovered_rooms = []
	players = {}
	game = null
	_authority = null
	_resume_state = {}
	_expected_houses = []
	_missing_peer = false
	is_host = false
	local_peer_id = 0
	revision = 0
	_sequence = 0
	pending_command = false
	all_houses_over = false
	phase = "idle"
	if reason != "":
		_set_status(reason)

func _reset_transport() -> void:
	if _peer != null:
		_peer.close()
	if _transport != null:
		_transport.clear()
	_peer = null
	_transport = null
	_last_seen = {}
	_closing_peers = {}

func _disconnected(reason: String) -> void:
	_reset_transport()
	phase = "disconnected"
	pending_command = false
	if game != null:
		game.speed = 0
	_set_status(reason)
	lobby_changed.emit()

func _connected_to_server() -> void:
	if _transport == null:
		return
	local_peer_id = _transport.get_unique_id()
	_last_seen[1] = Time.get_ticks_msec()
	_send(1, {"type":"hello", "app":_app, "fingerprint":_fingerprint, "name":_player_name})

func _peer_connected(id: int) -> void:
	_last_seen[id] = Time.get_ticks_msec()

func _peer_disconnected(id: int) -> void:
	_last_seen.erase(id)
	_closing_peers.erase(id)
	if not is_host:
		if id == 1:
			_disconnected("Die Verbindung zum Gastgeber wurde unterbrochen.")
		return
	if not players.has(id):
		return
	var name := str(players[id].name)
	players.erase(id)
	if phase == "playing" and game != null:
		game.speed = 0
		_missing_peer = true
		revision += 1
		_broadcast_snapshot()
		_set_status("%s hat die Verbindung verloren. Die Partie pausiert; bitte in die Lobby zurückkehren." % name)
	else:
		_broadcast_lobby()
	lobby_changed.emit()

func _receive_packet(id: int, raw: PackedByteArray) -> void:
	if _closing_peers.has(id):
		return
	var second := int(Time.get_ticks_msec() / 1000)
	if second != _packet_second:
		_packet_count.clear()
		_packet_second = second
	_packet_count[id] = int(_packet_count.get(id, 0)) + 1
	if int(_packet_count[id]) > 80:
		_reject(id, "Zu viele Netzwerknachrichten. Bitte erneut beitreten.")
		return
	var decoded := Protocol.decode_packet(raw)
	if not decoded.ok:
		_reject(id, str(decoded.message))
		return
	var message: Dictionary = decoded.message
	if int(message.v) != Protocol.VERSION:
		_reject(id, "Die WLAN-Protokollversionen passen nicht zusammen.")
		return
	_last_seen[id] = Time.get_ticks_msec()
	var kind := str(message.type)
	if kind == "ping":
		_send(id, {"type":"pong"})
		return
	if kind == "pong":
		return
	if is_host:
		_receive_host(id, kind, message)
	elif id == 1:
		_receive_guest(kind, message)
	else:
		_disconnected("Unerwarteter Absender im WLAN-Kanal.")

func _receive_host(id: int, kind: String, message: Dictionary) -> void:
	if kind == "hello":
		if players.has(id):
			_reject(id, "Dieser Spieler ist bereits angemeldet.")
			return
		var error := Protocol.handshake_error(message, _app, _fingerprint)
		if error != "":
			_reject(id, error)
			return
		if phase != "lobby" or players.size() >= 4:
			_reject(id, "Diese WLAN-Partie läuft bereits oder die Lobby ist voll.")
			return
		if not message.get("name") is String or not _valid_name(message.name, 32):
			_reject(id, "Ungültiger Spielername.")
			return
		var house := _free_house()
		players[id] = {"name":str(message.name).strip_edges(), "house":house, "ready":false}
		_broadcast_lobby()
		return
	if not players.has(id):
		_reject(id, "Bitte zuerst mit passender Spielversion anmelden.")
		return
	match kind:
		"house":
			if Protocol.integer(message.get("house"), 0, _data.houses().size() - 1):
				var result := _choose_house(id, int(message.house))
				if not result.ok:
					_send(id, {"type":"notice", "text":result.message})
			else:
				_reject(id, "Ungültige Hausauswahl.")
		"ready":
			if phase == "lobby" and message.get("ready") is bool:
				players[id].ready = message.ready
				_broadcast_lobby()
		"command":
			if phase != "playing" or not Protocol.integer(message.get("sequence"), 1, 2147483647) or not message.get("command") is Dictionary:
				_reject(id, "Ungültiger Spielbefehl oder falsche Partiephase.")
				return
			var result: Dictionary = Protocol.failure("Ein Spieler fehlt. Bitte zuerst in die Lobby zurückkehren.") if _missing_peer else _execute(id, int(message.sequence), message.command)
			_send(id, {"type":"result", "sequence":int(message.sequence), "result":result})
		"leave":
			if _transport != null:
				_transport.disconnect_peer(id)
			_peer_disconnected(id)
		_:
			_reject(id, "Unbekannte WLAN-Nachricht.")

func _receive_guest(kind: String, message: Dictionary) -> void:
	match kind:
		"reject", "closed":
			var reason := str(message.get("reason", "Der Gastgeber hat die Verbindung beendet."))
			_disconnected(reason.substr(0, 512))
		"notice":
			_set_status(str(message.get("text", "")).substr(0, 512))
		"lobby":
			_receive_lobby(message)
		"snapshot":
			_receive_snapshot(message)
		"result":
			if pending_command and Protocol.integer(message.get("sequence"), _pending_sequence, _pending_sequence) and message.get("result") is Dictionary:
				pending_command = false
				command_finished.emit(message.result)
		_:
			_disconnected("Unbekannte Nachricht des Gastgebers.")

func _choose_house(id: int, house: int) -> Dictionary:
	if phase != "lobby" or not players.has(id):
		return _failure("Häuser können nur in der Lobby gewählt werden.")
	for other in players:
		if int(other) != id and int(players[other].house) == house:
			return _failure("Dieses Haus ist bereits besetzt.")
	players[id].house = house
	players[id].ready = id == 1
	_broadcast_lobby()
	return _success()

func _free_house() -> int:
	var used: Array = []
	for seat in players.values():
		used.append(int(seat.house))
	for house in _expected_houses:
		if not used.has(int(house)):
			return int(house)
	for house in _data.houses().size():
		if not used.has(house):
			return house
	return -1

func _broadcast_lobby() -> void:
	var serialized: Dictionary = {}
	for id in players:
		serialized[str(id)] = players[id].duplicate(true)
	for id in players:
		if int(id) != 1:
			_send(int(id), {"type":"lobby", "players":serialized})
	_update_discovery()
	lobby_changed.emit()

func _receive_lobby(message: Dictionary) -> void:
	var incoming = message.get("players")
	if not incoming is Dictionary or incoming.size() < 1 or incoming.size() > 4:
		_disconnected("Ungültige WLAN-Sitzliste.")
		return
	var next: Dictionary = {}
	var occupied: Array = []
	for key in incoming:
		var seat = incoming[key]
		if not key is String or not key.is_valid_int() or not Protocol.integer(int(key), 1, 2147483647) or not seat is Dictionary:
			_disconnected("Ungültiger WLAN-Spielersitz.")
			return
		if not seat.get("name") is String or not _valid_name(seat.name, 32) or not seat.get("ready") is bool or not Protocol.integer(seat.get("house"), 0, _data.houses().size() - 1):
			_disconnected("Ungültige WLAN-Spielerdaten.")
			return
		var house := int(seat.house)
		if occupied.has(house):
			_disconnected("Doppelte Häuser in der WLAN-Lobby.")
			return
		occupied.append(house)
		next[int(key)] = {"name":str(seat.name), "house":house, "ready":bool(seat.ready)}
	if not next.has(1) or not next.has(local_peer_id):
		_disconnected("Der eigene Sitz fehlt in der WLAN-Lobby.")
		return
	players = next
	phase = "lobby"
	_sequence = 0
	pending_command = false
	_set_status("Mit der WLAN-Lobby verbunden. Haus wählen und Bereitschaft setzen.")
	lobby_changed.emit()

func _execute(id: int, sequence: int, command: Dictionary) -> Dictionary:
	var result: Dictionary = _authority.execute(id, sequence, command)
	revision += 1
	_broadcast_snapshot()
	if id == 1:
		command_finished.emit(result)
	game_updated.emit()
	return result

func _broadcast_snapshot() -> void:
	if _authority == null or game == null:
		return
	all_houses_over = game.all_human_houses_over()
	for id in players:
		if int(id) == 1:
			continue
		var state: Dictionary = _authority.snapshot_for_peer(int(id))
		_sanitize_paths(state)
		_send(int(id), {"type":"snapshot", "revision":revision, "hash":Protocol.world_hash(state), "state":state, "missing_peer":_missing_peer, "all_over":all_houses_over})
	_update_discovery()

func _receive_snapshot(message: Dictionary) -> void:
	if not Protocol.integer(message.get("revision"), 1, 2147483647) or not message.get("state") is Dictionary or not message.get("hash") is String or not message.get("missing_peer") is bool or not message.get("all_over") is bool:
		_disconnected("Ungültiger WLAN-Spielstand.")
		return
	var next_revision := int(message.revision)
	if next_revision <= revision:
		return
	var state: Dictionary = message.state
	if int(state.get("player", -1)) != local_house() or state.has("lan_contexts") or Protocol.world_hash(state) != str(message.hash):
		_disconnected("Der WLAN-Spielstand gehört zu einem anderen Haus oder seine Prüfsumme stimmt nicht.")
		return
	_sanitize_paths(state)
	var next = GameScript.new(_data, local_house())
	if not next.restore(state) or Protocol.world_hash(next.snapshot()) != str(message.hash):
		_disconnected("Der WLAN-Spielstand ist beschädigt oder nicht kompatibel.")
		return
	var starting := phase != "playing"
	game = next
	revision = next_revision
	_missing_peer = bool(message.missing_peer)
	all_houses_over = bool(message.all_over)
	phase = "playing"
	if _missing_peer:
		_set_status("Ein Spieler hat die Verbindung verloren. Die Partie pausiert; bitte in die Lobby zurückkehren.")
	if starting:
		_sequence = 0
		pending_command = false
		_set_status("WLAN-Partie verbunden. Der Gastgeber steuert die gemeinsame Zeit.")
		game_started.emit()
	game_updated.emit()

func _sanitize_paths(state: Dictionary) -> void:
	for house in state.get("houses", []):
		if house is Dictionary:
			house.erase("crest_file")

func _reject(id: int, reason: String) -> void:
	if is_host:
		_send(id, {"type":"reject", "reason":reason.substr(0, 512)})
		_closing_peers[id] = Time.get_ticks_msec() + 200
	else:
		_disconnected(reason)

func _send(id: int, message: Dictionary) -> bool:
	if _transport == null or _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	# ENet can finish several disconnects in one poll. A different peer may
	# already be reset while SceneMultiplayer is still delivering the first
	# disconnect signal, so a cached lobby seat is not sufficient here.
	if not _transport.get_peers().has(id):
		return false
	var destination: ENetPacketPeer = _peer.get_peer(id)
	if destination == null or not destination.is_active() or destination.get_state() != ENetPacketPeer.STATE_CONNECTED or destination.get_channels() < 1:
		return false
	var packet := message.duplicate(true)
	packet["v"] = Protocol.VERSION
	var raw := Protocol.encode_packet(packet)
	return not raw.is_empty() and _transport.send_bytes(raw, id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0) == OK

func _send_request(message: Dictionary) -> Dictionary:
	return _success("Anfrage an Gastgeber gesendet.") if _send(1, message) else _failure("Die Verbindung zum Gastgeber ist nicht bereit.")

func _process(delta: float) -> void:
	if _discovery != null:
		_discovery.poll()
		discovered_rooms = _discovery.rooms.duplicate(true)
		var digest := JSON.stringify(discovered_rooms)
		if digest != _discovered_digest:
			_discovered_digest = digest
			status_changed.emit()
	if _transport == null or _peer == null:
		return
	var transport := _transport
	transport.poll()
	if _transport == null:
		return
	var now := Time.get_ticks_msec()
	if not is_host and pending_command and now - _pending_started > TIMEOUT_MS:
		_disconnected("Der Gastgeber hat den Spielbefehl nicht innerhalb von acht Sekunden bestätigt. Bitte erneut beitreten.")
		return
	for id in _closing_peers.keys():
		if now >= int(_closing_peers[id]):
			_transport.disconnect_peer(int(id))
			_peer_disconnected(int(id))
	for id in _last_seen.keys():
		if now - int(_last_seen[id]) > TIMEOUT_MS:
			if is_host:
				_transport.disconnect_peer(int(id))
				_peer_disconnected(int(id))
			else:
				_disconnected("Der Gastgeber antwortet nicht mehr. Die Verbindung wurde nach acht Sekunden beendet.")
				return
	if phase == "connecting" and now - _connect_started > TIMEOUT_MS:
		_disconnected("Zeitüberschreitung: Gastgeber nicht erreichbar. IP-Adresse und gemeinsames WLAN prüfen.")
		return
	if now - _last_heartbeat >= 1000:
		_last_heartbeat = now
		for id in _last_seen:
			_send(int(id), {"type":"ping"})
	if not is_host or phase != "playing" or game == null or _missing_peer or game.speed <= 0 or game.has_pending_human_events() or game.all_human_houses_over():
		_accum = 0.0
		return
	_accum += delta
	var interval: float = [0.0, 1.4, 0.8, 0.35][clampi(game.speed, 0, 3)]
	if _accum >= interval:
		_accum = 0.0
		game.advance_month()
		revision += 1
		_broadcast_snapshot()
		game_updated.emit()

func _ensure_discovery() -> void:
	if _discovery == null:
		_discovery = Discovery.new()

func _room_info() -> Dictionary:
	return {"name":_room_name, "port":game_port, "players":players.size(), "open":phase == "lobby", "app":_app, "fingerprint":_fingerprint}

func _update_discovery() -> void:
	if _discovery != null and is_host:
		_discovery.update_room(_room_info())

func _valid_name(value: String, maximum: int) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= maximum and not "\n" in value and not "\r" in value

func _set_status(value: String) -> void:
	status = value
	status_changed.emit()

func _failure(message: String, code: String = "blocked") -> Dictionary:
	return Protocol.failure(message, code)

func _success(message: String = "") -> Dictionary:
	return {"ok":true, "code":"ok", "message":message, "delta":{}, "refresh":[]}

func _exit_tree() -> void:
	close_session()
