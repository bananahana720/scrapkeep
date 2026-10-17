extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const Waking := preload("res://src/boss/waking.gd")
const T := preload("res://tests/support/t.gd")

# The twelve boss codex rows on the default table. All twelve are declared once the game
# is ready. The Waking (world two) is struck through the module harness's TARGET hit, one
# chunk at a time: the first floor drop fires waking_floor_drop; a slam three seconds after
# a drop fires no breach slam; slams right after the second and third drops fire
# waking_breach_slam, then waking_floor_chain on the second distinct floor; the kill fires
# waking_final_floor. The Mind (world three) commits each family the test names with its
# own clock held: a lane held on the ball lands and fires no mind_lane; lane, split_lane
# and rush dodged off the ball fire their rows; on a staggered Warden under a plate, a
# strike with the plate's verb fires no mind_plate and another contact verb does.
#
# Evidence limit: slams and strikes are enemy_struck emits, not ball contacts; hits are
# TARGET calls; the ball is placed by the test, not steered. The plate check still forces a
# plate so it stays deterministic; the real fight commits one on entering phase 4
# (mind_plate_reach_test).

const STATE_FRAMES := 90 * 10
const CHUNK_FRAMES := 90 * 10
const DROP_FRAMES := int(Waking.FLOOR_WARN * 90.0) + 30
const LATE_FRAMES := 90 * 3 + 5
const ATTACK_FRAMES := 90 * 6

var _t := T.new("boss_codex_detectors_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_declared()
	Harness.boot(_game)
	await _waking()
	await _mind()
	_game.free()
	quit(_t.verdict())


func _found(id: String) -> bool:
	return id in _game.ctx.codex.discovered_this_run()


func _declared() -> void:
	var listed := {}
	for entry in _game.ctx.codex.entries(CodexEntries.CATEGORY):
		listed[entry["id"]] = true
	var missing: Array = CodexEntries.all().map(func(e): return e["id"]).filter(func(id): return not listed.has(id))
	_t.check("all 12 boss rows declared at game ready", CodexEntries.all().size() == 12 and missing.is_empty(), "missing %s" % str(missing))


# --- The Waking --------------------------------------------------------------------------

func _waking() -> void:
	var game = _game
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	if not _t.check("world 2 module is the Waking", mod != null and mod.get_script() == Waking, "module %s" % mod):
		return
	_t.check("no floor-drop row before a floor drops", not _found(CodexEntries.WAKING_FLOOR_DROP), "early")
	if not await _drop(mod, 1):
		return
	_t.check("floor drop fires waking_floor_drop", _found(CodexEntries.WAKING_FLOOR_DROP), str(game.ctx.codex.discovered_this_run()))

	for i in LATE_FRAMES:
		await physics_frame
	var late: float = mod.clock - mod._dropped_at
	_t.check("a slam %.2f s after a drop fires no breach slam" % late, late >= 3.0 and _slam(mod) and not _found(CodexEntries.WAKING_BREACH_SLAM),
			"found %s" % _found(CodexEntries.WAKING_BREACH_SLAM))

	if not await _drop(mod, 2):
		return
	_slam(mod)
	_t.check("a slam right after a drop fires waking_breach_slam", _found(CodexEntries.WAKING_BREACH_SLAM), "floor %d" % mod.floors.current_floor())
	_t.check("one breach floor fires no chain", not _found(CodexEntries.WAKING_FLOOR_CHAIN), str(mod._breach_floors.keys()))

	if not await _drop(mod, 3):
		return
	_slam(mod)
	_t.check("breach slams on two floors fire waking_floor_chain", _found(CodexEntries.WAKING_FLOOR_CHAIN), str(mod._breach_floors.keys()))
	_t.check("no final-floor row before the kill", not _found(CodexEntries.WAKING_FINAL_FLOOR), "early")

	var frames := 0
	while Harness._alive(Harness.target(mod)) and frames < CHUNK_FRAMES:
		Harness.hit(mod)
		frames += 1
		await physics_frame
	_t.check("the kill fires waking_final_floor", _found(CodexEntries.WAKING_FINAL_FLOOR) and not Harness._alive(Harness.target(mod)),
			"frames %d, floor %d" % [frames, mod.floors.current_floor()])
	await _until(func(): return game.flow.state_name() != "boss")


# Hit until one chunk breaks, then wait for its floor body to go. Returns whether n floors fell.
func _drop(mod, n: int) -> bool:
	var chunks: int = mod.warden.chunks_left()
	var frames := 0
	while mod.warden.chunks_left() == chunks and frames < CHUNK_FRAMES:
		Harness.hit(mod)
		frames += 1
		await physics_frame
	frames = 0
	while mod._floor_bodies.size() > mod.floors.floor_count() - n and frames < DROP_FRAMES:
		frames += 1
		await physics_frame
	return _t.eq("floor %d dropped" % n, mod._floor_bodies.size(), mod.floors.floor_count() - n)


func _slam(mod) -> bool:
	_game.ctx.events.enemy_struck.emit(mod.warden, "slam", 1.0)
	return true


# --- The Mind ----------------------------------------------------------------------------

func _mind() -> void:
	var game = _game
	Harness.enter_world(game, 3)
	var mod = Harness.module(game, 3)
	if not _t.check("world 3 module is the Mind", mod != null and mod.get_script().resource_path.ends_with("mind.gd"), "module %s" % mod):
		return
	mod._attack_clock = 1.0e9
	var center: Vector3 = mod.pad.global_position
	var home := Vector3(center.x, mod._top() + 2.0, center.z + 12.0)

	var held := await _attack(mod, "lane", home, false)
	_t.check("a lane that lands fires no mind_lane", held["aimed"] and held["landed"] and not _found(CodexEntries.MIND_LANE),
			"aimed %s, landed %s" % [held["aimed"], held["landed"]])
	for family in ["lane", "split_lane", "rush"]:
		var dodged := await _attack(mod, family, home, true)
		_t.check("a dodged %s fires mind_%s" % [family, family], dodged["aimed"] and not dodged["landed"] and _found("mind_" + family),
				"aimed %s, landed %s" % [dodged["aimed"], dodged["landed"]])

	var frames := 0
	while not mod.warden.staggered() and frames < CHUNK_FRAMES:
		Harness.hit(mod)
		frames += 1
		await physics_frame
	_hold(home)
	mod._commit_attack("plate")
	var verb: String = mod._plate_verb
	game.ctx.events.enemy_struck.emit(mod.warden, verb, 1.0)
	_t.check("a strike with the plate's verb %s fires no mind_plate" % verb, mod.warden.staggered() and not _found(CodexEntries.MIND_PLATE), "verb %s" % verb)
	var other: String = "ram" if verb != "ram" else "stomp"
	game.ctx.events.enemy_struck.emit(mod.warden, other, 1.0)
	_t.check("a %s on the staggered Warden under a %s plate fires mind_plate" % [other, verb], _found(CodexEntries.MIND_PLATE), "verb %s" % verb)


# Commits one family with the ball held at home, then holds the ball there (dodge false) or
# off every hazard (dodge true) until the attack is freed. Returns the attack record.
func _attack(mod, family: String, home: Vector3, dodge: bool) -> Dictionary:
	_hold(home)
	mod._commit_attack(family)
	var attack: Dictionary = mod.attacks[-1]
	var spot := home
	if dodge:
		spot = _clear_of(mod, attack)
		_t.check("%s has a clear spot" % family, spot != Vector3.INF, "spot %s" % spot)
	var frames := 0
	while attack in mod.attacks and frames < ATTACK_FRAMES:
		_hold(spot)
		frames += 1
		await physics_frame
	return attack


func _hold(at: Vector3) -> void:
	_game.ctx.player.reset_to(at, Vector3.ZERO)
	_game.ctx.player.body().global_position = at


# A point on the pad outside every hazard of the attack.
func _clear_of(mod, attack: Dictionary) -> Vector3:
	var center: Vector3 = mod.pad.global_position
	var y: float = mod._top() + 2.0
	for r in [6.0, 14.0, 22.0, 30.0]:
		for step in 24:
			var a := TAU * step / 24.0
			var p := Vector3(center.x + cos(a) * r, y, center.z + sin(a) * r)
			var clear := true
			for h in attack["hazards"]:
				clear = clear and not (is_instance_valid(h) and h.contains(p))
			if clear:
				return p
	return Vector3.INF


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame
