extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# Unit P1 probe (throwaway): the game's traversal bot (tools/bot_driver.gd, policy traversal)
# follows a line over the Dig probe: the deck, the breach, the gallery, the tunnel, the ramp and the
# south deck. The bot has no slam verb, so a thin shim adds the two presses the line needs (a jump
# a little before the plate, then Ctrl once over it and falling); everything else is the bot's own
# steering and its 150 ms reaction buffer.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/probe_bot.gd -- --seed=1 [--plate=10] [--no-shim]
#
# One seed per process (a fresh physics server each time). Prints one `bot:` line.

const ROUTE: Array[Vector2] = [Vector2(0.0, -30.0), Vector2(0.0, 20.0), Vector2(0.0, 70.0), Vector2(0.0, 104.0)]
const PLATE_Z := -40.0
const LIMIT_SECONDS := 70.0

var _game
var _driver
var _seed := 1
var _shim := true
var _ticks := 0
var _wait := 0
var _phase := "boot"
var _jumped := false
var _m := {"broke": false, "gallery": false, "tunnel": false, "ramp_top": false, "min_planar_after_drop": 99.0}
var _drop_t := -1
var _out := ""


func _initialize() -> void:
	SimClock.ticks = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		if arg == "--no-shim":
			_shim = false
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	seed(_seed)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "probe"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	if _phase == "boot":
		_game.ctx.calm = true
		_driver = BotDriver.new(_game, "traversal", _seed)
		_driver.route = ROUTE.duplicate()
		_driver.start()
		_phase = "settle"
		_wait = 0
		return false
	if _wait < 120:
		_game.player.source.hold = {}
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	var body: RigidBody3D = _game.player.body()
	var p := body.global_position
	var v := body.linear_velocity
	if _shim:
		_apply_shim(p, v)
	_measure(p, v)
	if over or _m["ramp_top"] or _ticks > int(LIMIT_SECONDS * 90.0):
		_report(p)
		return true
	return false


func _apply_shim(p: Vector3, v: Vector3) -> void:
	var source = _driver.source
	if p.y > 10.0 and p.z < PLATE_Z + 6.0:
		if not _jumped and p.z >= PLATE_Z - 11.0 and _game.player.state.grounded:
			_jumped = true
			source.press["jump_pressed"] = true
		if _jumped and not _game.player.state.grounded and v.y < 0.0 and p.z >= PLATE_Z - 4.0:
			source.hold["brake_held"] = true


func _measure(p: Vector3, v: Vector3) -> void:
	var plate = _plate(_game)
	if plate != null and plate.broken and not _m["broke"]:
		_m["broke"] = true
		_m["broke_t"] = snappedf(_ticks / 90.0, 0.01)
	if _m["broke"] and p.y < 3.0 and p.z > PLATE_Z - 3.0:
		_m["gallery"] = true
	if _m["gallery"] and p.z > 44.0 and p.y < 6.0:
		_m["tunnel"] = true
	if _m["tunnel"] and p.y > 13.0 and p.z > 78.0:
		_m["ramp_top"] = true
	_m["last"] = [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]
	_m["fell"] = _m.get("fell", false) or p.y < -2.0


func _plate(n: Node):
	if n.name == "BreachPlate":
		return n
	for c in n.get_children():
		var f = _plate(c)
		if f != null:
			return f
	return null


func _report(_p: Vector3) -> void:
	var line := "bot: seed=%d shim=%s line_followed=%s seconds=%.1f %s goal=%s" % [_seed, str(_shim), str(_m["ramp_top"]), _ticks / 90.0, JSON.stringify(_m), _driver._goal]
	print(line)
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.READ_WRITE if FileAccess.file_exists(_out) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(line)
		f.close()
	_game.free()
	quit(0)
