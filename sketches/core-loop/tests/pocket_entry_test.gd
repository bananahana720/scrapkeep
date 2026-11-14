extends SceneTree
# smoke: bots timeout=1800s

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const LIBRARY := "res://src/world/pockets/pocket_library.gd"
const TRIALS := 20
const CLEAR_SECONDS := 30.0
const H := 1.0 / 90.0
var t := T.new("pocket_entry_test")
var library
var game
var elapsed := 0.0
var entry_damage := 0.0
var seen_telegraphs := 0
var evasions := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not t.check("authored library exists", FileAccess.file_exists(LIBRARY)):
		quit(t.verdict())
		return
	library = load(LIBRARY)
	var args := OS.get_cmdline_user_args()
	var entries: Array = library.rows().filter(func(entry): return entry.kind != "trade")
	if "--entry-child" in args:
		var id: String = args[args.find("--entry-child") + 1]
		var selected: Array = entries.filter(func(entry): return entry.id == id)
		if selected.is_empty():
			quit(2)
			return
		await _child(selected[0], 1 if "--pilot" in args else TRIALS)
		return
	if "--only" in args:
		var id: String = args[args.find("--only") + 1]
		entries = entries.filter(func(entry): return entry.id == id)
	t.check("live interior selection is nonempty", not entries.is_empty())
	var covered := 0
	var total_telegraphs := 0
	var total_evasions := 0
	var rates := []
	for offset in range(0, entries.size(), 4):
		var batch: Array = entries.slice(offset, offset + 4)
		var jobs := []
		for entry in batch:
			_safe_path(entry)
			var flags := ["--entry-child", entry.id]
			if "--pilot" in args:
				flags.append("--pilot")
			jobs.append({"script": "res://tests/pocket_entry_test.gd", "args": flags})
		var results: Array = ChildRuns.run(jobs, 600.0)
		for i in results.size():
			var result: Dictionary = results[i]
			var summary: Dictionary = ChildRuns.summary(result)
			var rate := {}
			for line in String(result.log).split("\n"):
				if line.begins_with("pocket_entry_rate: "):
					rate = JSON.parse_string(line.trim_prefix("pocket_entry_rate: "))
				elif line.contains("SCRIPT ERROR") or line.begins_with("ERROR"):
					print(line)
			t.check(batch[i].id + " runtime child", result.code == 0 and not result.timed_out and summary.errors.is_empty() and not rate.is_empty(), "exit=%s timeout=%s errors=%s" % [result.code, result.timed_out, summary.errors])
			if rate.is_empty():
				print(String(result.log).right(3000))
				continue
			print("pocket_entry_rate: " + JSON.stringify(rate))
			rates.append(rate)
			var want := 1 if "--pilot" in args else TRIALS
			t.eq(batch[i].id + " idle and dodger entry count", [int(rate.idle_entries), int(rate.dodger_entries)], [want, want])
			t.check(batch[i].id + " idle safe in first two seconds", float(rate.idle_safe) / rate.idle_entries >= 0.95)
			if batch[i].kind == "arena":
				t.eq(batch[i].id + " every idle starts inside two seconds", int(rate.idle_engaged), want)
				t.eq(batch[i].id + " every dodger starts the encounter", int(rate.engaged), want)
			if int(batch[i].difficulty) == 1:
				t.check(batch[i].id + " difficulty-one dodger clears at least 80 percent", float(rate.dodger_clears) / rate.dodger_entries >= 0.8)
			elif int(batch[i].difficulty) == 10:
				t.check(batch[i].id + " difficulty-ten dodger clears under 80 percent", float(rate.dodger_clears) / rate.dodger_entries < 0.8)
			total_telegraphs += int(rate.telegraphs)
			total_evasions += int(rate.evasions)
			covered += 1
	t.eq("every selected live interior measured", covered, entries.size())
	if "--only" not in args:
		# Seventeen since the incline vault joined the library (W1-76, a4e664b31).
		t.eq("all seventeen live interiors", covered, 17)
		t.check("dodger exercised BotDriver telegraph steering", total_telegraphs > 0 and total_evasions > 0, "seen=%d evasions=%d reaction=%.3fs" % [total_telegraphs, total_evasions, BotDriver.REACTION])
	var path := OS.get_environment("SQ12_ENTRY_RATES")
	if path == "":
		path = "user://pocket-entry-rates.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if t.check("entry rates saved", file != null):
		file.store_string(JSON.stringify({"rates": rates, "failures": t.failures, "seeds": [71000, 71019], "clear_seconds": CLEAR_SECONDS}, "\t"))
		file.close()
	quit(t.verdict())

func _safe_path(entry: Dictionary) -> void:
	var path: Dictionary = entry.safe_path
	var start := Vector2(path.from[0], path.from[1])
	var finish := Vector2(path.to[0], path.to[1])
	var half: float = path.width * 0.5
	var corridor := Rect2(Vector2(minf(start.x, finish.x) - half, minf(start.y, finish.y)), Vector2(absf(start.x - finish.x) + half * 2.0, absf(start.y - finish.y)))
	var clear: bool = path.width >= 4.0 and finish == Vector2.ZERO and start.x == finish.x and entry.entrances.any(func(door): return Vector2(door.at[0], door.at[1]) == start and door.width >= path.width)
	clear = clear and corridor.grow(0.001).has_point(Vector2(entry.entry_spot[0], entry.entry_spot[1]))
	for block in entry.terrain + entry.hazards:
		var size := Vector2(block.size[0], block.size[2])
		var box := Rect2(Vector2(block.at[0], block.at[1]) - size * 0.5, size)
		clear = clear and not corridor.intersects(box, true)
	t.check(entry.id + " static four metre path to centre has no hazard or terrain footprint", clear, "corridor=%s" % corridor)

func _child(entry: Dictionary, count: int) -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.camera.set_physics_process(false)
	game.presentation.process_mode = Node.PROCESS_MODE_DISABLED
	game.screens.process_mode = Node.PROCESS_MODE_DISABLED
	game.events.player_hit.connect(func(amount, _source):
		if elapsed <= 2.0:
			entry_damage += amount)
	var idle_safe := 0
	var idle_engaged := 0
	var clears := 0
	var engaged := 0
	var outcomes := {}
	if "--unsafe-entry" in OS.get_cmdline_user_args():
		var control: Dictionary = await _trial(entry, "idle", 71000, true)
		print("pocket_entry_control: " + JSON.stringify(control))
		t.check(entry.id + " unsafe entry idle safety", control.started and control.entry_damage == 0.0)
		game.free()
		quit(t.verdict())
		return
	for mode in ["idle", "dodger"]:
		for seed_value in count:
			var trial: Dictionary = await _trial(entry, mode, 71000 + seed_value)
			if mode == "idle":
				idle_safe += int(trial.entry_damage == 0.0)
				idle_engaged += int(trial.started)
			else:
				clears += int(trial.cleared)
				engaged += int(trial.started)
				outcomes[trial.outcome] = int(outcomes.get(trial.outcome, 0)) + 1
			print("pocket_entry_trial: " + JSON.stringify(trial))
	var rate := {"id": entry.id, "difficulty": entry.difficulty, "idle_entries": count, "idle_safe": idle_safe, "idle_engaged": idle_engaged, "dodger_entries": count, "dodger_clears": clears, "engaged": engaged, "clear_seconds": CLEAR_SECONDS, "telegraphs": seen_telegraphs, "evasions": evasions, "outcomes": outcomes}
	print("pocket_entry_rate: " + JSON.stringify(rate))
	game.free()
	quit(0)

func _trial(entry: Dictionary, mode: String, seed_value: int, unsafe_entry := false) -> Dictionary:
	var acts = game.world.activities
	acts.clear()
	acts._elite_arrivals = 0
	game.combat._start_attempt()
	game.run.run_seed_override = seed_value
	game.run.begin(game.run.class_def)
	game.ctx.rng.seed = seed_value
	game.ctx.build.recompute()
	game.flow.state = game.flow.STAGE
	game.flow.sealed = false
	game.player.fit_class(game.run.class_def)
	game.combat._on_stage_entered(1, false)
	await physics_frame
	var spec: Dictionary = library.site_spec(entry)
	spec["site"] = "entry_test"
	var s = acts._build(entry.activity, Vector2(100, 100), spec)
	acts.sites.append(s)
	var local := Vector3(entry.entry_spot[0], 0, entry.entry_spot[1])
	var at: Vector3 = s.to_global(local)
	at.y = game.ctx.terrain.height(at.x, at.z) + Tuning.RADIUS + 0.1
	game.player.reset_to(at)
	game.player.active_body().global_position = at
	game.player.active_body().linear_velocity = Vector3.ZERO
	game.player.set_frozen(mode == "idle")
	game.player.set_physics_process(mode != "idle")
	var driver := BotDriver.new(game, "completionist", seed_value)
	driver._cache_phase = "runup"
	game.player.source = driver.source if mode != "idle" else Intent.Scripted.new()
	acts.set_physics_process(true)
	elapsed = 0.0
	entry_damage = 0.0
	var limit := 2.0 if mode == "idle" else CLEAR_SECONDS
	var control_placed := false
	while elapsed < limit and game.run.alive() and not s.done:
		if unsafe_entry and s.started and not control_placed and not s.pack.is_empty():
			var enemy = s.pack[0]
			enemy.global_position = game.ctx.terrain.drop_point(at.x, at.z, enemy.half_height)
			control_placed = true
		if mode != "idle":
			driver.ticks += 1
			driver._boost_clock -= H
			if entry.kind == "secret":
				driver._cache_ram(s, game.player.ball_position(), H)
			else:
				var foe = driver._pack_foe(s, game.player.ball_position())
				if foe != null:
					driver._fight(foe, H)
				else:
					driver._act(s.global_position, null, H)
		await physics_frame
		elapsed += H
	seen_telegraphs += driver._seen.size()
	evasions += driver._evaded.size()
	var result := {"id": entry.id, "mode": mode, "seed": seed_value, "entry_damage": entry_damage, "cleared": s.done, "started": s.started, "spawned": s.spawn_positions.size(), "wave": s.wave, "round": s.round, "seconds": snappedf(elapsed, 0.01), "outcome": "cleared" if s.done else "capped" if game.run.alive() else "died", "hp": game.run.hp, "seen": driver._seen.size(), "control_placed": control_placed}
	acts.set_physics_process(false)
	acts.clear()
	game.combat._start_attempt()
	await physics_frame
	return result
