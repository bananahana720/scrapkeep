extends SceneTree

# Rule (scrapkeep#494, flume entry stall): a stage built ahead on worker threads (a played game) builds
# its activity sites one a physics tick after entry, in entry order, and ends with the sites the entry
# build makes: the same ids at the same places, the same finds, and the hauler's brute out once the last
# is built. A new entry while jobs remain drops them. A stage built whole (bot runs, tests) keeps the
# entry build. Fixture: the park table's stage 2 (park_flume, which has a hauler bounty) on a live
# game; no check here is timed.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")

var _t := T.new("activities_spread_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 5:
		await physics_frame
	game.flow.enter_stage(2, Vector3.ZERO, false)
	for i in 5:
		await physics_frame
	var acts = game.world.activities
	var terrain = game.ctx.terrain
	_t.check("a test's stage is built whole, so its sites are built at entry", not terrain.built_threaded(2) and acts._site_jobs.is_empty())
	var whole := _read(acts)
	_t.check("the flume has sites to build, the hauler's brute out among them", whole.size() > 3 and _brutes(acts) > 0,
		"%d sites, %d brutes" % [whole.size(), _brutes(acts)])

	terrain._threaded[terrain._index(2)] = true
	acts._on_stage_entered(2, false)
	var jobs: int = acts._site_jobs.size()
	_t.check("built threaded, the entry builds no site and queues one job a site", acts.sites.is_empty() and jobs == whole.size(),
		"%d jobs for %d sites" % [jobs, whole.size()])
	var counts := []
	var early := 0
	while not acts._site_jobs.is_empty() and counts.size() < 200:
		await physics_frame
		counts.append(acts.sites.size())
		if not acts._site_jobs.is_empty():
			early += _brutes(acts)
	await physics_frame
	_t.check("the hauler's brute waits for the last site, then comes out", early == 0 and _brutes(acts) > 0,
		"%d brute-ticks before the last site, %d after" % [early, _brutes(acts)])
	var one_a_tick := true
	for i in counts.size():
		one_a_tick = one_a_tick and counts[i] == i + 1
	_t.check("the sites build one a physics tick", one_a_tick and counts.size() == jobs, str(counts))
	_t.eq("they are the entry build's sites, in its order", _read(acts), whole)

	acts._on_stage_entered(2, false)
	for i in 2:
		await physics_frame
	acts._on_stage_entered(2, false)
	while not acts._site_jobs.is_empty():
		await physics_frame
	await physics_frame
	var standing: Array = acts.get_children().filter(func(n): return n is Activities.Site and not n.is_queued_for_deletion())
	_t.check("an entry while jobs remain drops them: one set of sites stands", _read(acts) == whole and standing.size() == whole.size(),
		"%d standing for %d sites" % [standing.size(), whole.size()])
	game.free()
	quit(_t.verdict())


# Sites with a live brute out.
func _brutes(acts) -> int:
	return acts.sites.filter(func(s): return s.brute != null and is_instance_valid(s.brute)).size()


# Each site's id, place, find and whether a brute stands for it.
func _read(acts) -> Array:
	var out := []
	for s in acts.sites:
		out.append([String(s.id), s.global_position.snapped(Vector3.ONE * 0.001), String(s.get_meta("find", "")), s.brute != null])
	return out
