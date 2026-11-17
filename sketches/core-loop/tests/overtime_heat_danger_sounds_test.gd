extends SceneTree

const T := preload("res://tests/support/t.gd")
const Audio := preload("res://src/presentation/audio.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Redline := preload("res://src/combat/redline.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")

# World 1's overtime, heat and danger cues: each overtime row has a sound of its own, heat's rise,
# cooling and hot hit each sound once per crossing, and every sound that warns of a hit sits in the
# one danger registry (SfxBank.DANGER_SOUNDS). Cue decisions are read from audio.cue_log, so this
# is the director's choice, not a listen.

const OVERTIME_ROWS := ["overtime_offered", "overtime_rung", "overtime_paid"]
const NEW_SOUNDS := ["overtime_offer", "overtime_ring", "overtime_pay", "heat_rise", "heat_cool", "heat_hot_hit"]
# Pressure and charge cues that warn of a hit and are played outside windup_rows.gd.
const OTHER_WARNINGS := ["flank_call", "boil_rumble"]

class FakePlayer:
	extends RefCounted
	var redline

class FakeCtx:
	extends RefCounted
	var events: Node
	var run
	var player


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("overtime_heat_danger_sounds_test")
	_overtime(t)
	_bank(t)
	_danger(t)
	_heat(t)
	quit(t.verdict())


func _overtime(t) -> void:
	var heard := {}
	var others := 0
	for table in [EventKinds.ROWS, EventKinds.WORLD_ROWS]:
		for kind in table:
			if kind in OVERTIME_ROWS:
				continue
			others += 1
			heard[Rows.heard(table[kind])] = true
	t.check("compared against the other rows", others > 100, str(others))
	var own := {}
	var looped := 0
	for kind in OVERTIME_ROWS:
		looped += 1
		var sound := Rows.heard(EventKinds.world_row(kind))
		t.check("%s plays a sound no other row plays" % kind, not heard.has(sound) and not own.has(sound) and sound != "found_chime", sound)
		own[sound] = true
	t.eq("looped over the three overtime rows", looped, 3)
	t.check("overtime sounds are not the arena or gate sounds", not own.has("arena_unlock_bells") and not own.has("warden_gate_pip") and not own.has("warden_gate_release"))


func _bank(t) -> void:
	for id in NEW_SOUNDS:
		var buf := SfxBank.samples(id)
		var peak := 0.0
		for s in buf:
			peak = maxf(peak, absf(s))
		var seconds := buf.size() / float(SfxBank.RATE)
		t.check("recipe " + id, SfxBank.has_recipe(id))
		t.check("%s is not silent and under 1.5 s" % id, peak >= 0.1 and peak <= 0.95 and seconds > 0.1 and seconds < 1.5, "peak %.3f, %.2f s" % [peak, seconds])
		t.check("%s is not the fallback blip" % id, buf.size() != int(0.12 * SfxBank.RATE))
		t.check("level " + id, SfxBank.TRIM_DB.has(id))


func _danger(t) -> void:
	var warns: Array = []
	for kind in WindupRows.ROWS:
		var sound: String = WindupRows.ROWS[kind]["sound"]
		if sound != "none" and not sound in warns:
			warns.append(sound)
	for sound in OTHER_WARNINGS:
		warns.append(sound)
	warns.append(EventKinds.ROWS["vent_charging"]["sound"])
	t.check("the warning list is not empty", warns.size() >= 10, str(warns.size()))
	for sound in warns:
		t.check("%s warns of a hit and is a danger sound" % sound, sound in SfxBank.DANGER_SOUNDS or _in_threat_rows(sound))


func _in_threat_rows(sound: String) -> bool:
	for kind in EventKinds.THREAT_ROWS:
		if EventKinds.THREAT_ROWS[kind]["sound"] == sound:
			return true
	return false


func _rig(redline) -> Dictionary:
	var events := GameEvents.new()
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").new())
	var player := FakePlayer.new()
	player.redline = redline
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.run = run
	ctx.player = player
	var audio := Audio.new()
	audio.setup(ctx)
	audio.bake_now()
	audio.cue_log.clear()
	return {"audio": audio, "events": events}


# The sounds one step played: the per-sound gap runs on real time, so it is cleared first.
func _played(audio, action: Callable) -> Array:
	audio._last_start.clear()
	audio.cue_log.clear()
	action.call()
	audio._tend_heat()
	var out := []
	for cue in audio.cue_log:
		if cue[2] == "now" and String(cue[1]).begins_with("heat_"):
			out.append(cue[1])
	return out


func _heat(t) -> void:
	var redline := Redline.new()
	redline.mode = Redline.ON
	var rig := _rig(redline)
	var audio = rig["audio"]
	# Climb in steps of 5: nothing sounds until the value passes HOT_AT, then heat_rise once.
	var rises := 0
	var quiet := true
	for i in 12:
		var played := _played(audio, func(): redline._set_value(redline.value + 5.0))
		if redline.value < Redline.HOT_AT:
			quiet = quiet and played.is_empty()
		elif played.has("heat_rise"):
			rises += 1
	t.check("climbing below the hot line is quiet", quiet)
	t.eq("heat_rise sounds once for the crossing", rises, 1)
	t.check("the shell is hot after the climb", redline.hot(), str(redline.value))
	t.eq("a frame above the hot line adds nothing", _played(audio, func(): redline._set_value(redline.value + 1.0)), [])
	# A hit while hot.
	t.eq("a hit while hot plays heat_hot_hit", _played(audio, func(): redline.note_hit()), ["heat_hot_hit"])
	t.eq("the next frame with no new hit is silent", _played(audio, func(): pass), [])
	# Cooling back under the line.
	t.eq("falling under the hot line plays heat_cool", _played(audio, func(): redline._set_value(Redline.HOT_AT - 1.0)), ["heat_cool"])
	t.eq("staying cool is silent", _played(audio, func(): redline._set_value(Redline.HOT_AT - 6.0)), [])
	t.eq("a hit while cool plays nothing", _played(audio, func(): redline.note_hit()), [])
	# A blast empties a redline shell: it has its own crack, so no cooling sound.
	_played(audio, func(): redline._set_value(Redline.MAX))
	var blasts: int = redline.detonations
	var blast := _played(audio, func(): redline.spend("ram", Vector3.ZERO, 5.0))
	t.eq("the ram blasted the shell", redline.detonations, blasts + 1)
	t.check("a blast is not a cooling", not blast.has("heat_cool"), str(blast))
	# A cook-off, a death or a new stage (both clear()) and a mode change each empty a hot shell: none is a cooling.
	_played(audio, func(): redline._set_value(Redline.MAX))
	var cooks: int = redline.cook_offs
	var cook := _played(audio, func(): redline.tick(Redline.COOK_OFF_S + 0.1, 0))
	t.eq("the shell cooked off", redline.cook_offs, cooks + 1)
	t.check("a cook-off is not a cooling", not cook.has("heat_cool"), str(cook))
	_played(audio, func(): redline._set_value(Redline.HOT_AT + 1.0))
	t.check("hot again before the clear", redline.hot(), str(redline.value))
	t.eq("a clear on a death or a new stage is silent", _played(audio, func(): redline.clear()), [])
	_played(audio, func(): redline._set_value(Redline.HOT_AT + 1.0))
	t.eq("turning heat off while hot is silent", _played(audio, func(): redline.set_mode(Redline.OFF)), [])
	for node in [audio, rig["events"]]:
		node.free()
