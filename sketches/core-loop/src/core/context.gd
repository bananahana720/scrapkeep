extends RefCounted

const GameEvents := preload("res://src/core/game_events.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const RunState := preload("res://src/core/run_state.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")


var buffs: BuffLedger = BuffLedger.new():
	set(value):
		if buffs != null and buffs != value:
			buffs.bind_events(null)
		buffs = value
		if buffs != null and is_instance_valid(events):
			buffs.bind_events(events)
		if is_instance_valid(player) and player.get("abilities") != null and player.abilities.has_method("bind_buffs"):
			player.abilities.bind_buffs(buffs)
var events: GameEvents:
	set(value):
		events = value
		if buffs != null:
			buffs.bind_events(value if is_instance_valid(value) else null)
var run: RunState
var tuning: Tuning
var player: PlayerBall:
	set(value):
		if is_instance_valid(player) and player != value and player.get("abilities") != null and player.abilities.has_method("bind_buffs"):
			player.abilities.bind_buffs(null)
		player = value
		if is_instance_valid(value) and value.get("abilities") != null and value.abilities.has_method("bind_buffs"):
			value.abilities.bind_buffs(buffs)
var camera: ChaseCamera
var flow: Node
var terrain: RefCounted
var spawner: Node
var build: Node
var codex: Node
var run_log: Node
var profile: RefCounted
var progress: Node
var boss: Node
var stages = StageDefs
var root: Node3D
var destructibles: Node
var rng := RandomNumberGenerator.new()
var calm := false
var screen_busy: Node
var dev := false

var _hit_stop: Callable


func _init(hit_stop_impl := Callable()) -> void:
	_hit_stop = hit_stop_impl


func build_module() -> Node:
	if build != null:
		return build
	return get_meta("build") if has_meta("build") else null


func aim_origin() -> Vector3:
	return camera.aim_origin()


func aim_forward() -> Vector3:
	return camera.aim_forward()


func heading() -> Vector3:
	return -camera.yaw_basis().z if camera != null else Vector3.FORWARD


func can_spawn() -> bool:
	return spawner != null and spawner.has_method("spawn_enemy")


func break_props(at: Vector3, radius: float, source: String) -> void:
	if destructibles != null and is_instance_valid(destructibles):
		destructibles.on_blast(at, radius, source, 1, run.heft_class() if run != null else -1)


func hit_stop(seconds: float) -> void:
	if _hit_stop.is_valid():
		_hit_stop.call(seconds)
