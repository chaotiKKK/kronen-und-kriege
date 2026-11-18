extends Node
const Save = preload("res://scripts/SaveGame.gd")
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
	if not _previous_economy_release():
		return
	if not _previous_gameplay_release():
		return
	if not _previous_production_release():
		return
	print("LEGACYLANMIGRATIONTEST OK: %d Prüfungen" % checks)
	get_tree().quit(0)

func _previous_ui_release() -> bool:
	var protocol = load("res://scripts/LanProtocol.gd")
	var fixture := "res://tests/fixtures/lan-190-original.json"
	if not check(FileAccess.get_sha256(fixture) == "ff009fbd3bbbd94ea2c239b3fc4a06478dbf06eb6dee33ec74322cd5ea4822ba", "Unveränderte Datei aus der tatsächlichen alten 1.9.0-EXE"):
		return false
	var original := FileAccess.get_file_as_bytes(fixture)
	var envelope: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	var state: Dictionary = envelope.state
	var session = load("res://scripts/LanSession.gd").new()
	session.discovery_enabled = false
	add_child(session)
	if not check(session._app == "1.9.1", "Vorversionstest läuft unter 1.9.1"):
		return false
	if not check(session.host("UI-Fortsetzung", "Host", 0, 48900 + OS.get_process_id() % 300).ok, "Eigene Gastgeberlobby für 1.9.0-Datei"):
		return false
	var path := "user://previous-ui-lan-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_write_bytes(path, original)
	if not check(not protocol.handshake_error(envelope, session._app, session._fingerprint).is_empty(), "1.9.0-Netzteilnehmer bleibt am Versionshandshake abgewiesen"):
		return false
	var result: Dictionary = session.load_host_lobby(path)
	if not check(result.ok, "Lokale 1.9.0-Partie wird unter 1.9.1 geladen: " + str(result.message)):
		session.close_session()
		return false
	if not check(session.game.houses.size() == 11 and session.game.human_houses == [9,10] and session.local_house() == 9, "Eigene Häuser und Menschenplätze bleiben erhalten"):
		return false
	if not check(_without_economy(protocol,session.game.snapshot()) == _without_economy(protocol,state) and session.game.house().gold == 321 and session.game.house().prestige == 77, "Gespeicherte Welt, Ressourcen und aktives Menschenhaus bleiben unverändert"):
		return false
	var loaded_hash: String = protocol.world_hash(session.game.snapshot())
	if not check(session.game.houses[9].doctrine == "infantry" and session.game.houses[10].doctrine == "cavalry" and session.game.house().research.known == ["surveying"], "Doktrinen und Forschungsstand bleiben erhalten"):
		return false
	if not check(FileAccess.get_file_as_bytes(path) == original and FileAccess.get_file_as_bytes(path + ".pre-ui191.bak") == original, "1.9.0-Datei und Sicherung bleiben bytegleich"):
		return false
	for variant in ["fingerprint", "current_hash", "catalog", "protocol", "future_app", "corrupt_state"]:
		var rejected := envelope.duplicate(true)
		match variant:
			"fingerprint": rejected.fingerprint = "andere-spieldaten"
			"current_hash": rejected.fingerprint = session._fingerprint
			"catalog": rejected.state.region_catalog_hash = "anderer-katalog"
			"protocol": rejected.v = 2
			"future_app": rejected.app = "1.9.2"
			"corrupt_state": rejected.state.lan_human_houses = [9,9]
		var bad_path: String = path + "." + str(variant)
		_write_bytes(bad_path, JSON.stringify(rejected).to_utf8_buffer())
		if not check(not session.load_host_lobby(bad_path).ok, "Ungültige Vorversionsdatei bleibt abgewiesen: " + variant):
			return false
		if not check(protocol.world_hash(session.game.snapshot()) == loaded_hash, "Abgewiesene Datei verändert die bestehende Welt nicht: " + variant):
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

func _previous_economy_release() -> bool:
	var protocol = load("res://scripts/LanProtocol.gd")
	var fixture := "res://tests/fixtures/lan-191-schema13-original.json"
	if not check(FileAccess.get_sha256(fixture) == "a88ef779bf4eaa2c545ae8bfa18b638117350e7647354632478598ae1402e959", "Echte unveränderte Schema13-Datei aus der exportierten 1.9.1-EXE"):
		return false
	var original := FileAccess.get_file_as_bytes(fixture)
	var envelope: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	var session = load("res://scripts/LanSession.gd").new()
	session.discovery_enabled = false
	add_child(session)
	if not check(Save.CURRENT_VERSION >= 14 and envelope.state.schema_version == 13,"Echter Wirtschaftsvorgänger bleibt Schema13 und migriert zum aktuellen Schema"):
		return false
	if not check(session.host("Schemafortsetzung","Host",0,49300+OS.get_process_id()%300).ok,"Eigene Gastgeberlobby für Wirtschaftsmigration"):
		return false
	var path := "user://economy-legacy-%d-%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	_write_bytes(path,original)
	if not check(not protocol.handshake_error(envelope,session._app,session._fingerprint).is_empty(),"Alte1.9.1-Teilnehmer bleiben trotz gleicher Appnummer am Inhaltsfingerprint abgewiesen"):
		return false
	var result: Dictionary = session.load_host_lobby(path)
	if not check(result.ok,"Echte lokale1.9.1-Schema13-Partie migriert: "+str(result.message)):
		return false
	if not check(session.game.snapshot().schema_version == Save.CURRENT_VERSION and _without_economy(protocol,session.game.snapshot()) == _without_economy(protocol,envelope.state),"Migration ergänzt ausschließlich neue Wirtschafts- und unbenutzte Flottenfelder"):
		return false
	var defaults_valid := true
	for province in session.game.provinces:
		defaults_valid = defaults_valid and province.get("economic_focus") == "balanced" and province.get("focus_changed_month") == -1
	if not check(defaults_valid and session.game.house().gold == 237 and session.game.human_houses == [0,1],"Alle alten Provinzen bleiben ausgewogen ohne Sperre und behalten Kassen/Sitze"):
		return false
	if not check(FileAccess.get_file_as_bytes(path) == original and FileAccess.get_file_as_bytes(path+".pre-economy-schema13.bak") == original,"Alte1.9.1-Datei und neue Sicherung sind bytegleich"):
		return false
	var loaded_hash: String = protocol.world_hash(session.game.snapshot())
	for variant in ["fingerprint","current_hash","old_app_current_hash","catalog","protocol","future_app","new_schema","future_schema","corrupt_state"]:
		var rejected := envelope.duplicate(true)
		match variant:
			"fingerprint": rejected.fingerprint = "unbekannt"
			"current_hash": rejected.fingerprint = session._fingerprint
			"old_app_current_hash":
				rejected.app = "1.8.0"
				rejected.v = 2
				rejected.fingerprint = session._fingerprint
			"catalog": rejected.state.region_catalog_hash = "falsch"
			"protocol": rejected.v = 2
			"future_app": rejected.app = "1.9.2"
			"new_schema": rejected.state.schema_version = 14
			"future_schema": rejected.state.schema_version = Save.CURRENT_VERSION + 1
			"corrupt_state": rejected.state.lan_human_houses = [0,0]
		var bad_path: String = path+"."+str(variant)
		_write_bytes(bad_path,JSON.stringify(rejected).to_utf8_buffer())
		if not check(not session.load_host_lobby(bad_path).ok,"Manipulierte Altdatei bleibt abgewiesen: "+variant):
			return false
		if not check(protocol.world_hash(session.game.snapshot()) == loaded_hash and not FileAccess.file_exists(bad_path+".pre-economy-schema13.bak"),"Abweisung ändert weder Welt noch Backup: "+variant):
			return false
	if not check(session.save_host(path).ok,"Migrierte1.9.1-Datei wird aktuell gespeichert"):
		return false
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(current.app == "1.9.1" and current.state.schema_version == Save.CURRENT_VERSION and current.fingerprint == session._fingerprint and FileAccess.get_file_as_bytes(path+".pre-economy-schema13.bak") == original,"Aktuelles Speichern erneuert Schema/Hash und erhält ursprüngliche Bytes"):
		return false
	if not _direct_save_preservation(session):
		return false
	session.close_session()
	session.queue_free()
	return true

func _direct_save_preservation(session) -> bool:
	var stem := "user://direct-lan-backup-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var fixtures := [
		["res://tests/fixtures/lan-190-original.json",".pre-ui191.bak"],
		["res://tests/fixtures/lan-191-schema13-original.json",".pre-economy-schema13.bak"],
	]
	var live: Dictionary = session.game.snapshot()
	for index in fixtures.size():
		var raw := FileAccess.get_file_as_bytes(fixtures[index][0])
		var suffix: String = fixtures[index][1]
		var path := stem+"-"+str(index)+".json"
		_write_bytes(path,raw)
		if not check(session.save_host(path).ok,"Direktes Speichern über nie geladene historische Zieldatei gelingt erst nach Sicherung"):
			return false
		if not check(FileAccess.get_file_as_bytes(path+suffix)==raw,"Nie geladene Altdatei wird vor Überschreiben bytegleich gesichert: "+str(index)):
			return false
		var current = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not check(current.state.schema_version==Save.CURRENT_VERSION and current.fingerprint==session._fingerprint and session.game.snapshot()==live,"Direktes Speichern schreibt aktuelle Datei ohne Änderung der laufenden Welt"):
			return false
	var original := FileAccess.get_file_as_bytes(fixtures[0][0])
	var collision := stem+"-collision.json"
	var unrelated := "andere ursprüngliche Sicherung".to_utf8_buffer()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(original)
	var fallback: String = ".pre-regions-"+context.finish().hex_encode().substr(0,16)+".bak"
	_write_bytes(collision,original)
	_write_bytes(collision+".pre-ui191.bak",unrelated)
	if not check(session.save_host(collision).ok and FileAccess.get_file_as_bytes(collision+".pre-ui191.bak")==unrelated and FileAccess.get_file_as_bytes(collision+fallback)==original,"Kollidierende Sicherung bleibt erhalten; direkte Altdatei erhält eigenen Hash-Namen"):
		return false
	var blocked := stem+"-blocked.json"
	_write_bytes(blocked,original)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked+".pre-ui191.bak"))
	if not check(not session.save_host(blocked).ok and FileAccess.get_file_as_bytes(blocked)==original and not FileAccess.file_exists(blocked+".tmp"),"Nicht schreibbare Sicherung verhindert direktes Überschreiben und temporäre Buchung"):
		return false
	var both := stem+"-both-collide.json"
	_write_bytes(both,original)
	_write_bytes(both+".pre-ui191.bak",unrelated)
	_write_bytes(both+fallback,unrelated)
	if not check(not session.save_host(both).ok and FileAccess.get_file_as_bytes(both)==original and FileAccess.get_file_as_bytes(both+fallback)==unrelated,"Auch belegter Hash-Sicherungsname wird niemals überschrieben"):
		return false
	for variant in ["text","unknown_envelope","future","invalid_current"]:
		var raw := "beschädigter alter Spielstand".to_utf8_buffer()
		if variant != "text":
			var existing := {"kind":"BQ-LAN-SAVE","v":3,"app":session._app,"fingerprint":session._fingerprint,"state":live.duplicate(true)}
			if variant=="unknown_envelope": existing.kind = "anderes Format"
			if variant=="future": existing.app = "1.9.2"
			if variant=="invalid_current": existing.state.provinces[0].economic_focus = "ungültig"
			raw = JSON.stringify(existing).to_utf8_buffer()
		var path: String = stem+"-"+variant+".json"
		_write_bytes(path,raw)
		if not check(not session.save_host(path).ok and FileAccess.get_file_as_bytes(path)==raw,"Ungültiges oder unbekanntes bestehendes Ziel bleibt unverändert: "+variant):
			return false
	var rejected := stem+"-rejected-candidate.json"
	_write_bytes(rejected,original)
	var valid_resume: Dictionary = session._resume_state.duplicate(true)
	session._resume_state.provinces[0].economic_focus = "ungültig"
	var result: Dictionary = session.save_host(rejected)
	session._resume_state = valid_resume
	if not check(not result.ok and FileAccess.get_file_as_bytes(rejected)==original and not FileAccess.file_exists(rejected+".pre-ui191.bak"),"Ungültiger neuer Zustand wird vor jeder Sicherung abgewiesen"):
		return false
	return true

func _previous_gameplay_release() -> bool:
	var protocol = load("res://scripts/LanProtocol.gd")
	var raw := FileAccess.get_file_as_bytes("res://tests/fixtures/lan-191-gameplay-schema14-original.json")
	if not check(FileAccess.get_sha256("res://tests/fixtures/lan-191-gameplay-schema14-original.json") == "6def99ffb42c1ced6a52d03d12afa525105a3ed44bf8555daa6c29358d7b74c4","Unveränderte echte1.9.1-Gameplay-Datei mit Herkunftsreceipt"):
		return false
	var envelope: Dictionary = JSON.parse_string(raw.get_string_from_utf8())
	if not check(envelope.app == "1.9.1" and envelope.v == 3 and envelope.state.schema_version == 14 and envelope.fingerprint == "fcc2237b4e44b454f78a0a0721cc10ca7167289ec3c8d01ae49a455b2c98c9d3","Historischer Gameplay-Fingerabdruck stammt aus tatsächlich ausgeführter EXE"):
		return false
	var session = load("res://scripts/LanSession.gd").new()
	session.discovery_enabled = false
	add_child(session)
	if not check(session.host("Gameplay-Fortsetzung","Host",0,49700+OS.get_process_id()%200).ok,"Eigene Lobby für direkte Schema14-Fortsetzung"):
		return false
	var stem := "user://previous-gameplay-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var path := stem+"-load.json"
	_write_bytes(path,raw)
	check(not protocol.handshake_error(envelope,session._app,session._fingerprint).is_empty(),"Alter Gameplay-Peer bleibt trotz lokaler Fortsetzung am Wire abgewiesen")
	var loaded: Dictionary = session.load_host_lobby(path)
	var load_ok := check(loaded.ok,"Echte lokale Schema14-Gameplay-Datei lässt sich mit neuen Ereignisguards fortsetzen: "+str(loaded.message))
	# Zweiten, unabhängigen Direktpfad auch im roten Vorlauf ausführen.
	if not loaded.ok:
		session.game = load("res://scripts/Game.gd").new(load("res://scripts/GameRegionData.gd"),0)
		session.game.configure_human_houses([0,1])
		session._resume_state = session.game.snapshot()
	var live: Dictionary = session.game.snapshot()
	var direct := stem+"-direct.json"
	_write_bytes(direct,raw)
	var saved: Dictionary = session.save_host(direct)
	var direct_ok := check(saved.ok,"Direktes Überschreiben der noch nie geladenen alten Gameplay-Zieldatei benötigt vorher ihre Sicherung: "+str(saved.message))
	if not load_ok or not direct_ok:
		session.close_session()
		session.queue_free()
		return false
	var suffix := ".pre-choice-guards-v14.bak"
	var expected_humans: Array = []
	for seat in envelope.state.lan_human_houses: expected_humans.append(int(seat))
	if _without_naval(protocol,session.game.snapshot()) != _without_naval(protocol,envelope.state):
		print("GAMEPLAY_LEGACY_DIFF ",load("res://scripts/SaveGame.gd").diff(envelope.state,session.game.snapshot()))
	if not check(_without_naval(protocol,session.game.snapshot()) == _without_naval(protocol,envelope.state) and session.game.human_houses == expected_humans,"Vorherige Schema14-Welt und Menschenplätze bleiben bis auf neue Schema-/Flottenfelder erhalten"):
		return false
	if not check(FileAccess.get_file_as_bytes(path) == raw and FileAccess.get_file_as_bytes(path+suffix) == raw and FileAccess.get_file_as_bytes(direct+suffix) == raw,"Lokales Laden und direktes Speichern sichern ursprüngliche Gameplay-Bytes"):
		return false
	if not check(session.game.snapshot() == live and JSON.parse_string(FileAccess.get_file_as_string(direct)).fingerprint == session._fingerprint,"Direktspeichern aktualisiert nur die Hülle und erhält die laufende Welt"):
		return false
	for variant in ["unknown_hash","wrong_app","wrong_wire","wrong_schema","wrong_catalog"]:
		var bad := envelope.duplicate(true)
		match variant:
			"unknown_hash": bad.fingerprint = "unknown-gameplay"
			"wrong_app": bad.app = "1.9.0"
			"wrong_wire": bad.v = 2
			"wrong_schema": bad.state.schema_version = 13
			"wrong_catalog": bad.state.region_catalog_hash = "wrong"
		var bad_raw := JSON.stringify(bad).to_utf8_buffer()
		var bad_path: String = stem+"-"+str(variant)+".json"
		_write_bytes(bad_path,bad_raw)
		if not check(not session.load_host_lobby(bad_path).ok and not session.save_host(bad_path).ok,"Unbekannter/verfälschter Gameplay-Vorgänger wird in beiden Dateipfaden abgewiesen: "+variant):
			return false
		if not check(FileAccess.get_file_as_bytes(bad_path) == bad_raw and session.game.snapshot() == live and not FileAccess.file_exists(bad_path+suffix),"Abweisung erhält Datei, laufende Partie und fehlendes Backup: "+variant):
			return false
	var blocked := stem+"-blocked.json"
	_write_bytes(blocked,raw)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked+suffix))
	if not check(not session.load_host_lobby(blocked).ok and not session.save_host(blocked).ok and FileAccess.get_file_as_bytes(blocked) == raw and session.game.snapshot() == live,"Nicht schreibbares Gameplay-Backup verhindert Laden und Direktüberschreiben ohne Nebenwirkung"):
		return false
	session.close_session()
	session.queue_free()
	return true

func _without_economy(protocol, state: Dictionary) -> String:
	var old := _project_unused_naval_fields(state)
	old.schema_version = 13
	for province in old.provinces:
		province.erase("economic_focus")
		province.erase("focus_changed_month")
	return protocol.world_hash(old)

func _without_naval(protocol, state: Dictionary) -> String:
	var old := _project_unused_naval_fields(state)
	old.schema_version = 14
	return protocol.world_hash(old)

func _project_unused_naval_fields(state: Dictionary) -> Dictionary:
	var old := state.duplicate(true)
	if old.has("material_trades"):
		if not check(old.material_trades is Array and old.material_trades.is_empty(),"Historical migration adds only an empty material-trade list"): return old
		old.erase("material_trades")
	if old.has("trade_serial"):
		if not check((old.trade_serial is int or old.trade_serial is float) and old.trade_serial==0,"Historical migration adds only a zero material-trade serial"): return old
		old.erase("trade_serial")
	old.erase("project_serial")
	for province in old.provinces:
		for field in ["production","regional_project","logistics_sites"]:
			if province.has(field):
				var expected = {"materials_u":0,"rate_carry":0} if field=="production" else ({"depot":0} if field=="logistics_sites" else {})
				check(province[field]==expected,"Historical migration adds only empty production state: "+field)
				province.erase(field)
	for road in old.get("roads",[]):
		road.erase("construction")
		road.erase("legacy_construction")
	for house in old.houses:
		for fleet in house.get("fleets",[]):
			if fleet.has("last_naval_month"):
				check(fleet.last_naval_month == -1,"Historische Flotte erhält ausschließlich eine unbenutzte Monatswache")
				fleet.erase("last_naval_month")
	return old

func _previous_production_release() -> bool:
	var protocol = load("res://scripts/LanProtocol.gd")
	var fixture := "res://tests/fixtures/lan-191-campaign-schema16-original.json"
	var hash := "2e2b8befa58ef22ec3547221af2b4a059d4b09df6264a028a012eb9aac563e40"
	if not check(FileAccess.get_sha256(fixture)==hash,"Actual campaign16 original is unchanged and provenance-pinned"): return false
	var raw := FileAccess.get_file_as_bytes(fixture)
	var original: Dictionary = JSON.parse_string(raw.get_string_from_utf8())
	if not check(original.app=="1.9.1" and original.v==3 and original.state.schema_version==16 and original.fingerprint=="dc8f13abb2f9b93c1aabfcf115f592df02c8af9ceb2b445127bdcefd22fd3903","Actual schema16 family is exact, not relabelled"): return false
	var session = load("res://scripts/LanSession.gd").new()
	session.discovery_enabled = false
	add_child(session)
	if not check(session.host("Production16migration","Host",0,56000+OS.get_process_id()%1000).ok,"Own lobby for genuine16local migration"): return false
	var stem := "user://previous-production-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var path := stem+"-load.json"
	var suffix := ".pre-production-schema16.bak"
	_write_bytes(path,raw)
	check(not protocol.handshake_error(original,session._app,session._fingerprint).is_empty(),"Old16peer remains rejected on the live wire")
	var loaded: Dictionary = session.load_host_lobby(path)
	if not check(loaded.ok,"Actual16file migrates locally with new production: "+str(loaded.message)):
		session.close_session()
		return false
	var projected := _project_unused_naval_fields(session.game.snapshot())
	projected.schema_version = 16
	# This original has no fleets, so no naval-month projection is removed.
	if not check(Save.state_equal(projected,original.state),"Actual16migration preserves every prior shared/personal world field"): return false
	if not check(FileAccess.get_file_as_bytes(path)==raw and FileAccess.get_file_as_bytes(path+suffix)==raw,"Local16load preserves source and byte-exact backup"): return false
	var live: Dictionary = session.game.snapshot()
	var direct := stem+"-direct.json"
	_write_bytes(direct,raw)
	if not check(session.save_host(direct).ok and FileAccess.get_file_as_bytes(direct+suffix)==raw and session.game.snapshot()==live,"Never-loaded genuine16target is protected before direct overwrite"): return false
	for variant in ["unknown_hash","current_hash","app","wire","schema15","schema17","future_schema","catalog","malformed_production"]:
		var bad := original.duplicate(true)
		match variant:
			"unknown_hash": bad.fingerprint = "unknown-schema16"
			"current_hash": bad.fingerprint = session._fingerprint
			"app": bad.app = "1.9.0"
			"wire": bad.v = 2
			"schema15": bad.state.schema_version = 15
			"schema17": bad.state.schema_version = 17
			"future_schema": bad.state.schema_version = Save.CURRENT_VERSION+1
			"catalog": bad.state.region_catalog_hash = "wrong-catalog"
			"malformed_production": bad.state.provinces[0].production = null
		var bad_path := stem+"-"+str(variant)+".json"
		var bytes := JSON.stringify(bad).to_utf8_buffer()
		_write_bytes(bad_path,bytes)
		if not check(not session.load_host_lobby(bad_path).ok and not session.save_host(bad_path).ok,"Unknown/contradictory16identity rejects both file paths: "+variant): return false
		if not check(FileAccess.get_file_as_bytes(bad_path)==bytes and session.game.snapshot()==live and not FileAccess.file_exists(bad_path+suffix),"Rejected16file preserves source/liveworld/backups: "+variant): return false
	var collision := stem+"-collision.json"
	_write_bytes(collision,raw)
	_write_bytes(collision+suffix,"unrelated".to_utf8_buffer())
	if not check(session.load_host_lobby(collision).ok and FileAccess.get_file_as_string(collision+suffix)=="unrelated" and FileAccess.get_file_as_bytes(collision+".pre-regions-"+hash.substr(0,16)+".bak")==raw,"16backup collision preserves unrelated history and exact original"): return false
	var blocked := stem+"-blocked.json"
	_write_bytes(blocked,raw)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked+suffix))
	if not check(not session.load_host_lobby(blocked).ok and not session.save_host(blocked).ok and FileAccess.get_file_as_bytes(blocked)==raw and session.game.snapshot()==live,"Unwritable16backup prevents both paths without mutation"): return false
	check(FileAccess.get_sha256(fixture)==hash,"Historical16fixture remains immutable after all cases")
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
