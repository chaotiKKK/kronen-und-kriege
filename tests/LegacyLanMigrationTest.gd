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
	print("LEGACYLANMIGRATIONTEST OK: %d Prüfungen" % checks)
	get_tree().quit(0)

func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		return true
	print("LEGACYLANMIGRATIONTEST FAIL: " + message)
	get_tree().quit(1)
	return false
