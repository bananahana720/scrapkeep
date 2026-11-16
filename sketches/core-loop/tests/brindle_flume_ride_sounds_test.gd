extends SceneTree

const T := preload("res://tests/support/t.gd")
const Audio := preload("res://src/presentation/audio.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")

# World 1's last stand-in sounds: each of Brindle's five attacks warns with a sound of its own, the
# flume's head-gate siren has its own, and the ride and movement facts that borrowed a stand-in hear
# their planned sound. Cue decisions are read from audio.cue_log, so this is the director's choice, not a listen.

# Every attack id Brindle publishes on boss_attack_telegraphed (boss.gd), with the sound it must warn with.
# The two slag rings are one attack: they alternate rings and share a sound.
const ATTACKS := {
	"crane_sweep": "tele_crane_sweep", "slag_ring_a": "tele_slag_ring", "slag_ring_b": "tele_slag_ring",
	"charge": "tele_charge", "charge_wall": "tele_charge_wall", "eject": "tele_eject",
}
const SIREN := "sluice_siren_two_tone"
# Ride and movement facts that heard a stand-in, and the sound each now hears.
const RIDES := {
	"ride_chute": "ride_rolling_metal", "ride_bowl": "ride_bowl_carve", "ride_drop": "ride_drop_swoop",
	"ride_ledge": "ride_ledge_scuff", "ride_hop": "ride_hop_lift", "ride_grapple_line": "ride_cable_clink",
	"ride_sheet": "ride_sheet_swell", "launcher_charging": "steam_whistle_rise", "cannon_fired": "cannon_bang_rail_whoosh",
	"sluice_landed": "sluice_gush_roar",
}

class FakeCtx:
	extends RefCounted
	var events: Node
	var run
	var player


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("brindle_flume_ride_sounds_test")
	_telegraphs(t)
	_rows(t)
	_bank(t)
	quit(t.verdict())


# Which kind of row hears a sound, over every table the game reads: {sound: [row ids]}.
func _hearers() -> Dictionary:
	var out := {}
	for table in [EventKinds.ROWS, EventKinds.WORLD_ROWS]:
		for kind in table:
			var sound := Rows.heard(table[kind])
			if not out.has(sound):
				out[sound] = []
			out[sound].append(kind)
	return out


func _rig() -> Dictionary:
	var events := GameEvents.new()
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").new())
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.run = run
	ctx.player = RefCounted.new()
	var audio := Audio.new()
	audio.setup(ctx)
	audio.bake_now()
	return {"audio": audio, "events": events}


func _telegraphs(t) -> void:
	var rig := _rig()
	var audio = rig["audio"]
	var heard := {}
	var looped := 0
	for id in ATTACKS:
		audio._last_start.clear()
		audio.cue_log.clear()
		rig["events"].boss_attack_telegraphed.emit(id, 1.0)
		var played := []
		for cue in audio.cue_log:
			if cue[2] == "now":
				played.append(cue[1])
		looped += 1
		t.eq("%s plays one telegraph sound" % id, played.size(), 1)
		if played.size() == 1:
			heard[id] = played[0]
	t.eq("looped over every attack id", looped, 6)
	var distinct := {}
	for id in heard:
		t.eq("%s warns with its own sound" % id, heard[id], ATTACKS[id])
		distinct[heard[id]] = true
	t.eq("five attacks, five telegraph sounds", distinct.size(), 5)
	for sound in distinct:
		t.check("%s is a danger sound" % sound, sound in SfxBank.DANGER_SOUNDS)
		t.check("%s is heard by no row" % sound, not _hearers().has(sound))
	# An attack id the table does not name (the Mind's, the Warden's) keeps the shared telegraph.
	audio._last_start.clear()
	audio.cue_log.clear()
	rig["events"].boss_attack_telegraphed.emit("some_other_attack", 1.0)
	var other := []
	for cue in audio.cue_log:
		if cue[2] == "now":
			other.append(cue[1])
	t.eq("an unlisted attack id keeps boss_telegraph", other, ["boss_telegraph"])
	for node in [audio, rig["events"]]:
		node.free()


func _rows(t) -> void:
	var hearers := _hearers()
	var siren := Rows.heard(EventKinds.world_row("sluice_siren"))
	t.eq("sluice_siren is heard as its two tones", siren, SIREN)
	t.eq("nobody else hears the siren", hearers.get(SIREN, []), ["sluice_siren"])
	var looped := 0
	for kind in RIDES:
		looped += 1
		var heard := Rows.heard(EventKinds.world_row(kind))
		t.eq("%s hears its own sound" % kind, heard, RIDES[kind])
		t.eq("%s is heard by that row alone" % RIDES[kind], hearers.get(RIDES[kind], []), [kind])
	t.eq("looped over ten ride and movement rows", looped, 10)


func _bank(t) -> void:
	var ids := []
	for sound in ATTACKS.values():
		if not sound in ids:
			ids.append(sound)
	ids.append(SIREN)
	ids.append_array(RIDES.values())
	t.eq("sixteen new sounds", ids.size(), 16)
	for id in ids:
		var buf := SfxBank.samples(id)
		var peak := 0.0
		for s in buf:
			peak = maxf(peak, absf(s))
		var seconds := buf.size() / float(SfxBank.RATE)
		t.check("recipe " + id, SfxBank.has_recipe(id))
		t.check("%s is not silent and under 1.5 s" % id, peak >= 0.1 and peak <= 0.95 and seconds > 0.1 and seconds < 1.5, "peak %.3f, %.2f s" % [peak, seconds])
		t.check("%s is not the fallback blip" % id, buf.size() != int(0.12 * SfxBank.RATE))
		t.check("level " + id, SfxBank.TRIM_DB.has(id))
