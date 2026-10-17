extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# INTEGRATION section 1, target two: every musical stinger starts on the next beat, never
# later than one beat after the ask (349 ms at 172 BPM, 465 ms at 129). The stingers are
# the event-set files from the bank, asked for mid-beat on both grids, and the check reads
# the rendered stinger lane, not only the scheduled sample: silent before the beat,
# sounding from it.
#
# Planted control: SOUNDINT_PLANT=offbeat starts each stinger 500 samples after its beat,
# and the test must then fail. The same plant runs inside every pass against the checker.

const PLANT_OFFSET := 500
const GRIDS := {"172 bpm": Harmony.STEP, "129 bpm": Harmony.BOSS_STEP}

var t := T.new("audio_stinger_beat_test")
var _plant := OS.get_environment("SOUNDINT_PLANT") == "offbeat"


func _initialize() -> void:
	MusicEngine.prepare()
	var stingers: Array = []
	for id in SfxBank.STINGER_BEATS:
		if id in SfxBank.EVENT_CUES:
			stingers.append(id)
	t.check("the file stingers are found", stingers.size() >= 8, str(stingers))
	var checked := 0
	for grid in GRIDS:
		for id in stingers:
			checked += _check_stinger(grid, int(GRIDS[grid]), id, _plant)
	# Detector control: the same check on a planted off-beat start must fail.
	var control := _check_stinger("172 bpm", Harmony.STEP, "stinger_stage", true, true)
	t.eq("a planted off-beat start is caught", control, 0)
	print("STINGER_BEAT checked=%d stingers=%d grids=%d plant=%s" % [checked, stingers.size(), GRIDS.size(), str(_plant)])
	quit(t.verdict())


# Returns 1 when the stinger started on its beat, on this grid, within one beat of the ask.
func _check_stinger(grid: String, step: int, id: String, plant: bool, silent := false) -> int:
	var engine := MusicEngine.new()
	engine.step_len = step
	var beat := engine.beat_len()
	engine.render(beat + beat / 2 + 17)
	var asked := engine.clock
	var start := engine.schedule_stinger(id)
	if plant:
		# A second hit that lands off the beat, standing for a broken quantizer.
		start += PLANT_OFFSET
		engine.schedule_stinger_at(id, start)
	var on_grid := start % beat == 0
	var in_time := start > asked and start - asked <= beat
	engine.render(start - engine.clock - 1)
	var silent_before := engine.stinger_starts.is_empty()
	if not plant:
		for frame in engine.out_stinger:
			silent_before = silent_before and frame == Vector2.ZERO
	engine.render(512)
	var started := false
	for entry in engine.stinger_starts:
		started = started or (entry[0] == id and entry[1] == start)
	var sounding := false
	for frame in engine.out_stinger:
		sounding = sounding or absf(frame.x) > 0.001
	var ok := on_grid and in_time and silent_before and started and sounding
	if not silent:
		t.check("%s %s starts on the beat" % [grid, id], ok,
			"asked %d, start %d (%.3f beats), %.1f ms wait" % [asked, start, float(start) / beat, 1000.0 * (start - asked) / Harmony.RATE])
	return 1 if ok else 0
