extends SceneTree

# Rule: the mix is rows (mix_rows.gd) and the audio director reads them. The buses and the
# master chain exist with a ceiling under -1 dB, each game state resolves to its snapshot, the
# levels glide (down fast, up slow), a telegraph pulls the music and the ambience down and is
# never quieted by the crowd rule, and stacked low-priority voices step down per doubling.
const Game := preload("res://src/game.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")

var _game
var _done := false
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null or _game.presentation == null:
		return false
	_done = true
	_rows()
	_buses()
	_states()
	_glide_and_focus()
	_game.free()
	print("mix_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return false


func _rows() -> void:
	_check("every state names known buses", MixRows.STATES.values().all(func(row: Dictionary): return row.keys().all(func(bus): return MixRows.BUS_DB.has(bus))))
	_check("no state lifts a bus over its row", MixRows.STATES.values().all(func(row: Dictionary): return row.values().all(func(v): return float(v) <= 0.0)))
	_check("a fight is never quieter than roaming", MixRows.state_db("miniboss", "Music") >= MixRows.state_db("roam", "Music") and MixRows.state_db("boss_3", "Music") >= MixRows.state_db("boss_1", "Music"))
	_check("telegraphs are crowd-exempt", MixRows.crowd_db(64, 2) == 0.0 and MixRows.crowd_db(64, 3) == 0.0)
	_check("free voices are untouched", MixRows.crowd_db(MixRows.CROWD_FREE, 0) == 0.0)
	_check("a doubling over free costs its step", is_equal_approx(MixRows.crowd_db(MixRows.CROWD_FREE * 2, 0), -MixRows.CROWD_DB_PER_DOUBLING))
	_check("the crowd floor holds", MixRows.crowd_db(10000, 1) == MixRows.CROWD_FLOOR_DB)
	_check("the master ceiling leaves true-peak headroom", MixRows.MASTER_CEILING_DB <= -1.0)
	_check("the hysteresis has a gap", MixRows.COMBAT_OFF < MixRows.COMBAT_ON)


func _buses() -> void:
	for bus in MixRows.BUS_DB:
		_check("bus %s exists" % bus, AudioServer.get_bus_index(bus) >= 0)
	var master := AudioServer.get_bus_index("Master")
	var count := AudioServer.get_bus_effect_count(master)
	var last = AudioServer.get_bus_effect(master, count - 1) if count > 0 else null
	_check("master ends on its ceiling", last is AudioEffectHardLimiter and is_equal_approx(last.ceiling_db, MixRows.MASTER_CEILING_DB), "effects %d" % count)
	_check("master compresses first", count >= 2 and AudioServer.get_bus_effect(master, 0) is AudioEffectCompressor)
	var sfx := AudioServer.get_bus_index("SFX")
	_check("effects bus glues then limits", AudioServer.get_bus_effect_count(sfx) == 2 and AudioServer.get_bus_effect(sfx, 0) is AudioEffectCompressor)


func _states() -> void:
	var cases := [
		[["title", false, "level", 1, false, false], "menu"],
		[["title", true, "level", 1, false, false], "camp"],
		[["stage", false, "level", 1, false, false], "roam"],
		[["stage", false, "level", 1, false, true], "combat"],
		[["stage", false, "level", 1, true, true], "shop"],
		[["stage", false, "warden", 1, false, false], "miniboss"],
		[["stage", false, "miniboss", 1, true, false], "miniboss"],
		[["boss", false, "level", 2, false, false], "boss_2"],
		[["stage", false, "brindle", 3, false, false], "boss_3"],
		[["boss", false, "brindle", 9, false, false], "boss_3"],
		[["summary", false, "level", 1, false, false], "run_over"],
		[["dead", false, "brindle", 2, false, false], "run_over"],
	]
	for case in cases:
		var got: String = MixRows.resolve.callv(case[0])
		_check("state %s" % [case[0]], got == case[1], got)
	var audio = _game.presentation.audio
	audio._flow_state = "stage"
	audio._pressure = 0.5
	_check("pressure starts a fight", audio.mix_state() == "combat")
	audio._pressure = 0.3
	_check("a fight holds inside the hysteresis", audio.mix_state() == "combat")
	audio._pressure = 0.1
	_check("calm ends it", audio.mix_state() == "roam")


func _glide_and_focus() -> void:
	var audio = _game.presentation.audio
	audio._flow_state = "stage"
	audio._pressure = 0.0
	audio._focus_until = -1.0
	audio._tend_mix(10.0)
	var roam := MixRows.state_db("roam", "Music")
	_check("roam settles at its row", is_equal_approx(audio.mix_db["Music"], roam), str(audio.mix_db))
	audio._focus()
	audio._tend_mix(0.05)
	var down: float = audio.mix_db["Music"]
	var deep: float = roam + MixRows.FOCUS["Music"]
	_check("focus moves the music down fast", is_equal_approx(down, maxf(deep, roam - MixRows.GLIDE_DOWN_DB_S * 0.05)), str(down))
	audio._tend_mix(0.3)
	_check("focus reaches its depth", is_equal_approx(audio.mix_db["Music"], deep) and is_equal_approx(audio.mix_db["Ambient"], MixRows.FOCUS["Ambient"]), str(audio.mix_db))
	audio._focus_until = -1.0
	audio._tend_mix(0.1)
	_check("the way back up is slow", is_equal_approx(audio.mix_db["Music"], deep + MixRows.GLIDE_UP_DB_S * 0.1), str(audio.mix_db["Music"]))
	audio._flow_state = "summary"
	audio._tend_mix(10.0)
	var sfx := AudioServer.get_bus_index("SFX")
	var want := db_to_linear(MixRows.BUS_DB["SFX"] + MixRows.STATES["run_over"]["SFX"]) * float(audio.volumes["SFX"])
	_check("the snapshot reaches the bus", absf(AudioServer.get_bus_volume_linear(sfx) - want) < 0.001, "%f vs %f" % [AudioServer.get_bus_volume_linear(sfx), want])
	var amb := AudioServer.get_bus_index("Ambient")
	audio.muted = true
	audio._apply_volumes()
	_check("mute covers the ambience", AudioServer.is_bus_mute(amb))
	audio.muted = false
	audio._apply_volumes()
