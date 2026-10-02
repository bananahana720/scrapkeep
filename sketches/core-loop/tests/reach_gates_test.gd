extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

var _game
var _t := T.new("reach_gates_test")
var _boot := false
var _index := 0
var _check_next := false
var _docks := 0
var _legacy := false


func _initialize() -> void:
	SimClock.ticks = true
	_legacy = "--legacy" in OS.get_cmdline_user_args()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _boot:
		_boot = true
		_game.ctx.calm = true
		_game.flow.force_warden = true
		_game.player.source = Intent.Scripted.new()
		if _legacy:
			_game.ctx.terrain.map().gate_slots.clear()
		_game.flow.press_start()
		_game.flow.choose_class(0)
	if _check_next:
		_check()
		_index += 1
		_check_next = false
		if _index == 16:
			_t.eq("bay docks at all 16 Warden break positions", _docks, 16)
			_game.free()
			quit(_t.verdict())
			return true
		_game.flow.retry_stage()
	var radius := 20.0 if _index < 8 else 44.0
	var angle := TAU * (_index % 8) / 8.0
	var at := Vector2(cos(angle) * radius, 118.0 + sin(angle) * radius)
	var ball: Vector3 = _game.ctx.terrain.drop_point(at.x, at.y, 1.05)
	_game.player.reset_to(ball, Vector3.ZERO)
	_game.player.body().global_position = ball
	_game.player.body().freeze = true
	var warden: Node3D = _game.flow.warden
	_t.check("Warden exists at spot %d" % _index, is_instance_valid(warden))
	if not is_instance_valid(warden):
		_game.free()
		quit(1)
		return true
	warden.hp = 0.0
	warden._die()
	_check_next = true
	return false


func _check() -> void:
	var gates = _game.ctx.build.gates
	var offers: Array = gates.offers
	var bay = _game.world.bay
	var slots_ok := offers.size() == 3
	for i in offers.size():
		var expected := Vector3((i - 1) * 14.0, -8.0, 134.0)
		slots_ok = slots_ok and (offers[i]["at"] as Vector3).distance_to(expected) < 0.01 \
			and offers[i]["facing"] == Vector3(0.0, 0.0, 1.0)
	_t.check("fixed gates at spot %d" % _index, slots_ok, "offers %s" % [offers.map(func(o): return o["at"])])
	var docked: bool = bay.docked
	if docked:
		_docks += 1
	_t.check("first-lift clear dock at spot %d" % _index, docked and not bay._warned and absf(bay.deck_y() - 47.5) <= 1.0
		and Vector2(bay.cradle_at.x, bay.cradle_at.z).distance_to(Vector2(-28.0, 134.0)) < 0.01,
		"docked %s warned %s deck %.3f cradle %s" % [docked, bay._warned, bay.deck_y(), bay.cradle_at])
	if slots_ok:
		var original: Array = offers.map(func(o): return o["at"])
		gates.step(Vector3(70.0, -7.0, 160.0), Vector3(0.0, 0.0, 1.0))
		_t.eq("passing all gates replaces at the same slots", gates.offers.map(func(o): return o["at"]), original)
