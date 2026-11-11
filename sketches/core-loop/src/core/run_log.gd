extends Node

# The design feedback loop's run log (DEMO-SPEC). It listens to the bus and reads the
# run state and the ball, never a module's internals, and appends one record to
# runs.ndjson at every death and at the end of a run. A record is cumulative: each
# line carries the whole run so far, with the codex log's run_id. A run left without a
# death or an end since its last line (a new run started, the game closed, a bot that
# gave up) gets one more line with outcome "abandoned" and where it was left
# ("abandoned_in": "stage" or "arena"), so the loop sees runs that never finished. The
# arena block (I3) is the boss-entry record: it rides in every line after entry.
#
# Each record also carries the traversal facts (design-v3/TRAVERSAL.md): flow_share and
# dead_stops from the stage's spawn to the Warden's engagement, the harpoon's bites,
# smashes, breaks by cause and failed verbs by verb, and prompts_shown (one per key prompt
# drawn, counted on its rising edge, from prompt_shown), and the harpoon chain's record (HOOK-CHAIN.md):
# chains (one {links, pivots, combo, paid} per chain_end, read from the last row of
# player.chain.finished), best_combo and misses (chain_miss count). events_joined holds only the opt-in events the ball entered:
# the director publishes event_started for a participatory event when the ball reaches
# its ring, but also for the ambient flood, squall and terrain changes, which the player
# does not choose and which are left out.
#
# The sitting (LEGIBILITY): the record carries the table the run was played on, and each
# stage row carries the packs that arrived there in order ({faction, kinds} each), the synergies that fired there
# by id and, for a posture Warden only, its posture fight: staggers, chunks lost, glanced
# hits and the ticks from the first posture gain to the break or the stage's end. A row
# counts its attempts; packs, causes and posture describe the last attempt only and leave
# out the boss arena.

const LOG_FILE := "runs.ndjson"
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const UNKNOWN_CAUSE := "unspecified"


# The traversal measure's detector, fed one sample per physics tick. Flow share is the
# fraction of ticks at speed tier 2 or better. A dead stop is more than 0.5 s under tier 1
# with no brake, mount or interaction, or one contact that takes more than half of the
# planar speed the ball had in the last CONTACT_WINDOW seconds. The slow clock arms once
# the ball has first reached tier 1, so a standing start is not a stop. The park adds
# (PARK.md section 8) the airborne share (ticks with no ground contact over all ticks), the
# peak planar speed and the ticks at the blazing tier (3), read the same way on every tick.
class Traversal:
	extends RefCounted

	const FLOW_TIER := 2
	const MOVING_TIER := 1
	const DEAD_SECONDS := 0.5
	const HALVED := 0.5
	const CONTACT_WINDOW := 0.1
	const BLAZING_TIER := 3

	var ticks := 0
	var flow_ticks := 0
	var dead_stops := 0
	var airborne_ticks := 0
	var blazing_ticks := 0
	var peak_speed := 0.0
	var _tps := 90
	var _moving_speed := 0.0
	var _armed := false
	var _slow_ticks := 0
	var _slow_counted := false
	var _recent: Array[float] = []

	func _init(ticks_per_second: int, cruise: float) -> void:
		_tps = ticks_per_second
		_moving_speed = SpeedTier.MULTIPLES[MOVING_TIER] * cruise

	# One definition of a tick that neither counts toward a stop nor can start one.
	static func is_exempt(player) -> bool:
		var intent = player.intent
		return player.frozen() or player.kit.mounted or intent.interact_pressed or intent.mount_held

	# A stage was entered: the arming and the slow clock start over, the totals stay.
	func restart() -> void:
		_armed = false
		_slow_ticks = 0
		_slow_counted = false
		_recent.clear()

	func step(tier: int, planar_speed: float, braking: bool, exempt: bool, airborne := false) -> void:
		ticks += 1
		if tier >= FLOW_TIER:
			flow_ticks += 1
		if tier >= BLAZING_TIER:
			blazing_ticks += 1
		if airborne:
			airborne_ticks += 1
		peak_speed = maxf(peak_speed, planar_speed)
		if braking or exempt:
			_slow_ticks = 0
			_recent.clear()
			return
		var peak := 0.0
		for earlier in _recent:
			peak = maxf(peak, earlier)
		_recent.append(planar_speed)
		while _recent.size() > maxi(1, int(round(CONTACT_WINDOW * _tps))):
			_recent.pop_front()
		if tier >= MOVING_TIER:
			_armed = true
			_slow_ticks = 0
			_slow_counted = false
		elif _armed:
			_slow_ticks += 1
		if peak >= _moving_speed and planar_speed < peak * HALVED:
			dead_stops += 1
			_slow_counted = true
			_recent.clear()
			_recent.append(planar_speed)
		elif _slow_ticks > DEAD_SECONDS * _tps and not _slow_counted:
			dead_stops += 1
			_slow_counted = true

	func flow_share():
		return float(flow_ticks) / float(ticks) if ticks > 0 else null

	func airborne_share():
		return float(airborne_ticks) / float(ticks) if ticks > 0 else null

	func blazing_seconds() -> float:
		return float(blazing_ticks) / float(_tps)

var events
var run
var player
var codex
var storage_dir := "user://"
var records_written := 0

var _record := {}
var _fight_open := false
var _smash_base := -1.0
var _stages := {}
var _in_arena := false
var _phase := 0
# True when the run has moved on since its last line.
var _dirty := false
var _traversal: Traversal = null
var _measuring := false
var _stage_clock := -1.0
var _posture_starts := {}
var _posture_wardens := {}
var _posture_open := {}
# A line skill load is waiting for its bite: the next line_skill_fired is that bite.
var _line_waiting := false
var _bank_gains: Array = []


func setup(events_ref, run_ref, player_ref, codex_ref, dir: String) -> void:
	name = "RunLog"
	events = events_ref
	run = run_ref
	player = player_ref
	codex = codex_ref
	storage_dir = dir
	events.run_started.connect(_on_run_started)
	events.stage_entered.connect(_on_stage_entered)
	events.warden_engaged.connect(_on_warden_engaged)
	events.beacon_unsealed.connect(_on_beacon_unsealed)
	events.stage_cleared.connect(_on_stage_cleared)
	events.event_started.connect(_on_event_started)
	events.event_ended.connect(_on_event_ended)
	events.player_died.connect(_on_player_died)
	events.run_ended.connect(_on_run_ended)
	events.boss_phase_changed.connect(_on_boss_phase)
	events.stage_content_cleared.connect(_on_stage_content_cleared)
	events.line_state_changed.connect(_on_line_state)
	events.enemy_struck.connect(_on_enemy_struck)
	events.verb_failed.connect(_on_verb_failed)
	events.pack_arrived.connect(_on_pack_arrived)
	events.prompt_shown.connect(_on_prompt_shown)
	events.cause_fired.connect(_on_cause_fired)
	events.posture_changed.connect(_on_posture_changed)
	# The skill bar and the set piece (design-v3/SKILL-BAR.md section 7, run log rows).
	events.slot_cast.connect(func(slot: String, _id: String, _at: Vector3):
		if not _record.is_empty() and slot in ["special", "line"]:
			_count_in("slot_casts", slot))
	events.slot_selected.connect(_on_slot_selected)
	events.line_skill_loaded.connect(func(_id: String, _seconds: float):
		_line_waiting = true
		_count_line("loaded"))
	events.line_skill_fired.connect(func(_id: String, _target: Node3D, _at: Vector3, _on: String):
		if _id == "bank_shot" and player.kit.line_state != 2:
			_bank_gain()
		_count_line("load_bitten" if _line_waiting else "on_line")
		_line_waiting = false)
	events.line_skill_expired.connect(func(_id: String):
		_line_waiting = false
		_count_line("load_expired"))
	events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		if not _record.is_empty():
			(_record["ultimates"] as Array).append(_ultimate_row()))
	events.ultimate_landed.connect(func(_id: String, _at: Vector3, _hits: int, _damage: float): _close_ultimate())
	events.ultimate_cancelled.connect(func(_id: String, _reason: String, _refunded: bool): _close_ultimate())
	events.dismounted.connect(func(_v: Vector3):
		if player.bank_last.get("pending_log", false):
			player.bank_last["pending_log"] = false
			_bank_gain())


func _on_run_started(class_id: String) -> void:
	_bank_gains.clear()
	_stages = {}
	_in_arena = false
	_phase = 0
	_posture_starts = {}
	_posture_wardens = {}
	_posture_open = {}
	run.set_meta("boss_attacks", {})
	# PE-0: the pilot clip router writes plays by clip and missing-clip refusals here (hero_assets.gd).
	run.set_meta("pilot_clips", {"played": {}, "missing": 0})
	# Flourish rows finished this run (flourish_player.gd): {id, s, full, skipped, held, cut}.
	run.set_meta("flourishes", [])
	_record = {"run_id": run.run_id, "class": class_id, "table": _table_id(), "outcome": "running", "brindle_phase_reached": null,
		"bites": 0, "smashes": 0, "breaks": {}, "verb_fails": {}, "prompts_shown": 0,
		"chains": [], "best_combo": 0, "misses": 0, "smash_damage": 0.0, "smash_damage_by_fight": [],
		"slot_casts": {"special": 0, "line": 0}, "snaps": {}, "picks": 0,
		"line_skill": {"on_line": 0, "loaded": 0, "load_bitten": 0, "load_expired": 0, "bank_gain_mps": 0.0}, "ultimates": []}
	_line_waiting = false
	_fight_open = false
	_smash_base = -1.0
	_traversal = null
	_measuring = false
	_stage_clock = -1.0


# The id of the stage table the game chose, read from the game's own TABLES so the name
# is stated once; a game without one reads as the default.
func _table_id() -> String:
	var game = get_parent()
	if game == null or game.get("ctx") == null or game.get_script() == null:
		return "default"
	var tables = game.get_script().get_script_constant_map().get("TABLES", {})
	for id in tables:
		if tables[id] == game.ctx.stages:
			return String(id)
	return "default"


func _stage(index: int) -> Dictionary:
	if not _stages.has(index):
		_stages[index] = {
			"stage": index,
			"ticks_to_warden_engaged": null,
			"ticks_to_warden_break": null,
			"mass_at_engage": null,
			"heft_at_engage": null,
			"heft_class_at_engage": null,
			"heft_at_exit": null,
			"part_ids_at_exit": null,
			"bonus_cores": 0,
			"deaths": [],
			"events_joined": [],
			"events_won": [],
			"packs": [],
			"causes": {},
			"attempts": 0,
		}
	return _stages[index]


func _stage_list(key: String) -> Array:
	return _stage(run.stage)[key]


func _ticks() -> int:
	return int(round(run.stage_time * Engine.physics_ticks_per_second))


func _on_stage_entered(stage: int, retry: bool) -> void:
	_in_arena = false
	_fight_open = false
	_dirty = true
	var row := _stage(stage)
	row["attempts"] = int(row["attempts"]) + 1
	if retry:
		row["packs"] = []
		row["causes"] = {}
	if _traversal == null and player != null and player.get("tuning") != null:
		_traversal = Traversal.new(Engine.physics_ticks_per_second, player.tuning.f("cruise"))
	if _traversal != null:
		_traversal.restart()
	_measuring = _traversal != null
	_stage_clock = -1.0
	_stage(stage).erase("posture")
	_posture_starts.erase(stage)
	_posture_wardens.erase(stage)
	_posture_open.erase(stage)


# warden_engaged fires once per stage attempt, so a retry's engagement replaces the
# last one, as a retry's break does.
func _on_warden_engaged(stage: int) -> void:
	var row := _stage(stage)
	row["ticks_to_warden_engaged"] = _ticks()
	_open_fight()
	row["mass_at_engage"] = run.mass
	row["heft_at_engage"] = run.heft()
	row["heft_class_at_engage"] = run.heft_class()
	_measuring = false


# One sample per tick the stage clock moved, so a paused or frozen game adds none.
func _physics_process(_delta: float) -> void:
	if not _measuring or not is_instance_valid(player) or run == null:
		return
	if run.stage_time <= _stage_clock:
		return
	_stage_clock = run.stage_time
	var intent = player.intent
	_traversal.step(player.speed_tier(), player.planar_velocity().length(), intent.brake_held, Traversal.is_exempt(player))


func _on_event_started(id: String) -> void:
	if id in EventDirector.PARTICIPATORY:
		_stage_list("events_joined").append(id)


# Smash damage (HOOK-CHAIN.md measurement line). A smash landing's contact strike and its
# shockwave publish enemy_struck while player.smash_landing is set, and smash_lands follows
# once they are done. The first such strike marks combat's delivered-damage ledger total
# (run meta, read-only; its hit is recorded after the emit); smash_lands takes the
# difference. A fight is the span from warden_engaged (or the arena's entry) to the next
# stage_cleared or death; a smash outside one counts in the run total only.
func _on_enemy_struck(_enemy: Node3D, _kind: String, _force: float) -> void:
	if _record.is_empty() or _smash_base >= 0.0 or player == null or player.get("smash_landing") == null:
		return
	_smash_base = _ledger_total()


func _on_smash_lands() -> void:
	if _smash_base < 0.0:
		return
	var dealt := maxf(0.0, _ledger_total() - _smash_base)
	_smash_base = -1.0
	_record["smash_damage"] = float(_record["smash_damage"]) + dealt
	if _fight_open:
		var fights: Array = _record["smash_damage_by_fight"]
		fights[fights.size() - 1] = float(fights.back()) + dealt


func _ledger_total() -> float:
	return float((run.get_meta("delivered_damage", {}) as Dictionary).get("total", 0.0))


func _open_fight() -> void:
	if _record.is_empty():
		return
	_fight_open = true
	(_record["smash_damage_by_fight"] as Array).append(0.0)


func _on_line_state(state: String, _target: Node3D, _at: Vector3, cause: String) -> void:
	if _record.is_empty():
		return
	match state:
		"chain_end":
			_on_chain_end()
		"chain_miss":
			_record["misses"] += 1
		"latched_body":
			_record["bites"] += 1
		"smash_lands":
			_record["smashes"] += 1
			_on_smash_lands()
		"broke":
			_count_in("breaks", cause if cause != "" else UNKNOWN_CAUSE)


# The player's chain appends its finished row before it publishes chain_end, so the last
# row is the chain that just ended. Without a player or a row nothing is recorded.
func _on_chain_end() -> void:
	if player == null or player.get("chain") == null:
		return
	var done: Array = player.chain.finished
	if done.is_empty():
		return
	var row: Dictionary = done.back()
	_record["chains"].append({"links": int(row["links"]), "pivots": int(row["pivots"]), "combo": int(row["combo"]), "paid": bool(row["paid"])})
	_record["best_combo"] = maxi(int(_record["best_combo"]), int(row["combo"]))


func _on_verb_failed(verb: String, _reason: String, _at: Vector3) -> void:
	if not _record.is_empty():
		_count_in("verb_fails", verb)


func _on_slot_selected(_slot: String, reason: String) -> void:
	if _record.is_empty():
		return
	if reason == "pick":
		_record["picks"] = int(_record["picks"]) + 1
	else:
		_count_in("snaps", reason)


func _count_line(field: String) -> void:
	if not _record.is_empty():
		_count_in("line_skill", field)


# The set piece's record as ultimate.gd keeps it on the run (the delivered-damage pattern):
# {id, path, seconds, heft_class, volley_hits, landing_hits, damage, bailed, recalled,
# fill_seconds}. One row per start; the landing or the cancel closes it with the final counts.
func _ultimate_row() -> Dictionary:
	return (run.get_meta("ultimate_record", {}) as Dictionary).duplicate(true)


func _close_ultimate() -> void:
	if _record.is_empty():
		return
	var rows: Array = _record["ultimates"]
	if not rows.is_empty():
		rows[rows.size() - 1] = _ultimate_row()


func _count_in(key: String, name: String) -> void:
	var counts: Dictionary = _record[key]
	counts[name] = int(counts.get(name, 0)) + 1


func _on_beacon_unsealed(stage: int) -> void:
	_stage(stage)["ticks_to_warden_break"] = _ticks()
	_close_posture(stage)


func _on_pack_arrived(faction: String, _at: Vector3, kinds: Array) -> void:
	if not _record.is_empty() and not _in_arena:
		_stage_list("packs").append({"faction": faction, "kinds": kinds.duplicate()})


func _on_prompt_shown(_verb: String) -> void:
	if not _record.is_empty() and not _in_arena:
		_record["prompts_shown"] += 1


func _on_cause_fired(id: String, _target: Node3D, _at: Vector3) -> void:
	if not _record.is_empty() and not _in_arena:
		var causes: Dictionary = _stage(run.stage)["causes"]
		causes[id] = int(causes.get(id, 0)) + 1


# The Warden's bar moved. A stagger is the bar going from open to staggered; the rest is
# read from the Warden when the line is written, because no bus signal says a hit glanced.
func _on_posture_changed(enemy: Node3D, _posture: float, staggered: bool) -> void:
	# Brindle's hull also publishes its bar; it belongs to no stage's Warden row.
	if _record.is_empty() or not is_instance_valid(enemy) or _in_arena or enemy.get("boss") != null:
		return
	var stage: int = run.stage
	var row := _stage(stage)
	if not row.has("posture"):
		row["posture"] = {"staggers": 0, "chunks_lost": 0, "glances": 0, "fight_ticks": 0}
		_posture_starts[stage] = _ticks()
		_posture_open[stage] = false
	if staggered and not _posture_open[stage]:
		row["posture"]["staggers"] += 1
	_posture_open[stage] = staggered
	_posture_wardens[stage] = enemy
	_close_posture(stage)


# Brings a stage's posture block up to date: chunks lost and glances from the Warden's
# own accessors (no bus signal says a hit glanced), and the
# fight's length from the first posture gain to the break, or to now while it is open.
func _close_posture(stage: int) -> void:
	var row := _stage(stage)
	if not row.has("posture"):
		return
	var posture: Dictionary = row["posture"]
	var warden = _posture_wardens.get(stage)
	if is_instance_valid(warden):
		posture["chunks_lost"] = maxi(int(posture["chunks_lost"]), BossPosture.CHUNKS - warden.chunks_left())
		posture["glances"] = maxi(int(posture["glances"]), warden.glances())
	var broke = row["ticks_to_warden_break"]
	var end: int = int(broke) if broke != null else _ticks()
	posture["fight_ticks"] = maxi(0, end - int(_posture_starts[stage]))


func _on_stage_cleared(stage: int) -> void:
	_fight_open = false
	_close_posture(stage)
	var row := _stage(stage)
	row["heft_at_exit"] = run.heft()
	row["part_ids_at_exit"] = run.parts.duplicate()
	row["bonus_cores"] = run.bonus_cores


func _on_event_ended(id: String, outcome: String) -> void:
	if outcome == "won":
		_stage_list("events_won").append(id)


# A death in the arena goes in the arena's own record, on the arena's clock and the
# run's, with Brindle's phase; the stage rows keep only deaths on their own maps.
func _on_player_died() -> void:
	_fight_open = false
	var at: Vector3 = player.ball_position()
	var death := {"x": at.x, "y": at.y, "z": at.z, "ticks": _ticks()}
	if _in_arena:
		death["run_ticks"] = int(round(run.run_time * Engine.physics_ticks_per_second))
		death["phase"] = _phase
		(_record["arena"]["deaths"] as Array).append(death)
	else:
		_stage_list("deaths").append(death)
	_write("died")


func _on_stage_content_cleared(reason: String) -> void:
	if reason != "arena" and reason != "arena_retry":
		return
	_in_arena = true
	_dirty = true
	_phase = 0
	_open_fight()
	if not _record.has("arena"):
		_record["arena"] = {"entries": 0, "deaths": []}
	_record["arena"]["entries"] += 1


func _on_boss_phase(phase: int, _name: String) -> void:
	_phase = phase
	var reached = _record.get("brindle_phase_reached")
	_record["brindle_phase_reached"] = maxi(phase, int(reached)) if reached != null else phase


func _on_run_ended(won: bool) -> void:
	_write("won" if won else "lost")


# Flow calls this before run state resets, so the line carries the run it closes.
func abandon_open_run() -> void:
	_abandon()


func _abandon() -> void:
	if _dirty and not _record.is_empty():
		_record["abandoned_in"] = "arena" if _in_arena else "stage"
		_write("abandoned")
		_record.erase("abandoned_in")


func _exit_tree() -> void:
	_abandon()


func _write(outcome: String) -> void:
	if _record.is_empty():
		return
	var line := _record.duplicate(true)
	# Continue applies the saved run after run_started (flow.resume_run), so the id captured
	# there is begin()'s fresh one; the live run's id is the one the codex log uses.
	if run != null and String(run.run_id) != "":
		line["run_id"] = run.run_id
	line["outcome"] = outcome
	line["flow_share"] = _traversal.flow_share() if _traversal != null else null
	line["dead_stops"] = _traversal.dead_stops if _traversal != null else 0
	var stages: Array = []
	var keys := _stages.keys()
	keys.sort()
	for index in keys:
		# Only the stage being played is still open; an earlier stage closed on its own clock
		# when it cleared, and run.stage_time now reads a later stage's clock.
		if index == run.stage:
			_close_posture(index)
		stages.append(_stages[index])
	line["stages"] = stages
	line["codex"] = codex.discovered_this_run() if codex != null else []
	line["anomalies"] = run.anomalies.duplicate(true)
	# M0's delivered-damage ledger (combat.gd), mirrored onto the run through set_meta so
	# this module never needs its own reference to the spawner. A run with no hits still
	# carries the reset ledger (total 0.0), so a zero-damage run reads as zero, not missing.
	line["delivered_damage"] = run.get_meta("delivered_damage", {})
	# W18: the Mind's attack commitments by family (mind.gd _commit_attack), so a soak reads
	# which families it used without codex rows (dodged only) or damage sources (landed only).
	line["boss_attacks"] = run.get_meta("boss_attacks", {})
	# PE-0 (PILOT-CLIPS section 7.3): clips the pilot played by name, and refusals for a clip the
	# GLB lacks. PE-INT's bot run expects smash and drop_land played and missing at 0.
	line["pilot_clips"] = (run.get_meta("pilot_clips", {"played": {}, "missing": 0}) as Dictionary).duplicate(true)
	line["flourishes"] = (run.get_meta("flourishes", []) as Array).duplicate(true)
	# The ultimate meter's points by source this run (SKILL-BAR section 7, meter_points).
	var meter = player.abilities.get("meter") if player != null and player.get("abilities") != null else null
	line["meter_points"] = (meter.sources as Dictionary).duplicate() if meter != null else {}
	# Heat on the shell (redline.gd): its counts for the kill line (loops.md), present only when
	# --heat is watch or on, so a flag-off line is byte-identical to the base.
	var redline = player.get("redline") if player != null else null
	if redline != null and redline.mode != "off":
		line["redline"] = redline.summary()
	# The durability prototype's per-run metrics (run_state.gd), present only in armour
	# mode so a flag-off line is byte-identical to the base. reverse_seconds is an
	# approximation: seconds with a spill live and the ball moving against the stage's
	# entry heading (build.gd _step_armor).
	if run.armor_mode:
		var durability: Dictionary = run.metrics.duplicate()
		durability["scrap_mode"] = "armor"
		durability["wear"] = "on" if run.wear_on else "off"
		durability["mass_end"] = run.mass
		line["durability"] = durability
	_dirty = false
	if codex.append_line(storage_dir.path_join(LOG_FILE), JSON.stringify(line)):
		records_written += 1


func _bank_gain() -> void:
	if _record.is_empty() or player.bank_last.is_empty():
		return
	_bank_gains.append(float(player.bank_last["exit"]) - float(player.bank_last["entry"]))
	var values := _bank_gains.duplicate()
	values.sort()
	var n := values.size()
	_record["line_skill"]["bank_gain_mps"] = snappedf(float(values[n / 2]) if n % 2 == 1 else (float(values[n / 2 - 1]) + float(values[n / 2])) * 0.5, 0.01)
