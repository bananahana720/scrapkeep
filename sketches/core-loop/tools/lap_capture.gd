extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")


const SHOTS := [
	{"name": "01-drop-in", "at": 0.6},
	{"name": "02-down-the-wall", "at": 4.0},
	{"name": "03-vent-shot", "vent": 1, "after": 0.7},
	{"name": "04-crew-log", "at": 20.5},
	{"name": "05-the-sad-part", "at": 51.0},
	{"name": "06-countdown", "at": 57.6},
]
const CREDITS_AT := 5.0

var _out := ""
var _game
var _driver
var _phase := "boot"
var _lap_clock := 0.0
var _credits_clock := 0.0
var _taken: Array = []
var _vent_seen_at := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out == "":
		push_error("lap_capture: pass --out=<absolute dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1600, 900)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	match _phase:
		"boot":
			_driver = BotDriver.new(_game, "skipper", 1)
			_driver.start()
			_phase = "start"
		"start":
			if _game.flow.state_name() == "stage" and _game.run.stage == 1:
				_game.flow.enter_stage(StageDefs.COUNT, Vector3(0.0, 0.0, 14.0), false)
				_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
				_game.events.boss_defeated.emit()
				_phase = "victory"
			else:
				_driver.tick(delta)
		"victory":
			if _game.flow.state_name() == "lap":
				_game.bot_driven = false
				_phase = "lap"
		"lap":
			if _game.flow.state_name() != "lap":
				_phase = "credits"
				return false
			_lap_clock += delta
			_driver._lap_roll()
			var lap = _game.flow.lap
			if _vent_seen_at < 0.0 and int(lap.vent_shots) >= 1:
				_vent_seen_at = _lap_clock
			for shot in SHOTS:
				if _taken.has(shot["name"]):
					continue
				var due: bool = shot.has("at") and _lap_clock >= float(shot["at"])
				due = due or (shot.has("vent") and _vent_seen_at >= 0.0 and _lap_clock >= _vent_seen_at + float(shot["after"]))
				if due:
					_taken.append(shot["name"])
					_save(shot["name"])
		"credits":
			var seq = _game.screens.ending_sequence
			var rolled: float = seq.elapsed - seq.WORLD_SECONDS * 3.0 if is_instance_valid(seq) else INF
			if rolled >= CREDITS_AT:
				_credits_clock = CREDITS_AT
				_save("07-credits-over-the-bowl")
				_phase = "closing"
		"closing":
			_credits_clock += delta
			if _credits_clock >= CREDITS_AT + 0.5:
				_phase = "done"
				_game.free()
				quit(0)
	return false


func _save(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot + ".png")
	image.save_png(path)
	print("lap_capture: %s" % path)
