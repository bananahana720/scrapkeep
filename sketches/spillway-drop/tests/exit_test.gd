extends SceneTree

const Stage := preload("res://src/stage.gd")
const Terrain := preload("res://src/terrain.gd")
const ExitCharge := preload("res://src/exit_charge.gd")
const RunState := preload("res://src/run_state.gd")

const DT := 1.0 / 90.0
const OUTSIDE := ExitCharge.RADIUS + 20.0

var _stage
var _placed := false


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


# Driven by physics ticks, not idle frames. The rigid ball's reset only queues a
# transform that lands on the next physics tick, and how many ticks fall between
# two idle frames depends on wall-clock time: on a loaded machine the ball could
# still read at the spawn, 104 m away.
func _physics_process(_delta: float) -> bool:
	if not _placed:
		if _stage.player == null:
			return false
		_placed = true
		_stage.director.paused = true
		# Inside the 30 m charge zone but clear of the gate ring, so the run does
		# not end the instant the charge completes.
		_stage.player.reset_to(Terrain.at(Terrain.PUMP_HOUSE + Vector2(0.0, 30.0), 2.0))
		return false

	var terminal = _stage.exit_terminal
	var ball: Vector3 = _stage.player.ball_position()
	var distance: float = Vector2(ball.x, ball.z).distance_to(
		Vector2(terminal.global_position.x, terminal.global_position.z))
	var in_zone: bool = terminal.charge.in_zone(distance)

	terminal.interact(_stage.run)
	var began: bool = terminal.charge.phase == ExitCharge.CHARGING
	var boss_spawned: bool = _stage.enemy_count() > 0

	# Stepping with the ball out of the zone must not bank any progress.
	for i in int(5.0 / DT):
		terminal.charge.advance(DT, OUTSIDE)
	var banked: float = terminal.charge.progress
	var stalled: bool = banked == 0.0

	var elapsed := 0.0
	for i in int((ExitCharge.DURATION + 5.0) / DT):
		elapsed += DT
		terminal.step(DT, _stage.player.ball_position())
	var ready: bool = terminal.charge.phase == ExitCharge.READY

	print("exit: ball %.1f m from the terminal, inside the %d m zone -> %s"
		% [distance, int(ExitCharge.RADIUS), "PASS" if in_zone else "FAIL"])
	print("exit: E started the charge -> %s" % ["PASS" if began else "FAIL"])
	print("exit: the charge spiked the director and spawned %d enemy(s) -> %s"
		% [_stage.enemy_count(), "PASS" if boss_spawned else "FAIL"])
	print("exit: 5 s stepped from %.0f m away banked %.2f s of charge -> %s"
		% [OUTSIDE, banked, "PASS" if stalled else "FAIL"])
	print("exit: holding in the zone for %.0f s reached %d%% -> %s"
		% [elapsed, int(terminal.charge.fraction() * 100.0), "PASS" if ready else "FAIL"])

	var ok := in_zone and began and boss_spawned and stalled and ready
	print("exit_test: %s" % ("PASS" if ok else "FAILED"))
	_stage.free()
	quit(0 if ok else 1)
	return true
