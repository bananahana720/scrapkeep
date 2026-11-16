extends SceneTree

# Rule: the mix is rows (mix_rows.gd) and the audio director reads them. The buses and the
# master chain exist with a ceiling under -1 dB, each game state resolves to its snapshot, the
# levels glide (down fast, up slow), a telegraph pulls the music and the ambience down and is
# never quieted by the crowd rule, stacked low-priority voices step down per doubling, and the
# hurt cue makes room: every other effect but a warning steps down while it sounds.
const Game := preload("res://src/game.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

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
	_make_room()
	_whoosh_room()
	_game.free()
	print("mix_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return false


func _rows() -> void:
	_check("every state names known buses", MixRows.STATES.values().all(func(row: Dictionary): return row.keys().all(func(bus): return MixRows.BUS_DB.has(bus))))
	_check("no state lifts a bus over its row", MixRows.STATES.values().all(func(row: Dictionary): return row.values().all(func(v): return float(v) <= 0.0)))
	_check("a fight is never quieter than roaming", MixRows.state_db("miniboss", "Music") >= MixRows.state_db("roam", "Music") and MixRows.state_db("boss_3", "Music") >= MixRows.state_db("boss_1", "Music"))
	_check("telegraphs are crowd-exempt", MixRows.crowd_db(64, 2) == 0.0 and MixRows.crowd_db(64, 3) == 0.0)
	var audio_script := load("res://src/presentation/audio.gd")
	_check("no danger sound is crowd-quieted", MixRows.CROWD_SOUNDS.all(func(sound): return not sound in audio_script.DANGER_SOUNDS))
	_check("ultimates are not crowd-quieted", not "ultimate_land" in MixRows.CROWD_SOUNDS)
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
		[["stage", false, "brindle", 3, false, false], "roam"],
		[["stage", false, "title", 1, false, true], "combat"],
		[["lap", false, "level", 1, false, false], "roam"],
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
	var amb_bus := AudioServer.get_bus_index("Ambient")
	var want := db_to_linear(MixRows.BUS_DB["Ambient"] + MixRows.STATES["run_over"]["Ambient"]) * float(audio.volumes["SFX"])
	_check("the snapshot reaches the bus, ambience on the effects slider", absf(AudioServer.get_bus_volume_linear(amb_bus) - want) < 0.001, "%f vs %f" % [AudioServer.get_bus_volume_linear(amb_bus), want])
	_check("no state moves the stinger lane's bus", MixRows.STATES.values().all(func(row: Dictionary): return not row.has("SFX")))
	_check("a threat row is a telegraph", audio._is_telegraph(EventKinds.THREAT_ROWS.keys()[0], "x"))
	_check("a reward is not", not audio._is_telegraph("shop_bought", "shop_bell"))
	var amb := AudioServer.get_bus_index("Ambient")
	audio.muted = true
	audio._apply_volumes()
	_check("mute covers the ambience", AudioServer.is_bus_mute(amb))
	audio.muted = false
	audio._apply_volumes()


func _make_room() -> void:
	var audio = _game.presentation.audio
	var row: Dictionary = MixRows.MAKE_ROOM["hurt"]
	_check("hurt makes room", float(row["db"]) <= -6.0 and float(row["hold_s"]) >= 0.25, str(row))
	_check("hurt is a warning, so nothing it makes room for can be one", "hurt" in audio.DANGER_SOUNDS)
	audio.sound_ready = true
	audio._last_start.clear()
	audio.cue_log.clear()
	audio.play("player_hit")
	var rooms: Array = audio.cue_log.filter(func(c): return c[2] == "room")
	_check("a hit logs its room", rooms.size() == 1 and rooms[0][1] == "hurt" and is_equal_approx(float(rooms[0][4]), float(row["hold_s"])) and is_equal_approx(float(rooms[0][5]), float(row["db"])), str(audio.cue_log))
	_check("the vent's boom steps under the hit", is_equal_approx(audio._room_offset("reactor_erupt"), float(row["db"])))
	_check("a warning keeps its level", audio._room_offset("threat_hum") == 0.0 and audio._room_offset("boss_telegraph") == 0.0)
	_check("the hit keeps its own level", audio._room_offset("hurt") == 0.0)
	audio.clock += 10.0
	_check("the hold runs on the wall clock, not the audio clock slow motion scales", audio._room_offset("reactor_erupt") != 0.0)
	audio._room_until_ms = 0
	_check("the room ends after its hold", audio._room_offset("reactor_erupt") == 0.0)


# FX-28: the dodge's whoosh ducks the lane attack's tear, and only that, for a short hold.
func _whoosh_room() -> void:
	var audio = _game.presentation.audio
	var has_row: bool = MixRows.MAKE_ROOM.has("near_whoosh")
	_check("near_whoosh has a room row", has_row)
	if not has_row:
		return
	var row: Dictionary = MixRows.MAKE_ROOM.get("near_whoosh", {})
	_check("the whoosh's duck is audible but short", float(row["db"]) <= -6.0 and float(row["hold_s"]) <= 0.35, str(row))
	audio.sound_ready = true
	audio._room_until_ms = 0
	audio._last_start.clear()
	audio.cue_log.clear()
	audio.play("near_miss")
	var rooms: Array = audio.cue_log.filter(func(c): return c[2] == "room")
	_check("a dodge logs its room", rooms.size() == 1 and rooms[0][1] == "near_whoosh" and is_equal_approx(float(rooms[0][5]), float(row["db"])), str(audio.cue_log))
	_check("the room log carries the only list for the mix simulator", rooms[0].size() > 6 and rooms[0][6] == ["threat_tear"], str(rooms))
	_check("the tear steps under the whoosh", is_equal_approx(audio._room_offset("threat_tear"), float(row["db"])), str(audio._room_offset("threat_tear")))
	_check("the other warnings keep their level", audio._room_offset("threat_hum") == 0.0 and audio._room_offset("boss_telegraph") == 0.0 and audio._room_offset("hurt") == 0.0)
	_check("a reward is not ducked by the whoosh", audio._room_offset("shop_bell") == 0.0 and audio._room_offset("crit_ping") == 0.0 and audio._room_offset("chain_step") == 0.0)
	_check("the whoosh keeps its own level", audio._room_offset("near_whoosh") == 0.0)
	audio._room_until_ms = 0
	_check("the tear returns after the hold", audio._room_offset("threat_tear") == 0.0)
	audio._last_start.clear()
	audio.play("player_hit")
	audio._last_start.clear()
	audio.play("near_miss")
	_check("a hit's room is not cut short by a whoosh", audio._room_for == "hurt", audio._room_for)
	audio._room_until_ms = 0
