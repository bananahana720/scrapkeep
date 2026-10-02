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
# smashes, breaks by cause and failed verbs by verb, and prompts_shown (zero until a
# prompt publishes a fact). events_joined holds only the opt-in events the ball entered:
# the director publishes event_started for a participatory event when the ball reaches
# its ring, but also for the ambient flood, squall and terrain changes, which the player
# does not choose and which are left out.

const LOG_FILE := "runs.ndjson"
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const UNKNOWN_CAUSE := "unspecified"


# The traversal measure's detector, fed one sample per physics tick. Flow share is the
# fraction of ticks at speed tier 2 or better. A dead stop is more than 0.5 s under tier 1
# with no brake, mount or interaction, or one contact that takes more than half of the
# planar speed the ball had in the last CONTACT_WINDOW seconds. The slow clock arms once
# the ball has first reached tier 1, so a standing start is not a stop.
class Traversal:
	extends RefCounted

	const FLOW_TIER := 2
	const MOVING_TIER := 1
	const DEAD_SECONDS := 0.5
	const HALVED := 0.5
	const CONTACT_WINDOW := 0.1

	var ticks := 0
	var flow_ticks := 0
	var dead_stops := 0
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

	func step(tier: int, planar_speed: float, braking: bool, exempt: bool) -> void:
		ticks += 1
		if tier >= FLOW_TIER:
			flow_ticks += 1
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

var events
var run
var player
var codex
var storage_dir := "user://"
var records_written := 0

var _record := {}
var _stages := {}
var _in_arena := false
var _phase := 0
# True when the run has moved on since its last line.
var _dirty := false
var _traversal: Traversal = null
var _measuring := false
var _stage_clock := -1.0


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
	events.verb_failed.connect(_on_verb_failed)


func _on_run_started(class_id: String) -> void:
	_stages = {}
	_in_arena = false
	_phase = 0
	_record = {"run_id": run.run_id, "class": class_id, "outcome": "running", "brindle_phase_reached": null,
		"bites": 0, "smashes": 0, "breaks": {}, "verb_fails": {}, "prompts_shown": 0}
	_traversal = null
	_measuring = false
	_stage_clock = -1.0


func _stage(index: int) -> Dictionary:
	if not _stages.has(index):
		_stages[index] = {
			"stage": index,
			"ticks_to_warden_engaged": null,
			"ticks_to_warden_break": null,
			"heft_at_exit": null,
			"part_ids_at_exit": null,
			"bonus_cores": 0,
			"deaths": [],
			"events_joined": [],
			"events_won": [],
		}
	return _stages[index]


func _stage_list(key: String) -> Array:
	return _stage(run.stage)[key]


func _ticks() -> int:
	return int(round(run.stage_time * Engine.physics_ticks_per_second))


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_in_arena = false
	_dirty = true
	if _traversal == null and player != null and player.get("tuning") != null:
		_traversal = Traversal.new(Engine.physics_ticks_per_second, player.tuning.f("cruise"))
	if _traversal != null:
		_traversal.restart()
	_measuring = _traversal != null
	_stage_clock = -1.0


# warden_engaged fires once per stage attempt, so a retry's engagement replaces the
# last one, as a retry's break does.
func _on_warden_engaged(stage: int) -> void:
	_stage(stage)["ticks_to_warden_engaged"] = _ticks()
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


func _on_line_state(state: String, _target: Node3D, _at: Vector3, cause: String) -> void:
	if _record.is_empty():
		return
	match state:
		"latched_body":
			_record["bites"] += 1
		"smash_lands":
			_record["smashes"] += 1
		"broke":
			_count_in("breaks", cause if cause != "" else UNKNOWN_CAUSE)


func _on_verb_failed(verb: String, _reason: String, _at: Vector3) -> void:
	if not _record.is_empty():
		_count_in("verb_fails", verb)


func _count_in(key: String, name: String) -> void:
	var counts: Dictionary = _record[key]
	counts[name] = int(counts.get(name, 0)) + 1


func _on_beacon_unsealed(stage: int) -> void:
	_stage(stage)["ticks_to_warden_break"] = _ticks()


func _on_stage_cleared(stage: int) -> void:
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
	line["outcome"] = outcome
	line["flow_share"] = _traversal.flow_share() if _traversal != null else null
	line["dead_stops"] = _traversal.dead_stops if _traversal != null else 0
	var stages: Array = []
	var keys := _stages.keys()
	keys.sort()
	for index in keys:
		stages.append(_stages[index])
	line["stages"] = stages
	line["codex"] = codex.discovered_this_run() if codex != null else []
	line["anomalies"] = run.anomalies.duplicate(true)
	# M0's delivered-damage ledger (combat.gd), mirrored onto the run through set_meta so
	# this module never needs its own reference to the spawner. A run with no hits still
	# carries the reset ledger (total 0.0), so a zero-damage run reads as zero, not missing.
	line["delivered_damage"] = run.get_meta("delivered_damage", {})
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
