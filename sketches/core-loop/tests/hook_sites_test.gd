extends SceneTree
# smoke: solo timeout=360s

const Game := preload("res://src/game.gd")
const HookSites := preload("res://tools/hook_sites.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("hook_sites_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(731)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.force_warden = false
	game.flow.press_start()
	game.flow.choose_class(0)
	var probe := HookSites.new(game)
	var stations: Array = JSON.parse_string(FileAccess.get_file_as_string(HookSites.STATIONS)).stations
	var rows := []
	var paid := 0
	var planted := OS.get_environment("PLANT") == "no_bite"
	for site: Dictionary in stations:
		if site.stage is String and site.stage == "bowl":
			game.flow.enter_boss(Vector3.ZERO)
		else:
			if game.run.stage != int(site.stage):
				game.flow.enter_stage(int(site.stage), Vector3.ZERO, false)
			if not t.check("stage %s playable" % site.stage, await _ready_stage(site.stage)):
				break
		game.run.set_max_hp(99999.0)
		var row := await probe.measure(site, planted and site.id == "flume_hollow_trestles")
		rows.append(row)
		if site.id == "flume_hollow_trestles":
			t.eq("known timber gives a measurable swing", row.status, "measured")
		t.check("%s comparison finished" % site.id, row.status in ["no hold", "measured"], str(row))
		if row.status == "measured" and row.held.landing_mps >= row.best_early.landing_mps:
			paid += 1
	t.eq("all stations attempted", rows.size(), stations.size())
	print("RECEIPT ", JSON.stringify({"row": "hook-pays", "measured": {"entry_mps": HookSites.ENTRY_SPEED,
		"stations": rows, "sites_where_hold_beats_release": paid}, "pass": paid == stations.size() and t.failures == 0}))
	game.queue_free()
	await process_frame
	quit(t.verdict())


func _ready_stage(stage: int) -> bool:
	for tick in 1200:
		await physics_frame
		if game.ctx.terrain.is_ready(stage) and game.flow.in_play() and not game.player.frozen():
			game.flow.start_card.hide_card()
			return true
	return false
