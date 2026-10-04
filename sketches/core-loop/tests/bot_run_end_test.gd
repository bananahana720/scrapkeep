# smoke: solo (split by world from RunStore entrances; two seed children per world, 170 s wall cap)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# Each child plays only one world, then stops at the next world's entrance.
# The next child resumes that RunStore document with the earned kit and build.
# Only the final world's run_ended may produce won. This is automated native play.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("bot_run_end_test")
	var base := OS.get_user_data_dir().path_join("bot-run-end-%d" % OS.get_process_id())
	var folders := [base.path_join("1"), base.path_join("2")]
	var run_ids := ["", ""]
	var traces := ["", ""]
	for world in StageDefs.worlds():
		var jobs := []
		for i in 2:
			var args := ["--out=" + folders[i], "--policy=skipper", "--seeds=%d" % (i + 1),
				"--from-stage=%d" % StageDefs.first_of(world), "--trace=1"]
			if world != StageDefs.worlds().back():
				args.append("--until=%d" % StageDefs.last_of(world))
			jobs.append({"script": "res://tools/bot_run.gd", "args": args})
		var results := ChildRuns.run(jobs, 170.0)
		for i in 2:
			var result: Dictionary = results[i]
			var errors: Array = ChildRuns.summary(result)["errors"]
			traces[i] += String(result["log"])
			t.check("seed %d world %d child" % [i + 1, world], result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
				"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
			var path: String = folders[i].path_join("bots.ndjson")
			var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
			var row = JSON.parse_string(rows[-1]) if rows.size() == world else null
			if not t.check("seed %d world %d record" % [i + 1, world], row is Dictionary, "%d rows in %s" % [rows.size(), path]):
				continue
			if world == StageDefs.worlds()[0]:
				run_ids[i] = row["run_id"]
			t.eq("seed %d same run" % (i + 1), row["run_id"], run_ids[i])
			var final: bool = world == StageDefs.worlds().back()
			t.eq("seed %d world %d outcome" % [i + 1, world], row["outcome"], "won" if final else "until")
			t.eq("seed %d world %d reached" % [i + 1, world], int(row["stage_reached"]),
				StageDefs.COUNT if final else StageDefs.first_of(world + 1))
			print("seed %d world %d: %s, %.2f wall seconds" % [i + 1, world, row["outcome"], row["wall_seconds"]])
			if not final:
				var entrance := RunStore.new(folders[i].path_join("entrance.json")).load()
				t.check("seed %d next entrance saved" % (i + 1), entrance.get("run_id") == run_ids[i]
					and int(entrance.get("stage", 0)) == StageDefs.first_of(world + 1))
		if t.failures > 0:
			break
	for i in 2:
		for world in StageDefs.worlds():
			t.check("seed %d world %d entered in trace" % [i + 1, world],
				String(traces[i]).contains("trace world %d entered" % world))
	# Pin the summary fallback too: without a run_ended callback, a lost summary
	# must still stay lost. This does not mutate or simulate a win.
	var game := Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	var explorer := BotDriver.new(game, "completionist", 1)
	explorer.start()
	var activities = game.world.activities
	var camp = activities.site("enemy_camp")
	var altar = activities.site("ambush_altar")
	if t.check("camp and altar fixture", camp != null and altar != null):
		for spec in game.ctx.terrain.map().activity_sites:
			if spec["id"] == camp.id:
				spec["id"] = "renamed_camp"
		camp.id = "renamed_camp"
		camp.position.y = altar.position.y + 100.0
		for site in activities.sites:
			if site != camp and site != altar:
				site.done = true
				site.pickup = null
		t.check("authored pack before spawning", camp.pack.is_empty() and explorer._site_has_authored_pack(camp))
		t.check("altar has no authored pack", not explorer._site_has_authored_pack(altar))
		explorer._activity_goal(1.0 / 90.0)
		t.eq("renamed elevated camp deferred", explorer._activity, altar.id)
		altar.done = true
		altar.pickup = null
		explorer._activity_goal(1.0 / 90.0)
		t.eq("renamed camp uses ring fight", explorer._goal, "activity renamed_camp")
	game.flow._set_state(game.flow.SUMMARY)
	game.flow.run_won = false
	var driver := BotDriver.new(game, "skipper", 1)
	driver.tick(1.0 / 90.0)
	t.eq("lost summary fallback", driver.outcome, "lost")
	game.free()
	quit(t.verdict())
