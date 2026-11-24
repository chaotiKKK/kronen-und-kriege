extends Node

const Protocol = preload("res://scripts/LanProtocol.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var scene = load("res://scenes/Main.tscn")
	var host = scene.instantiate()
	var guest = scene.instantiate()
	add_child(host)
	add_child(guest)
	await get_tree().process_frame
	var h = host.lan_session
	var g = guest.lan_session
	h.discovery_enabled = false
	g.discovery_enabled = false
	var port := 47000 + OS.get_process_id() % 1000
	check(h.host("Main-Integration", "Host", 0, port).ok, "Host öffnen")
	check(g.join("127.0.0.1", "Gast", port).ok, "Gast verbinden")
	check(await until(func(): return g.phase == "lobby" and h.players.size() == 2), "Lobby verbinden")
	g.choose_house(1)
	g.set_ready(true)
	check(await until(func(): return bool(h.players[g.local_peer_id].ready)), "Bereitschaft")
	var other_guests: Array = []
	for index in [2, 3]:
		var extra = load("res://scripts/LanSession.gd").new()
		extra.discovery_enabled = false
		add_child(extra)
		other_guests.append(extra)
		check(extra.join("127.0.0.1", "Gast %d" % index, port).ok, "Weiterer Sitz verbindet")
		check(await until(func(): return extra.phase == "lobby"), "Weiterer Sitz in Lobby")
		extra.choose_house(index)
		extra.set_ready(true)
		check(await until(func(): return bool(h.players[extra.local_peer_id].ready)), "Weiterer Sitz bereit")
	check(h.players.size() == 4, "Vier Menschenplätze vorhanden")
	check(h.start_match().ok, "Spiel starten")
	check(await until(func(): return g.phase == "playing"), "Gast-Spielansicht")
	check(host.game == h.game and guest.game == g.game and not guest.start_layer.visible, "Main nutzt die Netzspielwelt")
	check(guest.game.player == 1 and host.game.player == 0, "Getrennte Perspektiven")
	for extra in other_guests:
		check(await until(func(): return extra.phase == "playing"), "Dritter/vierter Gast erhält Spiel")
		check(Protocol.world_hash(extra.game.snapshot()) == Protocol.world_hash(host.game.snapshot()), "Vier Sitzwelten identisch")
	var reference: Dictionary = guest.map_view.atlas_data.lookup("geonames:2809346")
	guest.map_view.focus_atlas_location(reference)
	var reference_region: String = guest.selected
	var expected_revision: int = g.revision + 1
	h.revision += 1
	h._broadcast_snapshot()
	check(await until(func(): return int(g.revision) >= expected_revision), "Gast erhält aktualisierte Welt ohne Ansichtswechsel")
	check(guest.map_view.atlas_location == "Wiesbaden" and guest.map_view.atlas_layer.selected_id == str(reference.id)
		and guest.selected == reference_region, "Vollständiger WLAN-Stand erhält den lokalen Atlasort und seine Spielregion")
	# Real guest UI must send the nonce for the reward-free event escape too.
	var host_event_before = h.game.pending_event
	h.game.select_player_context(1)
	h.game.house().gold = 0
	for event in load("res://scripts/Data.gd").events():
		if str(event.id) == "tempeldach": h.game.pending_event = event.duplicate(true)
	h.game._event_instance += 1
	h.game.select_player_context(0)
	# The controlled host fixture is a new authoritative state, not a replay
	# of the start-match snapshot (clients correctly ignore equal revisions).
	h.revision += 1
	h._broadcast_snapshot()
	check(await until(func(): return g.game.pending_event != null and str(g.game.pending_event.id) == "tempeldach"), "Gast erhält sein unbezahlbares Ereignis")
	guest.refresh()
	var decline_button: Button
	for row in guest.event_buttons.get_children():
		if row.get_child_count() > 0 and row.get_child(0) is Button and row.get_child(0).text.contains("Derzeit ablehnen"):
			decline_button = row.get_child(0)
	check(decline_button != null and not decline_button.disabled, "Gast kann die bedingte Ablehnung im echten Ereignisdialog bedienen")
	if decline_button != null:
		decline_button.pressed.emit()
		check(await until(func(): return not g.pending_command and g.game.pending_event == null), "Gast-UI sendet gültige Ereignisinstanz; Host bestätigt Ablehnung")
		check(int(g.game.house().gold) == 0 and h.game.pending_event == host_event_before, "Ablehnung gibt kein Gold und beantwortet kein fremdes Hostereignis")
	guest._on_province_selected(str(host.game.houses[0].capital))
	guest.map_view.zoom_by(1.2)
	var local_pan: Vector2 = guest.map_view.pan
	var local_zoom: float = guest.map_view.zoom
	var local_selection: String = guest.selected
	var before := Protocol.world_hash(host.game.snapshot())
	var host_packets: Array = []
	var guest_packets: Array = []
	h._transport.peer_packet.connect(func(_id, raw):
		var packet = Protocol.decode_packet(raw).message
		host_packets.append([packet.get("type", ""), packet.get("sequence", 0)]))
	g._transport.peer_packet.connect(func(_id, raw):
		var packet = Protocol.decode_packet(raw).message
		guest_packets.append([packet.get("type", ""), packet.get("sequence", 0)]))
	guest._dispatch({"id":"develop"})
	var answered: bool = await until(func(): return not g.pending_command)
	if not answered:
		print("LANMAIN_DIAGNOSTIC host_packets=", host_packets, " guest_packets=", guest_packets, " host_revision=", h.revision, " guest_revision=", g.revision, " phase=", g.phase, " status=", g.status, " pending_sequence=", g._pending_sequence)
	check(answered, "Gastantwort trifft ein")
	check(not g.status.contains("gesendet") and guest.hint_label.text.contains(g.status), "Hostablehnung fehlt im Gast-Hinweis")
	check(Protocol.world_hash(host.game.snapshot()) == before, "Abgewiesener Gastbefehl veränderte Welt")
	check(guest.kernel.game == guest.game and guest.map_view.game == guest.game, "Kernel/Karte halten veraltete Gastwelt")
	check(guest.selected == local_selection and guest.map_view.pan == local_pan and guest.map_view.zoom == local_zoom, "Snapshot verändert lokale Kartenauswahl/Pan/Zoom")
	# Der sichtbare Autosave-Schalter gilt auch für den autoritativen Host.
	var save_path := "user://lan_partie.json"
	var had_save := FileAccess.file_exists(save_path)
	var old_save := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	host.settings["autosave"] = true
	host.game.year = 1000
	host.game.month = 12
	host._on_lan_updated()
	host.game.advance_month()
	host._on_lan_updated()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else null
	check(saved is Dictionary and int(saved.get("state", {}).get("year", 0)) == 1001, "Jährlicher LAN-Autosave fehlt")
	if had_save:
		var restore := FileAccess.open(save_path, FileAccess.WRITE)
		restore.store_buffer(old_save)
		restore.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	host.settings["autosave"] = false
	# Ein noch offenes Ereignis darf nach Ablehnung nicht verschwinden.
	h.game._trigger_event()
	h._broadcast_snapshot()
	host.refresh()
	check(host.event_layer.visible, "Hostereignis sichtbar")
	guest.lan_session.close_session("Testabbruch")
	check(await until(func(): return h.players.size() == 3), "Gastabbruch erkannt")
	check(host.lan_menu.visible and host.kernel.top_modal() == "lan", "Lobby bleibt bei offenem Ereignis unerreichbar")
	host._choose(0)
	check(h.game.pending_event != null and host.event_layer.visible, "Abgelehnte Ereignisantwort versteckt ausstehendes Ereignis")
	host.refresh()
	check(h.return_to_lobby().ok, "Rückkehr zur Lobby")
	check(host.lan_menu.visible and h.phase == "lobby", "Wiederaufnahmelobby sichtbar")
	host.lan_menu.hide_menu()
	host._start(0)
	check(not host.event_layer.visible and host.game.pending_event == null, "Altes LAN-Ereignis verdeckt neue Einzelspielerpartie")
	for extra in other_guests:
		extra.close_session()
		extra.queue_free()
	host.queue_free()
	guest.queue_free()
	await get_tree().process_frame
	print("LANMAININTEGRATIONTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.02).timeout
	return condition.call()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("LANMAININTEGRATIONTEST FAIL: ", message)
