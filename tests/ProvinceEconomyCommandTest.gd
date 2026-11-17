extends Node
## Tatsächliche ENet-Teilnehmer und reguläre Startkasse, keine Spielkernattrappen.
const Protocol = preload("res://scripts/LanProtocol.gd")
var checks := 0
var failures := 0
var host
var guest
var replies: Array = []

func _ready() -> void:
	check(Protocol.validate_command({"id":"province_focus","selection":"bohemia","focus":"agriculture"}).ok,"Provinzschwerpunkt ist ein ausdrücklich erlaubter Befehl")
	for field in ["house","gold","cost","months","focus_changed_month","economic_share"]:
		var injected := {"id":"province_focus","selection":"bohemia","focus":"agriculture"}
		injected[field] = 0
		check(not Protocol.validate_command(injected).ok,"Client darf keinen serverseitigen Wert einschleusen: " + field)
	check(not Protocol.validate_command({"id":"province_focus","selection":"bohemia","focus":1}).ok,"Fokus muss ein Bezeichner sein")
	if not Protocol.validate_command({"id":"province_focus","focus":"agriculture"}).ok:
		finish()
		return
	var Session = load("res://scripts/LanSession.gd")
	host = Session.new()
	guest = Session.new()
	host.discovery_enabled = false
	guest.discovery_enabled = false
	add_child(host)
	add_child(guest)
	var port := 46300 + OS.get_process_id()%600
	check(host.host("Versorgung", "Host",0,port).ok,"Eigene Hostlobby startet")
	check(guest.join("127.0.0.1","Gast",port).ok,"Gast verbindet sich über ENet")
	if not check(await until(func(): return guest.phase == "lobby" and host.players.size() == 2),"Zwei echte Peers erreichen die Lobby"):
		finish()
		return
	guest.choose_house(1)
	guest.set_ready(true)
	check(await until(func(): return host.players[guest.local_peer_id].ready),"Gastbereitschaft erreicht Host")
	check(host.start_match().ok,"Gemeinsame Partie startet")
	if not check(await until(func(): return guest.phase == "playing"),"Gast erhält Startzustand"):
		finish()
		return
	if not check(host.game.has_method("set_province_focus"),"Spielkern unterstützt den Schwerpunktwechsel"):
		finish()
		return
	guest.command_finished.connect(func(result): replies.append(result))
	var own := str(host.game.houses[1].capital)
	var foreign := str(host.game.houses[0].capital)
	var own_gold := int(host.game.houses[1].gold)
	var foreign_gold := int(host.game.houses[0].gold)
	var cost := maxi(1,roundi(20.0*float(host.game.province(own).economic_share)))
	var start_month := int(host.game.calendar_index())
	check(own_gold >= cost,"Reguläre Startkasse reicht für den echten Wechsel")
	check(await command({"id":"province_focus","selection":own,"focus":"agriculture"}),"Gastauftrag wird durch Host bestätigt")
	check(bool(replies[-1].ok),"Eigene Kornkammer wird angenommen")
	check(host.game.province(own).get("economic_focus") == "agriculture" and host.game.province(own).get("focus_changed_month") == start_month,"Host setzt Schwerpunkt und Bindungsbeginn")
	check(host.game.houses[1].gold == own_gold-cost and host.game.houses[0].gold == foreign_gold,"Kosten werden genau dem eigenen Haus belastet")
	check(same_world(),"Bestätigter Wechsel hat bei beiden Peers denselben Weltzustand")
	check(await command({"id":"province_focus","selection":foreign,"focus":"trade"}) and not bool(replies[-1].ok),"Gast darf fremde Provinz nicht verwalten")
	check(host.game.province(foreign).get("economic_focus") == "balanced" and host.game.houses[0].gold == foreign_gold and host.game.houses[1].gold == own_gold-cost,"Fremder Auftrag verändert weder Schwerpunkt noch Kassen")
	check(await command({"id":"province_focus","selection":own,"focus":"agriculture"}) and not bool(replies[-1].ok),"Gleiche Auswahl wird ohne zweite Buchung abgewiesen")
	check(await command({"id":"province_focus","selection":own,"focus":"trade"}) and not bool(replies[-1].ok),"Zwölfmonatige Bindung ist auf dem Host verbindlich")
	check(await command({"id":"province_focus","selection":own,"focus":"unknown"}) and not bool(replies[-1].ok),"Unbekannte Ausrichtung wird nicht angewandt")
	check(host.game.houses[1].gold == own_gold-cost and same_world(),"Abgewiesene Aufträge erhalten Kosten und Synchronität")
	var path := "user://province-economy-command-%d-%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(host.save_host(path).ok,"Fokussierter Zustand wird regulär gespeichert")
	check(host.return_to_lobby().ok,"Host öffnet Fortsetzungslobby")
	check(await until(func(): return guest.phase == "lobby"),"Gast folgt in Fortsetzungslobby")
	check(host.load_host_lobby(path).ok,"Host lädt gespeicherten Fokus und Zeitbindung")
	check(await until(func(): return guest.is_resuming()),"Gast erhält Wiederaufnahmeplätze")
	guest.set_ready(true)
	check(await until(func(): return host.players[guest.local_peer_id].ready),"Gast stimmt Fortsetzung zu")
	check(host.start_match().ok,"Gespeicherte Partie wird fortgesetzt")
	check(await until(func(): return guest.phase == "playing"),"Gast erhält geladenen Stand")
	check(host.game.province(own).get("economic_focus") == "agriculture" and host.game.province(own).get("focus_changed_month") == start_month and same_world(),"Save/Resume erhält Fokus, Frist und Weltgleichheit")
	check(await command({"id":"province_focus","selection":own,"focus":"trade"}) and not bool(replies[-1].ok),"Laden umgeht die Bindung nicht")
	# Direkter regulärer Monatsfortschritt spart Wandzeit; beide Peers bleiben pausiert.
	for month in 11:
		host.game.advance_month()
	host.revision += 1
	host._broadcast_snapshot()
	check(await until(func(): return guest.game.calendar_index() == start_month+11),"Elf reale Spielmonate werden an Gast synchronisiert")
	check(await command({"id":"province_focus","selection":own,"focus":"trade"}) and not bool(replies[-1].ok),"Nach elf Monaten bleibt der Wechsel gesperrt")
	host.game.advance_month()
	host.revision += 1
	host._broadcast_snapshot()
	check(await until(func(): return guest.game.calendar_index() == start_month+12),"Zwölfter Monat wird synchronisiert")
	var gold_after_year := int(host.game.houses[1].gold)
	check(await command({"id":"province_focus","selection":own,"focus":"trade"}) and bool(replies[-1].ok),"Nach zwölf Monaten ist der echte neue Wechsel erlaubt")
	check(host.game.houses[1].gold == gold_after_year-cost and host.game.province(own).economic_focus == "trade" and same_world(),"Erneuter Wechsel bucht einmal und synchronisiert die neue Ausrichtung")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	finish()

func same_world() -> bool:
	return Protocol.world_hash(host.game.snapshot()) == Protocol.world_hash(guest.game.snapshot())

func command(value: Dictionary) -> bool:
	var count := replies.size()
	if not guest.submit(value).ok:
		return false
	return await until(func(): return not guest.pending_command and replies.size() > count)

func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+6500
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.015).timeout
	return condition.call()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("PROVINCEECONOMYCOMMANDTEST FAIL: " + message)
	return ok

func finish() -> void:
	if host != null: host.close_session()
	if guest != null: guest.close_session()
	print("PROVINCEECONOMYCOMMANDTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)
