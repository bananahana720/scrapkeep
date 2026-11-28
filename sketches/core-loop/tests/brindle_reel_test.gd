extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The reel (W1-61, ruling ed / W1-139d) and Brindle's two visible cue twins (W1-105, W1-106).
# A chunk broken before its phase floor holds the phase (ruling bs), and for the rest of that
# floor Brindle reels: he keeps pressing at a slowed cadence across all three hull phases with
# no gap over 6.0 s without a committed attack (and a planted 7.0 s quiet reel caught), every
# committed attack keeps a tell >= 0.6 s, each gapped hull hit still sheds Rules.REEL_SCRAP and
# fills the ultimate, and the phase floors (Rules.PHASE_MIN_SECONDS) still turn the phase.
# Alongside: the Furnace reprise previews its exact committed band in harmless bone style for
# the whole sound cue (W1-105) without moving commit time; the Scuttle's hull braces visibly
# for >= 0.6 s before a hook turn commits (W1-106) without moving commit time, with a no-brace
# plant caught; and phase turns publish boss_phase_changed and fight_phase_changed on the bus.
#
# Evidence limit: combat.strike() stands in for hull contacts, and previews/bracing are checked
# through their live nodes and accessors rather than pixels (before/after Metal stills prove pixels).

const DT := 1.0 / 90.0
const RAM_FORCE := 150.0
const MAX_REEL_GAP_S := 6.0

var _game
var _boss
var _combat
var _failures := 0
var _reels := 0
var _commits: Array = []
var _cues: Array = []
var _boss_phases: Array = []
var _fight_phases: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _above() -> void:
	Harness.put_ball(_game, _boss.arena.global_position + Vector3.UP * 40.0)


func _hit(target, kind: String, force: float) -> void:
	_above()
	_combat.strike(target, kind, force)
	await physics_frame


func _advance(seconds: float) -> void:
	for _i in int(ceil(seconds / DT)):
		_above()
		_boss.advance(DT)


func _stagger_by_rams(hull) -> int:
	var rams := 0
	while not _boss.staggered() and rams < 8:
		await _hit(hull, "ram", RAM_FORCE)
		rams += 1
	return rams


# Breaks the live phase's chunk: a crack in one opening, the shatter in the next.
func _break_chunk(hull) -> void:
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)


func _reel_pickups() -> Array:
	return _boss.pickups_left().filter(func(p): return p["source"] == "reel")


func _reel_value() -> int:
	var total := 0
	for p in _reel_pickups():
		total += int(p["value"])
	return total


func _reel_points() -> float:
	return float(_game.player.abilities.meter.sources.get("reel", 0.0))


# Advances `seconds` while the boss reels (stopping early if the phase turns) and returns the
# worst gap without a committed attack, the commit timestamps, and the shortest committed tell.
func _watch_reel(seconds: float, ball_fn: Callable = Callable()) -> Dictionary:
	var start: float = _boss.clock
	var commit_start := _commits.size()
	var last_at := start
	var worst_gap := 0.0
	var min_tell := INF
	var times: Array = []
	for _i in int(ceil(seconds / DT)):
		if not _boss.reeling():
			break
		if ball_fn.is_valid():
			ball_fn.call()
		else:
			_above()
		_boss.advance(DT)
		while commit_start < _commits.size():
			var row: Dictionary = _commits[commit_start]
			commit_start += 1
			var at: float = row["at"]
			worst_gap = maxf(worst_gap, at - last_at)
			last_at = at
			times.append(at)
			min_tell = minf(min_tell, float(row["warn"]))
	var end_at: float = _boss.clock
	worst_gap = maxf(worst_gap, end_at - last_at)
	return {"worst_gap": worst_gap, "commits": times.size(), "times": times, "min_tell": min_tell, "span": end_at - start}


func _check_reprise_preview() -> void:
	_boss.jump_to_phase(2)
	var cue_idx := _cues.size()
	var commit_idx := _commits.size()
	var lead_at := -1.0
	var lead_warn := -1.0
	var cue_at := -1.0
	var preview_seen := false
	var preview_harmless := true
	var preview_band := Vector2.ZERO
	var preview_duration := 0.0
	var reprise_commit_at := -1.0
	var reprise_band := Vector2.ZERO
	var preview_after_commit := true
	var park: Vector3 = _boss.arena.point_at(0.0, 42.0, 1.0)
	for _i in int(ceil(18.0 / DT)):
		Harness.put_ball(_game, park)
		_boss.advance(DT)
		while commit_idx < _commits.size():
			var row: Dictionary = _commits[commit_idx]
			commit_idx += 1
			if lead_at < 0.0:
				lead_at = float(row["at"])
				lead_warn = float(row["warn"])
			elif reprise_commit_at < 0.0:
				reprise_commit_at = float(row["at"])
				for h in _boss.active_hazards():
					if h.cued:
						reprise_band = Vector2(h.r_in, h.r_out)
						break
				preview_after_commit = _boss.reprise_preview() != null
		while cue_idx < _cues.size():
			var c: Dictionary = _cues[cue_idx]
			cue_idx += 1
			if cue_at < 0.0 and String(c["id"]).begins_with("slag_ring_"):
				cue_at = float(c["at"])
		var p = _boss.reprise_preview()
		if p != null:
			preview_seen = true
			preview_duration += DT
			preview_band = Vector2(p.r_in, p.r_out)
			var desc: Dictionary = p.descriptor()
			var roles: Array = Threat.marks(desc, false).map(func(m): return String(m["role"]))
			var ok_harmless: bool = p.color == Palette.SAND and not p.is_hostile() \
				and not p.is_in_group(Threat.GROUP) and not (p in _boss.active_hazards()) \
				and roles.all(func(r): return r.begins_with("outline"))
			preview_harmless = preview_harmless and ok_harmless
		if reprise_commit_at >= 0.0:
			break
	var expected_commit := lead_at + lead_warn + Rules.SLAG_LIVE
	var timing_ok: bool = cue_at > 0.0 and reprise_commit_at > 0.0 \
		and absf(reprise_commit_at - cue_at - FightPhases.CUE_LEAD) <= DT * 2.0 \
		and absf(reprise_commit_at - expected_commit) <= DT * 2.0
	var duration_ok: bool = absf(preview_duration - FightPhases.CUE_LEAD) <= DT * 3.0
	_report("W1-105 reprise slag ring previews its exact band in harmless style for the whole sound cue",
		preview_seen and preview_harmless and preview_band == reprise_band and duration_ok and not preview_after_commit and timing_ok,
		"seen %s, harmless %s, preview band %s vs committed %s, shown %.3f s (CUE_LEAD %.2f), cleared %s, commit delta %.3f s"
			% [preview_seen, preview_harmless, preview_band, reprise_band, preview_duration, FightPhases.CUE_LEAD,
				not preview_after_commit, reprise_commit_at - expected_commit])


func _run_hook_brace_probe(plant: String) -> Dictionary:
	_boss._reel_plant = plant
	_boss.jump_to_phase(3)
	var ship = _boss.ship
	var anim: AnimationPlayer = BossModel.player_of(ship.model) if ship.model != null else null
	var brace_clips: Array = []
	var track := {"on": false}
	var on_anim_started := func(clip: StringName) -> void:
		if bool(track["on"]):
			brace_clips.append(String(clip))
	if anim != null:
		anim.animation_started.connect(on_anim_started)
	var centre: Vector3 = _boss.arena.global_position
	var inward := Vector3(centre.x - ship.global_position.x, 0.0, centre.z - ship.global_position.z).normalized()
	var bait: Vector3 = ship.global_position + inward * 12.0
	bait.y = _boss.arena.ground(bait) + Tuning.RADIUS + 0.05
	var cue_idx := _cues.size()
	var commit_idx := _commits.size()
	var lead_seen := false
	var brace_start := -1.0
	var brace_clip_played := false
	var cue_at := -1.0
	var hook_commit_at := -1.0
	var held_through_cue := true
	var cleared_on_commit := false
	for _i in int(ceil(12.0 / DT)):
		var st: String = _boss._charge.get("state", "")
		if st == _boss.CHARGE_REST:
			Harness.put_ball(_game, bait)
		elif st in [_boss.CHARGE_BRACE, _boss.CHARGE_RUN]:
			Harness.put_ball(_game, bait + Vector3.UP * 40.0)
		elif st == _boss.CHARGE_HOOK:
			Harness.put_ball(_game, bait + Vector3.UP * 40.0)
		var was_bracing: bool = ship.bracing()
		track["on"] = lead_seen and not was_bracing and hook_commit_at < 0.0
		_boss.advance(DT)
		if anim != null:
			anim.advance(DT)
		track["on"] = false
		while commit_idx < _commits.size():
			var row: Dictionary = _commits[commit_idx]
			commit_idx += 1
			if not lead_seen:
				lead_seen = true
			elif hook_commit_at < 0.0:
				hook_commit_at = float(row["at"])
				cleared_on_commit = not ship.bracing()
		while cue_idx < _cues.size():
			var c: Dictionary = _cues[cue_idx]
			cue_idx += 1
			if cue_at < 0.0 and String(c["id"]) == "charge":
				cue_at = float(c["at"])
		if lead_seen and hook_commit_at < 0.0:
			if ship.bracing() and brace_start < 0.0:
				brace_start = _boss.clock
				brace_clip_played = "charge_warn" in brace_clips \
					and (anim == null or anim.assigned_animation == &"charge_warn")
			if cue_at > 0.0 and not ship.bracing():
				held_through_cue = false
		if hook_commit_at >= 0.0:
			break
	if anim != null and anim.animation_started.is_connected(on_anim_started):
		anim.animation_started.disconnect(on_anim_started)
	_boss._reel_plant = ""
	var visible_s := (hook_commit_at - brace_start) if (brace_start >= 0.0 and hook_commit_at > 0.0) else 0.0
	return {
		"brace_start": brace_start,
		"cue_at": cue_at,
		"commit_at": hook_commit_at,
		"visible_s": visible_s,
		"before_cue": brace_start >= 0.0 and cue_at > 0.0 and brace_start < cue_at,
		"held_through_cue": held_through_cue,
		"cleared": cleared_on_commit,
		"timing_ok": cue_at > 0.0 and hook_commit_at > 0.0 and absf(hook_commit_at - cue_at - FightPhases.CUE_LEAD) <= DT * 2.0,
		"model_loaded": anim != null and anim.has_animation("charge_warn"),
		"brace_clip_played": brace_clip_played,
		"brace_clips": brace_clips,
	}


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_combat = _game.combat
	_game.ctx.spawner = _combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.boss_reeled.connect(func(_at: Vector3, _scrap: int): _reels += 1)
	_game.events.boss_attack_telegraphed.connect(func(id: String, warn: float):
		_commits.append({"id": id, "warn": warn, "at": _boss.clock}))
	_game.events.attack_cued.connect(func(_fight: String, id: String, s: float):
		_cues.append({"id": id, "s": s, "at": _boss.clock}))
	_game.events.boss_phase_changed.connect(func(p: int, n: String): _boss_phases.append([p, n]))
	_game.events.fight_phase_changed.connect(func(fid: String, p: int, count: int): _fight_phases.append([fid, p, count]))
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	var hull = _boss.ship.hull
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)

	# An open phase: hull hits shed nothing and pay no reel.
	await _hit(hull, "ram", RAM_FORCE)
	_advance(Rules.REEL_GAP + 0.1)
	await _hit(hull, "ram", RAM_FORCE)
	_report("an open phase does not reel", not _boss.reeling() and _reel_pickups().is_empty() and _reels == 0 and _reel_points() == 0.0,
		"reeling %s, %d reel pickups, %d reel events, %.1f reel points" % [_boss.reeling(), _reel_pickups().size(), _reels, _reel_points()])

	# Break the Requisition's chunk early: the phase holds and the reel starts.
	await _break_chunk(hull)
	var broke_at: float = _boss.phase_clock
	_report("an early chunk starts the reel", _boss.phase == 1 and _boss.chunks_left() == 3 and broke_at < Rules.PHASE_MIN_SECONDS[0]
			and _boss.reeling(),
		"chunk broken %.1f s into a %.0f s floor; reeling %s" % [broke_at, Rules.PHASE_MIN_SECONDS[0], _boss.reeling()])

	# Ruling ed (phase 1): Brindle keeps pressing, slowed, with no gap over 6 s during the reel.
	var p1 := _watch_reel(10.0)
	var p1_gap_between := float(p1["times"][1]) - float(p1["times"][0]) if p1["times"].size() >= 2 else 0.0
	var normal_p1 := ChallengeDials.period("brindle", Rules.CRANE_PERIOD, 1)
	_report("phase 1 reel keeps pressing slowed with no gap over 6 s",
		p1["commits"] >= 2 and p1["worst_gap"] <= MAX_REEL_GAP_S and p1_gap_between > normal_p1
			and p1["min_tell"] >= ChallengeDials.TELL_FLOOR and _boss.reeling(),
		"%d commits over %.1f s, worst gap %.2f s (<= %.1f), interval %.2f s vs normal %.2f s, shortest tell %.2f s"
			% [p1["commits"], p1["span"], p1["worst_gap"], MAX_REEL_GAP_S, p1_gap_between, normal_p1, p1["min_tell"]])

	# A burst of hits inside one gap pays one reel hit; a hit after the gap pays the next.
	var meter_before: float = _reel_points()
	for _i in 4:
		await _hit(hull, "ram", RAM_FORCE)
	var burst_pickups := _reel_pickups()
	var burst_scrap := 0
	for p in burst_pickups:
		burst_scrap += int(p["value"])
	var burst_reels := _reels
	_advance(Rules.REEL_GAP + 0.05)
	await _hit(hull, "arc", 1.0e6)
	var shot_reels := _reels
	await _hit(hull, "ram", RAM_FORCE)
	_report("each gapped hull hit sheds scrap and fills the ultimate", burst_reels == 1 and burst_pickups.size() == Rules.REEL_PICKUPS
			and burst_scrap == Rules.REEL_SCRAP and shot_reels == 1 and _reels == 2 and _reel_pickups().size() == 2 * Rules.REEL_PICKUPS
			and is_equal_approx(_reel_points() - meter_before, 2.0 * float(UltimateMeter.WEIGHTS["reel"])),
		"four rams in one gap: %d reel event, %d pickups worth %d; a weapon shot after the gap left %d, a ram made %d; meter paid %.1f"
			% [burst_reels, burst_pickups.size(), burst_scrap, shot_reels, _reels, _reel_points() - meter_before])

	# The pickups lie between the hull and the ball, on the floor, and pay scrap and cogs.
	var p0: Dictionary = _reel_pickups()[0]
	var ship_at: Vector3 = _boss.ship.global_position
	var from_hull := Vector2(p0["at"].x - ship_at.x, p0["at"].z - ship_at.z).length()
	var cogs_before: int = _game.run.cogs
	var scrap_before: int = _reel_value()
	Harness.put_ball(_game, p0["at"])
	_boss.advance(DT)
	var taken: int = scrap_before - _reel_value()
	_report("reel pickups pay scrap and cogs", from_hull > Rules.REEL_REACH - Rules.REEL_SPREAD - 0.5
			and taken >= int(p0["value"]) and _game.run.cogs - cogs_before == taken,
		"pickup %.1f m from the hull centre; rolling over it took %d scrap of reel pickups and paid %d cogs"
			% [from_hull, taken, _game.run.cogs - cogs_before])

	# The reel caps its hits.
	for _i in Rules.REEL_HITS + 3:
		_advance(Rules.REEL_GAP + 0.02)
		await _hit(hull, "ram", RAM_FORCE)
	_report("a reel pays at most REEL_HITS hits", _reels == Rules.REEL_HITS and _boss.phase == 1,
		"%d reel events after %d gapped hits (cap %d)" % [_reels, Rules.REEL_HITS + 5, Rules.REEL_HITS])

	# The floor still turns the phase, publishes phase-turn facts, and phase 2 opens unreeled.
	if _boss.phase_clock < Rules.PHASE_MIN_SECONDS[0] - 0.5:
		_advance(Rules.PHASE_MIN_SECONDS[0] - _boss.phase_clock - 0.5)
	var still_one: bool = _boss.phase == 1
	_advance(1.0)
	var turned_p2: bool = _boss.phase == 2 and _boss_phases.back() == [2, "Furnace"] and _fight_phases.back() == ["brindle", 2, 3]
	_advance(FightPhases.TRANSITION_SECONDS + 3.0)
	_report("the floor turns the phase and publishes phase-turn bus facts", still_one and turned_p2 and not _boss.reeling()
			and not _boss.active_hazards().is_empty(),
		"phase 1 held %s; phase %d boss_phase %s fight_phase %s; reeling %s with %d hazards"
			% [still_one, _boss.phase, _boss_phases.back(), _fight_phases.back(), _boss.reeling(), _boss.active_hazards().size()])

	# Ruling ed (phase 2): Furnace reels and keeps committing slag rings within 6 s.
	await _break_chunk(hull)
	var p2 := _watch_reel(minf(12.0, Rules.PHASE_MIN_SECONDS[1] - _boss.phase_clock - 0.5))
	_report("phase 2 reel keeps pressing with no gap over 6 s",
		p2["commits"] >= 2 and p2["worst_gap"] <= MAX_REEL_GAP_S and p2["min_tell"] >= ChallengeDials.TELL_FLOOR and _boss.reeling(),
		"%d commits over %.1f s, worst gap %.2f s (<= %.1f), shortest tell %.2f s"
			% [p2["commits"], p2["span"], p2["worst_gap"], MAX_REEL_GAP_S, p2["min_tell"]])

	# Planted fault (7 s with no committed attack during a reel) must fail the 6 s line.
	_boss.jump_to_phase(2)
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)
	await _break_chunk(hull)
	_boss._reel_plant = "stop"
	var planted := _watch_reel(7.2)
	_boss._reel_plant = ""
	_report("planted 7 s quiet reel fails the 6 s gap rule",
		planted["commits"] == 0 and planted["worst_gap"] > MAX_REEL_GAP_S,
		"planted stop: %d commits, worst gap %.2f s (> %.1f s)" % [planted["commits"], planted["worst_gap"], MAX_REEL_GAP_S])

	# W1-105: Furnace reprise shows its harmless preview band for the whole sound cue.
	_check_reprise_preview()

	# Ruling ed (phase 3): Scuttle reels and keeps committing charges within 6 s.
	_boss.jump_to_phase(3)
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)
	await _break_chunk(hull)
	var scuttle_reel: bool = _boss.phase == 3 and _boss.chunks_left() == 1 and _boss.reeling()
	var centre: Vector3 = _boss.arena.global_position
	var p3_ball := func() -> void:
		var ship_pos: Vector3 = _boss.ship.global_position
		var inward := Vector3(centre.x - ship_pos.x, 0.0, centre.z - ship_pos.z)
		inward = inward.normalized() if inward.length() > 1.0 else Vector3.FORWARD
		var spot: Vector3 = ship_pos + inward * 12.0
		Harness.put_ball(_game, Vector3(spot.x, _boss.arena.ground(spot) + 40.0, spot.z))
	var p3 := _watch_reel(minf(12.0, Rules.PHASE_MIN_SECONDS[2] - _boss.phase_clock - 0.5), p3_ball)
	_report("phase 3 reel keeps pressing with no gap over 6 s",
		scuttle_reel and p3["commits"] >= 2 and p3["worst_gap"] <= MAX_REEL_GAP_S
			and p3["min_tell"] >= ChallengeDials.TELL_FLOOR and _boss.reeling(),
		"reeling %s; %d commits over %.1f s, worst gap %.2f s (<= %.1f), shortest tell %.2f s"
			% [scuttle_reel, p3["commits"], p3["span"], p3["worst_gap"], MAX_REEL_GAP_S, p3["min_tell"]])

	# W1-106: Scuttle's hull braces visibly >= 0.6 s before hook commit without moving commit time,
	# and removing the brace (plant) fails.
	var brace := _run_hook_brace_probe("")
	_report("W1-106 hull braces visibly >= 0.6 s before hook turn commits without moving commit time",
		brace["before_cue"] and brace["held_through_cue"] and brace["cleared"] and brace["timing_ok"]
			and float(brace["visible_s"]) >= ChallengeDials.TELL_FLOOR,
		"visible %.3f s (>= %.1f s), started before cue %s, held through cue %s, cleared on commit %s, timing ok %s"
			% [brace["visible_s"], ChallengeDials.TELL_FLOOR, brace["before_cue"], brace["held_through_cue"],
				brace["cleared"], brace["timing_ok"]])
	_report("W1-106 hook brace starts the charge_warn clip after the lead charge",
		brace["model_loaded"] and brace["brace_clip_played"],
		"model_loaded %s, charge_warn started on brace %s, clips %s"
			% [brace["model_loaded"], brace["brace_clip_played"], str(brace["brace_clips"])])
	var brace_plant := _run_hook_brace_probe("no_brace")
	_report("W1-106 planted missing hull brace fails the >= 0.6 s visibility check",
		float(brace_plant["visible_s"]) < ChallengeDials.TELL_FLOOR and not brace_plant["before_cue"],
		"planted no_brace: visible %.3f s, before_cue %s" % [brace_plant["visible_s"], brace_plant["before_cue"]])

	# Phase 1 reel entry clamps a pre-existing slow crane timer (e.g. high brindle.period_mult)
	# so no gap over 6 s opens when the reel begins.
	ChallengeDials.set_overrides({"brindle.period_mult": 8.0})
	_boss.jump_to_phase(1)
	var pre_commits := _commits.size()
	for _i in int(ceil(3.0 / DT)):
		_above()
		_boss.advance(DT)
		if _commits.size() > pre_commits:
			break
	var open_before_break: bool = not _boss.reeling() and _commits.size() > pre_commits
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	await _stagger_by_rams(hull)
	var open_before_shatter: bool = not _boss.reeling()
	var pending_before_shatter: float = _boss._next_attack - _boss.clock
	await _hit(hull, "ram", RAM_FORCE)
	var p1_clamped := _watch_reel(8.0)
	ChallengeDials.reset()
	_report("phase 1 reel entry clamps a high-period_mult crane timer within 6 s",
		open_before_break and open_before_shatter and pending_before_shatter > MAX_REEL_GAP_S
			and p1_clamped["commits"] >= 1 and p1_clamped["worst_gap"] <= MAX_REEL_GAP_S and _boss.reeling(),
		"open_before_break %s, open_before_shatter %s, pending_before_shatter %.2f s (> %.1f s), %d commits over %.1f s, worst gap %.2f s (<= %.1f s)"
			% [open_before_break, open_before_shatter, pending_before_shatter, MAX_REEL_GAP_S,
				p1_clamped["commits"], p1_clamped["span"], p1_clamped["worst_gap"], MAX_REEL_GAP_S])

	print("brindle_reel_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
