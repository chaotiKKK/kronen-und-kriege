extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/LanProtocol.gd"):
		check(false, "Das typisierte WLAN-Protokoll fehlt.")
		finish()
		return
	var protocol = load("res://scripts/LanProtocol.gd")
	check(protocol != null, "WLAN-Protokoll ist nicht ladbar.")
	if protocol == null:
		finish()
		return
	check(protocol.validate_command({"id":"develop", "selection":"bohemia"}).ok, "Gültiger Provinzbefehl abgelehnt.")
	check(not protocol.validate_command({"id":"load"}).ok, "Remote-Dateizugriff zugelassen.")
	check(not protocol.validate_command({"id":"call", "method":"restore"}).ok, "Beliebige Methode zugelassen.")
	check(not protocol.validate_command({"id":"develop", "house":2}).ok, "Client-Hausvorgabe zugelassen.")
	check(not protocol.validate_command({"id":"develop", "selection":12}).ok, "Provinz mit falschem Typ zugelassen.")
	check(not protocol.validate_command({"id":"set_speed", "value":2.5}).ok, "Gebrochene Zeitstufe zugelassen.")
	check(not protocol.validate_command({"id":"set_speed", "value":4}).ok, "Ungültige Zeitstufe zugelassen.")
	check(protocol.validate_command({"id":"set_speed", "value":2.0}).command.value is int, "JSON-Ganzzahl nicht normalisiert.")
	check(not protocol.validate_command({"id":"marry"}).ok, "Fehlendes Ziel zugelassen.")
	check(not protocol.validate_command({"id":"apply_event", "option":0}).ok, "Ereignis ohne Instanz zugelassen.")
	check(protocol.validate_command({"id":"apply_event", "option":0, "event_instance":3}).ok, "Gültige Ereignisantwort abgelehnt.")
	check(not protocol.validate_command({"id":"research", "innovation":"x".repeat(200)}).ok, "Übergroßer Bezeichner zugelassen.")
	var encoded: PackedByteArray = protocol.encode_packet({"v":1,"type":"hello","name":"Müller"})
	var decoded: Dictionary = protocol.decode_packet(encoded)
	check(decoded.ok and decoded.message.name == "Müller", "UTF-8-Nachricht verändert.")
	check(not protocol.decode_packet("{broken".to_utf8_buffer()).ok, "Beschädigtes JSON akzeptiert.")
	check(not protocol.decode_packet("[]".to_utf8_buffer()).ok, "Array als Nachricht zugelassen.")
	check(not protocol.decode_packet("{\"v\":1,\"type\":1}".to_utf8_buffer()).ok, "Falscher Nachrichtentyp zugelassen.")
	var oversized := PackedByteArray()
	oversized.resize(protocol.MAX_PACKET_BYTES + 1)
	check(not protocol.decode_packet(oversized).ok, "Übergroßes Paket zugelassen.")
	check(protocol.handshake_error({"v":1,"app":"1.7.0","fingerprint":"a"},"1.7.0","a").is_empty(), "Gleiche Kennung abgelehnt.")
	check(not protocol.handshake_error({"v":2,"app":"1.7.0","fingerprint":"a"},"1.7.0","a").is_empty(), "Falsches Protokoll zugelassen.")
	check(not protocol.handshake_error({"v":1,"app":"1.6.1","fingerprint":"a"},"1.7.0","a").is_empty(), "Falsche Appversion zugelassen.")
	check(not protocol.handshake_error({"v":1,"app":"1.7.0","fingerprint":"b"},"1.7.0","a").is_empty(), "Abweichende Daten zugelassen.")
	var world := {"year":-2000,"month":1,"houses":[{"gold":50}],"player":0,"opinion":[1],"history":[],"lan_contexts":{"0":{"scandal":2}}}
	var other := world.duplicate(true)
	other.player = 1
	other.opinion = [-20]
	other.lan_contexts = {}
	check(protocol.world_hash(world) == protocol.world_hash(other), "Hash hängt von der Perspektive ab.")
	other.houses[0].gold = 51
	check(protocol.world_hash(world) != protocol.world_hash(other), "Weltänderung fehlt im Hash.")
	finish()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("LANPROTOCOLTEST FAIL: ", message)

func finish() -> void:
	print("LANPROTOCOLTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
