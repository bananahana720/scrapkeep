extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Fabricators := preload("res://src/build/fabricators.gd")

# A fabricator is drive-through: roll through its hoop at speed with enough cogs and
# it grants its part, spends the price in cogs and no mass, and the ball keeps its
# horizontal speed within 15%. Rolling through short of cogs grants nothing and costs
# nothing. The rich pass clears the field first, so no gear on the lane moves the wallet. The ball is
# driven through two hoops on the flat top shelf with ctx.calm set, so the speed checks
# measure the ball and the fabricator alone. Each pass through a stocked hoop, bought or
# not, sends one world_fact("fabricator_used") at the hoop (the fabricator tune's cue).

const APPROACH := 16.0
const APPROACH_SPEED := 20.0
const TOLERANCE := 0.15
const SETTLE_TICKS := 9
const LANE_X := -62.0
const HOOP_Z := -70.0
const POOR_X := -30.0
const PART := "long_spool"

var _game
var _build
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _phase := "boot"
var _wait := 0
var _gained: Array = []
var _fab := {}
var _before := 0.0
var _after := 0.0
var _cogs_before := 0
var _mass_before := 0.0
var _range_before := 0.0
var _pieces_before := 0
var _poor := {}
var _collected := 0
var _used: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks > 90 * 20:
		_report("timeout", false, "stalled in phase %s" % _phase)
		return _finish()
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = _source
			_game.events.part_gained.connect(func(id: String, source: String): _gained.append([id, source]))
			_game.events.world_fact.connect(func(kind: String, at: Vector3):
				if kind == "fabricator_used":
					_used.append(at))
			_game.events.scrap_collected.connect(func(amount: int, _at: Vector3, _total: int): _collected += amount)
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_build = _game.ctx.get_meta("build")
			_phase = "settle"
		"settle":
			_wait += 1
			if _wait == 10:
				_start_rich_pass()
		"rich":
			if _along(_fab) < -1.5:
				_before = _planar()
			if _crossed(_fab):
				_phase = "rich_after"
				_wait = 0
		"rich_after":
			_wait += 1
			if _wait == SETTLE_TICKS:
				_after = _planar()
				_check_rich()
				_start_poor_pass()
		"poor":
			if _along(_poor) < -1.5:
				_poor["before"] = _planar()
			if _crossed(_poor):
				_phase = "poor_after"
				_wait = 0
		"poor_after":
			_wait += 1
			if _wait == SETTLE_TICKS:
				_poor["after"] = _planar()
				_check_poor()
				return _finish()
	return false


func _planar() -> float:
	return _game.player.planar_velocity().length()


func _along(fab: Dictionary) -> float:
	return (_game.player.ball_position() - (fab["at"] as Vector3)).dot(fab["facing"])


func _crossed(fab: Dictionary) -> bool:
	return _along(fab) > 0.0


func _drive_at(fab: Dictionary) -> void:
	var facing: Vector3 = fab["facing"]
	var start: Vector3 = (fab["at"] as Vector3) - facing * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * APPROACH_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}


func _start_rich_pass() -> void:
	_build.fabricators.clear()
	var at: Vector3 = _game.ctx.terrain.drop_point(LANE_X, HOOP_Z, 0.0)
	_fab = _build.fabricators.add_at(at, Vector3(0.0, 0.0, 1.0), PART)
	_build.scrap.clear()
	_game.run.add_cogs(60)
	_cogs_before = _game.run.cogs
	_mass_before = _game.run.mass
	_range_before = _game.player.grapple_range()
	_pieces_before = _build.accretion.piece_count()
	_gained.clear()
	_used.clear()
	_collected = 0
	_drive_at(_fab)
	_phase = "rich"


func _check_rich() -> void:
	var price := Fabricators.hoop_price(PART, 0)
	var granted: bool = _gained.size() == 1 and _gained[0] == [PART, "fabricator"]
	_report("fabricator grants", granted and _game.run.parts.has(PART),
		"rolled through the %s hoop with %d cogs: part_gained %s, run parts %s" % [PART, _cogs_before, _gained, _game.run.parts])
	_report("fabricator spends", _game.run.cogs == _cogs_before - price and is_equal_approx(_game.run.mass, _mass_before + _collected),
		"price %d: cogs %d before, %d after; mass %.1f before, %.1f after (%d scrap picked up on the lane)"
			% [price, _cogs_before, _game.run.cogs, _mass_before, _game.run.mass, _collected])
	_report("fabricator momentum", _kept(_before, _after),
		"%.2f m/s horizontal before the hoop, %.2f m/s after (within %d%%)" % [_before, _after, int(TOLERANCE * 100.0)])
	_report("fabricated part works", _game.player.grapple_range() > _range_before * 1.29,
		"grapple range %.1f m before, %.1f m after Long Spool" % [_range_before, _game.player.grapple_range()])
	_report("part shows on the ball", _build.accretion.piece_count() == _pieces_before + 1,
		"accreted hardware pieces %d before, %d after" % [_pieces_before, _build.accretion.piece_count()])
	_report("fabricator used, once at the hoop", _used.size() == 1 and _used[0] == _fab["at"], "fabricator_used facts %s" % [_used])
	_report("fabricator restocks", _fab["restock"] > 0.0, "restock timer %.2f s after the sale" % _fab["restock"])


func _start_poor_pass() -> void:
	# Spend down to nothing so the next hoop is out of reach.
	_game.run.spend_cogs(_game.run.cogs)
	_build.fabricators.clear()
	var at: Vector3 = _game.ctx.terrain.drop_point(POOR_X, HOOP_Z, 0.0)
	_poor = _build.fabricators.add_at(at, Vector3(0.0, 0.0, 1.0), "hot_rivets")
	_poor["parts_before"] = _game.run.parts.size()
	_gained.clear()
	_used.clear()
	_drive_at(_poor)
	_phase = "poor"


func _check_poor() -> void:
	var before: float = _poor.get("before", 0.0)
	var after: float = _poor.get("after", 0.0)
	_report("short of cogs", _gained.is_empty() and _game.run.parts.size() == _poor["parts_before"],
		"rolled through with %d cogs against a price of %d: part_gained %s" % [_game.run.cogs, Fabricators.hoop_price("hot_rivets", _poor["parts_before"]), _gained])
	_report("short of cogs still a pass", _used.size() == 1, "fabricator_used facts %s" % [_used])
	_report("short of cogs momentum", _kept(before, after),
		"%.2f m/s before, %.2f m/s after (within %d%%)" % [before, after, int(TOLERANCE * 100.0)])


static func _kept(before: float, after: float) -> bool:
	return before > 0.1 and absf(after - before) / before <= TOLERANCE


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _finish() -> bool:
	print("build_fabricator_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
