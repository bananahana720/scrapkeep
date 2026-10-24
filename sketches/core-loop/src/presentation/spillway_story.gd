extends Node

# World 1's stage beats (world 1 plan, unit 4): which bus fact starts which flourish row. The
# rows and their words are flourish_rows.gd; the player draws them. This file reads the bus and
# the flow and applies nothing.
#
#   cold_open            stage 1 entered fresh (not a retry) as a run's first stage
#   rivet_freed          rescue_completed("rivet"), anchored on the cage
#   flume_warden_reveal  warden_sighted on a world 1 stage whose Warden is the meltdown variant,
#                        once per run (before the fight, as Moss's Warden line)
#   bowl_handoff         beacon_unsealed on world 1's last stage when Brindle's arena follows,
#                        once per run (a retried stage does not hand off again)
#   spillway_clear       world 2 entered after Brindle fell this run: the Spillway's shift is
#                        logged on the way down (a Continue into world 2 logs nothing)
#
# A screen away from play (title, pilot select, death, summary) or a stage retry ends the showing
# row and its queue. So does a Warden fight: these rows are gone the moment the Warden is engaged,
# and a beat whose trigger lands while the fight holds the screen (field_tips.gd fight_live)
# waits for the unseal, so no card or caption ever counts inside a fight (LEGIBILITY word budget).
# Brindle's own beats (flourish_cues.gd) are the fight's flourishes and are not touched here.

const Worlds := preload("res://src/core/worlds.gd")

const WORLD := 1
const SHOWN_SECONDS := 0.5
const STOP_SCREENS := ["title", "class_select", "dead", "summary"]
const ROWS := ["cold_open", "rivet_freed", "flume_warden_reveal", "bowl_handoff", "spillway_clear"]

var ctx
var player
var _revealed := false
var _handed_off := false
var _brindle_beaten := false
# Once-per-run rows this file asked for that have not finished yet.
var _asked := {}
# Beats held while a Warden fight holds the screen: [row id, anchors], played on the unseal.
var _after_fight: Array = []


func setup(ctx_ref, flourish_player) -> void:
	name = "SpillwayStory"
	ctx = ctx_ref
	player = flourish_player
	var events = ctx.events
	events.run_started.connect(_on_run_started)
	events.boss_defeated.connect(_on_boss_defeated)
	events.stage_entered.connect(_on_stage_entered)
	events.rescue_completed.connect(_on_rescue_completed)
	events.warden_sighted.connect(_on_warden_sighted)
	events.warden_engaged.connect(_on_warden_engaged)
	events.beacon_unsealed.connect(_on_beacon_unsealed)
	events.world_entered.connect(_on_world_entered)
	player.finished.connect(_on_finished)
	events.flow_changed.connect(func(state: String):
		if state in STOP_SCREENS:
			_after_fight.clear()
			player.stop_all())


func _on_run_started(_class_id: String) -> void:
	_revealed = false
	_handed_off = false
	_brindle_beaten = false
	_asked.clear()
	_after_fight.clear()


func _on_boss_defeated() -> void:
	if ctx.run != null and _in_world_one(int(ctx.run.stage)):
		_brindle_beaten = true


func _stages():
	return ctx.stages


func _in_world_one(stage: int) -> bool:
	return _stages() != null and _stages().world_of(stage) == WORLD


func _on_stage_entered(stage: int, retry: bool) -> void:
	_after_fight.clear()
	if retry:
		player.stop_all()
	elif stage == 1 and _in_world_one(stage):
		player.play("cold_open")


func _on_rescue_completed(quest: String) -> void:
	if quest != "rivet":
		return
	var anchors := {}
	var world = ctx.root.get("world") if ctx.root != null else null
	var rescue = world.get("rescue") if world != null else null
	if rescue != null and rescue.has_method("cage"):
		var cage = rescue.cage(quest)
		if cage is Node3D:
			anchors["cage"] = cage
	if _fight_live():
		_after_fight.append(["rivet_freed", anchors])
	else:
		player.play("rivet_freed", -1, anchors)


func _fight_live() -> bool:
	return ctx.flow != null and ctx.flow.engaged() and ctx.flow.sealed


func _on_warden_engaged(_stage: int) -> void:
	if player.id in ROWS or player.queued().any(func(queued): return queued in ROWS):
		player.stop_all()


func _on_warden_sighted(stage: int) -> void:
	if _revealed or not _in_world_one(stage) or ctx.flow == null:
		return
	var warden = ctx.flow.warden
	if not is_instance_valid(warden):
		return
	var variant = warden.get("variant")
	if not variant is String or variant != "meltdown":
		return
	if not _pending("flume_warden_reveal"):
		_asked["flume_warden_reveal"] = true
		player.play("flume_warden_reveal", -1, {"warden": warden})


func _on_beacon_unsealed(stage: int) -> void:
	for held in _after_fight:
		player.play(held[0], -1, held[1])
	_after_fight.clear()
	if not _handed_off and not _pending("bowl_handoff") and _in_world_one(stage) and _stages().is_world_last(stage) and _boss_built():
		_asked["bowl_handoff"] = true
		player.play("bowl_handoff")


func _on_world_entered(world: int) -> void:
	if world == WORLD + 1 and _brindle_beaten:
		_brindle_beaten = false
		player.play("spillway_clear")


# A once-per-run row counts as played once it reached the screen; one that expired in the queue,
# or was stopped within SHOWN_SECONDS, may play on the next trigger.
func _on_finished(id: String, _skipped: bool) -> void:
	if not _asked.erase(id):
		return
	var record: Dictionary = player.played.back() if not player.played.is_empty() else {}
	var cut := String(record.get("cut", ""))
	if cut == "expired" or (cut == "stopped" and float(record.get("s", 0.0)) < SHOWN_SECONDS):
		return
	if id == "flume_warden_reveal":
		_revealed = true
	elif id == "bowl_handoff":
		_handed_off = true


func _pending(id: String) -> bool:
	return player.id == id or id in player.queued()


func _boss_built() -> bool:
	var row: Dictionary = Worlds.BOSSES.get(String(Worlds.ROWS[WORLD - 1].boss), {})
	return bool(row.get("built", false))
