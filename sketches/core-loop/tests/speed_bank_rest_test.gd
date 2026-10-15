# smoke: solo timeout=90s
extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

# SQ9-FIX: a roll start banks only from a free rest. The ball must already have been
# grounded at rest before the stick press, and a stop the brake held is a placed ball whose
# next roll starts clean. The free stop is the positive control: it must still bank, inside
# speed_bank_test's 1.2 to 1.3 band, within the same 0.3 s.
const PILOT := "tally"
const START := Vector3(0.0, 1.03, 0.0)
const SETTLE_TICKS := 12
const BRAKE_TICKS := 30
const READ_S := 0.3
const RATIO_FLOOR := 1.2

var t = T.new("speed_bank_rest_test")
var _player
var _tuning
var _source := Intent.Scripted.new()


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(0.0, -1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var events = GameEvents.new()
	world.add_child(events)
	_player = PlayerBall.new()
	world.add_child(_player)
	_tuning = Tuning.new()
	_player.setup(_tuning, events, START)
	_player.source = _source
	_player.fit_class(ClassDef.by_id(PILOT))
	_run.call_deferred()


func _run() -> void:
	var cruise: float = _tuning.f("cruise")
	var free: Dictionary = await _case("free", 0, SETTLE_TICKS)
	t.check("free stop banks a roll start", free.banked and free.peak >= RATIO_FLOOR * cruise,
		"bank=%s, peak %.2f m/s = %.3f x cruise (want a bank and at least %.1f)" % [free.banked, free.peak, free.peak / cruise, RATIO_FLOOR])
	for spec in [["braked stop, brake let go with the stick", BRAKE_TICKS, 0],
			["braked stop, brake let go before the stick", BRAKE_TICKS, SETTLE_TICKS],
			["stick on the second tick after a reset", -1, 0]]:
		var got: Dictionary = await _case(spec[0], spec[1], spec[2])
		t.check(spec[0] + " does not bank", not got.banked and got.peak < RATIO_FLOOR * cruise,
			"bank=%s, peak %.2f m/s = %.3f x cruise (want no bank, under %.1f)" % [got.banked, got.peak, got.peak / cruise, RATIO_FLOOR])
	quit(t.verdict())


# brake_ticks < 0 presses the stick on the second tick after the reset, before any grounded rest.
func _case(label: String, brake_ticks: int, free_ticks: int) -> Dictionary:
	_source.hold = {"brake_held": true} if brake_ticks > 0 else {}
	_source.press = {}
	_player.reset_to(START, Vector3.ZERO)
	if brake_ticks < 0:
		await physics_frame
	else:
		for i in brake_ticks:
			await physics_frame
		_source.hold = {}
		for i in free_ticks:
			await physics_frame
	var grounded: bool = _player.state.grounded
	_source.hold = {"move": Vector2(0.0, 1.0)}
	var banked := false
	var peak := 0.0
	for i in ceili(READ_S * Engine.physics_ticks_per_second):
		await physics_frame
		banked = banked or not _player.speed_bank.is_empty()
		peak = maxf(peak, _player.planar_velocity().length())
	print("  %s: grounded at the press %s" % [label, grounded])
	_source.hold = {}
	return {"banked": banked, "peak": peak}
