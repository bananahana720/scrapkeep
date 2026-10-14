extends RefCounted

# A stage's six beats (comps/ror2/run-flow.md "Why it works", SR13): arrive, loot, find, hold,
# fight, leave. Every physics tick of a stage attempt belongs to exactly one beat, chosen by
# classify() from facts the game already publishes, so the six tick counts add up to the
# attempt's length and a replay of a seed gives the same counts. The beats never gate
# anything: this file reads the bus and the flow and applies nothing (TADR-008).
#
#   arrive  the drop, from stage entry to the first landing. Owner: flow.gd (enter_stage).
#   loot    after landing and before the Warden engages, the ticks within LOOT_TAIL_S of a
#           pickup (scrap, cogs, a part, a finished activity). Owner: scrap_field.gd.
#   find    the rest of that stretch: roaming for the Warden and the activities. Owner:
#           activities.gd, whose sites the roam looks for.
#   hold    the Warden is engaged and its guard has not yet broken: hold your ground while
#           posture builds. Owner: boss_posture.gd, the rule that opens the window.
#   fight   from the Warden's first stagger to its break: the open window and the smashes.
#           Owner: warden.gd.
#   leave   the gates and the launch, from the break to the stage's exit. Owner: launch.gd.
#
# A stage that never staggers its Warden has no fight beat and says so in `skipped`; that is
# a finding the bot report prints, not something this file hides. dead, summary, boss and
# any other flow state count for no beat.

const BEATS := ["arrive", "loot", "find", "hold", "fight", "leave"]

const OWNERS := {
	"arrive": "res://src/core/flow.gd",
	"loot": "res://src/build/scrap_field.gd",
	"find": "res://src/world/activities.gd",
	"hold": "res://src/combat/boss_posture.gd",
	"fight": "res://src/combat/warden.gd",
	"leave": "res://src/world/launch.gd",
}

# A pickup keeps the loot beat alive this long.
const LOOT_TAIL_S := 3.0


static func owner_of(beat: String) -> String:
	return OWNERS.get(beat, "")


# The beat a tick belongs to, or "" for a tick no beat owns. The reading's keys: state
# (flow.state_name()), landed, engaged and staggered (this attempt, once true they stay true),
# since_pickup (ticks since the last pickup) and loot_tail (ticks a pickup keeps loot alive).
static func classify(reading: Dictionary) -> String:
	var state: String = reading["state"]
	if state == "gates" or state == "launch":
		return "leave"
	if state != "stage" and state != "beacon":
		return ""
	if not reading["landed"]:
		return "arrive"
	if reading["engaged"]:
		return "fight" if reading["staggered"] else "hold"
	if int(reading["since_pickup"]) <= int(reading["loot_tail"]):
		return "loot"
	return "find"


static func sum_ticks(row: Dictionary) -> int:
	var sum := 0
	for beat in BEATS:
		sum += int(row["ticks"][beat])
	return sum


# "arrive 1.0 s, loot 2.0 s, ..." for one row at a physics rate.
static func seconds_text(row: Dictionary, ticks_per_second: int) -> String:
	var parts := []
	for beat in BEATS:
		parts.append("%s %.1f s" % [beat, float(row["ticks"][beat]) / float(ticks_per_second)])
	return ", ".join(parts)


# The acceptance reading of a list of rows: every row reached its exit and none skipped a beat.
static func audit(rows: Array) -> Dictionary:
	var exits := 0
	var skipped := 0
	for row in rows:
		if row["exit"]:
			exits += 1
		skipped += (row["skipped"] as Array).size()
	return {"stages": rows.size(), "exits": exits, "skipped": skipped,
		"ok": rows.size() > 0 and exits == rows.size() and skipped == 0}


# True when two logs hold the same stages with the same tick counts and first ticks, frame for frame.
static func same_timings(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		if int(x["stage"]) != int(y["stage"]) or int(x["attempts"]) != int(y["attempts"]) or int(x["total"]) != int(y["total"]):
			return false
		for beat in BEATS:
			if int(x["ticks"][beat]) != int(y["ticks"][beat]):
				return false
			if int(x["first"].get(beat, -1)) != int(y["first"].get(beat, -1)):
				return false
	return true


# Listens to the bus and counts one tick per step() call. `rows` holds one row per stage entered,
# in order; a retry of a stage reuses its row and counts an attempt. A row is
#   {stage, attempts, ticks: {beat: n}, first: {beat: tick}, total, skipped: [beat], exit}
# where first is the 1-based counted tick on which a beat first appeared, total the counted ticks
# of the latest attempt, skipped the beats with no tick, and exit true once stage_cleared fired.
class Recorder:
	extends RefCounted

	var rows: Array = []
	var loot_tail := 0
	var _flow
	var _row: Dictionary = {}
	var _state := ""
	var _landed := false
	var _engaged := false
	var _staggered := false
	var _since_pickup := 1 << 30

	func _init(events, flow, loot_tail_ticks: int = -1) -> void:
		_flow = flow
		loot_tail = loot_tail_ticks if loot_tail_ticks >= 0 else int(ceil(LOOT_TAIL_S * Engine.physics_ticks_per_second))
		events.stage_entered.connect(_on_stage_entered)
		events.stage_cleared.connect(_on_stage_cleared)
		events.flow_changed.connect(_on_flow_changed)
		events.landed.connect(_on_landed)
		events.scrap_collected.connect(_on_scrap)
		events.cogs_collected.connect(_on_cogs)
		events.part_gained.connect(_on_part)
		events.activity_done.connect(_on_activity)
		events.warden_engaged.connect(_on_engaged)
		events.posture_changed.connect(_on_posture)

	# Counts one physics tick toward the beat it belongs to.
	func step() -> void:
		if _row.is_empty():
			return
		_since_pickup += 1
		var beat: String = load("res://src/core/stage_beats.gd").classify({"state": _state, "landed": _landed, "engaged": _engaged,
			"staggered": _staggered, "since_pickup": _since_pickup, "loot_tail": loot_tail})
		if beat == "":
			return
		_row["ticks"][beat] += 1
		_row["total"] += 1
		if not _row["first"].has(beat):
			_row["first"][beat] = _row["total"]
		_row["skipped"] = _missing(_row)

	static func _missing(row: Dictionary) -> Array:
		var out := []
		for beat in BEATS:
			if int(row["ticks"][beat]) == 0:
				out.append(beat)
		return out

	func _fresh(stage: int, attempts: int) -> Dictionary:
		var ticks := {}
		for beat in BEATS:
			ticks[beat] = 0
		return {"stage": stage, "attempts": attempts, "ticks": ticks, "first": {}, "total": 0,
			"skipped": BEATS.duplicate(), "exit": false}

	func _on_stage_entered(stage: int, retry: bool) -> void:
		var attempts := 1
		if retry and not rows.is_empty() and int(rows[-1]["stage"]) == stage:
			attempts = int(rows[-1]["attempts"]) + 1
			rows.pop_back()
		_row = _fresh(stage, attempts)
		rows.append(_row)
		_state = "stage"
		_landed = false
		_engaged = false
		_staggered = false
		_since_pickup = 1 << 30

	func _on_stage_cleared(stage: int) -> void:
		if not _row.is_empty() and int(_row["stage"]) == stage:
			_row["exit"] = true
			_row = {}

	func _on_flow_changed(state: String) -> void:
		_state = state

	func _on_landed(_impact: float) -> void:
		_landed = true

	func _pickup() -> void:
		_since_pickup = 0

	func _on_scrap(_amount: int, _at: Vector3, _total: int) -> void:
		_pickup()

	func _on_cogs(_amount: int, _total: int) -> void:
		_pickup()

	func _on_part(_part_id: String, _source: String) -> void:
		_pickup()

	func _on_activity(_id: String, _at: Vector3) -> void:
		_pickup()

	func _on_engaged(_stage: int) -> void:
		_engaged = true

	func _on_posture(enemy: Node3D, _posture: float, staggered: bool) -> void:
		if staggered and enemy != null and enemy == _flow.warden:
			_staggered = true
