extends SceneTree

# Rule: each entered stage consumes its structure row, each world announces once,
# and only built boss rows interrupt progression before the run ends won.
# Drive flow's finish step and boss defeat seams, not traversal or combat acceptance.
# Director event_mix/scrap_density omissions are reported as gaps, not failing rules.

const Game := preload("res://src/game.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Worlds := preload("res://src/core/worlds.gd")
const TICK_LIMIT := 1200

class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld

var _game
var _scenario := 0
var _started := false
var _done := false
var _ticks := 0
var _failures := 0
var _worlds: Array[int] = []
var _stages: Array[int] = []
var _arenas: Array[int] = []
var _order: Array[String] = []
var _checked := 0
var _ended := false
var _won := false
var _gaps := {}


func _initialize() -> void:
	# Game.test_mode owns this process's subfolder and removes it on exit.
	# Clear it before boot as well, so no prior profile can affect the run.
	var path := "user://test-%d" % OS.get_process_id()
	var dir := DirAccess.open(path)
	if dir != null:
		for file in dir.get_files():
			_report("storage cleared", dir.remove(file) == OK, file)
	# The flow is pinned with a smash-per-frame fight, not the fight's length: the PHASE_MIN_SECONDS hold
	# (waking.gd, mind.gd; tests/boss_phase_hold_test.gd) is multiplied out so each Warden falls inside TICK_LIMIT.
	ChallengeDials.set_overrides({"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0], "mind.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]})
	_boot()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _label() -> String:
	return ["two-world built", "two-world unbuilt", "alpha"][_scenario]


func _table():
	return AlphaDefs if _scenario == 2 else TwoWorld


func _boot() -> void:
	_game = Game.new() if _scenario == 2 else TwoWorldGame.new()
	_game.test_mode = true
	if _scenario == 2:
		_game.table = "alpha"
	root.add_child(_game)
	_started = false
	_ticks = 0
	_worlds = []
	_stages = []
	_arenas = []
	_order = []
	_checked = 0
	_ended = false
	_won = false


func _start() -> void:
	_started = true
	var bus = _game.events
	bus.world_entered.connect(func(world: int):
		_worlds.append(world)
		_order.append("world %d" % world))
	bus.stage_entered.connect(func(stage: int, _retry: bool):
		_stages.append(stage)
		_order.append("stage %d" % stage))
	bus.boss_arena_entered.connect(func():
		var world: int = _game.ctx.stages.world_of(_game.run.stage)
		_arenas.append(world)
		_order.append("boss %d" % world))
	bus.run_ended.connect(func(won: bool):
		_ended = true
		_won = won)
	if _scenario == 1:
		var unbuilt: Dictionary = Worlds.boss_of(2).duplicate()
		unbuilt["built"] = false
		_game.flow.boss_row_override[2] = unbuilt
		_report("unbuilt row selected", not _game.flow.boss_row(2)["built"], "world two built:false")
	_game.ctx.calm = true
	# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This test ends on the summary.
	_game.flow.victory_lap = false
	_game.flow.press_start()
	_game.flow.choose_class(0)


func _check_stage(stage: int) -> void:
	var row: Dictionary = _table().of(stage)
	var label := "%s stage %d" % [_label(), stage]
	_report(label + " flow row", _game.flow.stage_def() == row, "selected table row")
	var audio = _game.presentation.audio
	var music: Dictionary = row["music"]
	# 2026-10-04 (fix round D): since C8b, audio._music_row returns music_rows' resolved pack
	# {synth_theme, ace_manifest}, not the row's {theme, ace}; compare the row through it.
	var pack: Dictionary = audio._music_row(stage)
	var manifest: String = pack["ace_manifest"]
	var pack_ace: String = manifest.get_base_dir().get_file() if manifest != "" else ""
	_report(label + " music row", pack["synth_theme"] == music["theme"] and pack_ace == music["ace"],
		"%s resolves to %s" % [music, pack])
	_report(label + " music id", audio._ace_package_for(stage) == music["ace"],
		"ACE '%s', synth theme %d" % [audio._ace_package_for(stage), audio._stage_theme(stage)])
	_report(label + " music theme", audio._stage_theme(stage) == music["theme"], str(music["theme"]))
	var family: String = _game.combat.warden_spec(stage)["family"]
	_report(label + " Warden family", family == row["warden_family"], family)
	var director = _game.world.director
	_report(label + " director use_row", director._row.has("unlock_base")
		and director._row.has("ancient"), str(director._row))
	_report(label + " director unlock", director._unlock_base() == row["unlock_base"], str(director._unlock_base()))
	_report(label + " director ancient", director._ancient() == row["ancient"], director._ancient())
	_report(label + " director threat", is_equal_approx(director.threat, row["threat"]), str(director.threat))
	for key in ["event_mix", "scrap_density"]:
		if row.has(key) and not director._row.has(key):
			if not _gaps.has(key):
				_gaps[key] = []
			_gaps[key].append(label)
	_checked += 1


func _fight() -> void:
	var module = _game.flow._boss_module()
	if module == _game.boss:
		module._defeat("ram", _game.player.ball_position())
		return
	# The built world-two row selects the real stub module. Break its posture body
	# through its hit seam; the module emits the boss defeat, then flow advances.
	var warden = module.warden
	if not is_instance_valid(warden) or warden.is_dead():
		return
	var result: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
	warden.on_struck("slam", String(result.get("part", "")), result)
	if bool(result.get("shatter", false)):
		warden.take_damage(float(result.get("dealt", 0.0)))


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_report(_label() + " frame limit", false, "state %s stage %d" % [_game.flow.state_name(), _game.run.stage])
		return _finish()
	if not _started:
		if _game.flow != null:
			_start()
		return false
	if _ended:
		return _conclude_run()
	if _game.flow.in_stage():
		var stage: int = _game.run.stage
		_check_stage(stage)
		_game.flow._finish_stage()
	elif _game.flow.state_name() == "boss":
		_fight()
	return false


func _conclude_run() -> bool:
	var expected_stages: Array[int] = []
	var expected_arenas: Array[int] = []
	var expected_order: Array[String] = []
	var table = _table()
	for world in table.worlds():
		expected_order.append("world %d" % world)
		for stage in range(table.first_of(world), table.last_of(world) + 1):
			expected_stages.append(stage)
			expected_order.append("stage %d" % stage)
		if not (_scenario == 1 and world == 2):
			expected_arenas.append(world)
			expected_order.append("boss %d" % world)
	_report(_label() + " world_entered once", _worlds == table.worlds(), str(_worlds))
	_report(_label() + " every stage entered", _stages == expected_stages, str(_stages))
	_report(_label() + " every stage checked", _checked == table.COUNT, str(_checked))
	_report(_label() + " built bosses only", _arenas == expected_arenas, str(_arenas))
	_report(_label() + " transition order", _order == expected_order, " > ".join(_order))
	var skips: Array = _game.flow._warned.keys().filter(func(key): return str(key).begins_with("boss_unbuilt_"))
	_report(_label() + " boss_row skip", skips == (["boss_unbuilt_2"] if _scenario == 1 else []), str(skips))
	_report(_label() + " run won", _ended and _won and _game.flow.state_name() == "summary", _game.flow.state_name())
	_game.free()
	_game = null
	_scenario += 1
	if _scenario == 3:
		return _finish()
	_boot()
	return false


func _finish() -> bool:
	for key in _gaps:
		var consumer := "world EventDirector" if key == "event_mix" else "build scrap.lay_out"
		print("GAP director.use_row: %s not retained/read in %d stage checks; current consumer: %s" % [key, _gaps[key].size(), consumer])
	if is_instance_valid(_game):
		_game.free()
	_done = true
	print("structure_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
