extends SceneTree

const Game := preload("res://src/game.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")
const RunLog := preload("res://src/core/run_log.gd")

# The v3 fun lab's switch (LOOP-REDESIGN section 7): one loop_mode and one gun_role in
# tuning, set by the launcher flag, the title row's L and G (keys and buttons) and the
# panel; the run log carries both; the Spillway's return lift and drop lips stand only
# in a loop mode, so v2 plays the stage it always did.

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0


func _initialize() -> void:
	var t := Tuning.new()
	_check("defaults", LoopMode.mode(t) == "v2" and LoopMode.gun_role(t) == "hold", "%s / %s" % [LoopMode.mode(t), LoopMode.gun_role(t)])
	var applied := LoopMode.apply_args(t, PackedStringArray(["--path", "x", "--loop=drop", "--gun=full", "--out=y", "--loop=nope"]))
	_check("flags", LoopMode.mode(t) == "drop" and LoopMode.gun_role(t) == "full" and applied.size() == 2,
		"--loop=drop --gun=full applied %s; an unknown value is refused" % [applied])
	_check("cycle", LoopMode.cycle(t, LoopMode.LOOP_KEY) == "laps" and LoopMode.cycle(t, LoopMode.LOOP_KEY) == "v2"
		and LoopMode.cycle(t, LoopMode.GUN_KEY) == "hold", "L cycles v2, drop, laps; G flips hold and full")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			var loop_button: Button = _game.screens.button_for("loop")
			var gun_button: Button = _game.screens.button_for("gun")
			_check("title row", loop_button != null and gun_button != null and loop_button.text == "Loop: v2" and gun_button.text == "Gun: hold",
				"title buttons read '%s' and '%s'" % [loop_button.text if loop_button else "?", gun_button.text if gun_button else "?"])
			_game._screen_key(KEY_L)
			gun_button.pressed.emit()
			_check("title keys", LoopMode.mode(_game.tuning) == "drop" and LoopMode.gun_role(_game.tuning) == "full"
				and loop_button.text == "Loop: drop" and gun_button.text == "Gun: full",
				"L key then a G click: %s, %s" % [loop_button.text, gun_button.text])
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_phase = "drop"
			_wait = 0
		"drop":
			if _wait < 5:
				return false
			var m = _game.ctx.terrain.map()
			var lip: Vector2 = m.drop_lines[0]["at"]
			var raised: float = _game.ctx.terrain.height(lip.x, lip.y) - m.beacon_floor
			_check("loop live in drop", m.loop_live and _game.world.contraptions[1].live and raised > 1.5,
				"lips swapped in (%.1f m over the floor at the west lip), return lift live %s" % [raised, _game.world.contraptions[1].live])
			var tag: Dictionary = _game.run_log._stage(1)
			_check("run log tag", _game.run_log._record.get("loop_mode") == "drop" and tag.get("gun_role") == "full",
				"run %s / %s, stage 1 %s / %s" % [_game.run_log._record.get("loop_mode"), _game.run_log._record.get("gun_role"),
					tag.get("loop_mode"), tag.get("gun_role")])
			_game.tuning.set_option("loop_mode", "v2")
			_game.flow.retry_stage()
			_phase = "v2"
			_wait = 0
		"v2":
			if _wait < 5:
				return false
			var m = _game.ctx.terrain.map()
			var lip: Vector2 = m.drop_lines[0]["at"]
			var raised: float = _game.ctx.terrain.height(lip.x, lip.y) - m.beacon_floor
			_check("v2 untouched", not m.loop_live and not _game.world.contraptions[1].live and not _game.world.contraptions[1].visible
				and absf(raised) < 0.01 and _game.run_log._stage(1).get("loop_mode") == "v2",
				"after a flip to v2 and a retry: lips parked (%.2f m), lift idle and hidden" % raised)
			print("loop_mode_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false
