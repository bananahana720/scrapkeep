extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# prompts_shown counts rising edges of a key prompt being drawn (key_glyphs.gd emits
# events.prompt_shown, run_log.gd counts it). Pass: every label prints PASS, exit 0.

var _game
var _failures := 0
var _wait := 0
var _started := false
var _emitted := 0
var _base := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _view(on: Array, at: Vector3) -> Dictionary:
	var ready := {"harpoon": false, "haul": false, "boost": false, "interact": false, "jump": false}
	var points := {}
	for verb in on:
		ready[verb] = true
		points[verb] = at
	return {"ready": ready, "line": "", "charging": false, "mounted": false, "airborne": false, "winching": false, "points": points}


func _count() -> int:
	return int(_game.run_log._record.get("prompts_shown", -1)) - _base


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.events.prompt_shown.connect(func(_verb: String): _emitted += 1)
		# (f) nothing counts before a run has started
		_game.events.prompt_shown.emit("harpoon")
		_report("no run, no count", _game.run_log._record.is_empty(), "record empty, handler ignored the emit")
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 3:
		return false
	var glyphs = _game.hud.key_glyphs
	var cam = _game.camera.cam
	var at: Vector3 = cam.project_position(cam.get_viewport().get_visible_rect().size / 2.0, 5.0)
	glyphs.set_process(false)
	glyphs.set_physics_process(false)
	glyphs.new_run()
	_base = int(_game.run_log._record.get("prompts_shown", -1))
	_report("run record carries the field", _base >= 0, "prompts_shown %d before the test takes over the prompts" % _base)
	_emitted = 0
	glyphs.step(0.016, _view(["harpoon"], at))
	_report("(a) first draw", _emitted == 1 and _count() == 1, "emitted %d, prompts_shown %d" % [_emitted, _count()])
	for i in 30:
		glyphs.step(0.016, _view(["harpoon"], at))
	_report("(b) held drawn", _emitted == 1 and _count() == 1, "emitted %d, prompts_shown %d after 30 more steps" % [_emitted, _count()])
	glyphs.step(0.016, _view([], at))
	glyphs.step(0.016, _view(["harpoon"], at))
	_report("(c) hide then show", _emitted == 2 and _count() == 2, "emitted %d, prompts_shown %d" % [_emitted, _count()])
	glyphs.step(0.016, _view(["harpoon", "boost"], at))
	_report("(d) second verb joins", _emitted == 3 and _count() == 3, "emitted %d, prompts_shown %d" % [_emitted, _count()])
	glyphs.step(0.016, _view([], at))
	glyphs.step(0.016, _view(["harpoon", "boost"], at))
	_report("(d) two verbs in one frame", _emitted == 5 and _count() == 5, "emitted %d, prompts_shown %d" % [_emitted, _count()])
	glyphs.new_run()
	glyphs.step(0.016, _view(["harpoon"], at))
	_report("(e) new_run resets edges", _emitted == 6 and _count() == 6, "emitted %d, prompts_shown %d" % [_emitted, _count()])
	_game.run_log._in_arena = true
	glyphs.step(0.016, _view([], at))
	glyphs.step(0.016, _view(["harpoon"], at))
	_report("(f) arena does not count", _emitted == 7 and _count() == 6, "emitted %d, prompts_shown %d" % [_emitted, _count()])
	print("prompt_shown_count_test: %s" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures])
	quit(1 if _failures > 0 else 0)
	return true
