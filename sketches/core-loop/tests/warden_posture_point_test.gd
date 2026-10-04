extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")

# Every family Warden names its own weak point (reactor core, swarm queen, mind lens) in
# each place the open point is published or judged: family_point(), plating_for and
# weak_points in a stagger, the judge's part for a contact in a stagger, and the
# weak_point_opened a real stagger publishes on the bus.

const WANT := {Roster.REACTOR: "core", Roster.SWARM: "queen", Roster.MIND: "lens"}

var _game
var _failures := 0
var _opened: Array = []


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.weak_point_opened.connect(func(id: String, _at: Vector3, _seconds: float): _opened.append(id))
	await physics_frame
	_game.run.set_max_hp(99999.0)
	var x := 40.0
	for family in [Roster.REACTOR, Roster.SWARM, Roster.MIND]:
		await _check(family, _spawn(family, x))
		x += 30.0
	_game.free()
	print("warden_posture_point_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# A Warden of one family on the fleet's bus, held out of play so only the test moves it.
func _spawn(family: String, x: float) -> Node3D:
	var warden := Warden.new()
	_game.add_child(warden)
	warden.position = Vector3(x, 0.0, 0.0)
	warden.setup(_game.player, _game.ctx.terrain, _game, func(): return false, 1.0,
		{"family": family, "stage": 1, "fleet": _game.ctx.spawner.fleet, "plating": 30.0, "hp": 800.0})
	return warden


func _check(family: String, warden: Node3D) -> void:
	# Every check holds the Warden to the family's name, not to its own answer.
	var point: String = WANT[family]
	_report("%s point" % family, warden.family == family and warden.family_point() == point, "family %s names %s" % [warden.family, warden.family_point()])
	warden._posture.staggered = true
	var points: Array = warden.weak_points()
	_report("%s forced stagger opens the point" % family, warden.plating_for("runner", point) == 0.0
		and points.size() == 1 and points[0]["id"] == point,
		"plating_for(runner, %s) %.1f, weak points %s" % [point, warden.plating_for("runner", point), points.map(func(p): return p["id"])])
	var judged: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
	_report("%s judge names the point" % family, String(judged.get("part", "")) == point,
		"judge_hit(slam) in a stagger: part '%s'" % judged.get("part", ""))
	warden._posture.staggered = false
	_opened.clear()
	var guard := 0
	while not warden.staggered() and guard < 10:
		_target_hit(warden)
		await physics_frame
		guard += 1
	_report("%s real stagger is heard" % family, warden.staggered() and _opened == [point],
		"staggered %s after %d hits, weak_point_opened %s" % [warden.staggered(), guard, _opened])
	await physics_frame
	var live: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
	_report("%s live stagger judge names the point" % family, String(live.get("part", "")) == point,
		"part '%s'" % live.get("part", ""))
	warden.queue_free()


# BossContract.TARGET, as alpha_flow_run_test drives it: judged, applied, a shatter's damage taken.
func _target_hit(warden) -> void:
	var result: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
	warden.on_struck("slam", String(result.get("part", "")), result)
	if bool(result.get("shatter", false)):
		warden.take_damage(float(result.get("dealt", 0.0)))
