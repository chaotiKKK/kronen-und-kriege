extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
const Save = preload("res://scripts/SaveGame.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	_test_zero_army()
	_test_monthly_ai()
	_test_ai_year_boundary()
	_test_human_army()
	_test_legacy_calendar()
	print("ARMYLIFECYCLETEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func _army(home: String, strength: int) -> Dictionary:
	return {"id":1,"province":home,"strength":strength,"upkeep":2,"morale":100}

func _test_zero_army() -> void:
	var g = Game.new(Data)
	var home := str(g.house().capital)
	var target := str(g.neighbours(home)[0])
	g.province(target).owner = 1
	g.province(target).levy = 100000
	g._add_claim(0,target)
	g.house().gold = 1000
	g.house().armies = [_army(home,1)]
	g.attack_roll_override = 1.0
	var defeat: Dictionary = g.attack(target)
	check(defeat.ok and defeat.get("won")==false,"Echter aufgelöster Niederlagepfad eines Ein-Mann-Heers")
	check(g.house().armies.is_empty() and g.army_for().is_empty(),"Aufgeriebene Armee hinterlässt weder Marker noch unsichtbare Aufstellungssperre")
	check(g.army_upkeep() == 0,"Aufgeriebenes Heer verlangt keinen Unterhalt")
	var restored = Game.new(Data)
	check(restored.restore(g.snapshot()) and restored.house().armies.is_empty(),"Speichern und Laden erzeugt keine Geisterarmee")
	check(restored.raise_army(home).ok and int(restored.army_for().strength) > 0,"Neue Armee nach Niederlage und Laden regulär aufstellbar")
	var legacy: Dictionary = g.snapshot()
	legacy.houses[0].armies = [_army(home,0)]
	check(restored.restore(legacy) and restored.house().armies.is_empty(),"Gültiger alter Null-Verband wird verlustfrei entfernt")
	check(restored.raise_army(home).ok,"Auch alter Null-Verband verhindert keine neue Aufstellung")
	g.house().armies = [_army(home,0)]
	check(g.raise_army(home).ok,"Lokaler leerer Alt-Verband ist direkt ersetzbar")
	legacy = g.snapshot()
	var survivor := _army(home,321)
	survivor.id = 7
	legacy.houses[0].armies = [_army(home,0),survivor]
	check(restored.restore(legacy) and restored.house().armies.size() == 1 and int(restored.army_for().strength) == 321 and int(restored.army_for().id) == 7,"Bereinigung entfernt nur leere Verbände und bewahrt gesunde Bestandsarmee samt ID")

func _route_fixture():
	var g = Game.new(Data)
	var home := str(g.houses[1].capital)
	var step := ""
	var target := ""
	for n in g.neighbours(home):
		for t in g.neighbours(str(n)):
			if str(t) != home and not g.neighbours(home).has(t):
				step = str(n)
				target = str(t)
	for p in g.provinces: p.owner = 0
	g.province(home).owner = 1
	g.province(step).owner = 1
	for h in g.houses:
		h.armies = []
		h.claims = []
		h.fleets = []
	g.houses[1].armies = [_army(home,500)]
	g.houses[1].gold = 1000
	# Isolierter Kalender-/Monatstakt mit tatsächlich bereitem Feldheer und
	# gedeckter Versorgung; keine vorausgesetzte alte Festungsformel.
	g.houses[1].ruler.martial=8
	g.houses[1].doctrine="balanced"
	g.houses[1].research.known=[]
	for id in [home,step]:
		g.province(id).levy=200
		g.province(id).terrain_supply=6
	g.province(target).levy=100
	g.province(target).defense=0
	g.province(target).terrain_defense=0
	g.province(target).terrain_supply=6
	g._add_claim(1,target)
	g.opinion[0] = 0
	g.month = 2
	return {"game":g,"home":home,"step":step,"target":target}

func _test_monthly_ai() -> void:
	var f = _route_fixture()
	var g = f.game
	var gold := int(g.houses[1].gold)
	var prestige := int(g.houses[1].prestige)
	g.advance_month()
	check(g.army_for(1).province == f.step,"Echter Monatswechsel bewegt KI zur Front")
	check(int(g.province(f.target).siege) == 0,"Marschmonat enthält keine zweite Belagerungsaktion")
	g.advance_month()
	check(int(g.province(f.target).siege) > 0,"Nächster echter Monatswechsel setzt KI-Belagerung fort")
	for index in 4: g.advance_month()
	check(int(g.province(f.target).owner) == 1,"KI erobert über mehrere echte Monate ohne Jahreswechsel")
	check(int(g.houses[1].gold) == gold,"Monatlicher Militärzug wiederholt keine jährlichen Goldausgaben")
	check(int(g.houses[1].prestige) == prestige,"Hof und jährliche Prestigeaktionen laufen nicht monatlich")
	check(g.houses[1].armies.size() == 1 and g.houses[1].claims.is_empty(),"Monats-KI stellt keine zusätzlichen Armeen auf und kauft keine Folgeansprüche")

func _test_ai_year_boundary() -> void:
	var f = _route_fixture()
	var g = f.game
	g.month = 12
	g.army_for(1).province = f.step
	# Eine erfolgreiche Jahresheirat würde rechtmäßig den Gegner befreunden;
	# dieser isolierte Takt-Test schaltet allein die Heiratskante ab.
	g.set_edge_enabled("AI3",false)
	var before: Dictionary = g.siege_preview(f.target,1)
	check(before.ok and before.coverage==1.0 and before.fort_bonus==0 and before.required_strength==35,"Jahresfixture hat echten vollen Nachschub, keine Festungsboni und35Mann Mindestdruck")
	check(before.progress==30,"Kontrollierter Festungsschritt ist literal30:20+floor(500/60)+floor(8/4)")
	g.advance_month()
	var after: Dictionary = g.siege_preview(f.target,1)
	check(after.progress==30 and after.coverage==1.0 and after.fort_bonus==0,"Jahresversorgung bewahrt dieselbe kontrollierte aktuelle Festungsquote")
	check(g.month == 1 and int(g.province(f.target).siege) == int(before.next) and int(g.province(f.target).siege)==30,"Jahreswechsel führt genau einen militärischen KI-Schritt gemäß tatsächlicher Vorschau aus")
	check(int(g.army_for(1).get("last_siege_month",-1)) == g._now(),"Jahreswechsel setzt dieselbe monatliche Armeewache")
	g.advance_month()
	check(int(g.province(f.target).siege) == int(after.next) and int(g.province(f.target).siege)==60,"Militärische KI führt im Februar genau den nächsten tatsächlichen Festungsschritt aus")

func _test_human_army() -> void:
	var f = _route_fixture()
	var g = f.game
	g.configure_human_houses([0,1])
	g.advance_month()
	check(g.army_for(1).province == f.home and int(g.province(f.target).siege) == 0,"KI bewegt auch inaktive menschliche LAN-Heere nicht")

func _test_legacy_calendar() -> void:
	var g = Game.new(Data)
	g.year = 1
	g.month = 12
	g.house().armies = [_army(str(g.house().capital),100)]
	g.house().armies[0].last_siege_month = g._now()
	var s: Dictionary = g.snapshot()
	s.schema_version = 11
	s.year = 0
	s.erase("calendar_version")
	s.erase("month_index")
	s.erase("campaign_sandbox")
	s.cooldowns = {"calendar_probe":24014}
	var m: Dictionary = Save.migrate(s)
	check(m.ok,"Legacy-Jahr null mit gültigem Roh-Armeedatum migriert: " + str(m.errors))
	var restored = Game.new(Data)
	check(restored.restore(s) and restored.year == 1 and restored.month == 12,"Legacy-Datum wird korrekt vor Prüfung interpretiert")
	check(restored._cooldown_left("calendar_probe") == 2,"Absolute Legacy-Frist behält Restdauer")
	s.houses[0].armies[0].last_siege_month = 24013
	check(not Save.migrate(s).ok,"Auch Legacy-Datum erlaubt keinen zukünftigen Armeemarker")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("ARMYLIFECYCLETEST FAIL: " + message)
