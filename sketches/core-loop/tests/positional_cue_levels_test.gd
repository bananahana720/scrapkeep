extends SceneTree

const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const JoltLayer := preload("res://src/combat/jolt_layer.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpecialAudio := preload("res://src/presentation/special_audio.gd")
const WavIo := preload("res://src/presentation/wav_io.gd")
const T := preload("res://tests/support/t.gd")

const FOLEY := "res://assets/audio/foley/"
const SPECIALS := "res://assets/audio/specials/"
const HEARD := {
	"lift_cage_arrive": [FOLEY + "lift_cage_arrive.wav", -4.0, 12.0, 80.0, false],
	"zipline_whine": [FOLEY + "zipline_whine.wav", -6.0, 12.0, 80.0, false],
	"zipline_snap": [FOLEY + "zipline_snap.wav", -4.0, 12.0, 80.0, false],
	"cave_in_rumble": [FOLEY + "cave_in_rumble.wav", -5.0, 12.0, 80.0, false],
	"cave_in_debris": [FOLEY + "cave_in_debris.wav", -4.0, 12.0, 80.0, false],
	"prop_crew_presence": [FOLEY + "prop_crew_presence.wav", -14.0, 12.0, 80.0, true],
	"prop_crew_strain": [FOLEY + "prop_crew_strain.wav", -4.0, 12.0, 80.0, false],
	"prop_crew_collapse": [FOLEY + "prop_crew_collapse.wav", -3.0, 12.0, 80.0, false],
	"jolt_layer_presence": [SPECIALS + "jolt_layer_presence.wav", -14.0, 12.0, 70.0, true],
	"jolt_layer_tell": [SPECIALS + "jolt_layer_tell.wav", -4.0, 12.0, 70.0, false],
	"jolt_layer_jam": [SPECIALS + "jolt_layer_jam.wav", -4.0, 12.0, 70.0, false],
	"jolt_layer_fizzle": [SPECIALS + "jolt_layer_fizzle.wav", -4.0, 12.0, 70.0, false],
	"jolt_layer_break": [SPECIALS + "jolt_layer_break.wav", -3.0, 12.0, 70.0, false],
}
const FOLEY_PLAYERS := ["zipline_whine", "prop_crew_presence"]
const FOLEY_ONE_SHOTS := ["lift_cage_arrive", "zipline_snap", "cave_in_rumble", "cave_in_debris", "prop_crew_strain",
	"prop_crew_collapse"]
const JOLT_CUES := ["tell", "jam", "fizzle"]
const PRESENCE := {
	"foreman": [SPECIALS + "foreman_presence.wav", -14.0, 12.0, 70.0, true],
	"dispatcher": [SPECIALS + "dispatcher_presence.wav", -14.0, 12.0, 70.0, true],
	"splitter": [SPECIALS + "splitter_presence.wav", -14.0, 12.0, 70.0, true],
	"linker": [SPECIALS + "linker_presence.wav", -14.0, 12.0, 70.0, true],
}
const BANK_HEARD := {"jolt_layer_tell": [SPECIALS + "jolt_layer_tell.wav", -4.0]}

var t := T.new("positional_cue_levels_test")
var fixture: Node3D
var _added_bus := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if AudioServer.get_bus_index(MixRows.BUS_SFX) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MixRows.BUS_SFX)
		_added_bus = true
	fixture = Node3D.new()
	root.add_child(fixture)
	var seen := {}
	for id in FOLEY_PLAYERS:
		var host := Node3D.new()
		fixture.add_child(host)
		seen[id] = FoleyAudio.player(id, host)
	for id in FOLEY_ONE_SHOTS:
		var before := _players()
		t.check(id + " one-shot starts", FoleyAudio.one_shot(id, fixture, Vector3.ZERO))
		seen[id] = _added(before)
	var unit := JoltLayer.new()
	fixture.add_child(unit)
	unit.setup(null, null, fixture, Callable(), 1.0, {"kind": "jolt_layer"})
	unit.set_physics_process(false)
	seen["jolt_layer_presence"] = unit.get("_presence")
	for part in JOLT_CUES:
		var before := _players()
		unit._cue(part)
		seen["jolt_layer_" + part] = _added(before)
	var before_break := _players()
	unit._die()
	seen["jolt_layer_break"] = _added(before_break)
	t.eq("every heard cue was built", seen.keys().filter(func(id): return seen[id] == null), [])
	for id in HEARD:
		t.eq(id + " plays its file at its level", _summary(seen.get(id), HEARD[id][0]), HEARD[id])
	for kind in PRESENCE:
		var p := SpecialAudio.presence_player(kind)
		t.eq(kind + " presence plays its file at its level", _summary(p, PRESENCE[kind][0], SfxBank.loop_stream(kind + "_presence")),
			PRESENCE[kind])
		t.eq(kind + " presence file", SfxBank.file_path(kind + "_presence"), PRESENCE[kind][0])
		t.eq(kind + " presence keeps its node name", String(p.name) if p != null else "", "SpecialPresence")
		if p != null:
			p.free()
	for id in BANK_HEARD:
		t.eq(id + " bank file and level", [SfxBank.file_path(id), SfxBank.trim_db(id)], BANK_HEARD[id])
	fixture.free()
	if _added_bus:
		AudioServer.remove_bus(AudioServer.get_bus_index(MixRows.BUS_SFX))
	for frame in 20000:
		if not _held():
			break
		await process_frame
	quit(t.verdict())


func _players() -> Array:
	return fixture.find_children("*", "AudioStreamPlayer3D", true, false)


func _added(before: Array) -> AudioStreamPlayer3D:
	var fresh := _players().filter(func(p): return not p in before)
	return fresh[0] if fresh.size() == 1 else null


func _summary(p: AudioStreamPlayer3D, file: String, want_stream: AudioStream = null) -> Array:
	if p == null or not (p.stream is AudioStreamWAV):
		return []
	var s := p.stream as AudioStreamWAV
	var source := want_stream if want_stream != null else WavIo.load_wav(file)
	var same: bool = source is AudioStreamWAV and s.data.size() > 0 and s.data == (source as AudioStreamWAV).data
	t.check("%s is on the SFX bus" % p.name, p.bus == MixRows.BUS_SFX, p.bus)
	t.check("%s file exists" % file, FileAccess.file_exists(file), file)
	return [file if same else "", snappedf(p.volume_db, 0.001), p.unit_size, p.max_distance,
		s.loop_mode == AudioStreamWAV.LOOP_FORWARD]


func _held() -> bool:
	for id in HEARD:
		var s := FoleyAudio.stream(id)
		if s != null and s.get_reference_count() > 2:
			return true
	return false
