extends Node
## Prüft den UiKernel ohne Szene: Auswahl, Modalstapel, Kommando-Routing,
## blockierte Kommandos, Save-Grenze und die reinen View-Model-Zeichenketten.
## Aufruf: godot --headless --path . res://tests/UiKernelTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const UiKernelScript = preload("res://scripts/UiKernel.gd")
const ViewModelBuilder = preload("res://scripts/ViewModelBuilder.gd")

var _failed := false
var _checks := 0

func _ready() -> void:
	var game = GameScript.new(DataScript, 0)
	var kernel = UiKernelScript.new()
	kernel.bind_game(game)

	# Modalstapel: Basis, doppeltes Öffnen, falsches Schließen, Reset.
	kernel.set_base_modal("game")
	_check(kernel.top_modal() == "game", "Basis-Modal fehlt.")
	kernel.push_modal("picker")
	kernel.push_modal("picker")
	_check(kernel.modal_stack.size() == 2, "Picker wurde doppelt gestapelt.")
	_check(kernel.pop_modal("herrschaft") == "picker", "Falsches Schließen veränderte den Stapel.")
	_check(kernel.modal_stack.size() == 2, "Falsches Schließen hat den Stapel verkleinert.")
	_check(kernel.pop_modal("picker") == "picker", "Picker wurde nicht geschlossen.")
	_check(kernel.pop_modal("game") == "game", "Basis-Modal wurde nicht geschlossen.")
	_check(kernel.top_modal() == "", "Stapel ist nach dem Schließen nicht leer.")

	# Auswahl und Zielhaus.
	var owned: Array = game.owned()
	_check(not owned.is_empty(), "Haus 0 besitzt keine Provinz.")
	var own_id := str(owned[0]["id"])
	kernel.select_province(own_id)
	_check(kernel.selection == own_id, "Eigene Provinz wurde nicht ausgewählt.")
	_check(kernel.target_house() == -1, "Eigene Provinz liefert ein fremdes Zielhaus.")
	var foreign := ""
	for p in game.provinces:
		if int(p["owner"]) != game.player:
			foreign = str(p["id"])
			break
	_check(foreign != "", "Keine fremde Provinz gefunden.")
	kernel.select_province(foreign)
	_check(kernel.target_house() == int(game.province(foreign)["owner"]), "Fremde Provinz liefert das falsche Zielhaus.")

	# Blockiertes Kommando ohne Ziel verändert weder Gold noch Log.
	kernel.clear_selection()
	var gold_before: int = int(game.house()["gold"])
	var log_before: int = game.log_lines.size()
	var blocked: Dictionary = kernel.dispatch({"id": "peace"})
	_check(not bool(blocked["ok"]) and str(blocked["code"]) == "no_target", "Frieden ohne Ziel war nicht blockiert.")
	_check(int(game.house()["gold"]) == gold_before, "Blockiertes Kommando veränderte Gold.")
	_check(game.log_lines.size() == log_before, "Blockiertes Kommando schrieb in den Log.")

	# Gültiges Entwickeln über denselben Router.
	game.house()["gold"] = 500
	var dev_id := ""
	for p in game.owned():
		if game.can_develop(str(p["id"])):
			dev_id = str(p["id"])
			break
	_check(dev_id != "", "Keine ausbaubare eigene Provinz gefunden.")
	kernel.select_province(dev_id)
	var dev_before: int = int(game.province(dev_id)["dev"])
	var gold_before_dev: int = int(game.house()["gold"])
	var develop: Dictionary = kernel.dispatch({"id": "develop"})
	_check(bool(develop["ok"]), "Entwickeln wurde abgelehnt.")
	_check(int(game.province(dev_id)["dev"]) > dev_before, "Entwickeln veränderte die Provinz nicht.")
	_check(int(game.house()["gold"]) < gold_before_dev, "Entwickeln kostete kein Gold.")

	# Unbekanntes Kommando und Save-Grenze.
	var unknown: Dictionary = kernel.dispatch({"id": "gibt_es_nicht"})
	_check(not bool(unknown["ok"]) and str(unknown["code"]) == "invalid", "Unbekanntes Kommando war nicht ungültig.")
	var no_handler: Dictionary = kernel.dispatch({"id": "save"})
	_check(not bool(no_handler["ok"]) and str(no_handler["code"]) == "invalid", "Save ohne Handler war nicht blockiert.")
	var seen := {"count": 0}
	kernel.save_handler = func():
		seen["count"] += 1
		return {"ok": true, "message": "Test gespeichert.", "code": "ok", "delta": {}, "refresh": []}
	var saved: Dictionary = kernel.dispatch({"id": "save"})
	_check(bool(saved["ok"]) and int(seen["count"]) == 1, "Save-Handler wurde nicht genau einmal aufgerufen.")
	_check(str(saved["message"]) == "Test gespeichert.", "Save-Ergebnis wurde nicht durchgereicht.")

	# Reine Anzeigezeichenketten aus dem Snapshot.
	var vm: Dictionary = ViewModelBuilder.refresh(game, "")
	_check(str(vm["date"]) == game.date_text(), "Datum weicht vom Spielstand ab.")
	_check(str(vm["gold"]) == "Gold: %d" % int(game.house()["gold"]), "Gold-Anzeige weicht ab.")
	_check(str(vm["title"]) == str(game.house()["name"]), "Titel weicht vom Haus ab.")
	_check(str(vm["hint"]) == "Tippe auf eine Grafschaft, um sie auszuwählen.", "Hinweis ohne Auswahl weicht ab.")
	var picker: Dictionary = ViewModelBuilder.picker(game, "marry")
	_check(str(picker["title"]) == "Wen heiratest du?", "Picker-Titel weicht ab.")
	_check(picker["options"].size() == game.houses.size() - 1, "Picker enthält nicht alle fremden Häuser.")
	var rule: Dictionary = ViewModelBuilder.rule(game, "")
	_check(str(rule["title"]) == "Herrschaft — %s" % str(game.house()["name"]), "Herrschaftstitel weicht ab.")
	_check(str(rule["province_hint"]) == "Wähle auf der Karte eine eigene Provinz.", "Provinzhinweis weicht ab.")
	_check(bool(rule["claim_disabled"]), "Anspruch ist ohne Auswahl nicht deaktiviert.")
	var tree: Dictionary = ViewModelBuilder.tree(game)
	_check(str(tree["title"]) == "Stammbaum — %s" % str(game.house()["name"]), "Stammbaumtitel weicht ab.")
	var law: String = str(game.house()["laws"]["succession"])
	_check(str(tree["law"]) == "Erbfolgegesetz: %s." % ("Ältester" if law == "eldest" else "Jüngster"), "Erbfolge-Anzeige weicht ab.")
	var event: Dictionary = ViewModelBuilder.event(game)
	_check(event["options"].is_empty(), "Leeres Ereignis liefert Optionen.")

	if _failed:
		get_tree().quit(1)
		return
	print("UIKERNELTEST OK: %d Prüfungen; Auswahl, Modalstapel, blockiertes und gültiges Kommando, Save-Grenze und View-Model-Strings." % _checks)
	get_tree().quit(0)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failed = true
	print("UIKERNELTEST FAIL: " + message)
