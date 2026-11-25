extends Node

const Worlds := preload("res://src/core/worlds.gd")

const WORLD := 1
const CLEAR_KEY := "spillway_clear"
const SHOWN_SECONDS := 0.5
const STOP_SCREENS := ["title", "class_select", "dead", "summary"]
const STINGS := {"cold_open": "sting_cold_open", "rivet_freed": "sting_rivet_cage", "flume_warden_reveal": "sting_warden_reveal",
	"bowl_handoff": "sting_bowl_handoff", "spillway_clear": "sting_spillway_clear"}
const ROWS := ["cold_open", "rivet_freed", "flume_warden_reveal", "bowl_handoff", "spillway_clear"]

var ctx
var player
var _revealed := false
var _handed_off := false
var _brindle_beaten := false
var _asked := {}
var _after_fight: Array = []
var _open_due := false
var _clear_due := false


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
	player.started.connect(_on_started)
	var opening = _opening()
	if opening != null:
		opening.turned.connect(_on_turned)
	events.flow_changed.connect(func(state: String):
		if state in STOP_SCREENS:
			_drop_clear()
			_after_fight.clear()
			player.stop_all())


func _on_run_started(_class_id: String) -> void:
	_revealed = false
	_handed_off = false
	_brindle_beaten = false
	_asked.clear()
	_after_fight.clear()
	_open_due = false
	_drop_clear()


func _on_boss_defeated() -> void:
	if ctx.run != null and _in_world_one(int(ctx.run.stage)):
		_brindle_beaten = true


func _stages():
	return ctx.stages


func _in_world_one(stage: int) -> bool:
	return _stages() != null and _stages().world_of(stage) == WORLD


func _on_stage_entered(stage: int, retry: bool) -> void:
	_after_fight.clear()
	_open_due = false
	if retry:
		_drop_clear()
		player.stop_all()
	elif stage == 1 and _in_world_one(stage):
		var opening = _opening()
		if opening != null and opening.waits("title"):
			_open_due = true
		else:
			player.play("cold_open")


func _opening():
	return ctx.root.get("opening") if ctx.root != null else null


func _on_turned(voice: String) -> void:
	if voice == "title" and _open_due:
		_open_due = false
		if ctx.flow != null and ctx.flow.in_stage() and not _fight_live():
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
		_drop_clear()
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
		_clear_due = true
		if ctx.get("screen_busy") != null:
			ctx.screen_busy.request(CLEAR_KEY, true)
		if ctx.stages.worlds().size() <= 1:
			_ask_clear()


func _process(_delta: float) -> void:
	if _clear_due:
		_ask_clear()


func _ask_clear() -> void:
	var hud = ctx.root.get("hud") if ctx.root != null else null
	var busy = ctx.get("screen_busy")
	if hud != null and hud.launch_card.showing():
		if busy != null:
			busy.ready(CLEAR_KEY)
		return
	if busy != null and not busy.may_show(CLEAR_KEY, 0.0):
		return
	_clear_due = false
	if not player.play("spillway_clear") and busy != null:
		busy.done(CLEAR_KEY)


func _drop_clear() -> void:
	_clear_due = false
	var busy = ctx.get("screen_busy") if ctx != null else null
	if busy != null:
		busy.done(CLEAR_KEY)


func _on_started(id: String) -> void:
	var host = get_parent()
	var audio = host.get("audio") if host != null else null
	if STINGS.has(id) and audio != null and audio.has_method("story_sting"):
		audio.story_sting(STINGS[id])


func _on_finished(id: String, _skipped: bool) -> void:
	if id == "spillway_clear" and ctx.get("screen_busy") != null:
		ctx.screen_busy.done(CLEAR_KEY)
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
