extends Node
## Phasen und Ressourcenleser werden gesteuert; kein langsamer Main-Import im Test.
class HarnessLoading extends "res://scripts/Loading.gd":
	var read_calls := 0
	var simulate_failure := false
	func _read_main_scene() -> PackedScene:
		read_calls += 1
		if simulate_failure: return null
		var fixture := PackedScene.new()
		var control := Control.new()
		fixture.pack(control)
		control.free()
		return fixture

var checks := 0
var failures := 0

func _ready() -> void:
	var loading = HarnessLoading.new()
	add_child(loading)
	loading.set_process(false)
	if not check(loading.get("intro_layer") is Control, "Das unveränderte chaotiKKK-Logo erscheint als erster Bildschirm"):
		loading.free()
		finish()
		return
	check(loading.intro_layer.visible, "Logo ist beim Start sichtbar")
	check(loading.intro_layer.color == Color.BLACK and is_equal_approx(loading.modulate.a, 1.0), "Erster Bildschirm ist sofort vollständig undurchsichtig")
	check(loading.intro_image.texture.get_width() == 2560 and loading.intro_image.texture.get_height() == 1440, "Logo behält seine vollständige Originalauflösung")
	check(loading.intro_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Logo wird vollständig und zentriert ohne Beschnitt dargestellt")
	check(loading.read_calls == 0 and not loading.load_started, "Main wird nicht vor dem Logo geladen")
	check(not loading.bar.visible and not loading.percent.text.contains("%"), "Ohne Messwert erscheinen keine erfundenen Ladeprozente")
	loading._load_main()
	check(loading.read_calls == 0, "Direkter Ladeaufruf kann die Logo- und Renderfreigabe nicht umgehen")
	loading._finish()
	check(not loading.done, "Szenenwechsel ist vor geladenen Ressourcen gesperrt")
	loading._process(2.99)
	check(loading.intro_layer.visible and loading.read_calls == 0, "Nach 2,99 Sekunden bleibt ausschließlich das Logo vorne")
	loading._process(0.01)
	check(not loading.intro_layer.visible, "Bei drei Sekunden verschwindet das Logo automatisch")
	check(loading.awaiting_loading_frame and not loading.loading_frame_presented, "Normaler Ladebildschirm wartet zuerst auf eine tatsächlich gezeichnete Ansicht")
	check(loading.read_calls == 0 and not loading.load_started, "Synchroner Main-Leser blockiert nicht die erste normale Ladeansicht")
	loading._load_main()
	check(loading.read_calls == 0, "Main-Laden bleibt vor dem gerenderten Ladebild gesperrt")
	# Headless zeichnet nicht. Dies charakterisiert dieselbe Produktionsfreigabe,
	# die im sichtbaren Lauf ausschließlich frame_post_draw aufruft.
	loading._on_loading_frame_presented()
	check(loading.loading_frame_presented and loading.read_calls == 0, "Renderfreigabe verschiebt das eigentliche Laden noch in den nächsten Idle-Schritt")
	await get_tree().process_frame
	await get_tree().process_frame
	check(loading.load_started and loading.loaded_ok and loading.read_calls == 1, "Nach gezeichnetem Ladebild wird Main genau einmal gelesen")
	loading._load_main()
	check(loading.read_calls == 1, "Doppelter Ladeaufruf lädt Main nicht erneut")
	loading._process(0.2)
	check(loading.bar.visible and is_equal_approx(loading.bar.value, 100.0) and not loading.percent.text.contains("%"), "Fertige Ressource zeigt nur belegten Abschluss und Laufzeit")
	check(loading.done, "Geladene Hauptszene startet den bestehenden Übergang")
	loading.free()
	var failed = HarnessLoading.new()
	failed.simulate_failure = true
	add_child(failed)
	failed.set_process(false)
	failed._process(3.0)
	failed._on_loading_frame_presented()
	await get_tree().process_frame
	await get_tree().process_frame
	check(failed.load_failed and not failed.loaded_ok and failed.read_calls == 1, "Fehlgeschlagener Ressourcenleser wird nach dem Logo erkannt")
	check(failed.status.text.contains("fehlgeschlagen") and not failed.done, "Ladefehler bleibt verständlich sichtbar ohne ungültigen Szenenwechsel")
	failed._process(10.0)
	check(not failed.intro_layer.visible and not failed.done, "Ein Ressourcenfehler bringt das Logo nicht erneut zurück")
	failed.free()
	finish()

func check(ok: bool, text: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("LOADINGSTATUSTEST FAIL: " + text)
	return ok

func finish() -> void:
	print("LOADINGSTATUSTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
