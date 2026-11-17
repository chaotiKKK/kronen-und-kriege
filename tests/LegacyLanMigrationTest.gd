extends Node
var checks := 0

func _ready() -> void:
	var old = load("res://scripts/Game.gd").new(load("res://scripts/Data.gd"), 0)
	old.configure_human_houses([0,1])
	var state: Dictionary = old.snapshot()
	state.schema_version = 12
	var envelope := {"kind":"BQ-LAN-SAVE","v":1,"app":"1.7.0","fingerprint":"old-layout","state":state}
	# Jeder Lauf besitzt seine eigene Altdatei und Sicherung. Eine vorhandene
	# Sicherung aus einem früheren Lauf muss unangetastet bleiben dürfen.
	var path := "user://legacy-lan-migration-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var raw := JSON.stringify(envelope)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	var session = load("res://scripts/LanSession.gd").new()
	session.discovery_enabled = false
	add_child(session)
	if not check(bool(session.host("Migration", "Host", 0, 48500 + OS.get_process_id() % 400).ok), "Eigene lokale Gastgeberlobby"):
		return
	var result: Dictionary = session.load_host_lobby(path)
	if not check(bool(result.ok), "Alte WLAN-Datei wird lokal migriert: " + str(result.message)):
		session.close_session()
		return
	if not check(session.game.provinces.size() == 108 and session.game.human_houses == [0,1], "Regionen und Menschenplätze erhalten"):
		return
	if not check(FileAccess.get_file_as_string(path + ".pre-regions-v1.bak") == raw, "Alte WLAN-Datei bytegleich gesichert"):
		return
	if not check(bool(session.save_host(path).ok), "Aktueller WLAN-Stand gespeichert"):
		return
	var current = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(int(current.v) == load("res://scripts/LanProtocol.gd").VERSION and current.state.region_catalog_hash.length() == 64, "Gespeicherte WLAN-Partie auf aktuellem Protokoll und Katalog"):
		return
	session.close_session()
	session.queue_free()
	if not _previous_ui_release():
		return
	print("LEGACYLANMIGRATIONTEST OK: %d Prüfungen" % checks)
	get_tree().quit(0)

func _previous_ui_release() -> bool:
	var data = load("res://scripts/GameRegionData.gd")
	var protocol = load("res://scripts/LanProtocol.gd")
	var design = load("res://scripts/HouseDesign.gd")
	var game = load("res://scripts/Game.gd").new(data, 0)
	var profile: Dictionary = design.defaults(data)
	profile.house = "Haus Vorher"
	profile.doctrine = "infantry"
	game._custom_start(profile)
	profile = design.defaults(data, str(data.provinces()[1].id))
	profile.house = "Haus Fortsetzung"
	profile.doctrine = "cavalry"
	game._custom_start(profile)
	game.configure_human_houses([9,10])
	game.select_player_context(9)
	game.house().gold = 321
	game.house().prestige = 77
	game.house().research.known = ["surveying"]
	game.speed = 0
	var state: Dictionary = game.snapshot()
	var session = load("res://scripts/LanSession.gd").new()
	session.discovery_enabled = false
	add_child(session)
	if not check(session._app == "1.9.1", "Vorversionstest läuft unter 1.9.1"):
		return false
	if not check(session.host("UI-Fortsetzung", "Host", 0, 48900 + OS.get_process_id() % 300).ok, "Eigene Gastgeberlobby für 1.9.0-Datei"):
		return false
	var path := "user://previous-ui-lan-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var envelope := {"kind":"BQ-LAN-SAVE","v":3,"app":"1.9.0","fingerprint":session._fingerprint,"state":state}
	var original := JSON.stringify(envelope).to_utf8_buffer()
	_write_bytes(path, original)
	if not check(not protocol.handshake_error(envelope, session._app, session._fingerprint).is_empty(), "1.9.0-Netzteilnehmer bleibt am Versionshandshake abgewiesen"):
		return false
	var result: Dictionary = session.load_host_lobby(path)
	if not check(result.ok, "Lokale 1.9.0-Partie wird unter 1.9.1 geladen: " + str(result.message)):
		session.close_session()
		return false
	if not check(session.game.houses.size() == 11 and session.game.human_houses == [9,10] and session.local_house() == 9, "Eigene Häuser und Menschenplätze bleiben erhalten"):
		return false
	if not check(protocol.world_hash(session.game.snapshot()) == protocol.world_hash(state) and session.game.house().gold == 321 and session.game.house().prestige == 77, "Gespeicherte Welt, Ressourcen und aktives Menschenhaus bleiben unverändert"):
		return false
	if not check(session.game.houses[9].doctrine == "infantry" and session.game.houses[10].doctrine == "cavalry" and session.game.house().research.known == ["surveying"], "Doktrinen und Forschungsstand bleiben erhalten"):
		return false
	if not check(FileAccess.get_file_as_bytes(path) == original and FileAccess.get_file_as_bytes(path + ".pre-ui191.bak") == original, "1.9.0-Datei und Sicherung bleiben bytegleich"):
		return false
	for variant in ["fingerprint", "catalog", "protocol", "future_app", "corrupt_state"]:
		var rejected := envelope.duplicate(true)
		match variant:
			"fingerprint": rejected.fingerprint = "andere-spieldaten"
			"catalog": rejected.state.region_catalog_hash = "anderer-katalog"
			"protocol": rejected.v = 2
			"future_app": rejected.app = "1.9.2"
			"corrupt_state": rejected.state.lan_human_houses = [9,9]
		var bad_path: String = path + "." + str(variant)
		_write_bytes(bad_path, JSON.stringify(rejected).to_utf8_buffer())
		if not check(not session.load_host_lobby(bad_path).ok, "Ungültige Vorversionsdatei bleibt abgewiesen: " + variant):
			return false
		if not check(protocol.world_hash(session.game.snapshot()) == protocol.world_hash(state), "Abgewiesene Datei verändert die bestehende Welt nicht: " + variant):
			return false
	if not check(session.save_host(path).ok, "Geladene Vorversionspartie wird aktuell gespeichert"):
		return false
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(saved.app == "1.9.1" and int(saved.v) == 3 and saved.fingerprint == session._fingerprint, "Neu gespeicherte Partie trägt 1.9.1 und unverändertes Protokoll 3"):
		return false
	if not check(FileAccess.get_file_as_bytes(path + ".pre-ui191.bak") == original, "Aktuelles Speichern erhält die bytegleiche 1.9.0-Sicherung"):
		return false
	session.close_session()
	session.queue_free()
	return true

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		return true
	print("LEGACYLANMIGRATIONTEST FAIL: " + message)
	get_tree().quit(1)
	return false
