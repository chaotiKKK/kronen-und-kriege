extends Node
var checks := 0
var failures := 0

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/HouseDesign.gd"):
		check(false, "Gemeinsames Entwurfsmodell fehlt")
		finish()
		return
	var design = load("res://scripts/HouseDesign.gd")
	var data = load("res://scripts/GameRegionData.gd")
	var base: Dictionary = design.defaults(data)
	check(design.validate(base, data).ok, "Vollständiger Standardentwurf wird akzeptiert")
	var before := JSON.stringify(base)
	var accepted: Dictionary = design.validate(base, data)
	accepted.profile.house = "Mutation"
	check(JSON.stringify(base) == before, "Validierung isoliert den angenommenen Entwurf")
	for field in ["gold", "strength", "crest_file", "house_index", "unknown"]:
		var changed := base.duplicate(true)
		changed[field] = 100
		check(not design.validate(changed, data).ok, "Zusatzfeld wird verworfen: " + field)
	for field in ["martial", "diplomacy", "stewardship", "intrigue"]:
		var changed := base.duplicate(true)
		changed[field] = 3.5
		check(not design.validate(changed, data).ok, "Gebrochener Wert wird abgewiesen: " + field)
	var over := base.duplicate(true)
	for key in ["martial", "diplomacy", "stewardship", "intrigue"]:
		over[key] = 20
	check(not design.validate(over, data).ok, "Gemeinsames Punktebudget wird eingehalten")
	var exact := base.duplicate(true)
	exact.martial = 20
	exact.diplomacy = 12
	check(design.validate(exact, data).ok, "44 Punkte sind zulässig")
	for pair in [["portrait", -1],["crest", 999],["color", -1],["gender", "x"],["province", "../../file"],["doctrine", "unlimited"],["house", "A\nB"],["ruler", ""],["age", 100]]:
		var changed := base.duplicate(true)
		changed[pair[0]] = pair[1]
		check(not design.validate(changed, data).ok, "Ungültiger Entwurfswert: " + str(pair[0]))
	check(not design.validate({"house":"x".repeat(2049)}, data).ok, "Überlanger Entwurf wird vor Verarbeitung abgewiesen")
	for doctrine in ["balanced", "infantry", "cavalry", "siege"]:
		var changed := base.duplicate(true)
		changed.doctrine = doctrine
		check(design.validate(changed, data).ok, "Bekannte Armeedoktrin: " + doctrine)
	await dialog_cases(base)
	finish()

func dialog_cases(base: Dictionary) -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var received: Array = []
	var dialog = load("res://scripts/HouseDesignerDialog.gd").new()
	dialog.configure(main,base,func(profile): received.append(profile))
	dialog.fields.ruler.text = "Nicht übernehmen"
	dialog.cancel()
	check(received.is_empty() and base.ruler == "Ari" and main.game == null, "Abbrechen verändert weder Vorlage noch Spiel oder angenommene Profile")
	await get_tree().process_frame
	dialog = load("res://scripts/HouseDesignerDialog.gd").new()
	dialog.configure(main,base,func(profile): received.append(profile))
	dialog.fields.ruler.text = "Ari Entwurf"
	dialog.doctrine_picker.select(1)
	dialog.submit()
	check(received.size() == 1 and received[0].ruler == "Ari Entwurf" and received[0].doctrine == "infantry", "Dialog übergibt genau einen validierten Entwurf")
	check(main.kernel.top_modal() != "house_designer", "Bestätigung beendet das Entwurfsmodal")
	await get_tree().process_frame
	dialog = load("res://scripts/HouseDesignerDialog.gd").new()
	dialog.configure(main,base)
	main.get_meta("modern_interface").set_text_scale(2.0)
	for index in 4: await get_tree().process_frame
	check(main.get_viewport_rect().grow(1).encloses(dialog.apply_button.get_global_rect()), "Feste Bestätigung bleibt bei 200 Prozent erreichbar")
	check(main.get_viewport_rect().grow(1).encloses(dialog.cancel_button.get_global_rect()), "Fester Abbruch bleibt bei 200 Prozent erreichbar")
	check(dialog.scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Entwurf braucht kein horizontales Scrollen")
	for field in dialog.fields.values():
		check(field.get_global_rect().end.x <= main.get_viewport_rect().end.x, "Entwurfsfeld bleibt auch bei 200 Prozent innerhalb der Bildschirmbreite")
	for key in ["age", "martial", "diplomacy", "stewardship", "intrigue"]:
		check(dialog.fields[key].get_line_edit().get_theme_font_size("font_size") == 28, "Numerischer Entwurfswert skaliert auf 200 Prozent: " + key)
	var doctrine_caption: Label = null
	for label in dialog.find_children("*", "Label", true, false):
		if label.text in ["Armeedoktrin", "Doktrin"]: doctrine_caption = label
	check(doctrine_caption != null and doctrine_caption.get_theme_font("font").get_string_size(doctrine_caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, doctrine_caption.get_theme_font_size("font_size")).x <= doctrine_caption.size.x, "Doktrinbeschriftung bleibt bei 200 Prozent vollständig in einer Zeile")
	main.refresh()
	check(dialog.fields.age.get_line_edit().get_theme_font_size("font_size") == 28, "Wiederholtes Aktualisieren vergrößert numerische Werte nicht erneut")
	main.get_meta("modern_interface").set_text_scale(1.0)
	for index in 4: await get_tree().process_frame
	check(dialog.fields.age.get_line_edit().get_theme_font_size("font_size") == 14, "Numerischer Wert kehrt ohne Skalierungsdrift auf 100 Prozent zurück")
	dialog.cancel()
	var created := base.duplicate(true)
	created.age = 42
	created.portrait = 17
	created.doctrine = "cavalry"
	main._start_designed_house(created)
	check(main.game.custom_start and main.game.house().ruler.age == 42 and main.game.house().ruler.portrait == 17 and main.game.house().doctrine == "cavalry", "Singleplayer nutzt denselben Entwurf samt Alter, Porträt und Doktrin")
	main.lan_session.discovery_enabled = false
	main.lan_session.host("Editor-UI","Host",0,52000+OS.get_process_id()%500)
	main.lan_menu.show_menu()
	main.lan_menu._open_designer()
	main.lan_session.choose_house(0)
	check(main.kernel.top_modal() == "house_designer", "Lobby-Updates verdecken den Entwurf weder visuell noch im Modalzustand")
	main.lan_menu.designer.cancel()
	main.lan_menu.hide_menu()
	main.queue_free()
	await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("HOUSEDESIGNTEST FAIL: " + message)

func finish() -> void:
	print("HOUSEDESIGNTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
