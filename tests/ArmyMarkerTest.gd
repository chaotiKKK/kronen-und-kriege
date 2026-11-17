extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
const Map = preload("res://scripts/MapView.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var game = Game.new(Data)
	var map = Map.new()
	map.game = game
	map.size = Vector2(720,420)
	map.map_mode = "war"
	var home := str(game.house().capital)
	game.house().armies = []
	for i in 3:
		game.house().armies.append({"id":i+1,"province":home,"strength":200+i,"morale":100,"upkeep":1})
	for anchor in [Vector2(50,10),Vector2(710,10),Vector2(10,410),Vector2(710,410),Vector2(360,210)]:
		map.pan = Vector2.ZERO
		var fit: Array = map._fit()
		var point: Vector2 = map._label_point(game.province(home))*float(fit[0])+Vector2(fit[1])
		map.pan += anchor-point
		var markers: Array = map.army_markers()
		check(markers.size()==3,"Alle Verbände bleiben am Kartenrand vorhanden")
		for i in markers.size():
			var rect: Rect2 = markers[i].rect
			check(Rect2(Vector2.ZERO,map.size).encloses(rect),"Armeetrefferfläche liegt vollständig im Kartenbereich")
			check(rect.size.y >= 44,"Armeemarker besitzt mindestens44logischeTouchpunkte")
			for j in range(i):
				check(not rect.intersects(markers[j].rect),"Mehrere Verbände bleiben auch nach Randbegrenzung getrennt anwählbar")
	map.free()
	print("ARMYMARKERTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("ARMYMARKERTEST FAIL: "+message)
