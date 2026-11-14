extends SceneTree

const Game := preload("res://src/game.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# The telegraph row and the painter agree (every look but classic draws the haze fill). A repeated --telegraph flag resolves to its last
# value in both (checked in child processes, which see real command-line args); the row
# takes effect at the next hold-R, as the panel says; Threat.set_haze() still overrides
# for tests and tools.

var _failures := 0


func _initialize() -> void:
	if "--child" in OS.get_cmdline_user_args():
		var t := Tuning.new()
		t.apply_cmdline("launch")
		print("CHILD painter=%s tuning=%s" % [Threat.haze(), t.option("telegraph")])
		quit(0)
		return
	for flags in [["--telegraph=haze", "--telegraph=classic"], ["--telegraph=classic", "--telegraph=haze"], ["--telegraph=haze"], []]:
		_child(flags)
	_row.call_deferred()


func _child(flags: Array) -> void:
	var out := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/telegraph_haze_test.gd", "--", "--child"]
	args.append_array(flags)
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	var line := ""
	for text in out:
		for row in String(text).split("\n"):
			if row.begins_with("CHILD "):
				line = row
	var fields := line.split(" ")
	var ok: bool = code == 0 and fields.size() == 3 and fields[1].trim_prefix("painter=") == str(fields[2].trim_prefix("tuning=") != "classic")
	_check("args %s" % [flags], ok, "%s (exit %d)" % [line, code])


func _row() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 10:
		await physics_frame
	Threat.set_haze(false)
	game.tuning.set_option("telegraph", "haze")
	_check("not live", not Threat.haze(), "a panel edit does not change the painter mid-stage")
	game.flow.retry_stage()
	for i in 3:
		await physics_frame
	_check("row at hold-R", Threat.haze(), "after hold-R the painter follows the haze row")
	game.tuning.set_option("telegraph", "classic")
	game.flow.retry_stage()
	for i in 3:
		await physics_frame
	_check("row back", not Threat.haze(), "and the classic row")
	Threat.set_haze(true)
	_check("override", Threat.haze(), "set_haze(true) still overrides between stage entries")
	Threat.set_haze(false)
	game.free()
	print("telegraph_haze_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
