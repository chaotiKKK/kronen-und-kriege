extends Node
## Verbindungsrichtung, belegte Küstenpunkte und Datenfehler prüfen den echten
## Reader mit dem wirklichen Regionskatalog; kein Textur-/Hauptszenenpfad.
var checks := 0
var failures := 0
var route_script
var document: Dictionary

func _ready() -> void:
	if not check(FileAccess.file_exists("res://scripts/NavalRoutes.gd"),"Verbindlicher Reader für geprüfte Seewege vorhanden"):
		finish()
		return
	route_script = load("res://scripts/NavalRoutes.gd")
	var routes = route_script.new()
	if not check(routes.load_data(),"Eingebettete geprüfte Route lädt: "+str(routes.error_message)):
		finish()
		return
	document = JSON.parse_string(FileAccess.get_file_as_string("res://data/naval_routes.json"))
	var before_regions := FileAccess.get_sha256("res://data/game_regions.json")
	var before_geometry := FileAccess.get_sha256("res://data/game_region_geometry.bin")
	var forward: Dictionary = routes.route("britannien__03","gallien__04")
	check(not forward.is_empty(),"London–Brüssel besitzt die tatsächlich bewiesene direkte Kanalroute")
	if not forward.is_empty():
		check(str(forward.from)=="britannien__03" and str(forward.to)=="gallien__04","Route liefert die angeforderte Orientierung")
		var points: PackedVector2Array = forward.points
		check(points.size()==2 and points[0].distance_to(Vector2(244.58000027674163,408.30999989005585))<0.0001 and points[1].distance_to(Vector2(270.0573627821329,408.04879030824435))<0.0001,"Darstellung nutzt bewiesene Küstenanker statt Stadtlabel oder Innenpunkt")
		check(absf(float(forward.length_map_units)-25.478701510805966)<0.000001,"Tatsächliche Kartenlänge des geprüften Kanalübergangs bleibt erhalten")
		var reverse: Dictionary = routes.route("gallien__04","britannien__03")
		check(not reverse.is_empty() and reverse.id==forward.id and reverse.from=="gallien__04" and reverse.to=="britannien__03","Gegenrichtung verwendet denselben geprüften Übergang")
		if not reverse.is_empty():
			var reversed_points: PackedVector2Array = reverse.points
			check(reversed_points.size()==2 and reversed_points[0]==points[1] and reversed_points[1]==points[0],"Gegenrichtung vertauscht die tatsächlichen Küstenpunkte")
		forward.points[0] = Vector2.ZERO
		forward.proof.accepted = false
		check(routes.route("britannien__03","gallien__04").points[0] != Vector2.ZERO and routes.route("britannien__03","gallien__04").proof.accepted,"Aufrufermutationen verändern weder Geometrie noch Prüfbeleg")
	check(routes.destinations("britannien__03")==["gallien__04"] and routes.destinations("gallien__04")==["britannien__03"],"Verbindliche Nachbarn enthalten nur den geprüften Wasserweg in beiden Richtungen")
	var destinations: Array = routes.destinations("britannien__03")
	destinations.append("gallien__01")
	check(routes.destinations("britannien__03")==["gallien__04"],"Aufrufer kann keine unbewiesenen Seeziele nachträglich einschleusen")
	check(routes.is_port("britannien__03") and routes.is_port("gallien__04") and not routes.is_port("germanien__01"),"Nur tatsächlich verifizierte Endpunkte gelten als Transporthäfen")
	check(routes.route("britannien__03","britannien__03").is_empty() and routes.route("britannien__03","gallien__01").is_empty() and routes.route("unknown","gallien__04").is_empty(),"Selbstfahrt, ungeprüfte Küste und unbekanntes Gebiet erzeugen keine Verbindung")
	check(routes.destinations("unknown").is_empty(),"Unbekannter Hafen hat keine Seeziele")
	var catalog = load("res://scripts/GameRegionCatalog.gd").new()
	check(catalog.load_data(),"Unveränderter echter Regionskatalog lädt unabhängig vom Seeweg")
	check(not catalog.get_region("britannien__03").neighbours.has("gallien__04") and not catalog.get_region("gallien__04").neighbours.has("britannien__03"),"Der Kanalweg erzeugt keine künstliche Landnachbarschaft")
	var original_fingerprint: String = routes.fingerprint()
	check(original_fingerprint.length()==64 and original_fingerprint.is_valid_hex_number(false),"Geladene Routendefinitionen liefern einen Netzwerkfingerabdruck")
	var reordered := {}
	var keys: Array = document.keys()
	keys.reverse()
	for key in keys: reordered[key] = document[key]
	var copy = route_script.new()
	check(copy.load_bytes(JSON.stringify(reordered,"\t",true,true)) and copy.fingerprint()==original_fingerprint,"Schlüsselreihenfolge und JSON-Whitespace ändern keine logische Routendefinition")
	var renamed: Dictionary = document.duplicate(true)
	renamed.routes[0].name = "Geänderte Routendefinition"
	check(copy.load_bytes(JSON.stringify(renamed,"",true,true)) and copy.fingerprint()!=original_fingerprint,"Veränderte gültige Routendefinition liefert keinen konstanten Netzwerkfingerabdruck")
	_invalid_cases(routes)
	check(FileAccess.get_sha256("res://data/game_regions.json")==before_regions and FileAccess.get_sha256("res://data/game_region_geometry.bin")==before_geometry,"Routenlesen und Fehlervalidierung verändern keine Regions-/Landgeometriebytes")
	finish()

func _invalid_cases(routes) -> void:
	var cases: Array = []
	var changed: Dictionary = document.duplicate(true)
	changed.schema = 1.5
	cases.append([changed,"Bruchteiliges Schema ist kein still normalisiertes gültiges Format"])
	changed = document.duplicate(true)
	changed.catalog_hash = "0".repeat(64)
	cases.append([changed,"Anderer Regionskatalog wird abgewiesen"])
	changed = document.duplicate(true)
	changed.sources["data/game_regions.json"] = "0".repeat(64)
	cases.append([changed,"Falscher Hash der tatsächlichen Regionsdaten wird abgewiesen"])
	changed = document.duplicate(true)
	changed.sources["data/atlas_geometry.bin"] = "0".repeat(64)
	cases.append([changed,"Küstenquellen müssen an die im Katalog gebundenen Quellen anschließen"])
	changed = document.duplicate(true)
	changed.projection.size = [1200,761]
	cases.append([changed,"Falsche Kartenprojektion erzeugt keinen verschobenen Seeweg"])
	changed = document.duplicate(true)
	changed.routes[0].to = "unknown"
	cases.append([changed,"Nicht existierendes Ziel wird abgewiesen"])
	changed = document.duplicate(true)
	changed.routes[0].to = changed.routes[0].from
	cases.append([changed,"Selbstschleife wird abgewiesen"])
	changed = document.duplicate(true)
	changed.routes.append(changed.routes[0].duplicate(true))
	cases.append([changed,"Doppelter Routenbeleg wird nicht zweifach aufgenommen"])
	changed = document.duplicate(true)
	var reversed: Dictionary = changed.routes[0].duplicate(true)
	reversed.id = "duplicate_reverse"
	reversed.from = "gallien__04"
	reversed.to = "britannien__03"
	reversed.points.reverse()
	changed.routes.append(reversed)
	cases.append([changed,"Separater umgekehrter Doppeleintrag wird abgewiesen"])
	changed = document.duplicate(true)
	changed.routes[0].points = [[201.9835712,395.705],[270.0573627821329,408.04879030824435]]
	cases.append([changed,"Tatsächlicher Londoner Kapitalinnenanker ersetzt keinen geprüften Küstenanker"])
	changed = document.duplicate(true)
	changed.routes[0].points = [[244.58,408.31]]
	cases.append([changed,"Unvollständige Wasserlinie wird abgewiesen"])
	changed = document.duplicate(true)
	changed.routes[0].points[0] = ["244.58",408.31]
	cases.append([changed,"Zahlenähnlicher Text ist keine gültige Koordinate"])
	changed = document.duplicate(true)
	changed.routes[0].length_map_units = 150.5
	cases.append([changed,"Falsche beziehungsweise zu lange Etappenlänge wird abgewiesen"])
	changed = document.duplicate(true)
	changed.routes[0].proof.accepted = false
	cases.append([changed,"Fehlgeschlagene Vorwärtsprüfung erzeugt keine Freigabe"])
	changed = document.duplicate(true)
	changed.routes[0].proof.reverse_accepted = false
	cases.append([changed,"Nicht belegte Rückrichtung wird nicht aus Symmetrie erfunden"])
	changed = document.duplicate(true)
	changed.routes[0].proof.accepted = "true"
	cases.append([changed,"Wahrheitsähnlicher Text ersetzt keinen booleschen Wasserbeleg"])
	changed = document.duplicate(true)
	changed.routes[0].proof.land_contact_length = 0.5
	cases.append([changed,"Positive Strecke über Land sperrt den Eintrag"])
	changed = document.duplicate(true)
	changed.routes = []
	cases.append([changed,"Leere Routentabelle erzeugt keine scheinbar geladene Seekarte"])
	for entry in cases:
		check(not routes.load_bytes(JSON.stringify(entry[0])),str(entry[1]))
		check(not routes.error_message.is_empty() and routes.fingerprint().is_empty() and routes.route("britannien__03","gallien__04").is_empty() and routes.destinations("britannien__03").is_empty() and not routes.is_port("britannien__03"),"Fehlgeschlagener Reload gibt keine veraltete Freigabe oder Fingerabdruck zurück")
		check(routes.load_data(),"Nach Fehler lässt sich die unveränderte eingebettete Tabelle erneut laden")
	check(not routes.load_bytes("not-json"),"Unlesbares JSON wird abgewiesen")
	check(not routes.load_bytes("[]"),"Array statt Dokument wird abgewiesen")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("NAVALROUTETEST FAIL: "+message)
	return ok

func finish() -> void:
	print("NAVALROUTETEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
