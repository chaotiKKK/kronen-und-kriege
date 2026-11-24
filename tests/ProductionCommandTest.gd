extends Node
## Echte lokale ENet-Peers mit normalen Startkassen; keine UI-/Geräteattrappe.
const Session = preload("res://scripts/LanSession.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
var checks := 0
var failures := 0
var host
var guest
var replies: Array=[]

func _ready() -> void:
	seed(20261118)
	check(Protocol.validate_command({"id":"construction_cancel","selection":"bohemia","project":1}).ok,"Abbruch ist eine explizite neue LAN-Absicht")
	check(Protocol.validate_command({"id":"construction_priority","selection":"bohemia","project":1,"priority":1}).ok,"Vorrang besitzt einen typisierten LAN-Vertrag")
	for field in ["house","gold","paid_gold","materials_u","work_done_u","builder"]:
		var injected := {"id":"construction_cancel","selection":"bohemia","project":1}
		injected[field]=0
		check(not Protocol.validate_command(injected).ok,"Gast darf keinen autoritativen Produktionswert einschleusen: "+field)
	host=Session.new(); guest=Session.new()
	host.discovery_enabled=false; guest.discovery_enabled=false
	add_child(host); add_child(guest)
	var port := 47000+OS.get_process_id()%500
	check(host.host("Baustellen","Host",0,port).ok,"Eigene Produktionslobby startet")
	check(guest.join("127.0.0.1","Gast",port).ok,"Tatsächlicher Gast verbindet sich")
	if not check(await until(func():return guest.phase=="lobby" and host.players.size()==2),"Beide Peers erreichen die Lobby"):
		finish(); return
	guest.choose_house(1); guest.set_ready(true)
	if not check(await until(func():return host.players[guest.local_peer_id].ready),"Sitz und Bereitschaft erreichen Host"):
		finish(); return
	check(host.start_match().ok,"Gemeinsame Produktionswelt startet")
	if not check(await until(func():return guest.phase=="playing"),"Aktueller Schema17-Zustand kommt beim Gast an"):
		finish(); return
	host.game.speed=0
	guest.command_finished.connect(func(result):replies.append(result))
	var own: String=host.game.houses[1].capital
	var foreign: String=host.game.houses[0].capital
	var preview: Dictionary=host.game.regional_project_preview(own,"market",1)
	var gold: int=host.game.houses[1].gold
	check(preview.ok,"Normales Gastbudget reicht für ersten örtlichen Markt")
	check(await command({"id":"build","selection":own,"key":"market"}) and bool(replies[-1].ok),"Gast startet über echte Autorität einen Markt")
	var p: Dictionary=host.game.province(own)
	check(int(p.buildings.market)==0 and not p.regional_project.is_empty() and int(host.game.houses[1].gold)==gold-int(preview.gold),"Host zahlt einmal, speichert echten Auftrag und gibt keinen Soforteffekt")
	var id: int=p.regional_project.id
	check(same_world(),"Beide Peers erhalten denselben Produktionsweltzustand")
	var before := exact_host()
	check(await command({"id":"build","selection":own,"key":"walls"}) and not bool(replies[-1].ok),"Besetzter örtlicher Projektplatz weist zweite Absicht ab")
	check(exact_host()==before,"Abgewiesener zweiter Bau verändert weder History noch Ressourcen oder Seriennummer")
	check(await command({"id":"build","selection":foreign,"key":"market"}) and not bool(replies[-1].ok),"Gast kann fremde Bauverwaltung nicht erzwingen")
	check(exact_host()==before,"Fremde Absicht verschmutzt auch keine persönlichen Logbücher")
	check(await command({"id":"construction_cancel","selection":own,"project":id+100}) and not bool(replies[-1].ok),"Veraltete Projektkennung wird vom Host abgewiesen")
	check(exact_host()==before,"Ungültiger Abbruch bleibt im vollständigen Hostzustand neutral")
	check(await command({"id":"construction_priority","selection":own,"project":id,"priority":1}) and bool(replies[-1].ok),"Host bestätigt echten Vorrang für denselben Auftrag")
	check(int(p.regional_project.priority)==1 and same_world(),"Priorität wird bei beiden Peers identisch gespeichert")
	host.game.advance_month()
	host.revision+=1
	host._broadcast_snapshot()
	check(await until(func():return guest.game.calendar_index()==host.game.calendar_index()),"Realer Monatswechsel synchronisiert Arbeits-/Materialfortschritt")
	check(int(p.regional_project.work_done_u)>0 and int(p.regional_project.material_spent_u)>0 and same_world(),"Gast erhält den tatsächlichen Baustoffverbrauch und Arbeitsstand")
	gold=host.game.houses[1].gold
	var stock: int=p.production.materials_u
	check(await command({"id":"construction_cancel","selection":own,"project":id}) and bool(replies[-1].ok),"Gültiger Gastabbruch wird genau einmal angenommen")
	check(p.regional_project.is_empty() and int(host.game.houses[1].gold)==gold and int(p.production.materials_u)==stock and same_world(),"Abbruch erstattet nichts und erhält denselben örtlichen Restbestand bei beiden Peers")
	before=exact_host()
	check(await command({"id":"construction_cancel","selection":own,"project":id}) and not bool(replies[-1].ok),"Wiederholte Bestätigung kann keinen neuen Auftrag oder alten Vorrat treffen")
	check(exact_host()==before and same_world(),"Wiederholter Abbruch hat auch keinen Log-/Historyeffekt")
	await irrigation_command()
	await undertaking_command()
	finish()

func undertaking_command() -> void:
	var target: String = str(host.game.houses[1].capital)
	var start := {"id":"undertake_start","kind":"granary","province":target}
	check(await command(start) and bool(replies[-1].ok),"Gast nimmt über ENet ein eigenes Reichsvorhaben an")
	var host_plan: Dictionary=host.game.undertaking_board("",1).active
	var projection: Dictionary=host._authority.snapshot_for_peer(guest.local_peer_id)
	var frame: Dictionary={"v":Protocol.VERSION,"type":"snapshot","revision":host.revision,
		"hash":Protocol.world_hash(projection),"state":projection,"missing_peer":false,"all_over":false,
		"production_report":preload("res://scripts/ProductionNetworkReport.gd").pack(host.game._last_production,projection)}
	var serialized: PackedByteArray=Protocol.encode_packet(frame)
	check(not serialized.is_empty() and Protocol.decode_packet(serialized).ok,"Der angenommene Auftrag ist als echtes WLAN-Paket kodierbar")
	var arrived: bool=await until(func():return guest.game!=null and guest.game.undertaking_board().active==host_plan and same_world())
	check(host_plan.get("province")==target and arrived,"Autorisierter Auftrag wird bei beiden Peers identisch gespeichert · Gastgeber %s · Gast %s · Revisionen %d / %d" % [host.status,guest.status,host.revision,guest.revision])
	if host_plan.is_empty(): return
	var finish_order := {"id":"undertake_finish","token":int(host_plan.serial)}
	var prior: String=exact_host()
	check(await command(finish_order) and not bool(replies[-1].ok) and exact_host()==prior,"Host verweigert vorzeitige Auszahlung ohne Spielstandsänderung")

func irrigation_command() -> void:
	var id := "gallien__06"
	var region: Dictionary=host.game.province(id)
	if not check(int(region.owner)==1,"Gewählter Bewässerungsort gehört dem Gast"): return
	var order := {"id":"build","selection":id,"key":"irrigation_works"}
	check(await command(order) and not bool(replies[-1].ok),"Host lehnt ein Bewässerungswerk vor der Forschung ab")
	host.game.houses[1].research.known=["surveying","crop_rotation","irrigation"]
	var price: Dictionary=host.game.regional_project_preview(id,"irrigation_works",1)
	if not check(price.ok,"Gast verfügt über Forschung, Land und normales Budget für das Werk: "+str(price.reason)): return
	var gold: int=int(host.game.houses[1].gold)
	check(await command(order) and bool(replies[-1].ok),"Gast kann das Werk über den echten Host finanzieren")
	check(int(host.game.houses[1].gold)==gold-int(price.gold) and same_world(),"Bauauftrag wird genau einmal bezahlt und bei beiden Spielern synchronisiert")
	check(guest.game.province(id).regional_project.get("kind","")=="irrigation_works","Gast sieht denselben neuen Auftrag")

func exact_host() -> String:
	var state: Dictionary=host.game.snapshot()
	check(not state.is_empty(),"Verglichener Hostsnapshot ist tatsächlich gültig")
	return JSON.stringify(state).sha256_text()

func same_world() -> bool:
	return Protocol.world_hash(host.game.snapshot())==Protocol.world_hash(guest.game.snapshot())

func command(value: Dictionary) -> bool:
	var count := replies.size()
	if not guest.submit(value).ok: return false
	return await until(func():return not guest.pending_command and replies.size()>count)

func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.015).timeout
	return condition.call()

func check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("PRODUCTIONCOMMANDTEST FAIL: "+message)
	return ok

func finish() -> void:
	if host!=null: host.close_session()
	if guest!=null: guest.close_session()
	print("PRODUCTIONCOMMANDTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
