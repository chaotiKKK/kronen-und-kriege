extends Node
## Echte ENet-Pakete; optional dieselbe Szene in getrennten Host-/Gastprozessen.

const DataScript = preload("res://scripts/Data.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")

# Ein erreichbarer, aber fehlerhafter Host: Heartbeats funktionieren weiterhin,
# nur Befehlsbestätigungen bleiben aus. Der Gast muss trotzdem begrenzt warten.
class SilentCommandHost:
	extends "res://scripts/LanSession.gd"
	func _receive_host(id: int, kind: String, message: Dictionary) -> void:
		if kind != "command":
			super._receive_host(id, kind, message)

var checks := 0
var failures := 0
var sessions: Array = []
var Session
var args: Dictionary = {}

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/LanSession.gd"):
		check(false, "Der private ENet-Transport fehlt.")
		finish()
		return
	Session = load("res://scripts/LanSession.gd")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--lan-") and argument.contains("="):
			var pair := argument.split("=", true, 1)
			args[pair[0]] = pair[1]
	if args.has("--lan-role"):
		await process_case()
	else:
		await same_process_cases()
		await discovery_case()
		await unconfirmed_command_case()
		await reset_peer_case()
	finish()

func reset_peer_case() -> void:
	var host = session()
	var guest = session()
	var port := 55000 + OS.get_process_id() % 1000
	check(host.host("Disconnect-Regression", "Host", 0, port).ok, "Regression konnte Host nicht öffnen.")
	guest.join("127.0.0.1", "Gast", port)
	check(await wait_until(func(): return guest.phase == "lobby" and host.players.size() == 2), "Regression konnte Gast nicht verbinden.")
	if host.players.size() == 2:
		# Fault injection: ENet has reset its peer before the queued SceneMultiplayer
		# disconnect callback removes the cached seat, as with concurrent exits.
		var destination: ENetPacketPeer = host._peer.get_peer(guest.local_peer_id)
		destination.reset()
		check(not destination.is_active(), "Disconnect-Zwischenzustand wurde nicht erzeugt.")
		check(not host._send(guest.local_peer_id, {"type":"notice", "text":"Nicht mehr senden"}), "Zurückgesetzter ENet-Empfänger wurde weiterhin beschrieben.")
	host.close_session()
	guest.close_session()

func session(fingerprint: String = "transport-test"):
	var created = Session.new(DataScript, fingerprint)
	created.discovery_enabled = false
	add_child(created)
	sessions.append(created)
	return created

func wait_until(condition: Callable, milliseconds: int = 4000) -> bool:
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().create_timer(0.015).timeout
	return condition.call()

func same_process_cases() -> void:
	var host = session()
	var guest = session()
	var port := 51000 + int(Time.get_ticks_msec() % 3000)
	check(host.host("Testzimmer", "Host", 0, port).ok, "Host konnte eigenen Testport nicht öffnen.")
	check(guest.join("127.0.0.1", "Gast", port).ok, "Direkter Verbindungsversuch scheiterte.")
	check(await wait_until(func(): return guest.phase == "lobby" and host.players.size() == 2), "Handshake führte nicht zu zwei Lobbysitzen.")
	if host.players.size() != 2:
		return
	check(guest.local_peer_id > 1 and guest.local_house() != 0, "Gast erhielt Host-ID oder besetzten Haussitz.")
	guest.choose_house(0)
	await get_tree().create_timer(0.1).timeout
	check(guest.local_house() != 0, "Doppelter Haussitz wurde akzeptiert.")
	check(guest.choose_house(1).ok and guest.set_ready(true).ok, "Gast konnte Haus oder Bereitschaft nicht anfordern.")
	check(await wait_until(func(): return bool(host.players[guest.local_peer_id].ready)), "Gastbereitschaft erreichte Host nicht.")
	check(host.start_match().ok, "Host konnte bereite Partie nicht starten.")
	check(await wait_until(func(): return guest.phase == "playing"), "Gast erhielt keinen Startsnapshot.")
	check(host.game.speed == 0 and guest.game.speed == 0, "Partie startete nicht pausiert.")
	var guest_capital := str(host.game.houses[1].capital)
	var host_capital := str(host.game.houses[0].capital)
	var guest_gold := int(host.game.houses[1].gold)
	var host_gold := int(host.game.houses[0].gold)
	check(guest.submit({"id":"develop", "selection":guest_capital}).ok, "Gastbefehl wurde nicht versendet.")
	check(guest.pending_command and not guest.submit({"id":"recruit", "selection":guest_capital}).ok, "Mehrere Gastbefehle konnten zugleich ausstehen.")
	check(await wait_until(func(): return not guest.pending_command and int(guest.game.houses[1].gold) == guest_gold - 50), "Gastkosten wurden nicht bestätigt.")
	check(int(host.game.houses[1].gold) == guest_gold - 50 and int(host.game.houses[0].gold) == host_gold, "Gastbefehl belastete falsches Haus.")
	check(host.submit({"id":"recruit", "selection":host_capital}).ok, "Hostbefehl scheiterte.")
	check(await wait_until(func(): return int(guest.game.houses[0].gold) == host_gold - 30), "Hostbefehl kam nicht beim Gast an.")
	check(Protocol.world_hash(host.game.snapshot()) == Protocol.world_hash(guest.game.snapshot()), "Host und Gast haben verschiedene Welten.")
	var baseline := int(host.game.calendar_index())
	host.submit({"id":"set_speed", "value":3})
	check(await wait_until(func(): return host.game.calendar_index() > baseline), "Nur Hostzeit lief nicht.")
	host.submit({"id":"set_speed", "value":0})
	check(await wait_until(func(): return guest.game.calendar_index() == host.game.calendar_index() and guest.game.speed == 0), "Gastdatum wurde nicht synchronisiert.")
	check(host.game.calendar_index() == baseline + 1, "Simulation wurde pro Teilnehmer mehrfach getaktet.")
	host.game.select_player_context(1)
	host.game._trigger_event()
	host.game.select_player_context(0)
	host.submit({"id":"set_speed", "value":3})
	baseline = int(host.game.calendar_index())
	await get_tree().create_timer(0.45).timeout
	check(host.game.calendar_index() == baseline, "Offenes Gastereignis pausierte Hosttakt nicht.")
	check(host.return_to_lobby().ok, "Laufende Partie konnte nicht in Lobby wechseln.")
	check(await wait_until(func(): return guest.phase == "lobby"), "Gast blieb beim Lobbywechsel im Spiel.")
	check(not bool(host.players[guest.local_peer_id].ready), "Gast blieb nach Lobbywechsel bereit.")
	var save_path := "user://lan_transport_test.json"
	check(host.save_host(save_path).ok, "Hostspielstand konnte nicht geschrieben werden.")
	check(not guest.save_host(save_path).ok and not guest.load_host_lobby(save_path).ok, "Gast durfte Hostdateien speichern oder laden.")
	check(host.load_host_lobby(save_path).ok, "Hostspielstand konnte nicht in Lobby geladen werden.")
	guest.set_ready(true)
	await wait_until(func(): return bool(host.players[guest.local_peer_id].ready))
	check(host.start_match().ok, "Gespeicherte Häuser konnten nicht gemeinsam fortgesetzt werden.")
	await wait_until(func(): return guest.phase == "playing")
	guest.close_session("Gast verlässt den Test.")
	check(await wait_until(func(): return host.players.size() == 1), "Gastende erreichte Host nicht.")
	check(host.game.speed == 0 and not host.submit({"id":"set_speed", "value":3}).ok, "Gastverlust ließ die Simulation weiterlaufen.")
	check(host.return_to_lobby().ok, "Nach Gastverlust fehlte neue Lobby.")
	var bad = session("andere-daten")
	bad.join("127.0.0.1", "Falsch", port)
	check(await wait_until(func(): return bad.phase == "disconnected"), "Falsche Spieldaten wurden nicht abgewiesen.")
	check("Spieldaten" in bad.status and host.players.size() == 1, "Fehlversion belegt Sitz oder zeigt keine Erklärung.")
	var replacement = session()
	replacement.join("127.0.0.1", "Ersatz", port)
	check(await wait_until(func(): return replacement.phase == "lobby"), "Neubeitritt in Wiederaufnahmelobby scheiterte.")
	replacement.choose_house(2)
	replacement.set_ready(true)
	await get_tree().create_timer(0.1).timeout
	check(not host.start_match().ok, "Wiederaufnahme ohne alle gespeicherten Menschenhäuser wurde akzeptiert.")
	replacement.choose_house(1)
	replacement.set_ready(true)
	await wait_until(func(): return int(host.players[replacement.local_peer_id].house) == 1 and bool(host.players[replacement.local_peer_id].ready))
	check(host.start_match().ok, "Ersatz für gespeichertes Haus konnte nicht fortsetzen.")
	await wait_until(func(): return replacement.phase == "playing")
	var newcomer = session()
	newcomer.join("127.0.0.1", "Zu spät", port)
	check(await wait_until(func(): return newcomer.phase == "disconnected"), "Beitritt in laufende Partie wurde akzeptiert.")
	for house in host.game.human_houses:
		host.game.select_player_context(int(house))
		host.game.game_over = true
	host.game.select_player_context(0)
	host.submit({"id":"set_speed", "value":0})
	check(await wait_until(func(): return host.get("all_houses_over") == true and replacement.get("all_houses_over") == true), "Gemeinsames Hausende wurde nicht getrennt von privaten Endflags übertragen.")
	host.close_session("Host beendet den Test.")
	check(await wait_until(func(): return replacement.phase == "disconnected"), "Hostende erreichte Gast nicht.")
	check("Host" in replacement.status or "Gastgeber" in replacement.status, "Hostverlust besitzt keine deutsche Erklärung.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func process_case() -> void:
	var role := str(args.get("--lan-role", ""))
	var port := int(args.get("--lan-port", "56001"))
	var output := str(args.get("--lan-output", "user://network-result.json"))
	var mode := str(args.get("--lan-case", "normal"))
	var peer = session("wrong" if mode == "mismatch" and role == "guest" else "two-process-test")
	if role == "host":
		check(peer.host("Zwei Prozesse", "Hostprozess", 0, port).ok, "Prozesshost konnte Port nicht öffnen.")
		write_json(output + ".ready", {"ready":true, "pid":OS.get_process_id()})
		if mode == "mismatch":
			await get_tree().create_timer(3.0).timeout
			check(peer.players.size() == 1, "Falscher Fingerprint belegte Hostprozesssitz.")
		else:
			check(await wait_until(func(): return peer.players.size() == 2 and bool(peer.players.values()[1].ready), 10000), "Gastprozess wurde nicht bereit.")
			if peer.players.size() == 2:
				check(peer.start_match().ok, "Mehrprozesspartie startete nicht.")
				check(await wait_until(func(): return int(peer.game.houses[1].gold) == 80, 6000), "Echter Gastprozessbefehl fehlte.")
				if mode == "host_loss":
					write_json(output, {"ready_to_stop":true, "checks":checks, "failures":failures})
					await get_tree().create_timer(15).timeout
				elif mode == "guest_loss":
					check(await wait_until(func(): return peer.players.size() == 1, 12000), "Abgestürzter Gast wurde nicht erkannt.")
					check(peer.game.speed == 0 and not peer.submit({"id":"set_speed", "value":3}).ok, "Abgestürzter Gast blockierte Fortsetzung nicht.")
				else:
					peer.submit({"id":"recruit", "selection":str(peer.game.houses[0].capital)})
					await get_tree().create_timer(0.3).timeout
					write_json(output + ".world", {"hash":Protocol.world_hash(peer.game.snapshot()), "month":peer.game.calendar_index(), "guest_gold":peer.game.houses[1].gold})
					check(await wait_until(func(): return peer.players.size() == 1, 6000), "Gastprozess hat nicht geordnet geschlossen.")
	else:
		check(peer.join("127.0.0.1", "Gastprozess", port).ok, "Gastprozess konnte nicht verbinden.")
		if mode == "mismatch":
			check(await wait_until(func(): return peer.phase == "disconnected", 6000), "Fehlversion wurde im Gastprozess nicht abgewiesen.")
			check("Spieldaten" in peer.status, "Fehlversion erklärt Abweisung nicht.")
		else:
			check(await wait_until(func(): return peer.phase == "lobby", 6000), "Gastprozess kam nicht in Lobby.")
			if peer.phase == "lobby":
				peer.choose_house(1)
				peer.set_ready(true)
				check(await wait_until(func(): return peer.phase == "playing", 6000), "Gastprozess erhielt keinen Start.")
				if peer.game != null:
					check(peer.submit({"id":"develop", "selection":str(peer.game.houses[1].capital)}).ok, "Gastprozessbefehl nicht versendet.")
					check(await wait_until(func(): return not peer.pending_command, 6000), "Gastprozessbefehl blieb unbeantwortet.")
					if mode == "guest_loss":
						write_json(output, {"ready_to_stop":true, "checks":checks, "failures":failures})
						await get_tree().create_timer(15).timeout
					elif mode == "host_loss":
						check(await wait_until(func(): return peer.phase == "disconnected", 12000), "Abgestürzter Host wurde nicht erkannt.")
					else:
						check(await wait_until(func(): return int(peer.game.houses[0].gold) == 110, 6000), "Hostprozessbefehl erreichte Gast nicht.")
						write_json(output + ".world", {"hash":Protocol.world_hash(peer.game.snapshot()), "month":peer.game.calendar_index(), "guest_gold":peer.game.houses[1].gold})
						peer.close_session("Gastprozess fertig.")
	write_json(output, {"checks":checks, "failures":failures, "status":peer.status, "pid":OS.get_process_id()})

func discovery_case() -> void:
	var DiscoveryScript = load("res://scripts/LanDiscovery.gd")
	var listener = DiscoveryScript.new()
	var searcher = DiscoveryScript.new()
	var port := 55000 + int(Time.get_ticks_msec() % 1000)
	check(listener.start_host({"name":"Lokale Suche", "port":56001, "players":2, "open":true}, port), "UDP-Testlistener konnte nicht öffnen.")
	searcher.search(port, "127.0.0.1")
	check(await wait_until(func():
		listener.poll()
		searcher.poll()
		return not searcher.rooms.is_empty()
	), "Unicast-Discoveryantwort erreichte Sucher mit eigenem Port nicht.")
	if not searcher.rooms.is_empty():
		check(searcher.rooms[0].address == "127.0.0.1" and int(searcher.rooms[0].port) == 56001, "Discovery nutzte nicht echte Absenderadresse und Spielport.")
		searcher.rooms[0].last_seen = Time.get_ticks_msec() - 13000
		searcher.poll()
		check(searcher.rooms.is_empty(), "Veraltete WLAN-Lobby blieb in der Suchliste.")
	listener.close()
	searcher.close()

func unconfirmed_command_case() -> void:
	var host = SilentCommandHost.new(DataScript, "silent-test")
	host.discovery_enabled = false
	add_child(host)
	sessions.append(host)
	var guest = session("silent-test")
	var port := 57000 + int(Time.get_ticks_msec() % 1000)
	check(host.host("Stummer Befehl", "Host", 0, port).ok and guest.join("127.0.0.1", "Gast", port).ok, "Bestätigungsfrist-Test konnte nicht verbinden.")
	await wait_until(func(): return guest.phase == "lobby")
	guest.set_ready(true)
	await wait_until(func(): return host.players.size() == 2 and bool(host.players[guest.local_peer_id].ready))
	check(host.start_match().ok, "Bestätigungsfrist-Test startete nicht.")
	await wait_until(func(): return guest.phase == "playing")
	check(guest.submit({"id":"recruit", "selection":str(guest.game.houses[1].capital)}).ok, "Testbefehl konnte nicht versendet werden.")
	check(await wait_until(func(): return guest.phase == "disconnected", 9000), "Erreichbarer Host ließ Gast unbegrenzt auf Befehlsbestätigung warten.")
	check(not guest.pending_command and ("bestätigt" in guest.status or "Spielbefehl" in guest.status), "Fehlende Befehlsbestätigung blieb ohne klare Erklärung.")
	host.close_session()

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("LANTRANSPORTTEST FAIL: ", message)

func finish() -> void:
	for peer in sessions:
		peer.close_session()
	print("LANTRANSPORTTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
