extends Node
## Echte Game-API; kontrollierte Handelslagen getrennt von der Normalkampagne.
const Game=preload("res://scripts/Game.gd")
const Data=preload("res://scripts/GameRegionData.gd")
const Save=preload("res://scripts/SaveGame.gd")
var checks:=0
var failures:=0

func _ready() -> void:
	seed(20261118)
	var game=Game.new(Data,0)
	var before: Dictionary=game.snapshot()
	check(game.get("material_trades") is Array and game.get("material_trades").is_empty(),"Neue Partie beginnt ohne geschenkten Handelsvertrag")
	check(game.get("trade_serial")==0,"Neue Partie beginnt ohne verbrauchte Handelskennung")
	check(before.get("material_trades") is Array and before.get("material_trades").is_empty() and before.get("trade_serial")==0,"Echter Snapshot enthält den leeren kanonischen Handelszustand")
	var copy=Game.new(Data,0)
	check(copy.restore(JSON.parse_string(JSON.stringify(before))),"Vollständige reale Welt bleibt über JSON ladbar")
	check(copy.get("material_trades") is Array and copy.get("material_trades").is_empty() and copy.get("trade_serial")==0,"Laden erzeugt weder Vertrag noch Handelsfortschritt")
	check(Save.diff(before,copy.snapshot()).is_empty(),"Handelsgrundzustand bewahrt den bestehenden JSON-Roundtripvertrag")
	if not check_api(game):
		finish()
		return
	test_contract_lifecycle()
	test_expired_acceptance()
	test_own_reserves()
	test_same_month_reentry()
	test_shared_npc_need()
	finish()

func check_api(game) -> bool:
	var available:=true
	for method in ["material_trade_preview","offer_material_trade","accept_material_trade","cancel_material_trade","material_trade_options","_tick_material_trade"]:
		if not game.has_method(method): available=false
	check(available,"Game stellt die tatsächlichen Handelsbefehle und reine Vorschau bereit")
	return available

func test_contract_lifecycle() -> void:
	var game=Game.new(Data,0)
	var source:=""
	var target:=""
	for p in game.provinces:
		if int(p.owner)!=0: continue
		for id in game.neighbours(str(p.id)):
			if int(game.province(str(id)).owner)!=0:
				source=str(p.id); target=str(id); break
		if not source.is_empty(): break
	check(not source.is_empty() and not target.is_empty(),"Kontrollierte Handelslage verwendet eine echte eigene Landgrenze")
	if source.is_empty(): return
	var a: Dictionary=game.province(source)
	var b: Dictionary=game.province(target)
	var buyer:=int(b.owner)
	# Kontrollierte Bestände/Gelder ausschließlich für Regeln, keine Normalbudget-Abnahme.
	a.production.materials_u=game.ProductionScript.stock_capacity_u(a)
	game.houses[buyer].gold=10000
	check(game.start_regional_project(target,"walls",buyer).ok,"NPC-Käufer besitzt einen wirklich bezahlten Baustellenbedarf")
	var before: Dictionary=game.snapshot()
	var quote: Dictionary=game.material_trade_preview(source,target,0)
	check(bool(quote.get("ok",false)) and int(quote.get("lot_u",0))>0 and int(quote.get("lot_gold",0))>0,"Echte Grenzvorschau beziffert eine lieferbare bezahlte Charge")
	check(Save.diff(before,game.snapshot()).is_empty(),"Vorschau verändert keine Bestände, Kasse, Verträge oder History")
	if not bool(quote.get("ok",false)): return
	var gold_before:=int(game.house().gold)
	var stock_before:=int(a.production.materials_u)
	check(game.offer_material_trade(source,target,0).ok,"Menschlicher Verkäufer schließt den tatsächlich angenommenen NPC-Vertrag")
	if game.material_trades.is_empty():
		check(false,"Erfolgreicher Vertrag existiert im tatsächlichen Weltzustand")
		return
	var trade: Dictionary=game.material_trades[0]
	var id:=int(trade.id)
	check(trade.status=="active" and int(trade.accepted_month)==game.calendar_index() and int(game.trade_serial)==1,"NPC-Zustimmung erzeugt genau eine aktive Kennung mit aktuellem Annahmemonat")
	check(int(game.house().gold)==gold_before and int(a.production.materials_u)==stock_before,"Vertragsschluss erzeugt und bucht noch keine Güter oder Gelder")
	before=game.snapshot()
	check(not game.offer_material_trade(source,target,0).ok and Save.diff(before,game.snapshot()).is_empty(),"Doppeltes Angebot bleibt einschließlich Log unverändert")
	game._tick_material_trade()
	check(Save.diff(before,game.snapshot()).is_empty(),"Im Annahmemonat liefert die Handelsphase nicht")
	var restored=Game.new(Data,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(before))) and Save.diff(before,restored.snapshot()).is_empty(),"Angenommener echter Vertrag überlebt vollständiges Speichern und Laden")
	var buyer_gold:=int(game.houses[buyer].gold)
	var receiver_stock:=int(b.production.materials_u)
	game.month+=1 # Isolierte Handelsphase, absichtlich keine übrige Monatssimulation.
	game._tick_material_trade()
	check(int(a.production.materials_u)==stock_before-int(quote.lot_u) and int(b.production.materials_u)==receiver_stock+int(quote.lot_u),"Tatsächliche Handelsphase übergibt ausschließlich vorhandene ganze Ware")
	check(int(game.house().gold)==gold_before+int(quote.lot_gold) and int(game.houses[buyer].gold)==buyer_gold-int(quote.lot_gold),"Die Zahlung wechselt exakt zwischen beiden wirklichen Kassen")
	check(int(game.material_trades[0].delivered_lots)==1,"Genau eine Lieferung wird im Vertrag fortgeschrieben")
	before=game.snapshot()
	game._tick_material_trade()
	check(Save.diff(before,game.snapshot()).is_empty(),"Wiederholte gleiche Monatsphase liefert und loggt nicht doppelt")
	check(game.cancel_construction(target,int(b.regional_project.id),buyer).ok,"NPC-Baustelle wird für die gezielte Nachfrage-Gegenprobe regulär beendet")
	var rows: Array=game.material_trade_options(source,0)
	var shown_reason:=""
	for row in rows:
		if row.kind=="contract" and int(row.contract.id)==id: shown_reason=str(row.reason)
	check(shown_reason.contains("Baustelle"),"Bestehender Vertrag erklärt konkret die entfallene NPC-Baustellennachfrage")
	game.month+=1
	before=game.snapshot()
	game._tick_material_trade()
	check(Save.diff(before,game.snapshot()).is_empty(),"NPC kauft ohne aktuellen Baustellenbedarf auch aus aktivem Vertrag keine nutzlose Ware")
	check(game.start_regional_project(target,"walls",buyer).ok,"Weitere Zustimmungsfälle nutzen wieder eine echte bezahlte Nachfrage")
	var outsider:=0
	for hi in game.houses.size():
		if hi!=0 and hi!=buyer: outsider=hi; break
	before=game.snapshot()
	check(not game.cancel_material_trade(id,outsider).ok and Save.diff(before,game.snapshot()).is_empty(),"Unbeteiligtes Haus darf weder Vertrag noch Log verändern")
	check(game.cancel_material_trade(id,buyer).ok and game.material_trades.is_empty(),"Der echte Käufer darf künftige Lieferungen beenden")
	check(int(a.production.materials_u)==stock_before-int(quote.lot_u) and int(game.house().gold)==gold_before+int(quote.lot_gold),"Beendigung nimmt weder verkaufte Ware noch verdientes Geld zurück")
	check(game.configure_human_houses([0,buyer]),"Gleiche Welt wechselt für Zustimmungstest in zwei menschliche Rollen")
	check(game.offer_material_trade(source,target,0).ok,"Zwischen Menschen entsteht ein echtes Angebot")
	trade=game.material_trades[0]; id=int(trade.id)
	check(trade.status=="offered" and int(trade.accepted_month)==-1,"Zweite menschliche Zustimmung wird nicht automatisch vorgetäuscht")
	before=game.snapshot()
	check(not game.accept_material_trade(id,0).ok and Save.diff(before,game.snapshot()).is_empty(),"Vorschlagender kann seine eigene Gegenbestätigung nicht erzwingen")
	check(game.accept_material_trade(id,buyer).ok and game.material_trades[0].status=="active","Die tatsächliche Gegenseite nimmt an")
	check(Save.validate(game.snapshot()).is_empty(),"Aktueller menschlicher Vertrag bleibt strikt speicherbar")
	check(game.cancel_material_trade(id,0).ok and game.offer_material_trade(source,target,0).ok,"Ein neues menschliches Angebot bleibt ein eigener, frischer Vorgang")
	id=int(game.material_trades[0].id)
	a.owner=outsider # Historisch gültiger, nach Laden inzwischen anders besessener Standort.
	before=game.snapshot()
	check(not game.accept_material_trade(id,buyer).ok and Save.diff(before,game.snapshot()).is_empty(),"Alte Gegenseite darf ein inzwischen fremd besessenes Angebot weder annehmen noch protokollieren")
	a.owner=0
	game._capture_province(target,0,false,false)
	check(game.material_trades.is_empty(),"Normaler Besitzerwechsel beendet den nun sinnlosen Parteienvertrag")

func test_expired_acceptance() -> void:
	var game=Game.new(Data,0)
	var groups: Dictionary={}
	for p in game.provinces:
		if int(p.owner)!=0: continue
		for id in game.neighbours(str(p.id)):
			var q: Dictionary=game.province(str(id))
			if int(q.owner)==0: continue
			var key:=str(q.owner)
			if not groups.has(key): groups[key]=[]
			groups[key].append([str(p.id),str(q.id)])
	var buyer:=-1
	for key in groups:
		if groups[key].size()>=3: buyer=int(key); break
	check(buyer>=0,"Historische Annahmefixture hat drei verschiedene echte Grenzbeziehungen")
	if buyer<0: return
	game.configure_human_houses([0,buyer])
	game.month=8
	game.houses[buyer].gold=10000 # Kontrollierter Restorefall, keine normale Finanzierung.
	for index in 3:
		var relation: Array=groups[str(buyer)][index]
		var a: Dictionary=game.province(str(relation[0]))
		var b: Dictionary=game.province(str(relation[1]))
		a.production.materials_u=game.ProductionScript.stock_capacity_u(a)
		var quote: Dictionary=game.MaterialTradeScript.quote(a,b)
		game.material_trades.append({"id":index+1,"seller":0,"buyer":buyer,"from":str(a.id),"to":str(b.id),"proposer":0,"lot_u":quote.lot_u,"lot_gold":quote.lot_gold,"created_month":0 if index<2 else 2,"expires_month":6 if index<2 else 8,"accepted_month":0 if index<2 else -1,"last_delivery_month":-1,"delivered_lots":0,"status":"active" if index<2 else "offered"})
	game.trade_serial=3
	var historical: Dictionary=game.snapshot()
	check(Save.validate(historical).is_empty(),"Zwei historisch abgelaufene aktive Verträge und ein noch lieferfähiges Angebot sind vor Annahme speicherbar")
	check(game.accept_material_trade(3,buyer).ok,"Gegenseite kann das noch gültige Angebot trotz abgelaufener Altverträge annehmen")
	check(game.material_trades.size()==1 and int(game.material_trades[0].id)==3 and game.material_trades[0].status=="active","Erfolgreiche Annahme räumt tote Verträge vor der Aktivierung ab")
	if game.material_trades.size()==1:
		check(Save.validate(game.snapshot()).is_empty(),"Erfolgreiche Gegenbestätigung bleibt strikt speicherbar")
	var deadline=Game.new(Data,0)
	check(deadline.restore(historical),"Gleiche historische Angebotswelt wird für die Lieferfrist-Gegenprobe normal geladen")
	deadline.month=9 # Index8 ist der letzte mögliche Liefermonat des noch offenen Angebots.
	var before: Dictionary=deadline.snapshot()
	check(not deadline.accept_material_trade(3,buyer).ok and Save.diff(before,deadline.snapshot()).is_empty(),"Ein Angebot ohne verbleibenden künftigen Liefermonat wird ohne Änderung abgewiesen")
	var row: Dictionary={}
	var relation: Array=groups[str(buyer)][2]
	for option in deadline.material_trade_options(str(relation[1]),buyer):
		if option.kind=="contract" and int(option.contract.id)==3: row=option
	check(not row.is_empty() and not bool(row.can_accept) and str(row.reason).contains("Liefermonat"),"Ansicht bietet keine wirkungslose Gegenannahme an und erklärt die Lieferfrist")

func test_own_reserves() -> void:
	var game=Game.new(Data,0)
	var source:=""
	var target:=""
	var own_neighbor:=""
	for p in game.provinces:
		if int(p.owner)!=0: continue
		var foreign_id:=""
		var own_id:=""
		for id in game.neighbours(str(p.id)):
			if int(game.province(str(id)).owner)==0: own_id=str(id)
			else: foreign_id=str(id)
		if not foreign_id.is_empty() and not own_id.is_empty():
			source=str(p.id); target=foreign_id; own_neighbor=own_id; break
	check(not source.is_empty(),"Reservegegenprobe besitzt eine echte eigene und fremde Landnachbarschaft")
	if source.is_empty(): return
	var a: Dictionary=game.province(source)
	var b: Dictionary=game.province(target)
	var buyer:=int(b.owner)
	game.house().gold=10000; game.houses[buyer].gold=10000 # Ausschließlich kontrollierte Grenzfälle.
	check(game.start_regional_project(target,"walls",buyer).ok,"Reservefall hat tatsächliche NPC-Baustellennachfrage")
	var quote: Dictionary=game.MaterialTradeScript.quote(a,b)
	var reserve: int=2*game.ProductionScript.weight_u(a)
	a.production.materials_u=reserve
	check(not game.material_trade_preview(source,target,0).ok,"Der vollständige eigene Grundvorrat wird nicht als Überschuss verkauft")
	a.production.materials_u=reserve+int(quote.lot_u)
	check(game.material_trade_preview(source,target,0).ok,"Eine vollständige zusätzliche Charge ist ohne eigene Bindung verkäuflich")
	check(game.start_regional_project(source,"market",0).ok,"Eigener bezahlter Markt beansprucht denselben wirklichen Baustoffvorrat")
	var before: Dictionary=game.snapshot()
	check(not game.offer_material_trade(source,target,0).ok and Save.diff(before,game.snapshot()).is_empty(),"Eigene nächste Bauarbeit hat Vorrang und ein abgewiesener Verkauf ändert auch das Log nicht")
	check(game.cancel_construction(source,int(a.regional_project.id),0).ok,"Eigene direkte Bedarfsbindung wird regulär aufgehoben")
	var recipient: Dictionary=game.province(own_neighbor)
	recipient.production.materials_u=0
	check(game.start_regional_project(own_neighbor,"walls",0).ok,"Ein anderer eigener Ort besitzt einen bezahlten Baustellenbedarf")
	game.roads.append({"from":source,"to":own_neighbor,"builder":0,"months":0,"state":"complete","construction":{}}) # Kontrollierte bereits fertige echte Nachbarschaft.
	before=game.snapshot()
	check(not game.material_trade_preview(source,target,0).ok and Save.diff(before,game.snapshot()).is_empty(),"Bereits mögliche eigene Straßenlieferung wird vor fremdem Verkauf geschützt und nur vorgerechnet")
	check(game.cancel_construction(own_neighbor,int(recipient.regional_project.id),0).ok,"Eigene entfernte Nachfrage kann regulär entfallen")
	check(game.material_trade_preview(source,target,0).ok,"Ohne eigene Gegenbindung wird derselbe wirkliche Überschuss wieder handelbar")
	game._run_ai_trade()
	check(not game.material_trades.any(func(trade):return int(trade.seller)==0 or int(trade.buyer)==0),"NPC-Planung verplant keine menschliche Kasse oder menschlichen Vorräte automatisch")

func reentry_contract(game, id: int, source: Dictionary, target: Dictionary) -> Dictionary:
	var quote: Dictionary=game.MaterialTradeScript.quote(source,target)
	return {"id":id,"seller":int(source.owner),"buyer":int(target.owner),"from":str(source.id),"to":str(target.id),"proposer":int(source.owner),"lot_u":quote.lot_u,"lot_gold":quote.lot_gold,"created_month":0,"expires_month":6,"accepted_month":0,"last_delivery_month":-1,"delivered_lots":0,"status":"active"}

func test_same_month_reentry() -> void:
	# Controlled model-reentrancy case. Stocks and money are fixture values;
	# the separate MaterialTradeCampaignTest proves the unmodified budget path.
	var game=Game.new(Data,0)
	var source: Dictionary={}
	var target: Dictionary={}
	for p in game.provinces:
		if int(p.owner)!=0: continue
		for id in game.neighbours(str(p.id)):
			var other: Dictionary=game.province(str(id))
			if int(other.owner)!=0: source=p; target=other; break
		if not source.is_empty(): break
	check(not source.is_empty(),"Monatsreplay verwendet eine echte menschliche Exportgrenze")
	if source.is_empty(): return
	var buyer: int=target.owner
	var incoming:=reentry_contract(game,1,source,target)
	var other_source: Dictionary={}
	var other_target: Dictionary={}
	for p in game.provinces:
		if int(p.owner)!=buyer or str(p.id)==str(target.id): continue
		for id in game.neighbours(str(p.id)):
			var other: Dictionary=game.province(str(id))
			if int(other.owner) in [0,buyer]: continue
			var quote: Dictionary=game.MaterialTradeScript.quote(p,other)
			if int(quote.lot_gold)>=int(incoming.lot_gold): other_source=p; other_target=other; break
		if not other_source.is_empty(): break
	check(not other_source.is_empty(),"Derselbe NPC hat einen zweiten tatsächlichen Grenzverkauf an eine dritte Partei")
	if other_source.is_empty(): return
	var third: int=other_target.owner
	game.houses[buyer].gold=10000
	game.houses[third].gold=10000
	check(game.start_regional_project(str(target.id),"walls",buyer).ok and game.start_regional_project(str(other_target.id),"walls",third).ok,"Beide Käufer haben wirkliche bezahlte Baustellen")
	var reserve: int=maxi(int(game.EconomyPlannerScript.RULES.minimum_military_reserve),game.NavalCampaignScript.military_reserve(game,buyer))
	game.houses[buyer].gold=reserve
	source.production.materials_u=game.ProductionScript.stock_capacity_u(source)
	other_source.production.materials_u=game.ProductionScript.stock_capacity_u(other_source)
	game.material_trades=[incoming,reentry_contract(game,2,other_source,other_target)]
	game.trade_serial=2
	game.month=2 # Isolated next-month phase; no restored end-of-month state is replayed first.
	check(Save.validate(game.snapshot()).is_empty(),"Kontrollierter Handelszustand ist vor der ersten Monatsphase strikt gültig")
	check(int(game._material_trade_context().funds[str(buyer)])==0,"Der NPC startet ohne kaufbares Gold oberhalb seiner wirklichen Militärreserve")
	game._tick_material_trade()
	var first: Dictionary=game._last_material_trade.duplicate(true)
	check(first.deliveries.size()==1 and int(first.deliveries[0].trade_id)==2,"Erste wirkliche Phase führt den bereits finanzierbaren Verkauf tatsächlich aus")
	check(str(first.statuses.get("1","")).contains("bezahlen") and int(game._material_trade_find(1).delivered_lots)==0,"Die andere Charge bleibt trotz Verkaufserlös in derselben ersten Phase gesperrt")
	check(int(game.houses[buyer].gold)>reserve,"Der Verkauf hat das wirkliche NPC-Konto erhöht; der Folgetest ist kein leerer Replay")
	var before: Dictionary=game.snapshot()
	game._tick_material_trade()
	check(Save.diff(before,game.snapshot()).is_empty(),"Ein zweiter interner Aufruf im selben Monat kann das neue Verkaufsgeld nicht erneut verplanen")
	check(int(game._material_trade_find(1).delivered_lots)==0,"Monatsreplay erzeugt keine erste Lieferung des zuvor gesperrten Vertrags")
	var restored=Game.new(Data,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(before))),"Der tatsächlich abgeschlossene Monatsstand wird vollständig aus JSON geladen")
	var loaded: Dictionary=restored.snapshot()
	restored._tick_material_trade()
	check(Save.diff(loaded,restored.snapshot()).is_empty(),"Ein geladener abgeschlossener Monat ist ebenfalls ohne Doppelfinanzierung wiederholbar")
	var delivered_before: int=restored._material_trade_find(1).delivered_lots
	restored.month+=1
	restored._tick_material_trade()
	check(int(restored._material_trade_find(1).delivered_lots)==delivered_before+1,"Erst die neue Monatsphase nutzt das früher verdiente Gold für genau eine weitere Charge")
	check(Save.validate(restored.snapshot()).is_empty(),"Reentranzschutz und folgende echte Lieferung bleiben gemeinsam strikt speicherbar")

func test_shared_npc_need() -> void:
	# Controlled accounting case, not the normal-budget campaign. All regions,
	# adjacency and frozen recipes are real; only bounded progress/stocks/funds
	# establish a buyer whose entire remaining job needs less than two lots.
	var setup=Game.new(Data,0)
	var target: Dictionary=setup.province("skythien__01") # Budapest.
	var first: Dictionary=setup.province("germanien__05") # Wien.
	var second: Dictionary=setup.province("hellas__01") # Zagreb.
	check(setup.neighbours(str(target.id)).has(str(first.id)) and setup.neighbours(str(target.id)).has(str(second.id)),"Gemeinsamer NPC-Bedarf verwendet die echten Landgrenzen Wien–Budapest und Zagreb–Budapest")
	var buyer: int=target.owner
	setup.houses[buyer].gold=10000
	check(setup.start_regional_project(str(target.id),"walls",buyer).ok,"NPC-Bedarf gehört zu einem tatsächlich bezahlten, regelkonformen Mauernauftrag")
	var quote_a: Dictionary=setup.MaterialTradeScript.quote(first,target)
	var quote_b: Dictionary=setup.MaterialTradeScript.quote(second,target)
	var largest: int=maxi(int(quote_a.lot_u),int(quote_b.lot_u))
	var task: Dictionary=target.regional_project
	@warning_ignore("integer_division")
	var remaining_work: int=(int(task.work_total_u)*largest+int(task.material_total_u)-1)/int(task.material_total_u)
	task.work_done_u=int(task.work_total_u)-remaining_work
	task.material_spent_u=setup.ProductionScript.material_at_work(int(task.material_total_u),int(task.work_total_u),int(task.work_done_u))
	first.production.materials_u=setup.ProductionScript.stock_capacity_u(first)
	second.production.materials_u=setup.ProductionScript.stock_capacity_u(second)
	var remaining: int=int(task.material_total_u)-int(task.material_spent_u)
	var needed: int=setup._material_trade_context().needs[str(target.id)]
	check(needed==remaining and int(quote_a.lot_u)<=needed and int(quote_b.lot_u)<=needed and int(quote_a.lot_u)+int(quote_b.lot_u)>needed,"Jede einzelne Charge ist nötig, beide zusammen überschreiten aber den gesamten echten Restbedarf")
	check(setup.offer_material_trade(str(first.id),str(target.id),int(first.owner)).ok and setup.offer_material_trade(str(second.id),str(target.id),int(second.owner)).ok,"Zwei wirkliche Grenzparteien schließen die derzeit einzeln sinnvollen NPC-Verträge")
	var prepared: Dictionary=setup.snapshot()
	check(Save.validate(prepared).is_empty(),"Kontrollierter geteilter Bedarfsfall ist vor Ausführung strikt speicherbar")
	var single=Game.new(Data,0)
	check(single.restore(JSON.parse_string(JSON.stringify(prepared))) and single.cancel_material_trade(1,buyer).ok,"Einzelvertrags-Gegenprobe lädt dieselbe Welt und beendet nur den anderen künftigen Vertrag")
	var seller_before: int=single.houses[int(second.owner)].gold
	var buyer_before: int=single.houses[buyer].gold
	var stock_before: int=single.province(str(second.id)).production.materials_u
	single.month+=1 # A restored end-of-month state first advances to its next phase.
	single._tick_material_trade()
	var alone: Dictionary=single._last_material_trade
	check(alone.deliveries.size()==1 and int(alone.deliveries[0].trade_id)==2 and int(alone.deliveries[0].amount_u)==int(quote_b.lot_u),"Ein einzelner finanzierbarer Vertrag liefert weiterhin seine vollständige erforderliche Charge")
	check(int(single.province(str(second.id)).production.materials_u)==stock_before-int(quote_b.lot_u) and int(single.province(str(target.id)).production.materials_u)==int(quote_b.lot_u),"Einzelcharge verlässt den wirklichen Verkäuferbestand und erreicht vollständig das NPC-Lager")
	check(int(single.houses[int(second.owner)].gold)==seller_before+int(quote_b.lot_gold) and int(single.houses[buyer].gold)==buyer_before-int(quote_b.lot_gold),"Einzelcharge bezahlt den tatsächlichen Verkäufer exakt aus der tatsächlichen Käuferkasse")
	var shared=Game.new(Data,0)
	check(shared.restore(JSON.parse_string(JSON.stringify(prepared))),"Mehrvertrags-Gegenprobe beginnt mit exakt derselben bezahlten Ausgangslage")
	var gold: Dictionary={}
	var stocks: Dictionary={}
	for hi in shared.houses.size(): gold[str(hi)]=int(shared.houses[hi].gold)
	for p in shared.provinces: stocks[str(p.id)]=int(p.production.materials_u)
	shared.month+=1
	shared._tick_material_trade()
	var bought:=0
	var paid:=0
	for delivery in shared._last_material_trade.deliveries:
		if str(delivery.to)==str(target.id): bought+=int(delivery.amount_u); paid+=int(delivery.gold)
	check(bought>0 and bought<=needed,"Gleichzeitige NPC-Käufe teilen einen echten Bedarfsrahmen statt denselben Restbedarf doppelt zu bezahlen")
	check(shared._last_material_trade.deliveries.size()==1,"Nach einer vollen Charge reicht der Restbedarf nicht für eine weitere volle Charge")
	check(int(shared.houses[buyer].gold)==int(gold[str(buyer)])-paid and int(shared.province(str(target.id)).production.materials_u)==bought,"Nur wirklich benötigte volle Käufe belasten Konto und Lager des NPC")
	var gold_sum:=0
	var material_sum:=0
	for hi in shared.houses.size(): gold_sum+=int(shared.houses[hi].gold)-int(gold[str(hi)])
	for p in shared.provinces: material_sum+=int(p.production.materials_u)-int(stocks[str(p.id)])
	check(gold_sum==0 and material_sum==0 and Save.validate(shared.snapshot()).is_empty(),"Bedarfsbegrenzung erhält sämtliche tatsächlichen Weltkonten und eine gültige Vertragswelt")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADEGAMETEST FAIL: "+message)

func finish() -> void:
	print("MATERIALTRADEGAMETEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
