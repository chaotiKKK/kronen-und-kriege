extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/LanAuthority.gd"):
		check(false, "Die autoritative WLAN-Befehlsverarbeitung fehlt.")
		finish()
		return
	var authority_script = load("res://scripts/LanAuthority.gd")
	var data = load("res://scripts/Data.gd")
	var game = load("res://scripts/Game.gd").new(data, 0)
	check(game.configure_human_houses([0,1]), "Menschliche Häuser nicht eingerichtet.")
	game.houses[0].gold = 1000
	game.houses[1].gold = 1000
	var host_province := ""
	var guest_province := ""
	for p in game.provinces:
		if int(p.owner) == 0:
			host_province = p.id
		if int(p.owner) == 1:
			guest_province = p.id
	var authority = authority_script.new(game, {1:0,2:1})
	var result: Dictionary = authority.execute(2,1,{"id":"develop","selection":guest_province})
	check(result.ok, "Eigener Gastbefehl fehlgeschlagen.")
	check(int(game.houses[1].gold) < 1000 and int(game.houses[0].gold) == 1000, "Kosten falsch zugeordnet.")
	check(game.player == 0, "Hostperspektive wurde nicht wiederhergestellt.")
	var after: Dictionary = game.snapshot()
	check(not authority.execute(2,1,{"id":"develop","selection":guest_province}).ok, "Doppelter Befehl ausgeführt.")
	check(not authority.execute(2,2,{"id":"develop","selection":host_province}).ok, "Fremde Provinz ausgebaut.")
	check(not authority.execute(2,3,{"id":"set_speed","value":3}).ok, "Gast änderte Zeit.")
	check(not authority.execute(2,4,{"id":"load"}).ok, "Gast lud Hostdatei.")
	check(not authority.execute(3,1,{"id":"develop","selection":host_province}).ok, "Unbekannter Peer durfte spielen.")
	var protocol = load("res://scripts/LanProtocol.gd")
	check(protocol.world_hash(after) == protocol.world_hash(game.snapshot()), "Abgelehnte Befehle veränderten die Welt.")
	check(authority.execute(1,1,{"id":"set_speed","value":2}).ok and game.speed == 2, "Host kann Zeit nicht setzen.")
	var guest: Dictionary = authority.snapshot_for_peer(2)
	check(int(guest.player) == 1 and not guest.has("lan_contexts"), "Gastprojektion leakt fremde Kontexte.")
	check(protocol.world_hash(guest) == protocol.world_hash(game.snapshot()), "Gast sieht eine andere Welt.")
	game.select_player_context(1)
	game._trigger_event()
	var instance: int = game.pending_event_instance()
	game.select_player_context(0)
	check(not authority.execute(2,5,{"id":"apply_event","option":0,"event_instance":instance + 1}).ok, "Falsche Ereignisinstanz akzeptiert.")
	check(authority.execute(2,6,{"id":"apply_event","option":0,"event_instance":instance}).ok, "Eigene Ereignisantwort abgelehnt.")
	game.year = 2200
	game.month = 12
	game.game_over = true
	check(authority.execute(1,2,{"id":"continue_sandbox"}).ok and game.campaign_sandbox, "Ausgeschiedener Host darf gemeinsame Sandbox nicht fortsetzen.")
	finish()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("LANAUTHORITYTEST FAIL: ", message)

func finish() -> void:
	print("LANAUTHORITYTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
