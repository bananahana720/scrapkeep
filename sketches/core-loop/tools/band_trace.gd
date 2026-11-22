extends "res://tools/band_run.gd"

# Tick-level replay and trace tool for World 1 band runs (PF-48, PF-49, W46-01).
# Built on tools/band_run.gd and tools/bot_run.gd so a seed replays identically with or without it.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/band_trace.gd \
#     -- --seeds=40317 --band=learner --attempt=1 [--every=90] [--from-tick=0] [--to-tick=0] \
#     [--trace-stage=0] [--trace-state=gates,launch|boss] [--out=<dir>]
#
# Without --out, defaults to the w1clear band-table run (--policy=skipper --table=park --gate=1
# --until=2 --fight-limit=240 --stage-limit=600 --ticks=156600 --qa-log=1) writing under
# artifacts/local/band-trace/<seed>-<band><attempt>.

var _trace_every := 90
var _trace_from := 0
var _trace_to := 0
var _trace_stage := 0
var _trace_states: Array[String] = []
var _trace_write := true
var _trace_hooked := false
var _trace_file: FileAccess
var _last_flow := ""
var _last_boss_phase := -1


func _initialize() -> void:
	var s := _parse(OS.get_cmdline_user_args())
	if not s.has("out"):
		_reexec_with_defaults(s)
		return
	_trace_every = maxi(1, int(s.get("every", "90")))
	_trace_from = maxi(0, int(s.get("from-tick", "0")))
	_trace_to = maxi(0, int(s.get("to-tick", "0")))
	_trace_stage = maxi(0, int(s.get("trace-stage", "0")))
	_trace_write = String(s.get("trace-out", "1")) != "0"
	for part in String(s.get("trace-state", "")).split(",", false):
		var cleaned := part.strip_edges()
		if cleaned != "":
			_trace_states.append(cleaned)
	super._initialize()


func _reexec_with_defaults(s: Dictionary) -> void:
	var seed_str := String(s.get("seeds", "40317"))
	var band_str := String(s.get("band", "learner"))
	var attempt_str := String(s.get("attempt", "1"))
	var out_rel := "artifacts/local/band-trace/%s-%s%s" % [seed_str.replace(",", "_"), band_str, attempt_str]
	var defaults := {
		"out": out_rel,
		"policy": "skipper",
		"table": "park",
		"gate": "1",
		"until": "2",
		"fight-limit": "240",
		"stage-limit": "600",
		"ticks": "156600",
		"qa-log": "1",
	}
	var forwarded := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		forwarded.append(arg)
	for key in defaults:
		if not s.has(key):
			forwarded.append("--%s=%s" % [key, defaults[key]])
	var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tools/band_trace.gd", "--"])
	args.append_array(forwarded)
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	for chunk in output:
		print(String(chunk).strip_edges())
	quit(code)


func _physics_process(delta: float) -> bool:
	var over := super._physics_process(delta)
	if _game == null or _game.flow == null or _driver == null:
		return over
	if not _trace_hooked:
		_trace_hooked = true
		_hook_trace_events()
	var tick: int = _driver.ticks
	var flow_state: String = _game.flow.state_name()
	var stage: int = _game.run.stage
	var boss = _driver._boss() if flow_state == "boss" else null
	var boss_phase: int = int(boss.phase) if boss != null and "phase" in boss else -1
	var changed := flow_state != _last_flow or boss_phase != _last_boss_phase
	_last_flow = flow_state
	_last_boss_phase = boss_phase
	if changed or _should_emit(tick, stage, flow_state):
		_emit_row(tick, stage, flow_state, boss, changed)
	if over and _trace_file != null:
		_trace_file.flush()
		_trace_file.close()
		_trace_file = null
	return over


func _hook_trace_events() -> void:
	if _trace_write and _out != "":
		var seed_num := _seeds[_index] if _index >= 0 and _index < _seeds.size() else 0
		_trace_file = FileAccess.open(_out.path_join("band-trace-%d.ndjson" % seed_num), FileAccess.WRITE)
	_game.events.stage_entered.connect(func(stage: int, retry: bool):
		print("band_trace: EVENT stage_entered stage=%d retry=%s tick=%d" % [stage, retry, _driver.ticks]))
	_game.events.warden_engaged.connect(func(stage: int):
		print("band_trace: EVENT warden_engaged stage=%d t=%.2f tick=%d" % [stage, _game.run.stage_time, _driver.ticks]))
	_game.events.beacon_unsealed.connect(func(stage: int):
		print("band_trace: EVENT beacon_unsealed stage=%d t=%.2f tick=%d" % [stage, _game.run.stage_time, _driver.ticks]))
	_game.events.flow_changed.connect(func(next_state: String):
		print("band_trace: EVENT flow_changed state=%s stage=%d t=%.2f tick=%d" % [next_state, _game.run.stage, _game.run.stage_time, _driver.ticks]))
	if _game.events.has_signal("boss_arena_entered"):
		_game.events.boss_arena_entered.connect(func():
			print("band_trace: EVENT boss_arena_entered stage=%d run_t=%.2f tick=%d" % [_game.run.stage, _game.run.run_time, _driver.ticks]))
	if _game.events.has_signal("boss_phase_changed"):
		_game.events.boss_phase_changed.connect(func(phase: int, phase_name: String):
			print("band_trace: EVENT boss_phase_changed phase=%d name=%s boss_t=%.2f tick=%d" % [phase, phase_name, _driver._boss_clock, _driver.ticks]))
	if _game.events.has_signal("boss_defeated"):
		_game.events.boss_defeated.connect(func():
			print("band_trace: EVENT boss_defeated boss_t=%.2f tick=%d" % [_driver._boss_clock, _driver.ticks]))


func _should_emit(tick: int, stage: int, flow_state: String) -> bool:
	if _trace_from > 0 and tick < _trace_from:
		return false
	if _trace_to > 0 and tick > _trace_to:
		return false
	if _trace_stage > 0 and stage != _trace_stage:
		return false
	if not _trace_states.is_empty() and flow_state not in _trace_states:
		return false
	return tick % _trace_every == 0


func _emit_row(tick: int, stage: int, flow_state: String, boss, transition: bool) -> void:
	var ball: Vector3 = _game.player.ball_position()
	var vel: Vector3 = _game.player.body().linear_velocity
	var spd: float = _game.player.planar_velocity().length()
	var grounded: bool = _game.player.state.grounded
	var goal := String(_driver.get("_goal"))
	var row := {
		"tick": tick,
		"stage": stage,
		"stage_s": snappedf(_game.run.stage_time, 0.01),
		"flow": flow_state,
		"transition": transition,
		"goal": goal,
		"pos": [snappedf(ball.x, 0.1), snappedf(ball.y, 0.1), snappedf(ball.z, 0.1)],
		"vel": [snappedf(vel.x, 0.1), snappedf(vel.y, 0.1), snappedf(vel.z, 0.1)],
		"speed": snappedf(spd, 0.1),
		"grounded": grounded,
		"hooked": _game.player.kit.hooked,
		"hp": snappedf(_game.run.hp, 0.1),
		"mass": snappedf(_game.run.mass, 0.1),
		"heft": snappedf(_game.run.heft(), 0.01),
		"punch": snappedf(_game.flow.punch_now(), 0.1),
	}
	var line := "T=%d s%d t=%.2f flow=%s goal=\"%s\" pos=(%.1f,%.1f,%.1f) v=(%.1f,%.1f,%.1f) spd=%.1f gnd=%s hp=%.0f heft=%.2f punch=%.0f" % [
		tick, stage, _game.run.stage_time, flow_state, goal,
		ball.x, ball.y, ball.z, vel.x, vel.y, vel.z, spd, str(grounded), _game.run.hp, _game.run.heft(), _game.flow.punch_now()
	]
	if flow_state == "gates" or flow_state == "launch":
		var offers: Array = _driver._offers
		var pick: int = _driver._gate_pick
		var gate_info := {
			"pick": pick,
			"offers": offers.size(),
			"gate_time": snappedf(_driver._gate_time, 0.01),
			"gate_run": String(_driver._gate_run),
			"climb_pts": _driver._fight_climb.size(),
			"launched": _game.flow._launched,
			"flight": snappedf(_game.flow._flight, 0.02),
			"seam_take": _game.flow._seam_take,
		}
		if not offers.is_empty() and pick >= 0 and pick < offers.size():
			var offer: Dictionary = offers[pick]
			var at: Vector3 = offer["at"]
			var facing: Vector3 = offer["facing"]
			var rel: Vector3 = ball - at
			var along: float = rel.dot(facing)
			var side: float = (rel - facing * along).length()
			gate_info["at"] = [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)]
			gate_info["along"] = snappedf(along, 0.1)
			gate_info["side"] = snappedf(side, 0.1)
			gate_info["dy"] = snappedf(rel.y, 0.1)
			line += " | gate=%d/%d gt=%.1f run=%s climb=%d at=(%.1f,%.1f,%.1f) along=%.1f side=%.1f dy=%.1f lnch=%s fl=%.2f" % [
				pick, offers.size(), _driver._gate_time, String(_driver._gate_run), _driver._fight_climb.size(),
				at.x, at.y, at.z, along, side, rel.y, str(_game.flow._launched), _game.flow._flight
			]
		else:
			line += " | gate=%d/%d gt=%.1f lnch=%s fl=%.2f" % [pick, offers.size(), _driver._gate_time, str(_game.flow._launched), _game.flow._flight]
		row["gate"] = gate_info
	elif flow_state == "boss" and boss != null:
		var chg: Dictionary = boss.get("_charge") if boss.get("_charge") is Dictionary else {}
		var hull_dist := -1.0
		var hull_pos := Vector3.ZERO
		if boss.get("ship") != null and is_instance_valid(boss.ship.hull):
			hull_pos = boss.ship.hull.global_position
			hull_dist = Vector2(ball.x - hull_pos.x, ball.z - hull_pos.z).length()
		var boss_info := {
			"state": boss.state_name(),
			"phase": int(boss.phase),
			"clock": snappedf(float(boss.clock), 0.02),
			"phase_clock": snappedf(float(boss.phase_clock), 0.02),
			"hp": snappedf(float(boss.hp), 0.1),
			"chunks": int(boss.chunks_left()) if boss.has_method("chunks_left") else -1,
			"posture": snappedf(float(boss.posture()), 0.1) if boss.has_method("posture") else -1.0,
			"staggered": bool(boss.staggered()) if boss.has_method("staggered") else false,
			"stagger_left": snappedf(float(boss.stagger_left()), 0.02) if boss.has_method("stagger_left") else 0.0,
			"cracked": bool(boss.chunk_cracked()) if boss.has_method("chunk_cracked") else false,
			"held": bool(boss._held()) if boss.has_method("_held") else false,
			"reeling": bool(boss.reeling()) if boss.has_method("reeling") else false,
			"transition": bool(boss._in_transition()) if boss.has_method("_in_transition") else false,
			"stunned": bool(boss.stunned()) if boss.has_method("stunned") else false,
			"charge_state": String(chg.get("state", "")),
			"charge_timer": snappedf(float(chg.get("timer", 0.0)), 0.02),
			"stuns": int(boss.stuns) if "stuns" in boss else 0,
			"clashes": int(boss.clashes) if "clashes" in boss else 0,
			"hull_pos": [snappedf(hull_pos.x, 0.1), snappedf(hull_pos.y, 0.1), snappedf(hull_pos.z, 0.1)],
			"hull_dist": snappedf(hull_dist, 0.1),
			"hazards": boss.active_hazards().size() if boss.has_method("active_hazards") else 0,
			"pickups": boss.pickups_left().size() if boss.has_method("pickups_left") else 0,
		}
		line += " | boss=%s ph=%d clk=%.1f pclk=%.1f ch=%d post=%.1f stag=%s(%.1f) crk=%s held=%s reel=%s trans=%s stun=%s chg=%s(%.2f) stuns=%d hd=%.1f pku=%d" % [
			boss_info["state"], boss_info["phase"], boss_info["clock"], boss_info["phase_clock"],
			boss_info["chunks"], boss_info["posture"], str(boss_info["staggered"]), boss_info["stagger_left"],
			str(boss_info["cracked"]), str(boss_info["held"]), str(boss_info["reeling"]), str(boss_info["transition"]),
			str(boss_info["stunned"]), boss_info["charge_state"], boss_info["charge_timer"],
			boss_info["stuns"], boss_info["hull_dist"], boss_info["pickups"]
		]
		row["boss"] = boss_info
	print(line)
	if _trace_file != null:
		_trace_file.store_line(JSON.stringify(row))
