extends Node
## Fängt frei erfundene Ladeprozente ohne messbaren Fortschritt ab.
func _ready() -> void:
	var loading = load("res://scenes/Loading.tscn").instantiate()
	add_child(loading)
	loading.set_process(false)
	loading.loaded_ok = false
	loading._process(0.2)
	var valid: bool = not str(loading.percent.text).contains("%")
	if not valid:
		print("LOADINGSTATUSTEST FAIL: Prozentanzeige ohne Ressourcenmesswert.")
	print("LOADINGSTATUSTEST %s; 1 Prüfungen." % ("OK" if valid else "FAIL"))
	get_tree().quit(0 if valid else 1)
