extends Node
## Kontrollierte 1000Gold-Fälle für echte Kernel-/Peerbefehle. Die reguläre
## Wessex-Budgetkampagne wird separat geprüft; hier keine Hauptszene/GPU.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
const Authority = preload("res://scripts/LanAuthority.gd")
const Session = preload("res://scripts/LanSession.gd")
const HOME := "britannien__03"
const TARGET := "gallien__04"
var checks := 0
var failures := 0
var refreshes := 0

func _ready() -> void:
	_protocol_cases()
	_kernel_cases()
	_authority_cases()
	await _enet_cases()
	print("NAVALCOMMANDTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func _protocol_cases() -> void:
	var checked: Dictionary = Protocol.validate_command({"id":"transport_army","selection":TARGET})
	check(checked.ok and checked.command=={"id":"transport_army","selection":TARGET},"Transportprotokoll übernimmt ausschließlich den gewählten Zielbezeichner")
	for key in ["house","route","price","capacity","landed","fleet","army","cost"]:
		var forged := {"id":"transport_army","selection":TARGET}
		forged[key] = 2
		check(not Protocol.validate_command(forged).ok,"Gast darf kein Transportfeld vorgeben: "+key)

func _funded():
	var game = Game.new(Data,2)
	game.house().gold = 1000
	check(game.raise_army(HOME).ok and game.raise_fleet(HOME).ok and game.fabricate_claim(TARGET).ok,"Kontrollierte Expedition bezahlt echtes Heer, Geleit und Küstenanspruch")
	game.houses[int(game.province(TARGET).owner)].fleets = []
	return game

func _kernel_cases() -> void:
	var game = _funded()
	var kernel = Kernel.new()
	kernel.bind_game(game)
	kernel.select_province(TARGET)
	kernel.state_changed.connect(func(_sections): refreshes+=1)
	var gold: int = game.house().gold
	var result: Dictionary = kernel.dispatch({"id":"transport_army"})
	check(result.ok and bool(result.get("landed",false)),"Kernel führt den wirklichen Transport aus und erhält landed=true")
	check(refreshes==1 and str(game.army_for().province)==TARGET and str(game.fleet_for().station)==TARGET,"Echte Landung aktualisiert Heer, Flotte und UI-Signal")
	check(int(game.house().gold)==gold,"Kernel erfindet keinen zusätzlichen Reisepreis")
	kernel.select_province(HOME)
	var prior_refreshes := refreshes
	var before: Dictionary = game.snapshot()
	var rejected: Dictionary = kernel.dispatch({"id":"transport_army"})
	check(not rejected.ok and game.snapshot()==before and refreshes==prior_refreshes,"Abgewiesene Monatswiederholung verändert auch im Kernel weder Welt noch Log")
	kernel.select_province("")
	check(not kernel.dispatch({"id":"transport_army","selection":TARGET}).ok and game.snapshot()==before,"Befehlsfeld ersetzt keine fehlende lokale Zielauswahl")
	game = _funded()
	var enemy: int = game.province(TARGET).owner
	game.houses[enemy].fleets = [{"id":1,"province":TARGET,"station":TARGET,"ships":40,"morale":100,"upkeep":4,"last_naval_month":-1}]
	game.attack_roll_override = 0.1
	kernel.bind_game(game)
	kernel.select_province(TARGET)
	refreshes = 0
	var ships: int = game.fleet_for().ships
	result = kernel.dispatch({"id":"transport_army"})
	check(result.ok and result.has("landed") and not bool(result.landed),"Tatsächlich abgewehrte Seeschlacht bleibt ok=true/landed=false im Kernel")
	check(refreshes==1 and str(game.army_for().province)==HOME,"Abgewehrter mutierender Versuch löst Refresh aus, ohne Soldaten zu versetzen")
	check(game.fleet_for().is_empty() or int(game.fleet_for().ships)<ships,"Aufgelöste Seeabwehr erhält die tatsächlichen Schiffsverluste")

func _authority_cases() -> void:
	var game = _funded()
	check(game.configure_human_houses([0,2]),"Zwei echte Menschenhäuser für Sitzautorität eingerichtet")
	game.select_player_context(0)
	var authority = Authority.new(game,{1:0,42:2})
	var host_gold: int = game.houses[0].gold
	var result: Dictionary = authority.execute(42,1,{"id":"transport_army","selection":TARGET})
	check(result.ok and bool(result.get("landed",false)) and str(game.houses[2].armies[0].province)==TARGET,"Serverseitiger Gastsitz transportiert das ihm zugeordnete Wessex-Heer")
	check(game.player==0 and int(game.houses[0].gold)==host_gold,"Befehl stellt Hostperspektive wieder her und belastet kein fremdes Haus")
	var before: Dictionary = game.snapshot()
	check(not authority.execute(42,1,{"id":"transport_army","selection":TARGET}).ok and game.snapshot()==before,"Replay derselben Transportsequenz bewirkt keine zweite Überfahrt")
	check(not authority.execute(42,2,{"id":"transport_army","selection":HOME,"house":0}).ok and game.snapshot()==before,"Gefälschtes Actorfeld bleibt vor jeder Transportmutation gesperrt")
	check(not authority.execute(1,1,{"id":"transport_army","selection":HOME}).ok and game.snapshot()==before,"Host kann mit eigener Autorität kein fremdes Feldheer zurückrufen")

func _enet_cases() -> void:
	var host = Session.new(Data)
	var guest = Session.new(Data)
	host.discovery_enabled = false
	guest.discovery_enabled = false
	add_child(host)
	add_child(guest)
	var port := 52000+OS.get_process_id()%1000
	check(host.host("Seetransport-Test","Host",0,port).ok and guest.join("127.0.0.1","Wessex",port).ok,"Zwei tatsächliche ENet-Sitzungen auf eigenem Testport verbunden")
	check(await until(func(): return guest.phase=="lobby" and host.players.size()==2),"Realer Host-/Gast-Handshake erreicht Lobby")
	if guest.phase!="lobby":
		await _close(host,guest)
		return
	guest.choose_house(2)
	guest.set_ready(true)
	check(await until(func(): return host.players.has(guest.local_peer_id) and int(host.players[guest.local_peer_id].house)==2 and bool(host.players[guest.local_peer_id].ready)),"Gast erhält ausdrücklich Wessex und bestätigt Bereitschaft")
	check(host.start_match().ok and await until(func(): return guest.phase=="playing"),"Beide tatsächlichen Sitzungen starten dieselbe Welt")
	if guest.phase!="playing":
		await _close(host,guest)
		return
	# Nur der autoritative Host erhält diese klar getrennte Kontrollkasse.
	host.game.select_player_context(2)
	host.game.house().gold = 1000
	check(host.game.raise_army(HOME).ok and host.game.raise_fleet(HOME).ok and host.game.fabricate_claim(TARGET).ok,"Host richtet kontrollierte Expedition über wirkliche Anschaffungsbefehle ein")
	host.game.houses[int(host.game.province(TARGET).owner)].fleets = []
	host.game.select_player_context(0)
	host.revision += 1
	host._broadcast_snapshot()
	check(await until(func(): return not guest.game.army_for().is_empty() and int(guest.game.house().gold)==850),"Gast erhält die bezahlte Expedition als echten persönlichen Snapshot")
	var responses: Array = []
	guest.command_finished.connect(func(result): responses.append(result))
	var original_host_gold: int = host.game.houses[0].gold
	var sent: Dictionary = guest.submit({"id":"transport_army","selection":TARGET})
	check(sent.ok,"Gast sendet tatsächlichen Ziel-only-Transportbefehl")
	if not sent.ok:
		await _close(host,guest)
		return
	check(await until(func(): return not guest.pending_command and not responses.is_empty() and str(guest.game.army_for().province)==TARGET),"Host bestätigt die Landung an den echten Gast")
	check(not responses.is_empty() and responses[-1].ok and bool(responses[-1].get("landed",false)),"ENet-Antwort erhält das aufgelöste Landungsergebnis")
	check(Protocol.world_hash(host.game.snapshot())==Protocol.world_hash(guest.game.snapshot()),"Nach Überfahrt besitzen Host und Gast dieselbe vollständige Welt")
	check(host.game.player==0 and guest.game.player==2 and int(host.game.houses[0].gold)==original_host_gold,"Netzwerktransport bewahrt Actor, Hostperspektive und fremde Kasse")
	var save_path := "user://naval-command-%d.json" % OS.get_process_id()
	check(host.save_host(save_path).ok,"Host speichert tatsächliche gemeinsame Partie nach Überfahrt")
	check(host.return_to_lobby().ok and await until(func(): return guest.phase=="lobby"),"Netzwerkpartie kehrt für echtes Wiederladen zur Lobby zurück")
	check(host.load_host_lobby(save_path).ok,"Gespeicherter aktueller LAN-Stand wird wirklich geladen")
	guest.set_ready(true)
	check(await until(func(): return bool(host.players[guest.local_peer_id].ready)) and host.start_match().ok,"Gespeicherte Menschenhäuser starten gemeinsam erneut")
	check(await until(func(): return guest.phase=="playing"),"Gast empfängt fortgesetzten Landungsstand")
	if guest.phase!="playing":
		await _close(host,guest)
		return
	check(str(guest.game.army_for().province)==TARGET and int(guest.game.fleet_for().get("last_naval_month",-1))==guest.game._now(),"Speichern/Wiederaufnahme erhält tatsächlichen Standort und verbrauchte Flottenaktion")
	var before: String = Protocol.world_hash(host.game.snapshot())
	var prior_responses := responses.size()
	check(guest.submit({"id":"transport_army","selection":HOME}).ok,"Gast sendet einen echten, noch monatsgesperrten Rückfahrtsversuch")
	check(await until(func(): return not guest.pending_command and responses.size()>prior_responses),"Monatssperre erreicht Gast als wirkliche Serverantwort")
	check(not responses[-1].ok and Protocol.world_hash(host.game.snapshot())==before and Protocol.world_hash(guest.game.snapshot())==before,"Abgewiesener Netzwerktransport verändert auch nach Wiederaufnahme keine Welt oder History")
	host.game.advance_month()
	host.game.houses[2].gold = 0
	host.revision += 1
	host._broadcast_snapshot()
	check(await until(func(): return guest.game._now()==host.game._now() and int(guest.game.house().gold)==0),"Getrennter Kontrollfall bringt tatsächlich neuen Monat und leere Reisekasse zum Gast")
	prior_responses = responses.size()
	check(guest.submit({"id":"transport_army","selection":HOME}).ok,"Gast kann regulären eigenen Rückweg ohne Reisepreis anfordern")
	check(await until(func(): return not guest.pending_command and responses.size()>prior_responses and str(guest.game.army_for().province)==HOME),"Host und Gast erhalten tatsächliche Rückkehr nach London")
	check(Protocol.world_hash(host.game.snapshot())==Protocol.world_hash(guest.game.snapshot()) and int(guest.game.house().gold)==0,"Rückweg bleibt weltgleich und erzeugt oder verbraucht kein Gold")
	# Zweiter klar kontrollierter Netzwerkfall: Die Hostschlacht verändert die
	# Welt, obwohl keine Landung stattfindet. Gast darf Verluste nicht verlieren.
	host.game.advance_month()
	var defender: int = host.game.province(TARGET).owner
	host.game.houses[defender].fleets = [{"id":1,"province":TARGET,"station":TARGET,"ships":40,"morale":100,"upkeep":4,"last_naval_month":-1}]
	host.game.attack_roll_override = 0.1
	host.revision += 1
	host._broadcast_snapshot()
	check(await until(func(): return guest.game._now()==host.game._now() and int(guest.game.houses[defender].fleets[0].ships)==40),"Gast empfängt den getrennten kontrollierten Seeabwehrfall")
	var ships_before: int = host.game.houses[2].fleets[0].ships
	prior_responses = responses.size()
	check(guest.submit({"id":"transport_army","selection":TARGET}).ok,"Gast fordert den tatsächlichen vom Host aufzulösenden Seekampf an")
	check(await until(func(): return not guest.pending_command and responses.size()>prior_responses),"Abgewehrter Transport erreicht den Gast als aufgelöste Antwort")
	check(responses[-1].ok and responses[-1].has("landed") and not bool(responses[-1].landed),"ENet erhält ausdrücklich ok=true und landed=false bei echter Seeabwehr")
	check(str(guest.game.army_for().province)==HOME and (guest.game.fleet_for().is_empty() or int(guest.game.fleet_for().ships)<ships_before),"Gast erhält wirkliche Schiffsverluste ohne versetzte Soldaten")
	check(Protocol.world_hash(host.game.snapshot())==Protocol.world_hash(guest.game.snapshot()),"Auch nach abgewehrter Landung sind Host und Gast vollständig weltgleich")
	await _close(host,guest)

func _close(host,guest) -> void:
	guest.close_session()
	host.close_session()
	guest.queue_free()
	host.queue_free()
	for index in 3: await get_tree().process_frame

func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.02).timeout
	return condition.call()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("NAVALCOMMANDTEST FAIL: "+message)
	return ok
