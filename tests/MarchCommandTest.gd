extends Node
const Protocol = preload("res://scripts/LanProtocol.gd")
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
const Authority = preload("res://scripts/LanAuthority.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	march_route_forecast()
	check(Protocol.validate_command({"id":"march","selection":"bohemia"}).ok,"Marschbefehl mit gewähltem Ziel wird zugelassen")
	check(not Protocol.validate_command({"id":"march","selection":"bohemia","house":0}).ok,"Client darf kein fremdes Haus vorgeben")
	check(not Protocol.validate_command({"id":"march","selection":"bohemia","strength":9999}).ok,"Client darf keine Armeestärke einschleusen")
	check(not Protocol.validate_command({"id":"march","selection":12}).ok,"Ungültiger Zieltyp wird abgewiesen")
	check(Protocol.validate_command({"id":"select_army","army":2}).ok,"Armeewahl ist ein ausdrücklicher Netzwerkbefehl")
	check(not Protocol.validate_command({"id":"select_army","army":2.5}).ok,"Gebrochene Armee-ID wird abgewiesen")
	check(not Protocol.validate_command({"id":"select_army","army":0}).ok,"Nichtpositive Armee-ID wird abgewiesen")
	check(not Protocol.validate_command({"id":"select_army","army":2,"house":0}).ok,"Armeewahl erlaubt keine fremde Hausvorgabe")
	if not Protocol.validate_command({"id":"march","selection":"bohemia"}).ok or not Protocol.validate_command({"id":"select_army","army":2}).ok:
		finish()
		return
	var game = Game.new(Data,0)
	if not game.has_method("march_army"):
		check(false,"Marschregeln fehlen im Spielkern")
		finish()
		return
	game.configure_human_houses([0,1])
	var home0 := str(game.houses[0].capital)
	var home1 := str(game.houses[1].capital)
	var next1 := str(game.neighbours(home1)[0])
	game.province(next1).owner = 1
	game.houses[0].armies = [{"id":1,"province":home0,"strength":400,"upkeep":2,"morale":100}]
	game.houses[1].armies = [{"id":1,"province":home1,"strength":400,"upkeep":2,"morale":100}]
	game.houses[0].armies.append({"id":77,"province":home0,"strength":100,"upkeep":1,"morale":100})
	game.houses[1].armies.append({"id":2,"province":home1,"strength":250,"upkeep":1,"morale":100})
	if not game.has_method("select_army"):
		check(false,"Eigene Feldarmee ist nicht auswählbar")
		finish()
		return
	var chooser := Authority.new(game,{1:0,2:1})
	var own_gold := int(game.houses[1].gold)
	var month := int(game.calendar_index())
	check(not chooser.execute(2,1,{"id":"select_army","army":77}).ok,"Gast wählt keine ausschließlich fremde Armee-ID")
	check(chooser.execute(2,2,{"id":"select_army","army":2}).ok,"Gast wählt eine eigene zweite Legacy-Armee")
	check(game.houses[1].armies[0].id == 2 and game.houses[1].armies[0].strength == 250 and game.houses[0].armies[0].id == 1,"Nur die eigene Armeereihenfolge ändert sich")
	check(game.player == 0 and game.houses[1].gold == own_gold and game.calendar_index() == month,"Armeewahl erhält Hostperspektive, Gold und Zeit")
	var selection_copy = Game.new(Data,0)
	check(selection_copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and selection_copy.houses[1].armies[0].id == 2,"Armeewahl bleibt nach Speichern und Laden erhalten")
	check(chooser.execute(2,3,{"id":"select_army","army":1}).ok,"Vorhandene erste Armee kann wieder gewählt werden")
	var kernel := Kernel.new()
	kernel.bind_game(game)
	kernel.select_province("missing")
	var before: Dictionary = game.snapshot()
	check(not kernel.dispatch({"id":"march"}).ok,"Unbekanntes Marschziel verändert keine Armee")
	check(game.houses[0].armies[0].province == home0,"Abgewiesener Marsch erhält Hoststandort")
	var authority := Authority.new(game,{1:0,2:1})
	check(not authority.execute(2,1,{"id":"march","selection":home0}).ok,"Gast verschiebt kein fremdes Heer")
	check(authority.execute(2,2,{"id":"march","selection":next1}).ok,"Gast marschiert im eigenen Kontext")
	check(game.player == 0 and game.houses[0].armies[0].province == home0 and game.houses[1].armies[0].province == next1,"Hostperspektive und fremdes Heer bleiben erhalten")
	check(game.houses[1].armies[0].strength == 400,"Marsch erzeugt keine zusätzlichen Truppen")
	check(not authority.execute(2,2,{"id":"march","selection":home1}).ok,"Doppelter Netzwerkbefehl wird nicht nochmals ausgeführt")
	check(not authority.execute(2,3,{"id":"march","selection":home1}).ok,"Zweiter Marsch im selben Monat wird abgewiesen")
	var saved: Dictionary = game.snapshot()
	var restored = Game.new(Data,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"Marschzustand ist speicherbar und ladbar")
	restored.select_player_context(1)
	var restored_kernel := Kernel.new()
	restored_kernel.bind_game(restored)
	restored_kernel.select_province(home1)
	check(not restored_kernel.dispatch({"id":"march"}).ok,"Laden umgeht keine monatliche Marschsperre")
	restored.advance_month()
	check(restored_kernel.dispatch({"id":"march"}).ok and restored.houses[1].armies[0].province == home1,"Nächster Monat erlaubt den nächsten benachbarten Schritt")
	finish()


func march_route_forecast() -> void:
	var game = Game.new(preload("res://scripts/GameRegionData.gd"),0)
	if not game.has_method("march_preview"):
		check(false,"Kriegsplanung bietet vor dem Befehl eine Versorgungsvorschau")
		return
	var source := "germanien__03"
	var gate := "germanien__02"
	var target := "gallien__05"
	var station: Dictionary = game.province(gate)
	var hostile: Dictionary = game.province(target)
	station.owner = 0
	hostile.owner = 2
	game.province(source).owner = 0
	game.province(source).economic_focus = "agriculture"
	game.province(source).logistics_sites.depot = 1
	game.set_opinion_value(0,2,-25)
	game._add_claim(0,target)
	game.houses[0].armies = [
		{"id":1,"province":gate,"strength":1800,"upkeep":12,"morale":100},
		{"id":3,"province":target,"strength":50,"upkeep":1,"morale":100},
	]
	game.roads.append({"from":gate,"to":source,"state":"complete","months":0,"builder":0,"construction":{}})
	var snapshot: Dictionary = game.snapshot()
	var preview: Dictionary = game.march_preview(target)
	check(preview.get("ok", false) and preview.get("origin","")==gate and preview.get("target","")==target,"Der mögliche Grenzmarsch hat einen gerichteten Anfang und ein Ziel")
	if not preview.get("ok", false): return
	var supply: Dictionary = preview.supply
	check(int(supply.demand)==1850,"Beide eigenen Heere teilen dieselbe Versorgung am Ziel")
	check(int(supply["import"])>0 and int(supply.shortfall)>0,"Fertiges Depot lindert, aber deckt den Engpass eines großen Heeres nicht vollständig")
	check(preview.depots==[source] and preview.get("annual_loss",0)>0,"Die Vorschau weist echtes Depot und das bei gleicher Lage fällige Verlustbudget aus")
	check(not snapshot.is_empty() and game.snapshot()==snapshot,"Die Vorschau ändert weder Datum, Inventar, Heer, noch Chronik")
	var evidence := OS.get_environment("BQ_MARCH_CAMPAIGN_PROOF")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(snapshot))
	var home: Dictionary = game.march_preview(source)
	check(home.get("ok",false) and home.get("depots",[]).is_empty() and home.get("supply",{}).get("shortfall",-1)!=supply.shortfall,"Eigenes Nachbarland bietet eine unterscheidbare zweite Entscheidung")
	var far: Dictionary = game.march_preview("missing")
	check(not far.get("ok",true) and not far.has("supply") and far.get("reason","")==game.march_reason("missing"),"Unzulässige Ziele tragen den tatsächlichen Grund und keine Phantomversorgung")
	game.roads[0].state = "building"
	var cut: Dictionary = game.march_preview(target)
	check(cut.get("ok",false) and cut.get("depots",[]).is_empty() and int(cut.get("supply",{}).get("shortfall",0))==int(supply.shortfall)+int(supply["import"]),"Offene Baustelle trägt keinen Nachschub nach dem Marsch")
	game.roads[0].state = "complete"
	var previous_strength: int = int(game.army_for().strength)
	check(game.march_army(target).ok and game.army_for().province==target and int(game.army_for().strength)==previous_strength,"Bestätigung führt den bestehenden Marsch aus und verursacht keinen erfundenen Sofortverlust")
	var actual: Dictionary = game.supply_report().regions[target]
	check(actual==supply,"Prognose und tatsächliche Versorgung nach dem regulären Befehl stimmen überein")
	var current := game.army_for()
	var other: Dictionary = game.house().armies[1]
	var before_loss: int = int(current.strength)+int(other.strength)
	game._apply_army_supply(0)
	check(before_loss-int(current.strength)-int(other.strength)==int(preview.annual_loss),"Vorschau entspricht dem im Jahr fälligen gemeinsamen Verlustbudget")
	var repeated: Dictionary = game.march_preview(gate)
	check(not repeated.get("ok",true) and repeated.get("reason","").contains("Monat"),"Nach einem Marsch greift die bestehende Monatssperre auch in der Vorschau")
	print("MARCH_FORECAST open=",JSON.stringify(preview)," blocked=",JSON.stringify(cut)," alternate=",JSON.stringify(home))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("MARCHCOMMANDTEST FAIL: " + message)

func finish() -> void:
	print("MARCHCOMMANDTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)
