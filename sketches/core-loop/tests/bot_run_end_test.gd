# smoke: solo (split by world from RunStore entrances; one seed child per world, 170 s wall cap)
# 2026-10-04 (wave 9): one seed child per world in the gate since 2026-10-04; the nightly runs more seeds.
# Two seeds ran past the 180 s smoke cap under load (killed at 189.5 s).
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Achievements := preload("res://src/core/achievements.gd")

const SEEDS := 1

# 2026-10-05 (wave 14, prog-G10): the file also pins a final win's progression end state, in process,
# because a bot child's profile dies with the child; the child supplies the played-win codex only.
# Each child plays only one world, then stops at the next world's entrance.
# The next child resumes that RunStore document with the earned kit and build.
# Only the final world's run_ended may produce won. This is automated native play.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("bot_run_end_test")
	var base := OS.get_user_data_dir().path_join("bot-run-end-%d" % OS.get_process_id())
	var folders := []
	var run_ids := []
	var traces := []
	for i in SEEDS:
		folders.append(base.path_join(str(i + 1)))
		run_ids.append("")
		traces.append("")
	for world in StageDefs.worlds():
		var jobs := []
		for i in SEEDS:
			var args := ["--out=" + folders[i], "--policy=skipper", "--seeds=%d" % (i + 1),
				"--from-stage=%d" % StageDefs.first_of(world), "--trace=1"]
			if world != StageDefs.worlds().back():
				args.append("--until=%d" % StageDefs.last_of(world))
			jobs.append({"script": "res://tools/bot_run.gd", "args": args})
		var results := ChildRuns.run(jobs, 170.0)
		for i in SEEDS:
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
			if final:
				var listed = JSON.parse_string(FileAccess.get_file_as_string(folders[i].path_join("codex-entries.json")))
				var entries: Array = listed if listed is Array else []
				t.check("seed %d codex has every Waking entry once" % (i + 1), _once(entries, BossCodex.WAKING), "%s" % [entries.size()])
				t.check("seed %d codex has every Mind entry once" % (i + 1), _once(entries, BossCodex.MIND), "%s" % [entries.size()])
			if not final:
				var entrance := RunStore.new(folders[i].path_join("entrance.json")).load()
				t.check("seed %d next entrance saved" % (i + 1), entrance.get("run_id") == run_ids[i]
					and int(entrance.get("stage", 0)) == StageDefs.first_of(world + 1))
		if t.failures > 0:
			break
	for i in SEEDS:
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
	# 2026-10-05 (wave 14, prog-G10): a final win driven through the real flow, in process.
	var won := Game.new()
	won.table = ""
	won.test_mode = true
	root.add_child(won)
	while won.flow == null:
		await physics_frame
	for i in 3:
		await physics_frame
	won.ctx.calm = true
	var earns := []
	var ended := [0]
	won.events.achievement_earned.connect(func(id): earns.append(id))
	won.events.run_ended.connect(func(_won): ended[0] += 1)
	won.flow.press_start()
	won.flow.choose_class(0)
	for i in 2:
		await physics_frame
	won.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	won.flow._set_state(won.flow.BOSS)
	won.events.boss_defeated.emit()
	var frames := 0
	while won.flow.state_name() != "summary" and frames < 90 * 6:
		await physics_frame
		frames += 1
	t.check("final win fixture reaches summary", won.flow.state_name() == "summary", "state %s after %d frames" % [won.flow.state_name(), frames])
	t.eq("run_ended fired once", ended[0], 1)
	t.check("won_final", won.flow.won_final(), "run_won %s" % won.flow.run_won)
	t.check("the ending page opens", won.screens.ending_open(), "closed")
	t.eq("the ending title is ENDING's", won.screens._ending_title.text, String(Worlds.ENDING["title"]))
	var waited := 0.0
	while won.screens.ending_open() and waited < won.screens.ENDING_HOLD + 1.0:
		await process_frame
		waited += won.get_process_delta_time()
	t.check("the bot closes the ending page", not won.screens.ending_open(), "open after %.2f s" % waited)
	t.check("the summary title reads RUN COMPLETE", won.screens._title.text.contains("RUN COMPLETE"), won.screens._title.text)
	t.check("the summary body holds the Mind's epitaph", won.screens._body.text.contains(String(Worlds.BOSSES["mind"]["epitaph"])), won.screens._body.text)
	var profile = won.ctx.profile
	t.check("first_win earned once", profile.earned("first_win") and earns.count("first_win") == 1, "earned %s count %d" % [profile.earned("first_win"), earns.count("first_win")])
	t.check("first_win unlocks paint_kest_dusk", profile.has_cosmetic("paint_kest_dusk")
		and Achievements.reward_of("first_win") == {"cosmetic": "paint_kest_dusk"}, "%s" % [Achievements.reward_of("first_win")])
	t.check("mind_quieted earned once", profile.earned("mind_quieted") and earns.count("mind_quieted") == 1, "earned %s count %d" % [profile.earned("mind_quieted"), earns.count("mind_quieted")])
	t.check("mind_quieted unlocks remembered_cannon", profile.has_pilot("remembered_cannon")
		and Achievements.reward_of("mind_quieted") == {"pilot": "remembered_cannon"}, "%s" % [Achievements.reward_of("mind_quieted")])
	var live: Array = won.codex.entries("enemy")
	t.check("codex holds every Waking and Mind entry once", _once(live, BossCodex.WAKING) and _once(live, BossCodex.MIND), "%d enemy entries" % live.size())
	t.eq("no store error after the win", won.flow.store_error, "")
	won.free()
	quit(t.verdict())


# True when every row of `ids` (codex rows) has its id exactly once among the entries' ids, in category enemy.
func _once(entries: Array, ids: Array) -> bool:
	for row in ids:
		var n := 0
		for e in entries:
			if e is Dictionary and e.get("id") == row["id"] and e.get("category") == "enemy":
				n += 1
		if n != 1:
			return false
	return true
