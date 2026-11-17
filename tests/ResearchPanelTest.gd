extends Node
const Definitions = preload("res://scripts/Infrastructure.gd")

class HarnessMain extends "res://scripts/Main.gd":
	var audit_research
	var audit_commands: Array = []
	func _refresh_infrastructure() -> void:
		if audit_research != null:
			audit_research.refresh(game, selected)
	func _dispatch(command: Dictionary) -> Dictionary:
		audit_commands.append(command.duplicate(true))
		var result: Dictionary = kernel.dispatch(command)
		audit_research.refresh(game, selected)
		return result

var checks := 0
var failures := 0
var main

func _ready() -> void:
	var path := "res://scripts/ResearchPanel.gd"
	if not check(FileAccess.file_exists(path), "Detailliertes Forschungspanel fehlt"):
		finish()
		return
	seed(9141)
	main = HarnessMain.new()
	add_child(main)
	await settle()
	main._start(0)
	main.game.house().gold = 1000
	var parent := VBoxContainer.new()
	main.infrastructure_body.add_child(parent)
	var panel = load(path).new()
	main.audit_research = panel
	panel.configure(main, parent)
	panel.refresh(main.game)
	main._show_infrastructure()
	await settle()
	check(panel.cards.size() == Definitions.INNOVATIONS.size() and main.research_buttons.size() == 16, "Alle 16 Definitionen haben stabile Forschungskarten und echte Buttons")
	check(panel.scope_label.text.contains("gesamte") and panel.scope_label.text.contains("Haus"), "Hausweiter Geltungsbereich ist ausdrücklich sichtbar")
	check(panel.detail_labels["crop_rotation"].text.contains("10 %") and panel.prerequisite_labels["crop_rotation"].text.contains("Vermessung"), "Konkrete Wirkung und benannte Voraussetzung sind sichtbar")
	check(main.research_buttons["crop_rotation"].disabled and panel.reason_labels["crop_rotation"].text.contains("Vermessung"), "Nicht verfügbare Forschung erklärt ihre Sperre")
	var surveying: Button = main.research_buttons["surveying"]
	var identity := surveying.get_instance_id()
	check(not surveying.disabled, "Vermessung ist anfangs tatsächlich startbar")
	panel.set_branch("Militär")
	var shown := 0
	for key in panel.cards:
		if panel.cards[key].visible:
			shown += 1
			check(str(Definitions.INNOVATIONS[key].branch) == "Militär", "Zweigfilter zeigt nur militärische Projekte")
	check(shown == 4, "Militärischer Zweig enthält vier Projekte")
	panel.refresh(main.game)
	check(main.research_buttons["surveying"].get_instance_id() == identity and panel.selected_branch == "Militär", "Refresh erhält Kartenidentität und Zweigfilter")
	panel.set_branch("Alle")
	var before: int = main.game.house().gold
	surveying.pressed.emit()
	check(main.audit_commands == [{"id":"research","innovation":"surveying"}], "Forschung läuft ausschließlich durch Main._dispatch")
	check(main.game.house().gold == before - 20 and main.game.house().research.active == "surveying", "Realer Router bucht Kosten und Forschungsprojekt korrekt")
	check(panel.status_label.text.contains("Vermessung") and panel.progress_bar.visible and is_zero_approx(panel.progress_bar.value), "Bestätigung und echter Anfangsfortschritt sind sichtbar")
	for month in 2:
		main.game.advance_month()
	panel.refresh(main.game)
	check(absf(panel.progress_bar.value - 100.0 / 3.0) < 0.1 and main.research_label.text.contains("4 Monate"), "Fortschritt basiert auf zwei von sechs tatsächlich verstrichenen Monaten")
	panel.set_branch("Medizin")
	check(panel.progress_bar.visible and main.research_label.text.contains("Vermessung"), "Aktiver Fortschritt bleibt auch bei anderem Zweig sichtbar")
	for month in 4:
		main.game.advance_month()
	panel.refresh(main.game)
	check(main.game.house().research.known.has("surveying") and main.research_buttons["surveying"].text.contains("Erforscht"), "Abgeschlossene Forschung erhält ihren dauerhaften Status")
	check(panel.status_label.text.contains("abgeschlossen"), "Fertigstellung erscheint als eigener Forschungsstatus")
	panel.set_branch("Alle")
	check(not main.research_buttons["crop_rotation"].disabled, "Erfüllte Voraussetzung schaltet Fruchtwechsel frei")
	var selected: String = str(main.game.house().capital)
	main.game.province(selected).terrain = "mountains"
	panel.refresh(main.game, selected)
	check(panel.applicability_labels["crop_rotation"].text.contains("nicht") and panel.scope_label.text.contains(str(main.game.province(selected).name)), "Unpassendes Gelände in ausgewählter Region wird erklärt")
	main.game.house().gold = 0
	panel.refresh(main.game, selected)
	check(main.research_buttons["crop_rotation"].disabled and panel.reason_labels["crop_rotation"].text.contains("Gold"), "Goldmangel bleibt sichtbar statt nur als Tooltip")
	main.audit_research = null
	main.queue_free()
	await get_tree().process_frame
	finish()

func settle() -> void:
	for frame in 4:
		await get_tree().process_frame

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("RESEARCHPANELTEST FAIL: " + message)
	return ok

func finish() -> void:
	print("RESEARCHPANELTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
