extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Combat := preload("res://src/combat/combat.gd")
const Route := preload("res://tests/doubles/world_one_mass_route.gd")

# Mass-R (BUILD-SYSTEMS.md, Rivet row): at mass 0, 450 and 990, the same speed, a sprint ram
# and a ground smash deal damage that rises once with heft, the formula already in
# combat.gd punch_of(), and turning is identical. A second mass multiplier shows as damage
# above (base + force * k) * heft * knob. The flag changes nothing here: the rows with
# --world-one-builds on and off must be identical.
#
# Evidence limit: contacts are called on the real combat with a bare target, and the turn is
# 30 physics frames on the spawn terrain; nothing here says a heavy ram feels like weight.

var _game
var _failures := 0
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _started or _game.flow == null:
		return false
	_started = true
	_run()
	return false


func _rows() -> Array:
	var route := Route.new()
	var rows: Array = []
	for m in Route.MASSES:
		rows.append(await route.measure(_game, m))
	return rows


func _run() -> void:
	_game.ctx.calm = true
	# A hit stop slows Engine.time_scale for wall time and starts only when the previous one has
	# ended, so which turn windows it lands in depends on CPU speed; measure without stops.
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	_game.flow.press_start()
	_game.flow.choose_class(Route.CLASS_INDEX)
	_game.run.set_max_hp(99999.0)
	var parts_heft: float = _game.run.heft() - 1.0  # zero parts at run start: guards the formula below
	var knob: float = float(_game.player.tree.knob("sprint_punch"))
	var ram_row: Array = Combat.STRIKE_DAMAGE["ram"]
	var slam_row: Array = Combat.STRIKE_DAMAGE["slam"]

	_game.ctx.tuning.set_option("world_one_builds", "on")
	var on_rows: Array = await _rows()
	_game.ctx.tuning.set_option("world_one_builds", "off")
	var off_rows: Array = await _rows()

	for r in on_rows:
		var heft := 1.0 + float(r["mass"]) / 450.0 + parts_heft
		var want_ram: float = (ram_row[0] + Route.SPEED * ram_row[1]) * heft * knob
		var want_smash: float = (slam_row[0] + Route.SPEED * slam_row[1]) * heft
		_report("heft once at mass %.0f" % r["mass"],
			absf(r["heft"] - heft) < 0.0001 and absf(r["ram_dealt"] - want_ram) < 0.01
			and absf(r["ram_delivered"] - want_ram) < 0.01 and absf(r["smash_dealt"] - want_smash) < 0.01,
			"heft %.3f: ram %.2f (want %.2f, delivered %.2f), smash %.2f (want %.2f)"
				% [r["heft"], r["ram_dealt"], want_ram, r["ram_delivered"], r["smash_dealt"], want_smash])

	var base: Dictionary = on_rows[0]
	var top: Dictionary = on_rows[2]
	var ratio: float = top["heft"] / base["heft"]
	_report("damage rises with mass",
		on_rows[0]["ram_dealt"] < on_rows[1]["ram_dealt"] and on_rows[1]["ram_dealt"] < on_rows[2]["ram_dealt"]
		and on_rows[0]["smash_dealt"] < on_rows[1]["smash_dealt"] and on_rows[1]["smash_dealt"] < on_rows[2]["smash_dealt"],
		"ram %.1f / %.1f / %.1f, smash %.1f / %.1f / %.1f" % [on_rows[0]["ram_dealt"], on_rows[1]["ram_dealt"], on_rows[2]["ram_dealt"],
			on_rows[0]["smash_dealt"], on_rows[1]["smash_dealt"], on_rows[2]["smash_dealt"]])
	_report("not squared",
		absf(top["ram_dealt"] / base["ram_dealt"] - ratio) < 0.001 and absf(top["smash_dealt"] / base["smash_dealt"] - ratio) < 0.001,
		"mass 990 over mass 0: heft x%.3f, ram x%.3f, smash x%.3f (squared would be x%.3f)"
			% [ratio, top["ram_dealt"] / base["ram_dealt"], top["smash_dealt"] / base["smash_dealt"], ratio * ratio])

	var spread := 0.0
	for r in on_rows:
		spread = maxf(spread, absf(r["heading"] - base["heading"]))
	_report("turning identical", spread < 0.0001 and absf(base["heading"]) > 0.02,
		"heading after %d frames of side input: %.4f / %.4f / %.4f rad (spread %.6f)"
			% [Route.TURN_FRAMES, on_rows[0]["heading"], on_rows[1]["heading"], on_rows[2]["heading"], spread])

	var same := true
	# 2026-10-04: name the first differing row and key, so a rare gate red carries its cause.
	var first_diff := ""
	for i in on_rows.size():
		for key in ["heft", "ram_dealt", "ram_delivered", "smash_dealt", "heading"]:
			if absf(on_rows[i][key] - off_rows[i][key]) > 0.0001:
				same = false
				if first_diff == "":
					first_diff = " (row %d %s: on %.4f, off %.4f)" % [i, key, on_rows[i][key], off_rows[i][key]]
	_report("flag off matches", same, "rows with --world-one-builds on and off are identical: %s%s" % [same, first_diff])

	print("world_one_mass_r_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
