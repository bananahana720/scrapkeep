extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Bay := preload("res://src/world/bay.gd")
const Push := preload("res://tests/support/push.gd")

# The workshop screens in Moss's real bay (v2 W8), armed as in play, through world's own
# hooks: stage 1's Warden gates (world-one builds open the pick at the stage-1 visit), the barge docked, the ball rolled into the cradle.
#   - The catch opens the next upgrade pick over the throw, paused. Moss's greeting
#     (world.bay_bark) is set in his bubble but not drawn while the pick is up (PF-30).
#   - A key takes the pick, the greeting shows, and the throw carries on aboard.
#   - Rolling up to Moss's hatch slowly opens the counter by itself and parks the ball;
#     the talk key shows, and T gets a beat.
#   - Esc leaves; parked in reach again, the counter waits until the ball has rolled away.
# Evidence limit: headless and calm; the look and the feel are Andrew's play.

const APPROACH := 14.0
const SPEED := 22.0

var _game
var _ws
var _failures := 0
var _phase := "boot"
var _clock := 0.0
var _caught := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _bay():
	return _game.world.bay


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	var player = _game.player
	match _phase:
		"boot":
			_ws = _game.get_node("Workshop")
			_game.ctx.calm = true
			player.source = Intent.Scripted.new()
			_game.events.bay_entered.connect(func(_b: float): _caught = true)
			_game.flow.beacon_seconds_override = 0.3
			_game.flow.press_start()
			_game.flow.choose_class(0)
			player.tree.pick(player.tree.offered(player.tree.class_id, 1)[0]["id"])
			_ws.armed = true
			_game.flow.enter_stage(1, Vector3.ZERO, false)
			_next("beacon")
		"beacon":
			if _clock < 0.1:
				var at: Vector3 = _game.flow.beacon.global_position + Vector3.UP * 1.5
				player.reset_to(at, Vector3(0.0, 0.0, 4.0))
				player.body().global_position = at
			if _game.flow.state_name() == "gates" and _bay().docked:
				var cradle: Vector3 = _bay().cradle_at
				var dir: Vector3 = -_bay().facing
				var start := cradle - dir * APPROACH
				var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
				player.reset_to(at, dir * SPEED)
				player.body().global_position = at
				_next("catch")
			elif _clock > 25.0:
				return _finish("the bay never docked; flow %s" % _game.flow.state_name())
		"catch":
			if _caught and _clock > 0.2 and _ws.pick.is_open():
				var greeting: String = _game.world.bay_bark.get("text", "")
				_report("the catch opens the pick", paused and _game.menu_held() and _ws.pick.depth == 2,
					"pick open at depth %d, paused %s, held %s" % [_ws.pick.depth, paused, _game.menu_held()])
				_report("Moss's greeting waits behind it", greeting != "" and _ws.bubble.text == greeting and not _ws.bubble.visible,
					"bubble \"%s\" for the bark \"%s\", drawn %s" % [_ws.bubble.text, greeting, _ws.bubble.visible])
				Push.key(root, KEY_1)
				_report("a key takes it", player.tree.path().size() == 2 and not paused and not _ws.pick.is_open(),
					"path %s, paused %s" % [player.tree.path(), paused])
				_report("the greeting shows once the pick is gone", _ws.bubble.text == greeting and _ws.bubble.visible,
					"bubble \"%s\", drawn %s" % [_ws.bubble.text, _ws.bubble.visible])
				_next("aboard")
			elif _clock > 6.0:
				return _finish("caught %s, pick open %s" % [_caught, _ws.pick.is_open()])
		"aboard":
			if _game.world.ride == null and _bay().on_deck(player.ball_position()) and player.state.grounded:
				_park_by_moss()
				_next("pull_up")
			elif _clock > 10.0:
				return _finish("never landed aboard; ball at %s" % [player.ball_position()])
		"pull_up":
			if _ws.counter.is_open():
				_report("pulling up opens the counter", player.frozen() and _game.menu_held() and _ws.talk.visible and not paused,
					"in reach %s; ball parked %s, held %s, talk key %s" % [_game.ctx.terrain.near_moss(player.ball_position()), player.frozen(), _game.menu_held(), _ws.talk.visible])
				Push.key(root, KEY_T)
				_report("T gets a beat", _ws.bubble.mood == "beat" and _game.build.shop.LINES.values().has(_ws.bubble.text),
					"bubble %s \"%s\"" % [_ws.bubble.mood, _ws.bubble.text])
				Push.key(root, KEY_ESCAPE)
				_park_by_moss()
				_next("stay_closed")
			elif _clock > 2.0:
				return _finish("counter never opened; near %s, speed %.2f" % [_game.ctx.terrain.near_moss(player.ball_position()), player.state.velocity.length()])
		"stay_closed":
			if _clock > 0.6:
				_report("it waits for the ball to roll away", not _ws.counter.is_open() and not player.frozen() and not _game.menu_held(),
					"counter open %s, ball parked %s, held %s" % [_ws.counter.is_open(), player.frozen(), _game.menu_held()])
				return _finish("")
	return false


func _park_by_moss() -> void:
	var at: Vector3 = _bay().deck_point(Bay.MOSS + Vector2(3.0, 0.0), 1.05)
	_game.player.reset_to(at, Vector3.ZERO)
	_game.player.body().global_position = at


func _next(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _finish(why: String) -> bool:
	if why != "":
		_report("reached the end", false, why)
	print("ui_workshop_bay_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
