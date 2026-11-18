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
const DataScript = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Discovery = preload("res://scripts/LanDiscovery.gd")
const Design = preload("res://scripts/HouseDesign.gd")
const Infrastructure = preload("res://scripts/Infrastructure.gd")
const Economy = preload("res://scripts/ProvinceEconomy.gd")
const Naval = preload("res://scripts/NavalTransport.gd")
const ProductionReport = preload("res://scripts/ProductionNetworkReport.gd")
const TIMEOUT_MS := 8000
# Tatsächlicher Fingerabdruck der veröffentlichten 1.9.0-Definitionen.
# Der damalige Algorithmus band Ereignisse/Forschung, jedoch noch nicht FIELDS.
# Ausschließlich lokale Dateien dürfen diesen historischen Wert verwenden.
const LOCAL_UI_190_FINGERPRINT := "ca7c50860f0e76f19153a6f985117ac8de7277a0f3559ecdcba692077aebf500"
# Tatsächlich gespeicherter Fingerabdruck der ausgeführten Gameplay-EXE.
# Herkunft: tests/fixtures/lan-191-gameplay-schema14-provenance.json.
# Ausschließlich lokale Dateien; der Peer-Handshake bleibt unverändert strikt.
const LOCAL_GAMEPLAY_191_FINGERPRINT := "fcc2237b4e44b454f78a0a0721cc10ca7167289ec3c8d01ae49a455b2c98c9d3"
# Genuine context schema14 file and immutable packaged-run provenance.
# Local migration only; network handshakes never recognize old identities.
const LOCAL_CONTEXT_191_FINGERPRINT := "49efe0af83dff5e58b98eff1d9e2978a8200f835562ac0202da13b036ac884a6"
# Exact published naval15 bytes and packaged-run provenance live in
# tests/fixtures/lan-191-naval-schema15-{original,provenance}.json.
# This identity authorizes local backup/migration only, never a network peer.
const LOCAL_NAVAL_191_FINGERPRINT := "d1d986d4adf5714ae629f351b377f3f159d58b126f72ba3b62ca3fccbdd84582"
# Genuine published campaign/code18 and UI/code19 save family, copied before
# production changes. Exact package/bytes evidence accompanies the fixture.
const LOCAL_CAMPAIGN_191_FINGERPRINT := "dc8f13abb2f9b93c1aabfcf115f592df02c8af9ceb2b445127bdcefd22fd3903"
static var _cached_fingerprints: Dictionary = {}

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
var _lobby_catalog: Array = []
var _lobby_resuming := false

func _init(data_script = null, fingerprint_override: String = "") -> void:
	_data = data_script if data_script != null else DataScript
	_app = str(ProjectSettings.get_setting("application/config/version", ""))
	_fingerprint = fingerprint_override if fingerprint_override != "" else _content_fingerprint()

func _content_fingerprint() -> String:
	var route_fingerprint: String = Naval.shared_routes().fingerprint()
	if route_fingerprint.is_empty():
		return ""
	var campaign_rules := _field_campaign_rules()
	var production_rules := _production_rules()
	var identity := {"schema":Save.CURRENT_VERSION,"protocol":Protocol.VERSION,
		"commands":Protocol.FIELDS,"naval":Naval.RULES,"campaign":campaign_rules,
		"production":production_rules,"innovations":Infrastructure.INNOVATIONS,
		"province_economy":{"foci":Economy.FOCI,"lock_months":Economy.LOCK_MONTHS}}
	var cache_key := str(_data.resource_path)+"|"+route_fingerprint+"|"+JSON.stringify(Save.canonical(identity))
	if _cached_fingerprints.has(cache_key):
		return str(_cached_fingerprints[cache_key])
	var content := {"schema":Save.CURRENT_VERSION, "protocol":Protocol.VERSION,
		"houses":_data.houses(), "provinces":_data.provinces(), "adjacency":_data.adjacency(),
		"events":_data.events(), "innovations":Infrastructure.INNOVATIONS, "commands":Protocol.FIELDS,
		"province_economy":{"foci":Economy.FOCI,"lock_months":Economy.LOCK_MONTHS},
		"naval_transport":{"rules":Naval.RULES,"route_fingerprint":route_fingerprint},
		"field_campaign":campaign_rules,"production":production_rules}
	for path in ["res://data/atlas.json", "res://data/atlas_geometry.bin", "res://data/europe_geometry.json"]:
		var digest := FileAccess.get_sha256(path)
		if digest == "":
			return ""
		content[path] = digest
	if _data.has_method("catalog_hash"):
		content["regions"] = _data.catalog_hash()
	_cached_fingerprints[cache_key] = JSON.stringify(Save.canonical(content)).sha256_text()
	return str(_cached_fingerprints[cache_key])

func _field_campaign_rules() -> Dictionary:
	# Resolve at call time: previews depend on Game at runtime, not through a
	# Save/LAN preload cycle. Every returned rule set participates in the cache.
	return {"siege":load("res://scripts/SiegeRules.gd").RULES,
		"battle":load("res://scripts/FieldBattleRules.gd").RULES,
		"recovery":load("res://scripts/ArmyRecovery.gd").RULES,
		"planner":load("res://scripts/NavalCampaign.gd").RULES,
		"army_limits":{"strength":Save.MAX_ARMY_STRENGTH,"upkeep":Save.MAX_ARMY_UPKEEP}}

func _production_rules() -> Dictionary:
	return {"regional":load("res://scripts/RegionalProduction.gd").RULES,
		"transport":load("res://scripts/MaterialTransport.gd").RULES,
		"depot":load("res://scripts/DepotSupply.gd").RULES,
		"economy_planner":load("res://scripts/EconomyPlanner.gd").RULES,
		"network_report":ProductionReport.RULES,
		"snapshot_fields":Protocol.SNAPSHOT_FIELDS,
		"legacy_research_durations":Infrastructure.LEGACY_RESEARCH_DURATIONS,
		"game":GameScript.PRODUCTION_RULES}

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

func house_catalog() -> Array:
	if not is_host and not _lobby_catalog.is_empty():
		return _lobby_catalog.duplicate(true)
	var result: Array = []
	var source: Array = game.houses if game != null else _data.houses()
	for index in source.size():
		result.append({"id":index, "name":str(source[index].name), "ruler":str(source[index].ruler.name), "selectable":not is_resuming() or game.human_houses.has(index)})
	return result

func is_resuming() -> bool:
	return not _resume_state.is_empty() if is_host else _lobby_resuming

func submit_design(profile: Dictionary) -> Dictionary:
	if phase != "lobby" or is_resuming():
		return _failure("Eigene Häuser können nur vor einer neuen Partie gestaltet werden.")
	var checked: Dictionary = Design.validate(profile, _data)
	if not checked.ok:
		return _failure(checked.message)
	if is_host:
		return _set_design(1, checked.profile)
	return _send_request({"type":"design", "profile":checked.profile})

func clear_design() -> Dictionary:
	if phase != "lobby" or is_resuming():
		return _failure("Der Hausentwurf ist in dieser Phase gesperrt.")
	if is_host:
		return _set_design(1, {})
	return _send_request({"type":"design", "profile":{}})

func _design_conflict(peer: int, profile: Dictionary, chosen_house: int = -1) -> String:
	var original_owner := {}
	for province in _data.provinces():
		original_owner[str(province.id)] = int(province.owner)
	var own_house: int = int(players[peer].house) if chosen_house < 0 else chosen_house
	for other in players:
		if int(other) == peer:
			continue
		var draft: Dictionary = players[other].get("design", {})
		if not profile.is_empty():
			if not draft.is_empty() and draft.province == profile.province:
				return "Diese Heimatregion ist bereits für ein anderes eigenes Haus reserviert."
			if draft.is_empty() and int(original_owner.get(profile.province, -1)) == int(players[other].house):
				return "Diese Region gehört zum Startreich eines anderen menschlichen Spielers."
		elif not draft.is_empty() and int(original_owner.get(draft.province, -1)) == own_house:
			return "In diesem Startreich ist bereits die Heimat eines eigenen Spielerhauses reserviert."
	return ""

func _set_design(peer: int, profile: Dictionary) -> Dictionary:
	if phase != "lobby" or is_resuming() or not players.has(peer):
		return _failure("Hausentwürfe sind nur in einer neuen Lobby veränderbar.")
	var clean := {}
	if not profile.is_empty():
		var checked: Dictionary = Design.validate(profile, _data)
		if not checked.ok:
			return _failure(checked.message)
		clean = checked.profile
	var conflict := _design_conflict(peer, clean)
	if conflict != "":
		return _failure(conflict)
	players[peer]["design"] = clean.duplicate(true)
	players[peer].ready = peer == 1
	_broadcast_lobby()
	return _success("Hausentwurf angenommen." if not clean.is_empty() else "Vorhandenes Haus ausgewählt.")

func choose_house(house: int) -> Dictionary:
	if phase != "lobby" or house < 0 or house >= house_catalog().size():
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
		var ordered: Array = players.keys()
		ordered.sort()
		# Erst sämtliche Entwürfe prüfen; bei Ablehnung bleibt die Lobby erhalten.
		for id in ordered:
			var profile: Dictionary = players[id].get("design", {})
			if not profile.is_empty():
				var checked: Dictionary = Design.validate(profile, _data)
				if not checked.ok or _design_conflict(int(id), profile) != "":
					game = null
					return _failure("Ein Hausentwurf oder seine Heimat ist nicht mehr gültig.")
		for id in ordered:
			var profile: Dictionary = players[id].get("design", {})
			if not profile.is_empty():
				game._custom_start(profile)
				game.house().ruler.portrait = int(profile.portrait)
				game.house()["doctrine"] = str(profile.doctrine)
				players[id].house = game.player
		houses.clear()
		seats.clear()
		for id in ordered:
			houses.append(int(players[id].house))
			seats[int(id)] = int(players[id].house)
		if not game.configure_human_houses(houses):
			return _failure("Die Menschenhäuser konnten nicht eingerichtet werden.")
		game.select_player_context(int(players[1].house))
		# Die neue ID-Zuordnung muss vor dem ersten persönlichen Snapshot ankommen.
		_broadcast_lobby()
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
	if not _valid_host_save(state):
		return _failure("Der WLAN-Spielstand enthält keine gültige gemeinsame Partie.")
	var envelope := {"kind":"BQ-LAN-SAVE", "v":Protocol.VERSION, "app":_app, "fingerprint":_fingerprint, "state":state}
	var raw := Protocol.encode_packet(envelope)
	if raw.is_empty():
		return _failure("Der WLAN-Spielstand ist zu groß.")
	var protected := _protect_save_target(path)
	if not protected.ok:
		return protected
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _failure("WLAN-Spielstand konnte nicht gespeichert werden.")
	file.store_buffer(raw)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _failure("WLAN-Spielstand konnte nicht vollständig geschrieben werden.")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		return _failure("WLAN-Spielstand konnte nicht vollständig gespeichert werden.")
	_set_status("WLAN-Partie gespeichert.")
	return _success("WLAN-Partie gespeichert.")

func _valid_host_save(state: Dictionary) -> bool:
	return Save.validate(state).is_empty() and state.get("lan_human_houses") is Array and state.lan_human_houses.size() >= 2 and not state.has("lan_projection") and game._valid_lan_state(state)

func _protect_save_target(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _success()
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > Protocol.MAX_PACKET_BYTES:
		return _failure("Das vorhandene WLAN-Speicherziel kann nicht sicher geprüft werden.")
	var original := file.get_buffer(file.get_length())
	file.close()
	var parser := JSON.new()
	if parser.parse(original.get_string_from_utf8()) != OK:
		return _failure("Das vorhandene Speicherziel ist beschädigt und bleibt erhalten.")
	var envelope = parser.data
	if not envelope is Dictionary or envelope.get("kind") != "BQ-LAN-SAVE" or not envelope.get("state") is Dictionary:
		return _failure("Das vorhandene Speicherziel ist beschädigt oder unbekannt und bleibt erhalten.")
	var normalized: Dictionary = Save.migrate(envelope.state)
	if not normalized.ok or not _valid_host_save(normalized.data):
		return _failure("Die vorhandene WLAN-Datei ist ungültig und bleibt erhalten.")
	var current_schema := Protocol.integer(envelope.state.get("schema_version"),Save.CURRENT_VERSION,Save.CURRENT_VERSION)
	if current_schema and Protocol.handshake_error(envelope,_app,_fingerprint).is_empty():
		return _success()
	# Both local paths identify exactly the same historical sources. Unknown
	# targets remain untouched even if their JSON can otherwise migrate.
	if envelope.get("fingerprint") == _fingerprint:
		return _failure("Fingerabdruck und vorhandenes Speicherformat widersprechen sich.")
	var matching_catalog: bool = _data.has_method("catalog_hash") and str(envelope.state.get("world_layout","")) == "regions108" and str(envelope.state.get("region_catalog_hash","")) == _data.catalog_hash()
	var suffix := _local_legacy_backup_suffix(envelope,matching_catalog)
	if suffix.is_empty():
		return _failure("Das vorhandene WLAN-Speicherformat ist unbekannt und bleibt erhalten.")
	return _ensure_local_backup(path,original,suffix)

func _is_previous_gameplay_file(envelope: Dictionary, matching_catalog: bool) -> bool:
	return _app == "1.9.1" and Save.CURRENT_VERSION >= 14 and str(envelope.get("app", "")) == "1.9.1" and matching_catalog and Protocol.integer(envelope.get("v"), 3, 3) and Protocol.integer(envelope.state.get("schema_version"), 14, 14) and envelope.get("fingerprint") == LOCAL_GAMEPLAY_191_FINGERPRINT

func _local_legacy_backup_suffix(envelope: Dictionary, matching_catalog: bool) -> String:
	var file_app := str(envelope.get("app",""))
	if _data.has_method("catalog_hash") and Protocol.integer(envelope.get("v"),1,1) and file_app.begins_with("1.7.") and str(envelope.state.get("world_layout","")) != "regions108":
		return ".pre-regions-v1.bak"
	if _app == "1.9.1" and Save.CURRENT_VERSION >= 14 and file_app in ["1.9.0","1.9.1"] and matching_catalog and Protocol.integer(envelope.get("v"),3,3) and Protocol.integer(envelope.state.get("schema_version"),13,13) and envelope.get("fingerprint") == LOCAL_UI_190_FINGERPRINT:
		return ".pre-ui191.bak" if file_app == "1.9.0" else ".pre-economy-schema13.bak"
	if _is_previous_gameplay_file(envelope,matching_catalog):
		return ".pre-choice-guards-v14.bak"
	if _app == "1.9.1" and Save.CURRENT_VERSION >= 15 and file_app == "1.9.1" and matching_catalog and Protocol.integer(envelope.get("v"),3,3) and Protocol.integer(envelope.state.get("schema_version"),14,14) and envelope.get("fingerprint") == LOCAL_CONTEXT_191_FINGERPRINT:
		return ".pre-naval-schema14.bak"
	if _app == "1.9.1" and Save.CURRENT_VERSION >= 16 and file_app == "1.9.1" and matching_catalog and Protocol.integer(envelope.get("v"),3,3) and Protocol.integer(envelope.state.get("schema_version"),15,15) and envelope.get("fingerprint") == LOCAL_NAVAL_191_FINGERPRINT:
		return ".pre-campaign-schema15.bak"
	if _app == "1.9.1" and Save.CURRENT_VERSION >= 17 and file_app == "1.9.1" and matching_catalog and Protocol.integer(envelope.get("v"),3,3) and Protocol.integer(envelope.state.get("schema_version"),16,16) and envelope.get("fingerprint") == LOCAL_CAMPAIGN_191_FINGERPRINT:
		return ".pre-production-schema16.bak"
	# 13/14 are source versions actually supported by the earlier regional
	# family; increasing our target schema must not extend this source range.
	if matching_catalog and file_app.begins_with("1.8.") and Protocol.integer(envelope.get("v"),2,Protocol.VERSION) and Protocol.integer(envelope.state.get("schema_version"),13,14):
		return ".pre-design-v%d.bak" % int(envelope.v)
	return ""

func _ensure_local_backup(path: String, original: PackedByteArray, suffix: String) -> Dictionary:
	var backup := path+suffix
	if FileAccess.file_exists(backup) and FileAccess.get_file_as_bytes(backup) != original:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(original)
		backup = path+".pre-regions-"+context.finish().hex_encode().substr(0,16)+".bak"
	if not FileAccess.file_exists(backup):
		var copy := FileAccess.open(backup,FileAccess.WRITE)
		if copy == null:
			return _failure("Die alte WLAN-Zieldatei konnte nicht gesichert werden.")
		copy.store_buffer(original)
		copy.flush()
		var error := copy.get_error()
		copy.close()
		if error != OK:
			return _failure("Die Sicherung der WLAN-Zieldatei wurde nicht vollständig geschrieben.")
	if FileAccess.get_file_as_bytes(backup) != original:
		return _failure("Die Sicherung der WLAN-Zieldatei ist nicht bytegleich.")
	return _success()

func load_host_lobby(path: String = "user://lan_partie.json") -> Dictionary:
	if not is_host or phase != "lobby":
		return _failure("WLAN-Spielstände können nur in einer geöffneten Gastgeberlobby geladen werden.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Protocol.MAX_PACKET_BYTES:
		return _failure("WLAN-Spielstand fehlt oder ist zu groß.")
	var original_bytes := file.get_buffer(file.get_length())
	var envelope = JSON.parse_string(original_bytes.get_string_from_utf8())
	file.close()
	if not envelope is Dictionary or envelope.get("kind") != "BQ-LAN-SAVE" or not envelope.get("state") is Dictionary:
		return _failure("Der WLAN-Spielstand ist beschädigt.")
	var error := Protocol.handshake_error(envelope, _app, _fingerprint)
	# Local file migration only. Old network peers still fail the handshake.
	var file_app := str(envelope.get("app", ""))
	var current_schema := Protocol.integer(envelope.state.get("schema_version"),Save.CURRENT_VERSION,Save.CURRENT_VERSION)
	# A current fingerprint cannot truthfully identify an old app/schema/wire.
	if envelope.get("fingerprint") == _fingerprint and (file_app != _app or not current_schema or not Protocol.integer(envelope.get("v"),Protocol.VERSION,Protocol.VERSION)):
		return _failure("Fingerabdruck und angegebenes Spielstandformat widersprechen sich.")
	var matching_catalog: bool = _data.has_method("catalog_hash") and str(envelope.state.get("world_layout","")) == "regions108" and str(envelope.state.get("region_catalog_hash","")) == _data.catalog_hash()
	var suffix := _local_legacy_backup_suffix(envelope,matching_catalog)
	if not current_schema and suffix.is_empty():
		return _failure("Das ältere WLAN-Spielstandformat besitzt keinen belegten Migrationspfad.")
	if error != "" and suffix.is_empty():
		return _failure(error)
	var restored = GameScript.new(_data, 0)
	if not restored.restore(envelope.state) or restored.human_houses.size() < 2:
		return _failure("Der WLAN-Spielstand enthält keine gültige gemeinsame Partie.")
	if not suffix.is_empty():
		var protected := _ensure_local_backup(path,original_bytes,suffix)
		if not protected.ok:
			return protected
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
		players[id].erase("design")
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
	_lobby_catalog = []
	_lobby_resuming = false
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
			if Protocol.integer(message.get("house"), 0, house_catalog().size() - 1):
				var result := _choose_house(id, int(message.house))
				if not result.ok:
					_send(id, {"type":"notice", "text":result.message})
			else:
				_reject(id, "Ungültige Hausauswahl.")
		"design":
			if not message.get("profile") is Dictionary:
				_reject(id, "Ungültiger Hausentwurf.")
				return
			var result := _set_design(id, message.profile)
			_send(id, {"type":"notice", "text":result.message})
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
	if is_resuming() and not _expected_houses.has(house):
		return _failure("Bitte ein gespeichertes Menschenhaus wählen.")
	if not is_resuming():
		var conflict := _design_conflict(id, players[id].get("design", {}), house)
		if conflict != "":
			return _failure(conflict)
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
	for house in house_catalog().size():
		if not used.has(house):
			return house
	return -1

func _broadcast_lobby() -> void:
	var serialized: Dictionary = {}
	for id in players:
		serialized[str(id)] = players[id].duplicate(true)
	for id in players:
		if int(id) != 1:
			_send(int(id), {"type":"lobby", "players":serialized, "houses":house_catalog(), "resuming":is_resuming()})
	_update_discovery()
	lobby_changed.emit()

func _receive_lobby(message: Dictionary) -> void:
	var catalog = message.get("houses")
	if not catalog is Array or catalog.size() < _data.houses().size() or catalog.size() > _data.houses().size() + 4 or not message.get("resuming") is bool:
		_disconnected("Ungültiger Hauskatalog in der WLAN-Lobby.")
		return
	for index in catalog.size():
		var entry = catalog[index]
		if not entry is Dictionary or not Protocol.integer(entry.get("id"), index, index) or not entry.get("name") is String or not _valid_name(entry.name, 48) or not entry.get("ruler") is String or not _valid_name(entry.ruler, 48) or not entry.get("selectable") is bool:
			_disconnected("Ungültiges Haus im WLAN-Katalog.")
			return
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
		if not seat.get("name") is String or not _valid_name(seat.name, 32) or not seat.get("ready") is bool or not Protocol.integer(seat.get("house"), 0, catalog.size() - 1):
			_disconnected("Ungültige WLAN-Spielerdaten.")
			return
		var house := int(seat.house)
		if occupied.has(house):
			_disconnected("Doppelte Häuser in der WLAN-Lobby.")
			return
		occupied.append(house)
		var draft = seat.get("design", {})
		if not draft is Dictionary or (not draft.is_empty() and not Design.validate(draft, _data).ok):
			_disconnected("Ungültiger bestätigter Hausentwurf.")
			return
		next[int(key)] = {"name":str(seat.name), "house":house, "ready":bool(seat.ready), "design":draft.duplicate(true)}
	if not next.has(1) or not next.has(local_peer_id):
		_disconnected("Der eigene Sitz fehlt in der WLAN-Lobby.")
		return
	players = next
	_lobby_catalog = catalog.duplicate(true)
	_lobby_resuming = bool(message.resuming)
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
		var report: Dictionary=ProductionReport.pack(game._last_production,state)
		if report.is_empty():
			_set_status("Produktionsbericht konnte nicht vollständig geprüft werden.")
			return
		_send(int(id), {"type":"snapshot", "revision":revision, "hash":Protocol.world_hash(state), "state":state, "missing_peer":_missing_peer, "all_over":all_houses_over,"production_report":report})
	_update_discovery()

func _receive_snapshot(message: Dictionary) -> void:
	if not Protocol.valid_snapshot_frame(message):
		_set_status("Ungültiger vollständiger WLAN-Berichtsrahmen.")
		return
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
	var report: Dictionary=ProductionReport.normalize(message.production_report,state)
	if not bool(report.ok):
		_set_status("Ungültiger Produktionsbericht: "+str(report.reason))
		return
	next._last_production=report.data
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
