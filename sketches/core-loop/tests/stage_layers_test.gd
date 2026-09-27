extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Gorge := preload("res://src/world/map_gorge.gd")

# Every height of the gorge is reachable by every class (DESIGN-V2 section 8; I3 test
# 1). Each class drops onto the rim deck (sky), rolls off the lip into the canal
# (undercroft), rides the geyser up to the crown dish (sky again, from below), and
# rolls out of the dish's notch onto the west shelf (shelf). The world's own layer
# facts are the record: a class passes when it heard layer_undercroft, layer_sky and
# layer_shelf in one run, all by rolling and riding, with no teleport after the drop.
#
# Evidence limit: one scripted line per class in calm; it shows the heights connect
# for every kit, not that each class's best route is its best.

const SIM_SCALE := 3.0
const PHASE_LIMIT := 25.0
const CLASSES := [0, 1, 2]

var _game
var _failures := 0
var _source := Intent.Scripted.new()
var _phase := "boot"
var _clock := 0.0
var _class := -1
var _heard: Array = []
var _todo: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = _source
			_game.events.world_fact.connect(func(kind: String, _at: Vector3): _heard.append(kind))
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_todo = CLASSES.duplicate()
			_phase = "next_class"
		"next_class":
			if _todo.is_empty():
				Engine.time_scale = 1.0
				print("stage_layers_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				_game.free()
				quit(0 if _failures == 0 else 1)
				return true
			_class = _todo.pop_front()
			# A fresh run as this class, then straight to stage 2 as a launch would bring it.
			_game.flow._begin_run(_game.flow.classes[_class])
			_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
			_heard.clear()
			_source.hold = {}
			_clock = 0.0
			Engine.time_scale = SIM_SCALE
			_phase = "drop"
		"drop":
			_clock += delta
			_steer(Vector3(0.0, 0.0, -60.0))
			if _heard.has("layer_undercroft"):
				_advance("geyser")
		"geyser":
			_clock += delta
			if _game.world.ride == null and not _heard.has("geyser_fired"):
				_steer(Vector3(-22.0, 0.0, 30.0))
			else:
				_source.hold = {}
			if _heard.has("layer_sky"):
				_advance("exit")
		"exit":
			_clock += delta
			if _game.world.ride == null:
				_steer(Vector3(Gorge.DISH.x, 0.0, Gorge.DISH.z + 40.0))
			if _heard.has("layer_shelf"):
				_done(true)
	if _phase != "next_class" and _clock > PHASE_LIMIT:
		_done(false)
	return false


func _advance(next: String) -> void:
	_phase = next
	_clock = 0.0


func _done(ok: bool) -> void:
	var name: String = _game.flow.classes[_class].display_name
	var layers := _heard.filter(func(k): return String(k).begins_with("layer_"))
	var rides := _heard.filter(func(k): return String(k).begins_with("ride_") or String(k).ends_with("_fired"))
	var reached: bool = layers.has("layer_undercroft") and layers.has("layer_sky") and layers.has("layer_shelf")
	_report("%s reaches every height" % name, ok and reached,
		"layers heard in order %s; rides %s; ended at %s" % [layers, rides, _game.player.ball_position()])
	_source.hold = {}
	_phase = "next_class"


func _steer(target: Vector3) -> void:
	var player = _game.player
	var ball: Vector3 = player.ball_position()
	var dir := Vector3(target.x - ball.x, 0.0, target.z - ball.z).normalized()
	_game.camera.yaw = atan2(-dir.x, -dir.z)
	var v: Vector3 = player.planar_velocity()
	var change := dir * maxf(v.length(), 12.0) - v
	var want := dir if change.length() < 0.5 else change.normalized()
	var yaw: float = _game.camera.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	_source.hold = {"move": Vector2(want.dot(right), want.dot(forward)).normalized()}
