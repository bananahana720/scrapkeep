extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const FieldTips := preload("res://src/ui/field_tips.gd")

const MINUTES := 15
const FIGHT_WORD_BUDGET := 25
const SPIKE_CONCEPTS := 6
const WORD_SAMPLE_STEP_S := 0.5

var _settings := {}
var _game
var _driver
var _tick := 0
var _done := false
var _out := ""
var _max_s := 900.0
var _max_stages := 2
var _concepts := {}
var _concept_order: Array = []
var _buckets: Array = []
var _first_part_s := -1.0
var _first_part_id := ""
var _first_warden_s := -1.0
var _first_stagger_s := -1.0
var _first_hit_s := -1.0
var _first_kill_s := -1.0
var _first_bay_s := -1.0
var _first_gate_s := -1.0
var _next_word_sample_s := 0.0
var _peak_fight_words := 0
var _peak_calm_words := 0
var _fight_budget_violations: Array = []
var _last_stage := 0


func _initialize() -> void:
	SimClock.ticks = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_settings["seed"] = arg.substr(7)
		elif arg.begins_with("--pilot="):
			_settings["pilot"] = arg.substr(8)
		elif arg.begins_with("--policy="):
			_settings["policy"] = arg.substr(9)
		elif arg.begins_with("--stages="):
			_settings["stages"] = arg.substr(9)
		elif arg.begins_with("--max-s="):
			_settings["max-s"] = arg.substr(8)
		elif arg.begins_with("--out="):
			_settings["out"] = arg.substr(6)
	_out = String(_settings.get("out", ""))
	_max_s = float(_settings.get("max-s", "900"))
	_max_stages = int(_settings.get("stages", "2"))
	for m in MINUTES:
		_buckets.append({
			"minute": m + 1,
			"concepts_new": 0,
			"concept_ids": [],
			"kills": 0,
			"hits_taken": 0,
			"damage_taken": 0.0,
			"parts_gained": 0,
			"peak_enemies": 0,
			"warden_active_s": 0.0,
			"stage": 0,
		})
	var run_seed := int(_settings.get("seed", "1"))
	seed(run_seed)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	var base_dir := _out.get_base_dir() if _out != "" else "user://"
	_game.run_store_path = base_dir.path_join("first15-probe-%d-%d.json" % [OS.get_process_id(), run_seed])
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_start()
		return false
	_tick += 1
	_observe(delta)
	var over: bool = _driver.tick(delta)
	if not over and _game.run != null:
		if _game.run.run_time >= _max_s:
			over = true
		elif _game.run.stage > _max_stages:
			over = true
	if over:
		_finish(String(_driver.outcome) if "outcome" in _driver else "")
	return false


func _start() -> void:
	var run_seed := int(_settings.get("seed", "1"))
	var events = _game.events
	events.stage_entered.connect(_on_stage_entered)
	events.scrap_collected.connect(func(_amount: int, _at: Vector3, _total: int): _note_concept("scrap_pickup"))
	events.prompt_shown.connect(func(verb: String): _note_concept("prompt:" + verb))
	events.line_state_changed.connect(_on_line_state)
	events.slammed.connect(func(_at: Vector3, _strength: float, _flatness: float): _note_concept("slam"))
	events.enemy_killed.connect(_on_enemy_killed)
	events.player_hit.connect(_on_player_hit)
	events.part_gained.connect(_on_part_gained)
	events.heft_class_changed.connect(func(_cls: int, _mass: float): _note_concept("heft_up"))
	events.activity_done.connect(func(id: String, _at: Vector3): _note_concept("activity:" + id))
	events.warden_engaged.connect(_on_warden_engaged)
	events.posture_changed.connect(_on_posture)
	events.reward_offered.connect(_on_reward_offered)
	events.bay_entered.connect(_on_bay_entered)
	events.boss_arena_entered.connect(func(): _note_concept("boss_arena"))
	events.synergy_discovered.connect(func(id: String, _cause, _first): _note_concept("synergy:" + id))
	_driver = BotDriver.new(_game, String(_settings.get("policy", "skipper")), run_seed)
	if _settings.has("pilot"):
		_driver.class_index = BotDriver.class_index_for(run_seed, String(_settings["pilot"]))
	_game.presentation.audio.bake_now()
	_game.run.run_seed_override = run_seed
	_driver.start(false)


func _minute_index() -> int:
	var t := float(_game.run.run_time) if _game != null and _game.run != null else 0.0
	return clampi(int(floor(t / 60.0)), 0, MINUTES - 1)


func _run_t() -> float:
	return snappedf(float(_game.run.run_time), 0.01) if _game != null and _game.run != null else 0.0


func _note_concept(id: String) -> void:
	if _concepts.has(id) or _game == null or _game.run == null:
		return
	var t := _run_t()
	var m := _minute_index()
	var stage := int(_game.run.stage)
	_concepts[id] = {"t": t, "minute": m + 1, "stage": stage}
	_concept_order.append({"id": id, "t": t, "minute": m + 1, "stage": stage})
	_buckets[m]["concepts_new"] = int(_buckets[m]["concepts_new"]) + 1
	(_buckets[m]["concept_ids"] as Array).append(id)


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_last_stage = stage
	_note_concept("stage_%d_drop" % stage)


func _on_line_state(state: String, _target, _at: Vector3, _cause: String) -> void:
	if state == "latched_world":
		_note_concept("harpoon_world")
	elif state == "latched_body":
		_note_concept("harpoon_body")
	elif state == "smash_committed":
		_note_concept("harpoon_smash")


func _on_enemy_killed(_kind: String, _at: Vector3, _scrap: int) -> void:
	if _first_kill_s < 0.0:
		_first_kill_s = _run_t()
	_note_concept("first_kill")
	var m := _minute_index()
	_buckets[m]["kills"] = int(_buckets[m]["kills"]) + 1


func _on_player_hit(amount: float, _source: String) -> void:
	if _first_hit_s < 0.0:
		_first_hit_s = _run_t()
	_note_concept("first_hit_taken")
	var m := _minute_index()
	_buckets[m]["hits_taken"] = int(_buckets[m]["hits_taken"]) + 1
	_buckets[m]["damage_taken"] = snappedf(float(_buckets[m]["damage_taken"]) + amount, 0.1)


func _on_part_gained(part_id: String, _source: String) -> void:
	if _first_part_s < 0.0:
		_first_part_s = _run_t()
		_first_part_id = part_id
	_note_concept("first_part")
	var m := _minute_index()
	_buckets[m]["parts_gained"] = int(_buckets[m]["parts_gained"]) + 1


func _on_warden_engaged(_stage_n: int) -> void:
	if _first_warden_s < 0.0:
		_first_warden_s = _run_t()
	_note_concept("warden_engaged")


func _on_posture(_enemy, _posture: float, staggered: bool) -> void:
	if not staggered:
		return
	if _game.flow.state_name() == "boss":
		_note_concept("boss_staggered")
	else:
		if _first_stagger_s < 0.0:
			_first_stagger_s = _run_t()
		_note_concept("warden_staggered")


func _on_reward_offered(_offers: Array) -> void:
	if _first_gate_s < 0.0:
		_first_gate_s = _run_t()
	_note_concept("reward_gates")


func _on_bay_entered(_banked: float) -> void:
	if _first_bay_s < 0.0:
		_first_bay_s = _run_t()
	_note_concept("bay_entered")


func _observe(delta: float) -> void:
	if _game.run == null or not _game.flow.in_play():
		return
	var m := _minute_index()
	var enemies := get_nodes_in_group("enemy").size()
	_buckets[m]["peak_enemies"] = maxi(int(_buckets[m]["peak_enemies"]), enemies)
	_buckets[m]["stage"] = maxi(int(_buckets[m]["stage"]), int(_game.run.stage))
	var fight_live: bool = FieldTips.fight_live(_game.flow)
	if fight_live:
		_buckets[m]["warden_active_s"] = float(_buckets[m]["warden_active_s"]) + delta
	if _game.hud != null:
		var obj_id := String(_game.hud.objective_reading().get("id", ""))
		if obj_id != "":
			_note_concept("objective:" + obj_id)
		if _game.run.run_time >= _next_word_sample_s:
			_next_word_sample_s = _game.run.run_time + WORD_SAMPLE_STEP_S
			var count := WordBudget.count(_game.hud, _game.camera.cam if _game.camera != null else null)
			var total := int(count["hud"])
			if fight_live:
				_peak_fight_words = maxi(_peak_fight_words, total)
				if total > FIGHT_WORD_BUDGET and _fight_budget_violations.size() < 8:
					_fight_budget_violations.append({"t": _run_t(), "stage": int(_game.run.stage), "words": total})
			else:
				_peak_calm_words = maxi(_peak_calm_words, total)


func _tip_audit() -> Dictionary:
	var max_lines := 0
	var max_words := 0
	var multi_line: Array = []
	for id in FieldTips.TIPS:
		var text := String(FieldTips.TIPS[id])
		var lines := text.split("\n", false).size()
		max_lines = maxi(max_lines, lines)
		max_words = maxi(max_words, WordBudget.words_in(text))
		if lines > 1:
			multi_line.append(id)
	return {"tip_count": FieldTips.TIPS.size(), "max_lines": max_lines, "max_words": max_words, "multi_line": multi_line}


func _finish(outcome: String) -> void:
	_done = true
	var run_s := _run_t()
	var played_minutes := clampi(int(ceil(maxf(run_s, 1.0) / 60.0)), 1, MINUTES)
	var active_buckets := _buckets.slice(0, played_minutes)
	var spikes: Array = []
	var flats: Array = []
	var quiet_run := 0
	for b in active_buckets:
		b["warden_active_s"] = snappedf(float(b["warden_active_s"]), 0.1)
		if int(b["concepts_new"]) >= SPIKE_CONCEPTS:
			spikes.append({"minute": b["minute"], "concepts_new": b["concepts_new"]})
		if int(b["concepts_new"]) == 0 and int(b["kills"]) == 0:
			quiet_run += 1
			if quiet_run >= 2:
				flats.append(b["minute"])
		else:
			quiet_run = 0
	var report := {
		"tool": "first_15_probe",
		"seed": int(_settings.get("seed", "1")),
		"pilot": String(_game.run.class_id()) if _game.run != null else "",
		"policy": String(_settings.get("policy", "skipper")),
		"outcome": outcome,
		"run_time_s": run_s,
		"ticks": _tick,
		"stage_reached": _last_stage,
		"milestones": {
			"first_kill_s": _first_kill_s,
			"first_hit_s": _first_hit_s,
			"first_part_s": _first_part_s,
			"first_part_id": _first_part_id,
			"first_warden_s": _first_warden_s,
			"first_stagger_s": _first_stagger_s,
			"first_gate_s": _first_gate_s,
			"first_bay_s": _first_bay_s,
		},
		"concept_total": _concept_order.size(),
		"concepts": _concept_order,
		"minutes": active_buckets,
		"spikes": spikes,
		"flat_minutes": flats,
		"word_budget": {
			"fight_cap": FIGHT_WORD_BUDGET,
			"peak_fight_words": _peak_fight_words,
			"peak_calm_words": _peak_calm_words,
			"violations": _fight_budget_violations,
			"tips": _tip_audit(),
		},
	}
	if _out != "":
		var file := FileAccess.open(_out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	if FileAccess.file_exists(_game.run_store_path):
		DirAccess.remove_absolute(_game.run_store_path)
	print("first_15_probe: seed=%d pilot=%s policy=%s outcome=%s t=%.1fs stage=%d concepts=%d first_part=%.1fs(%s) warden=%.1fs peak_fight_words=%d violations=%d" % [
		report["seed"], report["pilot"], report["policy"], outcome, run_s, _last_stage, _concept_order.size(),
		_first_part_s, _first_part_id, _first_warden_s, _peak_fight_words, _fight_budget_violations.size()])
	_game.free()
	SimClock.ticks = false
	quit(0)
