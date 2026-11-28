extends RefCounted


const Objectives := preload("res://src/core/objectives.gd")

const BEATS := ["arrive", "loot", "find", "hold", "fight", "leave"]

const OWNERS := {
	"arrive": "res://src/core/flow.gd",
	"loot": "res://src/build/scrap_field.gd",
	"find": "res://src/world/activities.gd",
	"hold": "res://src/core/boss_posture.gd",
	"fight": "res://src/combat/warden.gd",
	"leave": "res://src/world/launch.gd",
}

const LOOT_TAIL_S := 3.0


static func owner_of(beat: String) -> String:
	return OWNERS.get(beat, "")


static func classify(reading: Dictionary) -> String:
	var state: String = reading["state"]
	if state == "gates" or state == "launch":
		return "leave"
	if state != "stage" and state != "beacon":
		return ""
	if not reading["landed"]:
		return "arrive"
	if reading["engaged"]:
		return "fight" if reading["guard_broken"] else "hold"
	if int(reading["since_pickup"]) <= int(reading["loot_tail"]):
		return "loot"
	return "find"


static func within(rows: Array, last_stage: int) -> Array:
	if last_stage <= 0:
		return rows.duplicate()
	return rows.filter(func(row): return int(row["stage"]) <= last_stage)


static func sum_ticks(row: Dictionary) -> int:
	var sum := 0
	for beat in BEATS:
		sum += int(row["ticks"][beat])
	return sum


static func seconds_text(row: Dictionary, ticks_per_second: int) -> String:
	var parts := []
	for beat in BEATS:
		parts.append("%s %.1f s" % [beat, float(row["ticks"][beat]) / float(ticks_per_second)])
	return ", ".join(parts)


static func audit(rows: Array) -> Dictionary:
	var exits := 0
	var skipped := 0
	for row in rows:
		if row["exit"]:
			exits += 1
		skipped += (row["skipped"] as Array).size()
	return {"stages": rows.size(), "exits": exits, "skipped": skipped,
		"ok": rows.size() > 0 and exits == rows.size() and skipped == 0}


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


class Recorder:
	extends RefCounted

	var rows: Array = []
	var loot_tail := 0
	var _flow
	var _row: Dictionary = {}
	var _state := ""
	var _landed := false
	var _engaged := false
	var _guard_broken := false
	var _since_pickup := 1 << 30
	var _outer

	func _init(events, flow, loot_tail_ticks: int = -1) -> void:
		_flow = flow
		_outer = load("res://src/core/stage_beats.gd")
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

	func step() -> void:
		if _row.is_empty():
			return
		_since_pickup += 1
		var beat: String = _outer.classify({"state": _state, "landed": _landed, "engaged": _engaged,
			"guard_broken": _guard_broken, "since_pickup": _since_pickup, "loot_tail": loot_tail})
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
		_guard_broken = false
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

	func _on_posture(enemy: Node3D, posture: float, staggered: bool) -> void:
		if (staggered or posture >= Objectives.Struggle.CLEAR_AT) and enemy != null and enemy == _flow.warden:
			_guard_broken = true

	func finish() -> void:
		if not _row.is_empty() and int(_row["total"]) == 0:
			rows.pop_back()
			_row = {}


const WORLD_TWO_BEATS := [
	{
		"id": "dig_cold_open",
		"landmark": "headframe",
		"zone": "2-1",
		"trigger": "stage_entered",
		"owner": "res://src/presentation/dig_fx.gd",
		"lore_id": "lore.dig.cold_open",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "kest_rescue_banter",
		"landmark": "headframe",
		"zone": "2-1",
		"trigger": "rescue_completed",
		"owner": "res://src/presentation/dig_fx.gd",
		"lore_id": "lore.dig.kest_rescue.1",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "sinkhole_cold_open",
		"landmark": "sinkhole",
		"zone": "2-2",
		"trigger": "stage_entered",
		"owner": "res://src/presentation/dig_fx.gd",
		"lore_id": "lore.sinkhole.cold_open",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "waking_freeze_intro",
		"landmark": "sinkhole",
		"zone": "2-2",
		"trigger": "boss_intro",
		"owner": "res://src/boss/waking_dress.gd",
		"lore_id": "lore.dig_depths.waking_card",
		"skippable": true,
		"blocking": false,
	},
]


static func world_two_beat(id: String) -> Dictionary:
	for beat in WORLD_TWO_BEATS:
		if beat["id"] == id:
			return beat
	return {}


static func world_two_beats_for_landmark(landmark_kind: String) -> Array:
	return WORLD_TWO_BEATS.filter(func(beat): return beat["landmark"] == landmark_kind)


const WORLD_THREE_BEATS := [
	{
		"id": "isle_cold_open",
		"landmark": "sky_island",
		"zone": "3-1",
		"trigger": "stage_entered",
		"owner": "res://src/presentation/highdraft_fx.gd",
		"lore_id": "lore.isle.cold_open",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "crown_cold_open",
		"landmark": "spire",
		"zone": "3-2",
		"trigger": "stage_entered",
		"owner": "res://src/presentation/highdraft_fx.gd",
		"lore_id": "lore.crown.cold_open",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "golden_dusk_crossfade",
		"landmark": "spire",
		"zone": "3-2",
		"trigger": "stage_entered",
		"owner": "res://src/presentation/highdraft_fx.gd",
		"lore_id": "",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "foreman_call_in",
		"landmark": "spire",
		"zone": "3-2",
		"trigger": "boss_intro",
		"owner": "res://src/boss/mind_dress.gd",
		"lore_id": "lore.crown.foreman_call_in",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "hired_stamp",
		"landmark": "spire",
		"zone": "3-2",
		"trigger": "boss_defeated",
		"owner": "res://src/boss/mind_dress.gd",
		"lore_id": "lore.crown.hired",
		"skippable": true,
		"blocking": false,
	},
	{
		"id": "free_roll_bowl",
		"landmark": "spire",
		"zone": "3-2",
		"trigger": "boss_defeated",
		"owner": "res://src/world/victory_lap.gd",
		"lore_id": "",
		"skippable": true,
		"blocking": false,
	},
]

const LAUNCH_CROSSFADE := {
	"from_landmark": "sky_island",
	"to_landmark": "spire",
	"seconds": 6.0,
	"from_tint": Color("e8b45a", 0.42),
	"to_tint": Color("5a4f8c", 0.0),
}


static func world_three_beat(id: String) -> Dictionary:
	for beat in WORLD_THREE_BEATS:
		if beat["id"] == id:
			return beat
	return {}


static func world_three_beats_for_landmark(kind: String) -> Array:
	return WORLD_THREE_BEATS.filter(func(beat): return beat["landmark"] == kind)
