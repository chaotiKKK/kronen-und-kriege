extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
const Authority = preload("res://scripts/LanAuthority.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	_audit_catalog()
	_test_cost_rejection()
	_test_success_and_invalid()
	_test_house_authority()
	_test_decline()
	_test_decline_authority()
	print("EVENTCOSTGUARDTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)

func _event() -> Dictionary:
	for event in Data.events():
		if str(event.id) == "wasserquelle": return event.duplicate(true)
	return {}

func _fixture(gold: int):
	var g = Game.new(Data,0)
	g.house().gold = gold
	g.pending_event = _event()
	g._event_instance = 1
	return g

func _audit_catalog() -> void:
	var missing: Array = []
	var entries: Array = []
	for event in Data.events():
		var free := 0
		var paid := 0
		for option in event.options:
			if int(option.effects.get("gold",0)) < 0: paid += 1
			else: free += 1
		if free == 0: missing.append(str(event.id))
		entries.append({"id":event.id,"zero_gold_choices":free,"paid_choices":paid})
	check(entries.size() == 32,"Alle32 veröffentlichten Ereignisse werden geprüft")
	missing.sort()
	check(missing == ["gelehrtenstreit","tempeldach"],"Datenprüfung identifiziert exakt zwei Ereignisse ohne0GoldAlternative: " + str(missing))
	var f := FileAccess.open("res://build/verify/gameplay-long-campaign/event-cost-catalog.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"events":entries,"without_free_choice":missing},"\t"))
	f.close()

func _test_cost_rejection() -> void:
	var g = _fixture(3)
	check(g.has_method("event_option_reason"),"Gemeinsame UI-/Modellabfrage für Ereignisgründe vorhanden")
	if g.has_method("event_option_reason"):
		check(str(g.event_option_reason(0)).contains("Gold"),"18GoldOption bei3Gold nennt tatsächlichen Kostengrund")
		check(g.event_option_reason(1) == "","Kostenlose Alternative bleibt verfügbar")
	var before: Dictionary = g.snapshot()
	seed(191403)
	var expected := randi()
	seed(191403)
	var result = g.call("apply_event",0)
	check(result is Dictionary and not bool(result.get("ok",true)),"Game weist unbezahlbare positive Option explizit ab")
	check(g.snapshot() == before,"Abgewiesene Option verändert weder Geld noch Entwicklung, Ereignis, Frist oder Log")
	check(randi() == expected,"Abgewiesene Option verbraucht keine Zufallswerte")
	g = _fixture(3)
	var k := Kernel.new()
	k.bind_game(g)
	before = g.snapshot()
	var routed: Dictionary = k.dispatch({"id":"apply_event","option":0})
	check(not routed.ok and str(routed.message).contains("Gold"),"Kernel reicht Modellabweisung und lesbaren Kostengrund weiter")
	check(g.snapshot() == before,"Auch geroutete Abweisung bewahrt vollständigen Zustand")
	g = _fixture(17)
	before = g.snapshot()
	seed(191417)
	expected = randi()
	seed(191417)
	result = g.call("apply_event",0)
	check(result is Dictionary and not bool(result.get("ok",true)) and g.snapshot() == before,"Auch17Gold reichen für18GoldOption nicht aus")
	check(randi() == expected,"Auch17GoldAbweisung verbraucht keinen Zufallswert")

func _test_success_and_invalid() -> void:
	var g = _fixture(18)
	var p: Dictionary = g.owned()[0]
	var dev := int(p.dev)
	var result = g.call("apply_event",0)
	check(result is Dictionary and bool(result.get("ok",false)),"Exakt18Gold erlauben bezahlte Option")
	check(int(g.house().gold) == 0 and int(p.dev) == mini(10,dev+1),"Erfolgreiche Option bucht exakt18Gold und einmal Entwicklung")
	check(g.pending_event == null and g.event_timer >= 7 and g.event_timer <= 14,"Erfolg schließt Ereignis mit regulärer nächster Frist")
	var before: Dictionary = g.snapshot()
	result = g.call("apply_event",0)
	check(result is Dictionary and not bool(result.get("ok",true)) and g.snapshot() == before,"Bereits abgeschlossenes Ereignis gibt keine zweite Belohnung")
	g = _fixture(0)
	var k := Kernel.new()
	k.bind_game(g)
	check(k.dispatch({"id":"apply_event","option":1}).ok,"Kostenlose Alternative ist auch mit0Gold überKernel bedienbar")
	for index in [-1,2,999]:
		g = _fixture(18)
		before = g.snapshot()
		result = g.call("apply_event",index)
		check(result is Dictionary and not bool(result.get("ok",true)) and g.snapshot() == before,"Ungültiger Optionsindex verändert nichts")

func _test_house_authority() -> void:
	var g = Game.new(Data,0)
	g.configure_human_houses([0,1])
	g.house().gold = 500
	g.select_player_context(1)
	g.house().gold = 3
	g.pending_event = _event()
	g._event_instance = 1
	g.select_player_context(0)
	var authority := Authority.new(g,{1:0,2:1})
	var before: Dictionary = g.snapshot()
	var result: Dictionary = authority.execute(2,1,{"id":"apply_event","option":0,"event_instance":1})
	check(not result.ok,"Gast kann seine3Gold nicht mit der reichen Hostkasse ergänzen")
	check(g.player == 0 and g.snapshot() == before,"Autoritative Kostenabweisung erhält Host- und Gastperspektive vollständig")
	var restored = Game.new(Data,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(before))),"Noch offenes unbezahlbares Gast-Ereignis ist ladbar")
	var restored_authority := Authority.new(restored,{1:0,2:1})
	check(not restored_authority.execute(2,1,{"id":"apply_event","option":0,"event_instance":1}).ok,"JSON-/LAN-Roundtrip hebt Kostensperre nicht auf")
	check(restored_authority.execute(2,2,{"id":"apply_event","option":1,"event_instance":1}).ok,"Gast kann stattdessen seine kostenlose Alternative wählen")

func _test_decline() -> void:
	var g = _fixture(0)
	check(g.has_method("event_decline_reason") and g.has_method("decline_event"),"Belohnungsfreier gemeinsamer Verzichtspfad vorhanden")
	if not g.has_method("event_decline_reason") or not g.has_method("event_option_reason"): return
	for event in Data.events():
		g.house().gold = 0
		g.pending_event = event.duplicate(true)
		var available := 0
		var first_available := -1
		for index in event.options.size():
			if g.event_option_reason(index) == "":
				available += 1
				if first_available < 0: first_available = index
		check(available > 0 or g.event_decline_reason() == "","Alle32Ereignisse besitzen bei0Gold einen erkennbaren abschließbaren Pfad")
		check((g.event_decline_reason() == "") == (available == 0),"Verzicht ausschließlich wenn keine Originaloption bezahlbar ist")
		var closed: Dictionary = g.apply_event(first_available) if first_available >= 0 else g.decline_event()
		check(closed.ok and g.pending_event == null,"Jeder der32Nullgoldpfade lässt das Ereignis tatsächlich abschließen")
	for event in Data.events():
		if str(event.id) == "tempeldach": g.pending_event = event.duplicate(true)
	g.house().gold = 0
	var houses_before: Array = g.houses.duplicate(true)
	var original_gold := int(g.house().gold)
	var prestige := int(g.house().prestige)
	var dev := int(g.owned()[0].dev)
	var result: Dictionary = g.decline_event()
	check(result.ok and int(g.house().gold) == original_gold and int(g.house().prestige) == prestige and int(g.owned()[0].dev) == dev,"Tempeldach lässt sich ohne Geld, Effekt oder Belohnung ablehnen")
	check(g.houses == houses_before,"Verzicht verändert keinerlei Herrscher-, Heirats-, Ressourcen- oder Hauswerte")
	check(g.pending_event == null and g.event_timer >= 7 and g.event_timer <= 14,"Verzicht schließt Ereignis mit normaler Wartezeit")
	g = _fixture(0)
	var before: Dictionary = g.snapshot()
	seed(191499)
	var expected := randi()
	seed(191499)
	check(not g.decline_event().ok and g.snapshot() == before,"Kostenlose Originalalternative verhindert vorschnelles Ablehnen ohne Mutation")
	check(randi() == expected,"Abgewiesener Verzicht würfelt nichts")
	for event in Data.events():
		if str(event.id) == "gelehrtenstreit": g.pending_event = event.duplicate(true)
	g.house().gold = 15
	check(g.event_decline_reason() != "" and not g.decline_event().ok,"Exakt bezahlbare15GoldOriginaloption sperrt den Verzicht")

func _test_decline_authority() -> void:
	check(Protocol.validate_command({"id":"decline_event","event_instance":1}).ok,"Verzicht ist eigener whitelisted Befehl mit Ereignisnonce")
	check(not Protocol.validate_command({"id":"decline_event","event_instance":1,"option":0}).ok,"Verzicht nimmt keinen Originaloptionsparameter an")
	check(not Protocol.validate_command({"id":"decline_event","event_instance":1,"house":0}).ok,"Client darf dem Verzicht kein fremdes Haus zuweisen")
	check(not Protocol.validate_command({"id":"decline_event","event_instance":1,"gold":999}).ok,"Client darf keine Verzichtsbelohnung einschleusen")
	if not Protocol.validate_command({"id":"decline_event","event_instance":1}).ok: return
	var g = _fixture(100)
	g.configure_human_houses([0,1])
	g.select_player_context(1)
	g.house().gold = 0
	for event in Data.events():
		if str(event.id) == "tempeldach": g.pending_event = event.duplicate(true)
	g._event_instance = 1
	g.select_player_context(0)
	var authority := Authority.new(g,{1:0,2:1})
	var before: Dictionary = g.snapshot()
	check(not authority.execute(2,1,{"id":"decline_event","event_instance":99}).ok and g.snapshot() == before,"Falsche persönliche Gast-Ereignisinstanz wird ohne Mutation abgewiesen")
	check(authority.execute(2,2,{"id":"decline_event","event_instance":1}).ok,"Gast kann nur sein unbezahlbares Ereignis ohne Belohnung schließen")
	check(g.player == 0 and g.pending_event.id == "wasserquelle" and int(g.house().gold) == 100,"Gastverzicht erhält ursprüngliches Host-Ereignis und Hostkasse")
	var restored = Game.new(Data,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(g.snapshot()))),"Persönlicher Verzichtszustand ist als LANJSON ladbar")
	var resumed := Authority.new(restored,{1:0,2:1})
	check(not resumed.execute(2,1,{"id":"decline_event","event_instance":1}).ok,"Alte Gastinstanz bleibt nach Verzicht und Laden verbraucht")
	before = restored.snapshot()
	check(not resumed.execute(1,1,{"id":"decline_event","event_instance":1}).ok and restored.snapshot() == before,"Host kann seinen bezahlbaren Fall nicht über den Gast-Verzichtspfad verwerfen")

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("EVENTCOSTGUARDTEST FAIL: " + message)
