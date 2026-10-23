extends Node

# World 1's stage beats (world 1 plan, unit 4): which bus fact starts which flourish row. The
# rows and their words are flourish_rows.gd; the player draws them. This file reads the bus and
# the flow and applies nothing.
#
#   cold_open            stage 1 entered fresh (not a retry) as a run's first stage
#   rivet_freed          rescue_completed("rivet"), anchored on the cage
#   flume_warden_reveal  warden_engaged on a world 1 stage whose Warden is the meltdown variant,
#                        once per run
#   bowl_handoff         beacon_unsealed on world 1's last stage when Brindle's arena follows,
#                        once per run (a retried stage does not hand off again)
#   spillway_clear       world 2 entered after Brindle fell this run: the Spillway's shift is
#                        logged on the way down (a Continue into world 2 logs nothing)
#
# A screen away from play (title, pilot select, death, summary) or a stage retry ends the showing
# row and its queue.

const Worlds := preload("res://src/core/worlds.gd")

const WORLD := 1
const STOP_SCREENS := ["title", "class_select", "dead", "summary"]

var ctx
var player
var _revealed := false
var _handed_off := false
var _brindle_beaten := false


func setup(ctx_ref, flourish_player) -> void:
	name = "SpillwayStory"
	ctx = ctx_ref
	player = flourish_player
	var events = ctx.events
	events.run_started.connect(_on_run_started)
	events.boss_defeated.connect(_on_boss_defeated)
	events.stage_entered.connect(_on_stage_entered)
	events.rescue_completed.connect(_on_rescue_completed)
	events.warden_engaged.connect(_on_warden_engaged)
	events.beacon_unsealed.connect(_on_beacon_unsealed)
	events.world_entered.connect(_on_world_entered)
	events.flow_changed.connect(func(state: String):
		if state in STOP_SCREENS:
			player.stop_all())


func _on_run_started(_class_id: String) -> void:
	_revealed = false
	_handed_off = false
	_brindle_beaten = false


func _on_boss_defeated() -> void:
	if ctx.run != null and _in_world_one(int(ctx.run.stage)):
		_brindle_beaten = true


func _stages():
	return ctx.stages


func _in_world_one(stage: int) -> bool:
	return _stages() != null and _stages().world_of(stage) == WORLD


func _on_stage_entered(stage: int, retry: bool) -> void:
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
	player.play("rivet_freed", -1, anchors)


func _on_warden_engaged(stage: int) -> void:
	if _revealed or not _in_world_one(stage) or ctx.flow == null:
		return
	var warden = ctx.flow.warden
	if not is_instance_valid(warden):
		return
	var variant = warden.get("variant")
	if not variant is String or variant != "meltdown":
		return
	_revealed = true
	player.play("flume_warden_reveal", -1, {"warden": warden})


func _on_beacon_unsealed(stage: int) -> void:
	if not _handed_off and _in_world_one(stage) and _stages().is_world_last(stage) and _boss_built():
		_handed_off = true
		player.play("bowl_handoff")


func _on_world_entered(world: int) -> void:
	if world == WORLD + 1 and _brindle_beaten:
		_brindle_beaten = false
		player.play("spillway_clear")


func _boss_built() -> bool:
	var row: Dictionary = Worlds.BOSSES.get(String(Worlds.ROWS[WORLD - 1].boss), {})
	return bool(row.get("built", false))
