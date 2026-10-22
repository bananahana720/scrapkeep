extends SceneTree

const Game := preload("res://src/game.gd")
const Contact := preload("res://src/movement/contact.gd")

# player_ball.touch_body is the public contact entry for bodies the RigidBall signal never
# sees. It must run the same contact as _on_enemy_touched, derive the normal as RigidBall does
# (body to ball, full 3D) and ignore freed bodies. The fixture body is a plain Node3D with the
# knock/flash/weight surface the contact reads; the solver's incoming history is staged by hand.

const STUB := """extends Node3D
var weight := 0.5
var knocks := 0
func knock(_d: Vector3, _f: float) -> void:
	knocks += 1
func flash() -> void:
	pass
"""

var _game
var _stub_script: GDScript
var _failures := 0
var _checks := 0
var _events: Array = []


func _initialize() -> void:
	_stub_script = GDScript.new()
	_stub_script.source_code = STUB
	_stub_script.reload()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# A fresh body and a ball placed `offset` from it, moving at `velocity` going in.
func _setup(offset: Vector3, velocity: Vector3) -> Node3D:
	var body := Node3D.new()
	body.set_script(_stub_script)
	_game.add_child(body)
	body.global_position = _game.ctx.terrain.drop_point(0.0, 0.0, 1.5) + Vector3(40.0, 0.0, 0.0)
	_game.player.reset_to(body.global_position + offset)
	_game.player.set_velocity_now(velocity)
	_game.player._rigid.recent_velocities.assign([velocity])
	_events.clear()
	return body


func _last() -> Array:
	return _events[-1] if not _events.is_empty() else ["", 0.0]


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.player.struck.connect(func(_e: Node3D, kind: String, force: float): _events.append([kind, force]))
	var cruise: float = _game.player.tuning.f("cruise")
	var fall := Vector3(0.0, -(_game.player.STOMP_SPEED + 5.0), 0.0)
	var roll := Vector3(cruise, 0.0, 0.0)

	# Equivalence: same setup, the public entry against the private handler.
	var n := Vector3(-1.0, 0.2, 0.0).normalized()
	var a := _setup(Vector3(-2.0, 0.0, 0.0), roll)
	_game.player.touch_body(a, n)
	var via_public: Array = _last()
	var v_public: Vector3 = _game.player.state.velocity
	var count_public := _events.size()
	a.free()
	var b := _setup(Vector3(-2.0, 0.0, 0.0), roll)
	_game.player._on_enemy_touched(b, n)
	_report("touch_body matches _on_enemy_touched", count_public == 1 and _events.size() == 1 and via_public == _last()
		and v_public.is_equal_approx(_game.player.state.velocity),
		"public %s v %s, private %s v %s" % [via_public, v_public, _last(), _game.player.state.velocity])
	b.free()

	# The same for a stomp, which rewrites the velocity; the derived normal against the helper's.
	var s1 := _setup(Vector3(0.0, 2.0, 0.0), fall)
	_game.player.touch_body(s1)
	var stomp_public: Array = _last()
	var sv_public: Vector3 = _game.player.state.velocity
	var stomp_count := _events.size()
	s1.free()
	var s2 := _setup(Vector3(0.0, 2.0, 0.0), fall)
	_game.player._on_enemy_touched(s2, Contact.normal_between(_game.player.ball_position(), s2.global_position))
	_report("derived stomp matches the private handler", stomp_count == 1 and _events.size() == 1 and stomp_public == _last()
		and stomp_public[0] == "stomp" and sv_public.is_equal_approx(_game.player.state.velocity) and sv_public.y > 0.0,
		"public %s v %s, private %s v %s" % [stomp_public, sv_public, _last(), _game.player.state.velocity])
	s2.free()

	# The shared normal rule itself.
	var up_n: Vector3 = Contact.normal_between(Vector3(0.0, 2.0, 0.0), Vector3.ZERO)
	var level_n: Vector3 = Contact.normal_between(Vector3(-2.0, 0.0, 0.0), Vector3.ZERO)
	var same_n: Vector3 = Contact.normal_between(Vector3(0.004, 0.0, 0.0), Vector3.ZERO)
	_report("normal_between: above, level, coincident", up_n.y > 0.3 and is_zero_approx(level_n.y) and level_n.x < 0.0
		and same_n == Vector3.UP, "above %s, level %s, coincident %s" % [up_n, level_n, same_n])

	# Default normal from above: a stomp. The planar normal Challenge used to pass is not.
	var c := _setup(Vector3(0.0, 2.0, 0.0), fall)
	_game.player.touch_body(c)
	_report("default normal from above stomps", _events.size() == 1 and _last()[0] == "stomp", "events %s" % [_events])
	c.free()
	var d := _setup(Vector3(0.0, 2.0, 0.0), fall)
	_game.player.touch_body(d, Vector3(0.0, 0.0, 1.0))
	_report("planar normal from above does not stomp", not _events.any(func(e): return e[0] == "stomp"), "events %s" % [_events])
	d.free()

	# Default normal level with the body: a ram at cruise.
	var e := _setup(Vector3(-2.0, 0.0, 0.0), roll)
	_game.player.touch_body(e)
	_report("default normal level rams", _events.size() == 1 and _last()[0] == "ram", "events %s" % [_events])
	e.free()

	# A short caller normal is still normalized: 0.2 stomps only once it is unit length (the bar is 0.3).
	var f := _setup(Vector3(0.0, 2.0, 0.0), fall)
	_game.player.touch_body(f, Vector3(0.0, 0.2, 0.0))
	_report("short caller normal is normalized", _events.size() == 1 and _last()[0] == "stomp", "events %s" % [_events])
	f.free()

	# Invalid bodies do nothing.
	var h := _setup(Vector3(-2.0, 0.0, 0.0), roll)
	_game.player.touch_body(null)
	_report("null body does nothing", _events.is_empty(), "events %s" % [_events])
	var plain := Node.new()
	_game.player.touch_body(plain)
	plain.free()
	_report("non-Node3D object does nothing", _events.is_empty(), "events %s" % [_events])
	h.free()
	var g := _setup(Vector3(-2.0, 0.0, 0.0), roll)
	g.queue_free()
	await physics_frame
	await physics_frame
	_game.player.touch_body(g)
	_report("freed body does nothing", _events.is_empty(), "events %s" % [_events])

	_game.free()
	print("touch_body_test: %d checks, %s" % [_checks, "PASS" if _failures == 0 else "FAIL (%d)" % _failures])
	quit(0 if _failures == 0 else 1)
