extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Authority = preload("res://scripts/LanAuthority.gd")
const Production = preload("res://scripts/RegionalProduction.gd")
const Councils = preload("res://scripts/RegionalEvents.gd")
const VM = preload("res://scripts/ViewModelBuilder.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var game = Game.new(Data,0)
	var id := str(game.house().capital)
	var p: Dictionary = game.province(id)
	p.provisioning.food_u = Production.weight_u(p)
	for i in 32:
		seed(1850+i)
		game.house().event_history.clear()
		game.pending_event = null
		game._trigger_event()
		if game.pending_event.get("id") == "rat_vorrat": break
	if not check(game.pending_event.get("id") == "rat_vorrat" and game.pending_event.get("region") == id,"A real near-empty province draws its own actionable council decision"):
		finish()
		return
	var preview := VM.event(game)
	check(preview.text.contains(str(p.name)) and preview.options[0].chips.contains("75"),"Event view names the exact province and policy consequences")
	var snapshot: Dictionary = game.snapshot()
	check(str(snapshot.pending) == "rat_vorrat@"+id,"Pending event binds the selected province to its original instance")
	var copy = Game.new(Data,0)
	check(copy.restore(JSON.parse_string(JSON.stringify(snapshot))) and copy.pending_event.region==id,"Loading restores exact province without drawing another event")
	var instance: int = copy.pending_event_instance()
	var old_gold: int = copy.house().gold
	var old_food: int = copy.province(id).provisioning.food_u
	check(copy.apply_event(0).ok and copy.province(id).provisioning.rations=="scarce","Council decision uses the real provincial ration action")
	check(copy.house().gold==old_gold and copy.province(id).provisioning.food_u==old_food,"The decision changes policy before the next monthly food settlement")
	check(copy.pending_event == null and copy.pending_event_instance()==instance and not copy.apply_event(0).ok,"Council decision cannot grant a second effect")
	copy.advance_month()
	var after: Dictionary = copy.provision_report().regions[id]
	@warning_ignore("integer_division")
	var expected: int = Production.weight_u(p)*75/100
	check(int(after.requested_u)==expected and after.rations=="scarce","Regular monthly world step consumes precisely the reduced ration")
	var lost = Game.new(Data,0)
	check(lost.restore(snapshot),"Same historic council state is independently repeatable")
	lost.province(id).owner=1
	var before: Dictionary = lost.snapshot()
	check(not lost.apply_event(0).ok and Save.state_equal(before,lost.snapshot()),"Loss of ownership blocks stale impact and leaves every quantity unchanged")
	check(lost.apply_event(1).ok and lost.province(id).provisioning.rations=="normal","A stale event can be closed without touching the new owner")
	var again = Game.new(Data,0)
	check(again.restore(snapshot),"Original decision reloads for repetition test")
	again.pending_event = null
	for i in 24:
		seed(1800+i)
		again.house().event_history = ["rat_vorrat"]
		again._trigger_event()
		check(not again.pending_event.has("region"),"Local council does not repeat immediately")
		again.pending_event = null
	var forged := snapshot.duplicate(true)
	for token in ["rat_vorrat@unknown","unknown@"+id,"rat_vorrat@"+id+"@forged"]:
		forged.pending = token
		check(not Game.new(Data,0).restore(forged),"Invalid regional event token cannot be loaded: "+token)
	test_actions()
	test_lan()
	test_regular_campaign()
	finish()

func open_for(game, id: String, region: String) -> void:
	game.pending_event = Councils.for_region(id,region)
	game._event_instance += 1

func test_actions() -> void:
	var game = Game.new(Data,0)
	var id := str(game.house().capital)
	var locale: Dictionary = game.province(id)
	open_for(game,"rat_versorgung",id)
	check(game.apply_event(0).ok and locale.provisioning.rations=="generous","Relief uses the existing generous ration policy")
	game.house().laws.tax = 2
	open_for(game,"rat_abgaben",id)
	check(game.apply_event(0).ok and game.house().laws.tax==1,"Council changes actual house tax")
	for scene in [["rat_grenzmauer","walls"],["rat_markt","market"]]:
		game = Game.new(Data,0)
		open_for(game,str(scene[0]),id)
		var quote: Dictionary = game.regional_event_option(0)
		check(quote.ok and int(quote.cost)>0 and VM.event(game).options[0].chips.contains("−"+str(quote.cost)+" Gold"),"Build choice displays exact live quoted cost: "+str(scene[1]))
		var treasury: int = game.house().gold
		game.house().gold = quote.cost-1
		var prior: Dictionary = game.snapshot()
		check(not game.apply_event(0).ok and Save.state_equal(game.snapshot(),prior),"Last-minute reduction in treasury blocks the original choice")
		game.house().gold = treasury
		check(game.apply_event(0).ok and int(game.house().gold)==treasury-int(quote.cost) and str(game.province(id).regional_project.kind)==str(scene[1]),"Build choice starts exactly one genuine paid project")
	game = Game.new(Data,0)
	open_for(game,"rat_lager",id)
	check(not game.regional_event_option(0).ok,"Storage expertise respects existing research prerequisites")
	game.house().research.known = ["surveying","crop_rotation"]
	var cost: int = game.regional_event_option(0).cost
	var treasury: int = game.house().gold
	check(game.apply_event(0).ok and game.house().research.active=="granaries" and int(game.house().gold)==treasury-cost,"Storage council starts real paid research with the existing time and cost")

func test_lan() -> void:
	var game = Game.new(Data,0)
	check(game.configure_human_houses([0,1]),"Two separate house authorities can open councils")
	var host_region := str(game.houses[0].capital)
	var guest_region := str(game.houses[1].capital)
	open_for(game,"rat_vorrat",host_region)
	game.select_player_context(1)
	open_for(game,"rat_versorgung",guest_region)
	var guest_instance: int = game.pending_event_instance()
	game.select_player_context(0)
	var session = Game.new(Data,0)
	check(session.restore(JSON.parse_string(JSON.stringify(game.snapshot()))),"Both provincial targets survive WLAN host save")
	var authority = Authority.new(session,{1:0,2:1})
	check(not authority.execute(2,1,{"id":"apply_event","option":0,"event_instance":guest_instance+1}).ok,"An expired or incorrect instance cannot trigger a regional decision")
	check(authority.execute(2,2,{"id":"apply_event","option":0,"event_instance":guest_instance,"selection":host_region}).ok,"Real guest receives own council decision through authority")
	check(str(session.province(guest_region).provisioning.rations)=="generous" and str(session.province(host_region).provisioning.rations)=="normal","Guest selection cannot redirect a council effect to the host")
	check(str(session.pending_event.region)==host_region and session.player==0,"Other house retains its own pending situation")

func test_regular_campaign() -> void:
	seed(20261124)
	var game = Game.new(Data,0)
	var id := str(game.house().capital)
	check(game.set_province_focus(id,"agriculture").ok and game.start_research("surveying").ok,"Ordinary opening uses starting gold for farming and surveying")
	var triggered := []
	var archive := OS.get_environment("BQ_REGIONAL_EVENT_PROOF")
	for turn in 72:
		game.advance_month()
		var research: Dictionary = game.house().research
		if research.known.has("surveying") and not research.known.has("crop_rotation") and str(research.active).is_empty():
			game.start_research("crop_rotation")
		if game.pending_event==null:
			continue
		var event: Dictionary = game.pending_event
		triggered.append(str(event.id))
		if str(event.id)=="rat_lager":
			var local: Dictionary = game.province(str(event.region))
			check(int(local.provisioning.food_u)>=5*Production.weight_u(local),"Ordinary council appears only when the local stores are filled")
			if not archive.is_empty():
				var file := FileAccess.open(archive,FileAccess.WRITE)
				file.store_string(JSON.stringify(game.snapshot()))
				file.close()
			check(game.apply_event(0).ok and game.house().research.active=="granaries","Actual earned local event starts the real next research stage")
			print("REGIONAL_COUNCIL_CAMPAIGN month=",game.calendar_index()," region=",event.region," drawn=",JSON.stringify(triggered))
			return
		for index in range(event.options.size()-1,-1,-1):
			if game.apply_event(index).ok: break
		if game.pending_event!=null:
			game.decline_event()
	check(false,"Ordinary financed agricultural campaign draws real granary council within 72 months")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("REGIONALEVENTSTEST FAIL: "+message)
	return ok

func finish() -> void:
	print("REGIONALEVENTSTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
