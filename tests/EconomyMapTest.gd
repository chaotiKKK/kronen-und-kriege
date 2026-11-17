extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
const Map = preload("res://scripts/MapView.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var game = Game.new(Data)
	var home := str(game.house().capital)
	var middle := str(game.neighbours(home)[0])
	game.province(middle).owner = game.player
	game.province(home).economic_focus = "agriculture"
	game.province(home).focus_changed_month = game.calendar_index()
	game.roads = [{"from":home,"to":middle,"state":"complete","months":0,"builder":game.player}]
	var map = Map.new()
	map.game = game
	map.size = Vector2(720,420)
	map.map_mode = "economy"
	map.selected = home
	var segments: Array = map.infrastructure_segments()
	check(segments.size()==1 and bool(segments[0].get("transport_active",false)),"Wirtschaftskarte kennt das tatsächlich nutzbare eigene Transportnetz")
	check(map.has_method("focus_markers"),"Provinzschwerpunkte sind auf der Wirtschaftskarte erkennbar")
	if map.has_method("focus_markers"):
		var markers: Array = map.focus_markers()
		check(markers.any(func(marker): return marker.id==home and marker.focus=="agriculture" and str(marker.label).contains("Kornkammer")),"Kornkammer zeigt Namen und richtigen Provinzstandort")
	game.province(middle).siege = 20
	game.province(middle).siege_owner = 1
	segments = map.infrastructure_segments()
	check(not bool(segments[0].get("transport_active",true)) and str(segments[0].get("transport_reason","")).contains("Belagerung"),"Feindliche Belagerung wird auch im Kartenpfad als Unterbrechung erklärt")
	game.province(middle).siege = 0
	game.province(middle).owner = 1
	segments = map.infrastructure_segments()
	check(not bool(segments[0].get("transport_active",true)),"Besitzverlust unterbricht Kartennetz sofort")
	map.map_mode = "political"
	if map.has_method("focus_markers"):
		check(map.focus_markers().is_empty(),"Schwerpunktsymbole überladen die übrigen Karten nicht")
	map.free()
	print("ECONOMYMAPTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("ECONOMYMAPTEST FAIL: "+message)
