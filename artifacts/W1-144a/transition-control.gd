extends SceneTree

const Game := preload("res://src/game.gd")
var game
var inject := OS.get_environment("W144_DELAY") == "1"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(1)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	for i in 30:
		await physics_frame
	game.flow.choose_class(1)
	for i in 90:
		await physics_frame
	game.events.stage_entered.connect(on_entry)
	game.events.boss_arena_entered.connect(on_bowl)
	var t := Time.get_ticks_usec()
	game.flow.enter_stage(2, Vector3.ZERO, false)
	report("dam-to-flume", t)
	for i in 90:
		await physics_frame
	t = Time.get_ticks_usec()
	game.flow.enter_boss(Vector3.FORWARD * 18)
	report("flume-to-bowl", t)
	for i in 30:
		await physics_frame
	game.free()
	quit()

func on_entry(stage: int, _retry: bool) -> void:
	if stage == 2:
		delay()

func on_bowl() -> void:
	delay()

func delay() -> void:
	if inject:
		var t := Time.get_ticks_usec()
		OS.delay_msec(50)
		print("W144_SLEEP_US ", Time.get_ticks_usec() - t)

func report(seam: String, t: int) -> void:
	print("W144_ENTRY ", seam, " planted=", inject, " cpu_call_ms=", (Time.get_ticks_usec() - t) / 1000.0)
