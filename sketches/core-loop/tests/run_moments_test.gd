extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunMoments := preload("res://src/core/run_moments.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const T := preload("res://tests/support/t.gd")

# The run-end comic page (Q11): a won run with a hit, an item, a near-death, a retried death and
# a boss stagger folds into 4 to 6 panels, opening first and finale last, in run order, saved
# where the scrapbook reads it; a bare lost run still makes four.

# A park Warden as the run log reads one.
class FakeWarden:
	extends Node3D
	var kind := "warden"
	var family := "reactor"

	func chunks_left() -> int:
		return 3

	func glances() -> int:
		return 0


var _game
var _t := T.new("run_moments_test")
var _frames := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _frames == 1:
		var double := SpawnerDouble.new()
		_game.add_child(double)
		double.setup(_game.ctx)
		_game.ctx.spawner = double
		var boss := BossDouble.new()
		_game.add_child(boss)
		boss.setup(_game.ctx)
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(1)
		return false
	if _frames < 12:
		return false
	_full_run()
	_bare_loss()
	quit(_t.verdict())
	return true


func _full_run() -> void:
	var ev = _game.events
	var run = _game.run
	var target := FakeWarden.new()
	_game.add_child(target)
	run.run_time = 10.0
	ev.enemy_struck.emit(target, "ram", 40.0)
	run.run_time = 12.0
	ev.enemy_struck.emit(target, "ram", 95.0)
	run.run_time = 20.0
	ev.part_gained.emit("load_dividend", "gate")
	run.run_time = 30.0
	run.hp = run.max_hp * 0.12
	ev.player_hit.emit(5.0, "probe")
	run.hp = run.max_hp
	run.run_time = 40.0
	ev.player_died.emit()
	ev.stage_entered.emit(int(run.stage), true)
	run.run_time = 50.0
	ev.posture_changed.emit(target, 1.0, true)
	ev.posture_changed.emit(target, 1.0, true)
	run.run_time = 60.0
	ev.boss_defeated.emit()
	# The victory beat runs on before the summary; the ledger must not land after the finale.
	run.run_time = 63.0
	_game.flow._end_run(true)
	var moments = _game.run_moments
	# The save runs on a worker (78 to 82 ms of the 4080's victory frame, scrapkeep#241): the page
	# is ready at run_ended, and its path only once saved_path() has waited for the worker.
	_t.check("the run_ended save runs on a worker, not in the ending frame", moments._save_task >= 0 and moments.last_page_path == "", "task %d, path '%s'" % [moments._save_task, moments.last_page_path])
	var page: Dictionary = moments.last_page
	var panels: Array = page.get("panels", [])
	_t.check("won page has 4 to 6 panels", panels.size() >= RunMoments.MIN_PANELS and panels.size() <= RunMoments.MAX_PANELS, "%d" % panels.size())
	_t.eq("opening first", String(panels[0]["kind"]) if not panels.is_empty() else "", "opening")
	_t.eq("finale last", String(panels[-1]["kind"]) if not panels.is_empty() else "", "finale")
	var kinds := panels.map(func(p): return String(p["kind"]))
	for kind in ["boss_stagger", "biggest_hit", "near_death", "key_item"]:
		_t.check("won page holds %s" % kind, kinds.has(kind), "%s" % [kinds])
	var ordered := true
	for i in range(1, panels.size()):
		ordered = ordered and float(panels[i]["t"]) >= float(panels[i - 1]["t"])
	_t.check("panels in run order", ordered, "%s" % [panels.map(func(p): return p["t"])])
	var hit: Dictionary = panels.filter(func(p): return p["kind"] == "biggest_hit").front() if kinds.has("biggest_hit") else {}
	_t.eq("biggest hit is the larger strike", int(hit.get("facts", {}).get("force", 0)), 95)
	var near: Dictionary = panels.filter(func(p): return p["kind"] == "near_death").front() if kinds.has("near_death") else {}
	_t.eq("a retried death outranks a 12% scrape", int(near.get("facts", {}).get("hull", -1)), 0)
	_t.check("every panel has a caption", panels.all(func(p): return String(p["caption"]) != ""), "%s" % [panels.map(func(p): return p["caption"])])
	var stagger: Dictionary = panels.filter(func(p): return p["kind"] == "boss_stagger").front() if kinds.has("boss_stagger") else {}
	_t.eq("a park stagger names its Warden", String(stagger.get("facts", {}).get("who", "")), "The Meltdown Warden")
	_t.eq("page is won", page.get("won"), true)
	var path: String = moments.saved_path()
	_t.check("page saved under scrapbook/", path.contains("/%s/" % RunMoments.DIR) and FileAccess.file_exists(path), path)
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	_t.check("saved page parses with its panels", doc is Dictionary and (doc["panels"] as Array).size() == panels.size() and int(doc["schema"]) == RunMoments.SCHEMA, "%s" % [doc])
	_t.eq("page outcome", page.get("outcome"), "won")
	# The camp's drawing lands on its own branch; the summary shows the page once the build has it.
	var drawn = _game.screens.comic_page()
	_t.check("summary draws the page when the build has the drawing", (drawn != null) == ResourceLoader.exists(_game.screens.COMIC_PAGE_PATH), "drawn %s" % [drawn != null])
	print("run_moments_test page: %s" % JSON.stringify(doc))
	target.queue_free()


func _bare_loss() -> void:
	_game.flow.new_run()
	_game.flow.choose_class(1)
	_game.run.run_time = 5.0
	_game.events.player_died.emit()
	_game.flow._end_run(false)
	var page: Dictionary = _game.run_moments.last_page
	var panels: Array = page.get("panels", [])
	_t.check("bare lost run still has 4 panels", panels.size() >= RunMoments.MIN_PANELS, "%s" % [panels.map(func(p): return p["kind"])])
	_t.eq("lost page is lost", page.get("won"), false)
	_t.check("lost finale says so", not panels.is_empty() and String(panels[-1]["caption"]) in RunMoments.CAPTIONS["lost"], String(panels[-1]["caption"]) if not panels.is_empty() else "")
