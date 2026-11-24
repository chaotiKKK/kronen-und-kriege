extends VBoxContainer
## The chronicle shows exact terms and dispatches through the existing game router.
const UI = preload("res://scripts/ModernInterface.gd")

func configure(main) -> void:
	name = "Reichsvorhaben"
	add_theme_constant_override("separation",8)
	add_child(main._label("Reichsvorhaben",18,main.INK))
	var board: Dictionary = main.game.undertaking_board(main.selected)
	if board.active.is_empty():
		for offer in board.offers:
			_add_offer(main,offer)
	else:
		_add_active(main,board)
	add_child(HSeparator.new())

func _add_offer(main, offer: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_label(main,str(offer.name),15))
	var location := _location(main,offer) if offer.ok else str(offer.reason)
	if offer.ok:
		text.add_child(_label(main,location+" · "+_prize(offer),12))
		text.add_child(_label(main,str(offer.goal),11))
	else:
		text.add_child(_label(main,location,12))
	var command := {"id":"undertake_start","kind":str(offer.id),"province":str(offer.get("province",""))}
	var button := _action(main,"Annehmen" if not offer.done else "Abgeschlossen",
		"VorhabenStart_"+str(offer.id),func():main._dispatch(command))
	button.disabled=not bool(offer.ok) or _locked(main)
	button.accessibility_name=str(offer.name)+" · "+location+" · "+button.text
	row.add_child(button)

func _add_active(main,board: Dictionary) -> void:
	var plan: Dictionary=board.active
	var reward: Dictionary=board.reward
	add_child(_label(main,str(reward.name)+" · "+_location(main,plan),16))
	add_child(_label(main,_prize(reward),12))
	if not str(board.reason).is_empty():
		add_child(_label(main,str(board.reason),12))
	for step in board.steps:
		var state := "Erledigt" if step.done else "Offen"
		add_child(_label(main,state+" · "+str(step.text),12))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",8)
	row.add_theme_constant_override("v_separation",5)
	add_child(row)
	var token := int(plan.serial)
	var claim := _action(main,"Abschließen","VorhabenAbschluss",
		func():main._dispatch({"id":"undertake_finish","token":token}))
	claim.disabled=not bool(board.ready) or _locked(main)
	row.add_child(claim)
	row.add_child(_action(main,"Auf Karte zeigen","VorhabenKarte",
		func():main._focus_undertaking(str(plan.province),str(reward.map))))
	var cancel := _action(main,"Aufgeben","VorhabenAufgeben",
		func():main._dispatch({"id":"undertake_cancel","token":token}))
	cancel.disabled=_locked(main)
	row.add_child(cancel)

func _location(main,plan: Dictionary) -> String:
	var name := str(main.game.province(str(plan.province)).get("name",plan.province))
	if not str(plan.partner).is_empty():
		name+=" → "+str(main.game.province(str(plan.partner)).get("name",plan.partner))
	return name

func _prize(offer: Dictionary) -> String:
	return "+%d Gold · +%d Ruhm" % [int(offer.gold),int(offer.renown)]

func _locked(main) -> bool:
	return main.game.game_over or (main._lan_active() and main.lan_session.pending_command)

func _label(main,text: String,points: int) -> Label:
	var result: Label=main._label(text,points,main.INK_SOFT)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return result

func _action(main,text: String,node_name: String, callback: Callable) -> Button:
	var button: Button=main._button(text,callback)
	button.name=node_name
	button.custom_minimum_size=Vector2(150,maxf(44,30*UI.text_scale))
	button.add_theme_font_size_override("font_size",roundi(13*UI.text_scale))
	return button
