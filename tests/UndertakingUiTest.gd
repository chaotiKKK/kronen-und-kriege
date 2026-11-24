extends Node

var checks := 0
var fails := 0

func _ready() -> void:
	var main=load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.game.speed=0
	main._show_chronicle()
	await frames()
	var panel = main.chronicle_body.find_child("Reichsvorhaben",true,false)
	check(panel!=null,"Chronik enthält sichtbare Reichsvorhaben")
	check(not str(main.chronicle_body.get_child(0).text).begins_with("Haus Haus"),"Chronikkopf gibt den gespeicherten Hausnamen einmal wieder")
	if panel!=null:
		await play(main,panel)
	print("UNDERTAKINGUI %s: %d Prüfungen" % ["OK" if fails==0 else "FAIL",checks])
	get_tree().quit(0 if fails==0 else 1)

func play(main,panel) -> void:
	for kind in ["roads","granary","watch"]:
		var option: Button = panel.find_child("VorhabenStart_"+kind,true,false)
		check(option!=null and option.is_visible_in_tree() and not option.disabled,"Spielstart zeigt die Wahl "+kind)
	var choose: Button=panel.find_child("VorhabenStart_granary",true,false)
	var gold:int=main.game.house().gold
	choose.pressed.emit()
	await frames()
	var active: Dictionary=main.game.undertaking_board().active
	check(active.get("id")=="granary" and main.game.house().gold==gold,"Schaltfläche nimmt Vorhaben zum bekannten Preis null an")
	panel=main.chronicle_body.find_child("Reichsvorhaben",true,false)
	var redeem: Button=panel.find_child("VorhabenAbschluss",true,false)
	check(redeem.disabled,"Chronik sperrt eine vorzeitige Belohnung")
	panel.find_child("VorhabenKarte",true,false).pressed.emit()
	await frames()
	check(not main.chronicle_layer.visible and main.map_view.map_mode=="economy" and main.selected==active.province,"Zum Vorhaben springen wechselt in die richtige Karte und Provinz")
	check(main.map_view.undertaking_marker().get("id")==active.province,"Die Wirtschaftskarte kennt den echten Zielort")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var proof:=OS.get_environment("BQ_UNDERTAKING_RENDER")
		if not proof.is_empty():
			check(get_viewport().get_texture().get_image().save_png(proof.path_join("reichsvorhaben-karte.png"))==OK,"Kartenbeleg gespeichert")
	var source:=OS.get_environment("BQ_UNDERTAKING_READY_PROOF")
	if FileAccess.file_exists(source):
		check(main.game.restore(JSON.parse_string(FileAccess.get_file_as_string(source))),"Regulär erfüllter Auftrag wird in die Szene geladen")
	else:
		var p: Dictionary=main.game.province(str(active.province))
		p.economic_focus="agriculture"
		p.provisioning.food_u=preload("res://scripts/CivicProvision.gd").need_u(p)*4
		main.game.house().research.known=["surveying","crop_rotation"]
	main.refresh()
	main._show_chronicle()
	await frames()
	panel=main.chronicle_body.find_child("Reichsvorhaben",true,false)
	redeem=panel.find_child("VorhabenAbschluss",true,false)
	check(redeem.is_visible_in_tree() and not redeem.disabled,"Erfüllte Schritte geben die Auszahlung frei")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var proof:=OS.get_environment("BQ_UNDERTAKING_RENDER")
		if not proof.is_empty():
			check(get_viewport().get_texture().get_image().save_png(proof.path_join("reichsvorhaben-chronik.png"))==OK,"Chronikbeleg gespeichert")
	gold=int(main.game.house().gold)
	redeem.pressed.emit()
	await frames()
	check(int(main.game.house().gold)==gold+24 and main.game.undertaking_board().completed.has("granary"),"Chronik zahlt die wirkliche Belohnung genau einmal")

func frames() -> void:
	for i in 4: await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		fails+=1
		print("UNDERTAKINGUI FAIL: "+label)
