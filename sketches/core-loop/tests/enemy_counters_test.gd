extends SceneTree

const Game := preload("res://src/game.gd")
const Roster := preload("res://src/combat/roster.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")

# Every Fleet counter that holds the ball, one at a time against a ball at rest (the
# netcaster's ball is lifted into the air just before its field goes live):
# - its warning is a committed telegraph in the Fleet voice with its own tag, and the
#   hold starts no sooner than the full warning after it;
# - the hold goes through the holds node (hold_started on the bus);
# - the player's own action (boost, jump or smash, the first the row lists) breaks it
#   on the next tick with hold_broken, the refund, and the unit's tool spent.

const HOLDERS := ["mag_trapper", "hooker", "netcaster", "bola_thrower", "winch_drone", "gyro_jammer", "swatter",
	"ramp_flipper", "catch_trap"]
const OWN_ACTIONS := ["boost", "jump", "smash"]
const OFFSET := Vector3(9.0, 0.0, 3.0)
const LIMIT := 6.0
const TICK := 1.0 / 60.0

var _game
var _fleet
var _failures := 0
var _index := -1
var _unit: Node3D
var _clock := 0.0
var _warn_at := -1.0
var _voice := ""
var _tag := ""
var _broke := ""
var _breaks_before := 0
var _ball_at := Vector3.ZERO
var _started := 0
var _broken_facts: Array = []
var _cooldown := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	if _index < 0:
		_setup()
		_next()
		return false
	if _cooldown > 0:
		_cooldown -= 1
		if _cooldown == 0:
			return _next()
		return false
	_clock += delta
	var kind: String = HOLDERS[_index]
	if _warn_at < 0.0 and is_instance_valid(_unit) and _unit.telegraph() != null:
		_warn_at = _clock
		_voice = _unit.telegraph().owner_voice
		_tag = _unit.telegraph().mechanic_tag
	if kind == "netcaster" and _unit.phase == _unit.Phase.WARN and _unit._t >= _unit.warn_seconds - 0.2 and _game.player.state.grounded:
		_game.player.reset_to(_ball_at + Vector3.UP * 3.5)
	if _broke == "":
		if _fleet.holds.held(_unit):
			_on_held(kind)
		elif _clock > LIMIT:
			_report(kind, false, "never held the ball in %.0f s (warned %d, phase %s)" % [LIMIT, _unit.warned, _unit.state_name()])
			_retire()
		return false
	var row: Dictionary = Roster.row(kind)
	var released: bool = not _fleet.holds.held(_unit)
	var last: Dictionary = _fleet.holds.last_release
	_report(kind + " breaks", released and last.get("reason", "") == _broke and _fleet.holds.breaks_by_player == _breaks_before + 1
			and _broken_facts.has([row["mechanic"], _broke]) and _unit.broken_by == _broke,
		"%s broke the %s hold on the next tick (release %s, hold_broken %s, refund paid %s)"
			% [_broke, row["mechanic"], last, _broken_facts, _fleet.holds.breaks_by_player == _breaks_before + 1])
	_retire()
	return false


func _on_held(kind: String) -> void:
	var row: Dictionary = Roster.row(kind)
	var held_after := _clock - _warn_at
	_report(kind + " telegraphs first", _warn_at >= 0.0 and held_after >= _unit.warn_seconds - TICK and _unit.warned >= 1,
		"held %.2f s after its warning drew (warning %.2f s)" % [held_after, _unit.warn_seconds])
	_report(kind + " voice", _voice == "clank" and _tag == row["tag"] and _tag != "",
		"telegraph voice %s, tag %s (row tag %s)" % [_voice, _tag, row["tag"]])
	_report(kind + " through the door", _started > 0, "%d hold_started facts" % _started)
	if kind == "netcaster":
		# The net catches only in the air, so its live ring keeps off the ground scorch (ruling
		# #241 6347013047 section 4); threat_grammar_test plants the same ring without "air".
		var field: Dictionary = _unit.telegraph().descriptor()
		var scorch := Color(Palette.HAZARD.lerp(Palette.CHARCOAL, Threat.LIVE_SCORCH), Threat.LIVE_SCORCH_ALPHA)
		var tint := Threat.fill_tint(field)
		_report("netcaster air ring", Threat.haze() and field.get("live", false) and field.get("air", false) and tint != scorch,
			"haze %s, live %s, air %s, live fill %s (scorch %s)" % [Threat.haze(), field.get("live", false), field.get("air", false), tint, scorch])
	_broke = ""
	for method in OWN_ACTIONS:
		if method in row["breaks"]:
			_broke = method
			break
	_breaks_before = _fleet.holds.breaks_by_player
	var events = _game.events
	match _broke:
		"boost":
			events.boosted.emit(Vector3.FORWARD)
		"jump":
			events.jumped.emit(true)
		"smash":
			events.slammed.emit(_game.player.ball_position(), 1.0, 1.0)
		_:
			_report(kind + " breaks", false, "its row lists no boost, jump or smash: %s" % [row["breaks"]])
			_retire()


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_fleet = ctx.spawner.fleet
	_ball_at = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.events.hold_started.connect(func(_kind: String, _at: Vector3): _started += 1)
	_game.events.hold_broken.connect(func(kind: String, method: String): _broken_facts.append([kind, method]))


func _next() -> bool:
	_index += 1
	if _index >= HOLDERS.size():
		return _finish()
	var ctx = _game.ctx
	_fleet.holds.clear()
	_game.player.reset_to(_ball_at)
	var at: Vector3 = _ball_at + OFFSET
	_unit = ctx.spawner.spawn_enemy(HOLDERS[_index], ctx.terrain.drop_point(at.x, at.z, 1.8))
	_unit._rest = 0.3
	_clock = 0.0
	_warn_at = -1.0
	_broke = ""
	_started = 0
	_broken_facts.clear()
	return false


func _retire() -> void:
	if is_instance_valid(_unit):
		_unit.queue_free()
	_cooldown = 3


func _finish() -> bool:
	var ok := _failures == 0
	print("enemy_counters_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
