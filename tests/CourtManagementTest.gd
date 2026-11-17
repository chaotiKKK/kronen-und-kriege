extends Node
class FakeLan extends RefCounted:
	var phase := "playing"
	var pending_command := false
	var status := ""

class HarnessMain extends "res://scripts/Main.gd":
	var audit_panel
	var audit_network
	var audit_dispatches := 0
	var audit_last_command := {}
	func _lan_active() -> bool:
		return false
	func _refresh_infrastructure() -> void:
		# This harness exercises the real Main refresh while isolating the
		# independently developed research panel.
		pass
	func _refresh_court() -> void:
		if audit_panel != null:
			audit_panel.refresh(game)
		else:
			super._refresh_court()
	func _dispatch(command: Dictionary) -> Dictionary:
		audit_dispatches += 1
		audit_last_command = command.duplicate(true)
		if audit_network != null:
			audit_network.pending_command = true
			audit_network.status = "Anfrage an Gastgeber gesendet."
			audit_panel.refresh(game)
			return {"ok":true,"message":audit_network.status}
		var result: Dictionary = kernel.dispatch(command)
		audit_panel.refresh(game)
		return result

var main
var checks := 0
var failures := 0

func _ready() -> void:
	var path := "res://scripts/CourtManagementPanel.gd"
	if not check(FileAccess.file_exists(path), "Stabile Hofverwaltung fehlt"):
		finish()
		return
	main = HarnessMain.new()
	add_child(main)
	await settle()
	main._start(0)
	main.game.house().gold = 1000
	main.game.house().prestige = 100
	if OS.get_cmdline_user_args().has("--probe-existing-court"):
		main._show_court()
		await settle()
		var old_button: Button = main.court_amenity_buttons["table"]
		var old_id := old_button.get_instance_id()
		old_button.grab_focus()
		main.refresh()
		await settle()
		check(main.court_amenity_buttons["table"].get_instance_id() == old_id, "Bestehender Hof erhält Aktionsnode bei Main.refresh")
		check(is_instance_valid(old_button) and get_viewport().gui_get_focus_owner() == old_button, "Bestehender Hof erhält Aktionsfokus bei Main.refresh")
		check(main.court_layer.find_child("HofAktionsstatus", true, false) != null, "Bestehender Hof zeigt eigenen Aktionsstatus")
		main.game.house().gold = 0
		main.refresh()
		check(_text(main.court_body).contains("Zu wenig Gold"), "Bestehender Hof erklärt die gesperrte Goldaktion")
		main.queue_free()
		await get_tree().process_frame
		finish()
		return
	main.audit_panel = load(path).new()
	main.audit_panel.configure(main)
	main._show_court()
	await settle()
	var panel = main.audit_panel
	check(not main.court_body.is_ancestor_of(panel.status_label), "Aktionsstatus bleibt außerhalb der scrollenden Aktionsliste")
	var hoftag: Button = panel.action_buttons["court"]
	check(hoftag.text.contains("Hoftag"), "Hoftag ist direkt in der Verwaltung verfügbar")
	check(panel.action_details["court"].text.contains("12 Prestige") and panel.action_details["court"].text.contains("Hofpracht"), "Hoftag beschreibt tatsächliche Prestige- und Hofprachtwirkung")
	var button_id := hoftag.get_instance_id()
	var relic_id: int = panel.action_buttons["relic:crown"].get_instance_id()
	var scroll: ScrollContainer = main.court_body.get_parent()
	scroll.scroll_vertical = 35
	hoftag.grab_focus()
	main.refresh()
	await settle()
	check(panel.action_buttons["court"].get_instance_id() == button_id and panel.action_buttons["relic:crown"].get_instance_id() == relic_id, "Main.refresh erhält Aktionsnodes")
	check(get_viewport().gui_get_focus_owner() == hoftag, "Main.refresh erhält den Tastaturfokus")
	check(scroll.scroll_vertical == 35, "Main.refresh erhält die vertikale Scrollposition")
	var gold: int = main.game.house().gold
	var prestige: int = main.game.house().prestige
	var grandeur: int = main.game.court_grandeur()
	hoftag.pressed.emit()
	check(main.audit_dispatches == 1 and main.audit_last_command == {"id":"court"}, "Hoftag läuft ausschließlich durch Main._dispatch")
	check(main.game.house().gold == gold - 40 and main.game.house().prestige == prestige + 12 and main.game.court_grandeur() == grandeur, "Hoftag bucht genau 40 Gold für 12 Prestige ohne Prachtänderung")
	check(panel.status_label.text.contains("Prestige"), "Ergebnis ist im Hof sichtbar")
	main.game.house().gold = 0
	main.refresh()
	check(hoftag.disabled and panel.action_reasons["court"].visible and panel.action_reasons["court"].text.contains("40"), "Goldmangel wird im Hof erklärt")
	main.game.house().gold = 1000
	main.game.house().prestige = 0
	main.refresh()
	check(panel.action_buttons["relic:crown"].disabled and panel.action_reasons["relic:crown"].text.contains("Prestige"), "Prestigevoraussetzung wird sichtbar erklärt")
	main.game.house().prestige = 100
	main.refresh()
	panel.action_buttons["amenity:table"].pressed.emit()
	check(main.game.court_amenity_level("table") == 1 and main.game.house().gold == 950, "Tafel-Ausbau verwendet den echten Kommando-Router")
	check(panel.action_details["amenity:table"].text.contains("Unterhalt") and panel.summary_label.text.contains("8"), "Unterhalt wird nach dem Ausbau aktualisiert")
	var original_session = main.lan_session
	var network := FakeLan.new()
	main.audit_network = network
	main.lan_session = network
	var before_gold: int = main.game.house().gold
	hoftag.pressed.emit()
	check(network.pending_command and hoftag.disabled, "Ausstehende Gastaktion sperrt weitere Mutationen")
	check(panel.status_label.text.contains("bestätigt"), "Wartende Bestätigung ist im Hof sichtbar")
	check(main.game.house().gold == before_gold, "Gastansicht ändert die Welt nicht optimistisch")
	for action in panel.action_buttons.values():
		check(action.disabled, "Alle mutierenden Hofaktionen warten auf dieselbe Bestätigung")
	network.pending_command = false
	network.status = "Der Gastgeber hat den Hoftag bestätigt."
	panel.refresh(main.game)
	check(not hoftag.disabled and panel.status_label.text == network.status, "Gastbestätigung aktualisiert Status und Freigabe")
	main.lan_session = original_session
	main.audit_network = null
	main.audit_panel = null
	main.queue_free()
	await get_tree().process_frame
	finish()

func settle() -> void:
	for frame in 4:
		await get_tree().process_frame

func _text(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children():
		result += "\n" + _text(child)
	return result

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("COURTMANAGEMENTTEST FAIL: " + message)
	return ok

func finish() -> void:
	print("COURTMANAGEMENTTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
