extends Node
## Kontrollierte echte 108er-Welten und zwei reale ENet-Peers, keine Main.
## Testkasse/Einheiten sind ausdrücklich Fixtures, keine Budgetkampagne.
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
	_protocol()
	if OS.get_cmdline_user_args().has("--protocol-only"):
		print("FORTRESSCAMPAIGNCOMMANDTEST PROTOCOL %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
		get_tree().quit(0 if failures==0 else 1)
		return
	_no_log_duplicates()
	_kernel()
	_authority()
	await _enet()
	print("FORTRESSCAMPAIGNCOMMANDTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func _protocol() -> void:
	for id in ["relieve","recover_army","disband_army"]:
		var command := {"id":id,"selection":HOME}
		if id=="disband_army": command["army"]=7
		var clean: Dictionary = Protocol.validate_command(command)
		if not clean.ok or clean.get("command",{})!=command:
			print("FORTRESSCAMPAIGNCOMMANDTEST PROTOCOL DETAIL: ",command," -> ",clean)
		check(clean.ok and clean.get("command",{})==command,"Protokoll akzeptiert nur die vorgesehene Zielabsicht: "+id)
		for key in ["house","won","cost","price","retreat","strength","morale","refund"]:
			var forged := command.duplicate(true)
			forged[key]=2
			check(not Protocol.validate_command(forged).ok,"Gast bestimmt kein Ergebnis-/Ressourcenfeld "+id+":"+key)
	for invalid in [0,-1,1.5,"7",null]:
		check(not Protocol.validate_command({"id":"disband_army","selection":HOME,"army":invalid}).ok,"Auflösung verlangt positive ganzzahlige Armee-ID")
	check(not Protocol.validate_command({"id":"recover_army","selection":HOME,"army":7}).ok,"Auffüllen ist Ziel-only und übernimmt keine Gast-Armeewahl")

func _fixture():
	var game = Game.new(Data,2)
	game.house().gold=1000
	game.province(HOME).levy=500
	game.house().armies=[{"id":7,"province":HOME,"strength":100,"morale":40,"upkeep":1,"last_siege_month":0}]
	return game

func _no_log_duplicates() -> void:
	var game=_fixture()
	game.house().gold=0
	var kernel=Kernel.new()
	kernel.bind_game(game)
	kernel.select_province(HOME)
	for id in ["claim","army","fleet","blockade","attack","siege","march"]:
		var before: Dictionary=game.snapshot()
		check(not kernel.dispatch({"id":id}).ok and game.snapshot()==before,"Reine militärische Abweisung schreibt keine dauerhafte Notiz: "+id)
	var before: Dictionary=game.snapshot()
	check(kernel.dispatch({"id":"select_army","army":7}).ok and game.snapshot()==before,"Dieselbe vorhandene Armeewahl ist Navigation ohne zusätzliche Chroniknotiz")
	game=_fixture()
	kernel.bind_game(game)
	var destination: String=game.neighbours(HOME)[0]
	var log_size: int=game.log_lines.size()
	kernel.select_province(destination)
	var result: Dictionary=kernel.dispatch({"id":"march"})
	check(result.ok and game.log_lines.size()==log_size+1,"Ein tatsächlicher Landmarsch informiert genau einmal statt Modell- plus Kernelnotiz")

func _kernel() -> void:
	var game = _fixture()
	var kernel = Kernel.new()
	kernel.bind_game(game)
	kernel.select_province(HOME)
	kernel.state_changed.connect(func(_sections):refreshes+=1)
	var result: Dictionary = kernel.dispatch({"id":"recover_army"})
	if not check(result.ok,"Echter Kernel leitet Feldlageraktion an tatsächliche Game-Mutation"):
		return
	check(int(game.army_for().strength)==200 and int(game.army_for().morale)==60 and int(game.house().gold)==985 and int(game.province(HOME).levy)==400,"Feldlager kauft100echte Soldaten,20Moral für15Gold und zieht100örtliches Aufgebot ab")
	check(refreshes==1,"Aufgelöste Feldlageraktion aktualisiert den tatsächlichen UI-Zustand einmal")
	var before: Dictionary=game.snapshot()
	check(not kernel.dispatch({"id":"recover_army"}).ok and game.snapshot()==before,"Abgewiesene Wiederholung bucht weder History noch zweite Erholung")
	check(not kernel.dispatch({"id":"disband_army","army":99}).ok and game.snapshot()==before,"Veraltete bestätigte Armee-ID entfernt kein anderes Heer")
	for bad in [0,-1,1.5,"7",null]:
		check(not kernel.dispatch({"id":"disband_army","army":bad}).ok and game.snapshot()==before,"Lokaler Router sperrt ungültige Auflösungs-ID vor Mutation")
	kernel.select_province("")
	check(not kernel.dispatch({"id":"recover_army","selection":HOME}).ok and game.snapshot()==before,"Befehlsfeld ersetzt keine fehlende tatsächliche Kernelauswahl")
	game.month+=1
	kernel.select_province(HOME)
	var gold: int=game.house().gold
	var levy: int=game.province(HOME).levy
	check(kernel.dispatch({"id":"disband_army","army":7}).ok and game.house().armies.is_empty(),"Bestätigte aktuelle Armee am freien eigenen Ort wird wirklich aufgelöst")
	check(int(game.house().gold)==gold and int(game.province(HOME).levy)==levy,"Auflösung erzeugt weder Gold noch neue örtliche Soldaten")

func _authority() -> void:
	var game=_fixture()
	game.configure_human_houses([0,2])
	game.select_player_context(0)
	var authority=Authority.new(game,{1:0,42:2})
	var host_gold: int=game.houses[0].gold
	var result: Dictionary=authority.execute(42,1,{"id":"recover_army","selection":HOME})
	if not check(result.ok,"Autorität ordnet tatsächliche Erholung dem Gastsitz Wessex zu"):
		return
	check(game.player==0 and int(game.houses[0].gold)==host_gold and int(game.houses[2].gold)==985,"Hostperspektive und fremde Kasse bleiben bei Gastaktion erhalten")
	var before: Dictionary=game.snapshot()
	check(not authority.execute(42,2,{"id":"disband_army","selection":HOME,"army":99}).ok and game.snapshot()==before,"Host validiert Bestätigungs-ID erneut gegen den tatsächlichen Gastsitz")
	check(not authority.execute(42,3,{"id":"relieve","selection":HOME,"house":0}).ok and game.snapshot()==before,"Actor-Injektion bleibt auch im Entsatzpfad gesperrt")

func _enet() -> void:
	var probe=_fixture()
	if not check(probe.has_method("army_recovery_preview") and probe.has_method("relief_preview") and probe.has_method("disband_preview"),"Neue echte Game-Einstiegspunkte sind für Netzwerkprüfung vorhanden"):
		return
	var host=Session.new(Data)
	var guest=Session.new(Data)
	host.discovery_enabled=false
	guest.discovery_enabled=false
	add_child(host)
	add_child(guest)
	var port:=54000+OS.get_process_id()%1000
	check(host.host("Festungsfeldzug","Host",0,port).ok and guest.join("127.0.0.1","Wessex",port).ok,"Tatsächliche ENet-Sitzungen auf eigenem Prozessport geöffnet")
	if not check(await until(func():return guest.phase=="lobby" and host.players.size()==2),"Realer Festungs-Handshake erreicht Lobby"):
		await close(host,guest)
		return
	guest.choose_house(2)
	guest.set_ready(true)
	check(await until(func():return int(host.players[guest.local_peer_id].house)==2 and bool(host.players[guest.local_peer_id].ready)),"Gast wählt tatsächlichen Wessex-Sitz")
	check(host.start_match().ok and await until(func():return guest.phase=="playing"),"Host/Gast starten dieselbe echte Welt")
	if guest.phase!="playing":
		await close(host,guest)
		return
	var responses:Array=[]
	guest.command_finished.connect(func(result):responses.append(result))
	host.game.houses[2].gold=1000
	host.game.houses[2].armies=[{"id":7,"province":HOME,"strength":100,"morale":40,"upkeep":1,"last_siege_month":0}]
	host.game.province(HOME).levy=500
	push(host)
	check(await until(func():return not guest.game.army_for().is_empty() and int(guest.game.army_for().id)==7 and int(guest.game.house().gold)==1000),"Gast erhält ausdrücklich kontrollierte Feldlagerfixture als echten Snapshot")
	var prior:=responses.size()
	check(guest.submit({"id":"recover_army","selection":HOME}).ok,"Gast sendet reinen Ziel-Feldlagerbefehl")
	check(await until(func():return not guest.pending_command and responses.size()>prior),"Host bestätigt tatsächliche Feldlageraktion")
	check(responses[-1].ok and int(guest.game.army_for().strength)==200 and int(guest.game.house().gold)==985 and int(guest.game.province(HOME).levy)==400,"Gast erhält bezahlte wirkliche Soldatenübertragung")
	check(equal_world(host,guest),"Nach Auffüllen sind Host und Gast vollständig weltgleich")
	var save_path:="user://fortress-command-%d.json" % OS.get_process_id()
	check(host.save_host(save_path).ok and host.return_to_lobby().ok,"Tatsächlicher fortgeschrittener LAN-Spielstand wird gespeichert und zur Lobby zurückgekehrt")
	check(await until(func():return guest.phase=="lobby") and host.load_host_lobby(save_path).ok,"Gespeicherte Feldlagerpartie wird tatsächlich wieder geladen")
	guest.set_ready(true)
	check(await until(func():return bool(host.players[guest.local_peer_id].ready)) and host.start_match().ok and await until(func():return guest.phase=="playing"),"Echte gespeicherte Menschenhäuser setzen gemeinsam fort")
	var before:=Protocol.world_hash(host.game.snapshot())
	prior=responses.size()
	check(guest.submit({"id":"recover_army","selection":HOME}).ok and await until(func():return not guest.pending_command and responses.size()>prior),"Wirklicher monatsgesperrter Befehl erreicht nach Wiederaufnahme den Host")
	check(not responses[-1].ok and before==Protocol.world_hash(host.game.snapshot()) and equal_world(host,guest),"Wiederladen erneuert keine Aktion und erzeugt bei Abweisung keine Historymutation")
	var enemy: int=host.game.province(TARGET).owner
	host.game.month+=1
	host.game.houses[enemy].armies=[{"id":8,"province":HOME,"strength":100,"morale":100,"upkeep":1,"last_siege_month":0}]
	host.game.province(HOME).siege=40
	host.game.province(HOME).siege_owner=enemy
	host.game.attack_roll_override=1.15
	push(host)
	check(await until(func():return int(guest.game.province(HOME).siege)==40 and guest.game._now()==host.game._now()),"Gast erhält kontrollierte tatsächliche feindliche Belagerung im neuen Monat")
	prior=responses.size()
	check(guest.submit({"id":"relieve","selection":HOME}).ok and await until(func():return not guest.pending_command and responses.size()>prior),"Gast führt tatsächlichen Entsatz über ENet aus")
	check(responses[-1].ok and bool(responses[-1].get("won",false)) and int(guest.game.province(HOME).siege)==0 and int(guest.game.province(HOME).owner)==2,"Entsatz bestätigt echten Sieg und entfernt ungestützte Belagerung ohne Besitzwechsel")
	check(equal_world(host,guest),"Nach Entsatz sind Host und Gast weltgleich")
	host.game.month+=1
	push(host)
	check(await until(func():return guest.game._now()==host.game._now()),"Auflösung erreicht tatsächlich freien neuen Monat")
	var gold: int=host.game.houses[2].gold
	var levy: int=host.game.province(HOME).levy
	prior=responses.size()
	check(guest.submit({"id":"disband_army","selection":HOME,"army":7}).ok and await until(func():return not guest.pending_command and responses.size()>prior),"Gast sendet bestätigte aktuelle Armee-ID zur wirklichen Auflösung")
	check(responses[-1].ok and guest.game.house().armies.is_empty() and int(guest.game.house().gold)==gold and int(guest.game.province(HOME).levy)==levy and equal_world(host,guest),"Auflösung bleibt refundfrei und auf beiden echten Peers gleich")
	# Kontrollierter abgewehrter Sturm: echter Seerückzug, tatsächliche Verluste.
	host.game.month+=1
	host.game.houses[2].armies=[{"id":9,"province":TARGET,"strength":1000,"morale":100,"upkeep":4,"last_siege_month":0}]
	host.game.houses[2].claims=[{"province":TARGET,"strength":1,"expires":host.game._now()+12}]
	host.game.houses[2].fleets=[{"id":4,"province":TARGET,"station":TARGET,"ships":20,"morale":100,"upkeep":2,"last_naval_month":-1}]
	host.game.houses[enemy].armies=[{"id":8,"province":TARGET,"strength":4000,"morale":100,"upkeep":16,"last_siege_month":0}]
	host.game.province(TARGET).levy=3000
	host.game.attack_roll_override=.85
	push(host)
	check(await until(func():return not guest.game.army_for().is_empty() and int(guest.game.army_for().id)==9),"Gast erhält ausdrücklich kontrollierten Sturm-/Rückzugsfall")
	prior=responses.size()
	check(guest.submit({"id":"attack","selection":TARGET}).ok and await until(func():return not guest.pending_command and responses.size()>prior),"Gast fordert tatsächlichen vom Host aufzulösenden Sturm an")
	check(responses[-1].ok and responses[-1].has("won") and not bool(responses[-1].won),"Verlorener Sturm bleibt ok=true/won=false bis zum echten Gast")
	check(responses[-1].has("retreats") or responses[-1].has("retreat"),"Hostantwort erhält tatsächliche Rückzugsmetadaten")
	check(not guest.game.army_for().is_empty() and int(guest.game.army_for().strength)==800 and str(guest.game.army_for().province)==HOME and str(guest.game.fleet_for().station)==HOME,"Tatsächlicher verlorener Sturm verliert20Prozent und zieht über reales Geleit nach London zurück")
	check(equal_world(host,guest),"Auch nach mutierender Niederlage und Seerückzug bleiben beide echten Welten gleich")
	await close(host,guest)

func push(host) -> void:
	host.revision+=1
	host._broadcast_snapshot()

func equal_world(host,guest) -> bool:
	return Protocol.world_hash(host.game.snapshot())==Protocol.world_hash(guest.game.snapshot())

func until(condition: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await get_tree().create_timer(.02).timeout
	return condition.call()

func close(host,guest) -> void:
	guest.close_session()
	host.close_session()
	guest.queue_free()
	host.queue_free()
	for index in 3: await get_tree().process_frame

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("FORTRESSCAMPAIGNCOMMANDTEST FAIL: "+message)
	return ok
