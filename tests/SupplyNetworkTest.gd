extends Node
## Reale, handgerechnete Bilanzen; keine Spielzustands- oder Netzwerkattrappen.
var checks := 0
var failures := 0
var supply

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/SupplyNetwork.gd"):
		check(false, "Versorgungsberechnung fehlt")
		finish()
		return
	supply = load("res://scripts/SupplyNetwork.gd")
	if supply == null:
		check(false, "Versorgungsmodul ist ladbar")
		finish()
		return
	test_local_capacity()
	test_export_reserve()
	test_proportional_distribution()
	test_rounding_ties()
	test_roads_and_foreign_nodes()
	test_determinism()
	test_conservation()
	finish()

func region(id: String, owner: int = 0, siege: int = 0, besieger: int = -1) -> Dictionary:
	return {"id":id,"owner":owner,"siege":siege,"siege_owner":besieger}

func army(id: int, location: String, strength: int) -> Dictionary:
	return {"id":id,"province":location,"strength":strength}

func road(a: String, b: String, state: String = "complete") -> Dictionary:
	return {"from":a,"to":b,"state":state}

func balance(report: Dictionary, id: String) -> Dictionary:
	return report.get("regions",{}).get(id,{})

func test_local_capacity() -> void:
	check(supply.calculate([],[],[],0,{}, {}) == {"regions":{},"roads":[],"networks":[]}, "Leere Welt erzeugt keine Versorgung")
	var provinces := [region("home"),region("reserve"),region("foreign",1),region("unused",1)]
	var armies := [army(2,"home",70),army(1,"home",60),army(3,"foreign",60)]
	var report: Dictionary = supply.calculate(provinces,[],armies,0,{"home":100,"reserve":50,"foreign":40},{"home":50,"reserve":20,"foreign":20})
	check(balance(report,"home").get("demand") == 130,"Mehrere eigene Heere teilen einen örtlichen Bedarf")
	check(balance(report,"home").get("local_capacity") == 100 and balance(report,"home").get("shortfall") == 30,"Örtliche Kapazität wird am selben Standort nicht je Heer vervielfacht")
	check(balance(report,"home").get("export_available") == 0,"Unterversorgtes Heimatheer exportiert nichts")
	check(balance(report,"reserve").get("export_available") == 20 and balance(report,"reserve").get("export") == 0,"Unbenötigter Export bleibt ohne Empfänger unverbraucht")
	check(balance(report,"foreign").get("local_capacity") == 40 and balance(report,"foreign").get("shortfall") == 20,"Eigenes Heer im Ausland erhält seine örtliche Versorgung")
	check(balance(report,"foreign").get("export_available") == 0 and balance(report,"foreign").get("import") == 0,"Fremde Standorte erhalten keinen eigenen Transport")
	check(not report.get("regions",{}).has("unused"),"Unbenutzte fremde Provinzen werden keine eigenen Bilanzregionen")
	check(report.get("networks",[]).size() == 2,"Nur eigene Provinzen bilden auch isolierte Netzkomponenten")

func test_export_reserve() -> void:
	var provinces := [region("source"),region("target"),region("base")]
	var report: Dictionary = supply.calculate(provinces,[road("source","target"),road("target","base")],[army(1,"source",130),army(2,"target",100)],0,{"source":150,"target":20,"base":500},{"source":50,"base":0})
	check(balance(report,"source").get("export_available") == 20 and balance(report,"source").get("export") == 20,"Export wahrt die örtliche Eigenbedarfsreserve")
	check(balance(report,"target").get("import") == 20 and balance(report,"target").get("shortfall") == 60,"Ziel erhält nur den echten verfügbaren Überschuss")
	check(balance(report,"base").get("export_available") == 0,"Hohe Grundkapazität allein erzeugt keinen Landwirtschaftsexport")
	check(balance(report,"source").get("shortfall") == 0,"Export erzeugt kein neues Defizit an der Quelle")
	var surplus: Dictionary = supply.calculate([region("a"),region("b")],[road("a","b")],[army(1,"b",4)],0,{"a":100,"b":0},{"a":50})
	check(balance(surplus,"a").get("export") == 4 and balance(surplus,"a").get("export_available") == 50,"Quellen verbrauchen nur die tatsächlich benötigte Menge")

func test_proportional_distribution() -> void:
	var provinces := [region("a"),region("z"),region("b"),region("c"),region("d")]
	var roads := [road("a","z"),road("z","b"),road("b","c"),road("c","d")]
	var report: Dictionary = supply.calculate(provinces,roads,[army(1,"b",1),army(2,"c",2),army(3,"d",3)],0,{"a":3,"z":2},{"a":3,"z":2})
	check(balance(report,"b").get("import") == 1 and balance(report,"c").get("import") == 2 and balance(report,"d").get("import") == 2,"Fünf Einheiten werden nach Defizit 1:2:3 mit größtem Rest verteilt")
	check(balance(report,"a").get("export") == 3 and balance(report,"z").get("export") == 2,"Verbrauchte Quellen decken genau die fünf Importe")
	var partial: Dictionary = supply.calculate(provinces,roads,[army(1,"b",1),army(2,"c",1),army(3,"d",2)],0,{"a":3,"z":2},{"a":3,"z":2})
	check(balance(partial,"a").get("export") == 2 and balance(partial,"z").get("export") == 2,"Auch begrenzter Quellenverbrauch verwendet größte Reste")
	check(balance(partial,"b").get("shortfall") == 0 and balance(partial,"d").get("shortfall") == 0,"Ausreichender Export deckt alle Defizite ohne Überversorgung")

func test_rounding_ties() -> void:
	var provinces := [region("source"),region("c"),region("b"),region("a")]
	var roads := [road("source","c"),road("source","b"),road("source","a")]
	var report: Dictionary = supply.calculate(provinces,roads,[army(3,"c",1),army(2,"b",1),army(1,"a",1)],0,{"source":2},{"source":2})
	check(balance(report,"a").get("import") == 1 and balance(report,"b").get("import") == 1 and balance(report,"c").get("import") == 0,"Gleiche Rundungsreste bevorzugen stabile Provinz-IDs")
	check(balance(report,"c").get("shortfall") == 1,"Rundungsrest erzeugt keine zusätzliche Einheit")

func test_roads_and_foreign_nodes() -> void:
	var provinces := [region("a"),region("b"),region("c")]
	var roads := [road("a","b"),road("b","c")]
	var armies := [army(1,"c",30)]
	var capacities := {"a":100}
	var bonuses := {"a":40}
	var connected: Dictionary = supply.calculate(provinces,roads,armies,0,capacities,bonuses)
	check(balance(connected,"c").get("import") == 30,"Fertige eigene Straßen transportieren über einen Zwischenknoten")
	provinces[1].siege = 1
	provinces[1].siege_owner = 1
	var besieged: Dictionary = supply.calculate(provinces,roads,armies,0,capacities,bonuses)
	check(balance(besieged,"c").get("import") == 0 and balance(besieged,"c").get("shortfall") == 30,"Feindliche Belagerung kappt den Transport sofort")
	check(inactive_with_reasons(besieged) == 2,"Unterbrochene Straßen haben lesbare Sperrgründe")
	provinces[1].siege_owner = 0
	check(balance(supply.calculate(provinces,roads,armies,0,capacities,bonuses),"c").get("import") == 30,"Eigener Belagerungsindex sperrt keinen eigenen Endpunkt")
	provinces[1].siege_owner = -1
	check(balance(supply.calculate(provinces,roads,armies,0,capacities,bonuses),"c").get("import") == 30,"Belagerungsfortschritt ohne gültigen Feind sperrt kein Netz")
	provinces[1].owner = 1
	var foreign: Dictionary = supply.calculate(provinces,roads,armies,0,capacities,bonuses)
	check(balance(foreign,"c").get("import") == 0 and inactive_with_reasons(foreign) == 2,"Fremder Zwischenbesitz wird nicht als Transportroute benutzt")
	provinces[1].owner = 0
	provinces[1].siege = 0
	roads[1].state = "building"
	check(balance(supply.calculate(provinces,roads,armies,0,capacities,bonuses),"c").get("import") == 0,"Straße im Bau transportiert noch nichts")
	var abroad: Dictionary = supply.calculate([region("a"),region("f",1)],[road("a","f")],[army(1,"f",25)],0,{"a":100,"f":10},{"a":50,"f":20})
	check(balance(abroad,"f").get("import") == 0 and balance(abroad,"f").get("shortfall") == 15,"Straße ins Ausland ersetzt keine fehlende örtliche Kapazität")
	var wrong_house: Dictionary = supply.calculate([region("a"),region("b")],[road("a","b")],[],1,{"a":100},{"a":50})
	check(wrong_house.get("regions",{}).is_empty() and inactive_with_reasons(wrong_house) == 1,"Hausindex grenzt das Netz auf die eigenen Endpunkte ein")

func inactive_with_reasons(report: Dictionary) -> int:
	var count := 0
	for entry in report.get("roads",[]):
		if not bool(entry.get("active",true)) and not str(entry.get("reason","")).is_empty():
			count += 1
	return count

func test_determinism() -> void:
	var provinces := [region("z"),region("c"),region("a"),region("b")]
	var roads := [road("z","a"),road("b","a"),road("a","b"),road("c","b"),road("b","c","building")]
	var armies := [army(9,"b",2),army(1,"c",1),army(4,"b",1)]
	var capacities := {"z":3,"a":2}
	var bonuses := {"z":3,"a":2}
	var original := JSON.stringify([provinces,roads,armies,capacities,bonuses])
	var report: Dictionary = supply.calculate(provinces,roads,armies,0,capacities,bonuses)
	check(JSON.stringify([provinces,roads,armies,capacities,bonuses]) == original,"Berechnung mutiert keine Eingaben")
	check(report.get("roads",[]).size() == 3,"Doppelte und umgekehrte Straßenkanten werden einmal gezählt")
	check(report.get("networks",[]).size() == 1 and balance(report,"c").get("import") == 1,"Doppelte Baustelle hebt eine fertige Verbindung nicht auf")
	provinces.reverse()
	roads.reverse()
	armies.reverse()
	var reordered: Dictionary = supply.calculate(provinces,roads,armies,0,capacities,bonuses)
	check(JSON.stringify(report) == JSON.stringify(reordered),"Gesamtausgabe bleibt bei anderer Eingabereihenfolge bytegleich")
	check(report.get("regions",{}).keys() == ["a","b","c","z"],"Regionsausgabe ist nach IDs sortiert")
	if not report.get("networks",[]).is_empty():
		check(report.networks[0].get("members",[]) == ["a","b","c","z"],"Netzmitglieder haben stabile Sortierung")
	else:
		check(false,"Verbundene Regionen liefern Netzmitglieder")
	var disconnected: Dictionary = supply.calculate([region("z"),region("a"),region("m")],[],[],0,{}, {})
	var ids: Array = []
	for network in disconnected.get("networks",[]):
		ids.append(network.get("id",""))
	check(ids == ["a","m","z"],"Getrennte Netze sind stabil sortiert")

func test_conservation() -> void:
	# Unterschiedliche ganzzahlige Defizite und knappe/exzessive Quellen.
	for available in [0,1,2,4,11,100]:
		var report: Dictionary = supply.calculate([region("s"),region("a"),region("b"),region("c")],[road("s","a"),road("a","b"),road("b","c")],[army(1,"a",3),army(2,"b",7),army(3,"c",11)],0,{"s":available},{"s":available})
		var imported := 0
		var exported := 0
		var valid := true
		for item in report.get("regions",{}).values():
			imported += int(item.get("import",0))
			exported += int(item.get("export",0))
			valid = valid and int(item.get("export",0)) <= int(item.get("export_available",0)) and int(item.get("export",0)) >= 0
			valid = valid and int(item.get("import",0)) + int(item.get("shortfall",0)) == maxi(0,int(item.get("demand",0))-int(item.get("local_capacity",0)))
		check(imported == mini(available,21) and exported == imported and valid,"Bilanz erhält jede Versorgungseinheit bei Quellmenge %d" % available)
		var networks: Array = report.get("networks",[])
		check(networks.size() == 1 and networks[0].get("export") == imported and networks[0].get("import") == imported and networks[0].get("shortfall") == 21-imported,"Netzsumme entspricht Regionen bei Quellmenge %d" % available)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("SUPPLYNETWORKTEST FAIL: " + message)

func finish() -> void:
	print("SUPPLYNETWORKTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)
