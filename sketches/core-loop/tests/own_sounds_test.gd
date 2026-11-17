extends SceneTree

const T := preload("res://tests/support/t.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Rows := preload("res://src/presentation/rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

# The 28 world 1 cues that played a shared stand-in until wave 44 (the world 1 done read's row
# sound-own-recipes) each bake a sound of their own. For each: a recipe and a level no louder than
# the stand-in it replaces, a bake that is not the fallback blip and does not clip, a length that
# fits its moment, the row that names it now hearing it, and the right registry: the hazard warnings
# are danger sounds, and the pitched cues follow the live key. The five hazard families' warnings
# differ from each other and from the shared whistle. How any of it sounds is not judged here.
# With OWN_SOUNDS_OUT set to an absolute folder, each cue is also written there as <id>.wav at its
# bank level, for a listen.

# id -> [the stand-in it replaces, the row that names it, shortest s, longest s]
const OWN := {
	"flood_falling_pure": ["threat_whistle", "WORLD_ROWS:flood_rising", 0.5, 1.4],
	"fleet_falling_pure": ["threat_whistle", "WORLD_ROWS:fleet_inbound", 0.5, 1.4],
	"boiler_falling_pure": ["threat_whistle", "WORLD_ROWS:boiler_pressure", 0.5, 1.4],
	"lightning_falling_pure": ["threat_whistle", "WORLD_ROWS:lightning_charge", 0.4, 1.4],
	"ancient_falling_pure": ["threat_whistle", "WORLD_ROWS:ancient_stirring", 0.5, 1.4],
	"rock_grind_dust_hiss": ["threat_tick", "WORLD_ROWS:trestle_groan", 0.5, 1.4],
	"flood_drop": ["slam_boom", "WORLD_ROWS:flood_landed", 0.3, 1.2],
	"fleet_anvil_brass_drop": ["slam_boom", "WORLD_ROWS:fleet_landed", 0.3, 1.2],
	"lightning_strike": ["slam_boom", "WORLD_ROWS:lightning_landed", 0.3, 1.2],
	"rockfall_boom": ["slam_boom", "WORLD_ROWS:trestle_landed", 0.3, 1.2],
	"crater_crump_sub_boom": ["slam_boom", "WORLD_ROWS:reactor_landed", 0.3, 1.2],
	"steam_whistle_percussion_drop": ["slam_boom", "WORLD_ROWS:boiler_landed", 0.3, 1.2],
	"ancient_family_drop": ["slam_boom", "WORLD_ROWS:ancient_erupted", 0.3, 1.3],
	"cracked_wall_crumble": ["shatter", "WORLD_ROWS:wall_crumbled", 0.2, 1.0],
	"kest_snare_crack": ["shatter", "ROWS:cloak_broken", 0.08, 0.4],
	"companion_chirp_escape": ["companion_chirp_ready", "UI_ROWS:escape_acted", 0.1, 0.5],
	"kest_blast_lift": ["boost_whoosh", "ROWS:rocket_jumped", 0.2, 0.7],
	"kest_falling_triad": ["kest_demo_knock", "ROWS:demo_slammed", 0.3, 0.8],
	"kest_muffled_thump": ["stage_fade", "ROWS:cloak_started", 0.08, 0.4],
	"line_load": ["lock_tick", "ROWS:line_skill_loaded", 0.05, 0.3],
	"motif_accumulate": ["beacon_hum", "ROWS:gauge_charging", 0.5, 1.4],
	"motif_line": ["line_bite", "ROWS:line_skill_fired", 0.15, 0.5],
	"motif_stinger": ["special_fire", "ROWS:ultimate_peak", 0.4, 1.2],
	"pin_double_thwack": ["hit_thwack", "ROWS:enemy_pinned", 0.12, 0.35],
	"rebound_spring_snap": ["shell_spring", "ROWS:enemy_rebounded", 0.1, 0.35],
	"rivet_cymbal_choke": ["tenacity_choke", "ROWS:cc_ignored", 0.05, 0.25],
	"rivet_snare_flam": ["rivet_skid_plate", "ROWS:skid_smashed", 0.15, 0.5],
	"sable_root_fifth": ["zap_hum", "ROWS:arc_slammed", 0.25, 0.6],
}
const WARNINGS := ["flood_falling_pure", "fleet_falling_pure", "boiler_falling_pure", "lightning_falling_pure", "ancient_falling_pure",
	"rock_grind_dust_hiss"]
# Unpitched cues (noise, drums, sub drops): they need no key.
const UNPITCHED := ["rock_grind_dust_hiss", "flood_drop", "lightning_strike", "rockfall_boom", "crater_crump_sub_boom",
	"cracked_wall_crumble", "kest_snare_crack", "kest_blast_lift", "rivet_cymbal_choke"]
# The loudest an own sound may reach at its bank level, measured between samples (4x oversampled), in dBTP.
const TRUE_PEAK_DBTP := -1.5
# The motif cues each class hears in its own motif, and the stand-in each replaced.
const MOTIF_STANDINS := {"motif_accumulate": "beacon_hum", "motif_line": "line_bite", "motif_stinger": "special_fire"}
const FAMILIES := ["flood_falling_pure", "fleet_falling_pure", "boiler_falling_pure", "lightning_falling_pure", "ancient_falling_pure"]

var _t := T.new("own_sounds_test")


func _initialize() -> void:
	var tables: Dictionary = (EventKinds as GDScript).get_script_constant_map()
	var blip := int(0.12 * SfxBank.RATE)
	var looped := 0
	for id in OWN:
		looped += 1
		var spec: Array = OWN[id]
		var buf := SfxBank.samples(id)
		var seconds := float(buf.size()) / float(SfxBank.RATE)
		_t.check("%s has a recipe and a level" % id, SfxBank.has_recipe(id) and SfxBank.plays_own(id) and SfxBank.TRIM_DB.has(id))
		_t.check("%s sits no louder than %s" % [id, spec[0]], SfxBank.trim_db(id) <= SfxBank.trim_db(String(spec[0])), "%.1f vs %.1f" % [SfxBank.trim_db(id), SfxBank.trim_db(String(spec[0]))])
		_t.check("%s bakes its own sound, not the blip" % id, buf.size() != blip and buf != SfxBank.samples(String(spec[0])))
		_true_peak_check(id)
		_lists_check(id, String(spec[0]))
		_t.check("%s lasts %.2f to %.2f s" % [id, spec[2], spec[3]], seconds >= float(spec[2]) and seconds <= float(spec[3]), "%.3f s" % seconds)
		if id in SfxBank.LANDINGS:
			_t.check("%s is no longer than the slam it replaces" % id, buf.size() <= SfxBank.samples("slam_boom").size(), "%.3f s vs %.3f s" % [seconds, float(SfxBank.samples("slam_boom").size()) / SfxBank.RATE])
		var fact := String(spec[1])
		var row: Dictionary = tables[fact.get_slice(":", 0)][fact.get_slice(":", 1)]
		_t.eq("%s is what %s hears now" % [id, fact], Rows.heard(row), id)
		_t.eq("%s is %s danger sound" % [id, "a" if id in WARNINGS else "not a"], id in SfxBank.DANGER_SOUNDS, id in WARNINGS)
		_t.eq("%s %s the live key" % [id, "ignores" if id in UNPITCHED else "follows"], id in SfxBank.KEYED_SOUNDS, not id in UNPITCHED)
	_t.check("the loop ran over all 28", looped == OWN.size() and looped == 28, str(looped))
	var whistle := SfxBank.samples("threat_whistle")
	for i in FAMILIES.size():
		var a := SfxBank.samples(FAMILIES[i])
		_t.check("%s differs from the shared whistle" % FAMILIES[i], a != whistle and a.size() != whistle.size())
		for j in range(i + 1, FAMILIES.size()):
			_t.check("%s and %s differ" % [FAMILIES[i], FAMILIES[j]], a != SfxBank.samples(FAMILIES[j]))
	_motifs()
	_write()
	quit(_t.verdict())


# Each class hears the three motif cues in its own motif: Rows resolves them through the class, the notes are the
# class row's in Harmony.MOTIFS, and no two classes' versions bake the same. The stinger lands on the beat: it
# reaches within 10 dB of its peak no later than the special_fire it replaced does (or 10 ms, if that is later).
func _motifs() -> void:
	var fire_attack := _attack_s(SfxBank.samples("special_fire"))
	var looped := 0
	for cue in MOTIF_STANDINS:
		var bakes := {}
		for motif in Harmony.CLASS_MOTIFS:
			looped += 1
			var id := SfxBank.motif_cue_id(cue, motif)
			_t.eq("%s resolves to %s" % [cue, id], Rows.resolve(cue, {"motif": motif}), id)
			var cells: Array = (Harmony.MOTIFS[motif]["cells"] as Array).map(func(c): return int(c[1]))
			_t.eq("%s plays %s's own motif notes" % [id, motif], SfxBank.motif_cue_notes(motif), cells)
			_t.check("%s has a recipe at %s's level" % [id, cue], SfxBank.has_recipe(id) and is_equal_approx(SfxBank.trim_db(id), SfxBank.trim_db(cue)))
			_true_peak_check(id)
			_lists_check(id, String(MOTIF_STANDINS[cue]))
			var buf := SfxBank.samples(id)
			for other in bakes:
				_t.check("%s and %s differ" % [id, other], buf != bakes[other])
			bakes[id] = buf
			if cue == "motif_stinger":
				var attack := _attack_s(buf)
				print("ATTACK %s %.1f ms, special_fire %.1f ms" % [id, attack * 1000.0, fire_attack * 1000.0])
				_t.check("%s lands on the beat" % id, attack <= maxf(fire_attack, 0.01), "%.1f ms vs special_fire %.1f ms" % [attack * 1000.0, fire_attack * 1000.0])
	_t.check("the motif loop ran over 3 cues x 6 classes", looped == 18, str(looped))


# The seconds until a bake first reaches within 10 dB of its peak.
static func _attack_s(buf: PackedFloat32Array) -> float:
	var peak := 0.0
	for x in buf:
		peak = maxf(peak, absf(x))
	for i in buf.size():
		if absf(buf[i]) >= peak * 0.3162:
			return float(i) / SfxBank.RATE
	return 0.0


# The sound's true peak at its bank level is at or under TRUE_PEAK_DBTP.
func _true_peak_check(id: String) -> void:
	var dbtp := linear_to_db(true_peak(SfxBank.samples(id)) * db_to_linear(SfxBank.trim_db(id)))
	print("TRUEPEAK %s %.2f dBTP" % [id, dbtp])
	_t.check("%s true peak is at or under %.1f dBTP" % [id, TRUE_PEAK_DBTP], dbtp <= TRUE_PEAK_DBTP, "%.2f dBTP" % dbtp)


# A new cue is on every mix list its stand-in is on: crowd, danger, keyed, voice limit and gap.
func _lists_check(id: String, standin: String) -> void:
	var lost: Array = []
	if standin in MixRows.CROWD_SOUNDS and not id in MixRows.CROWD_SOUNDS:
		lost.append("crowd")
	if standin in SfxBank.DANGER_SOUNDS and not id in SfxBank.DANGER_SOUNDS:
		lost.append("danger")
	if standin in SfxBank.KEYED_SOUNDS and not id in SfxBank.KEYED_SOUNDS:
		lost.append("keyed")
	if MixRows.VOICE_LIMIT.has(standin) and not MixRows.VOICE_LIMIT.has(id):
		lost.append("voice limit")
	if MixRows.MIN_GAP_MS.has(standin) and not MixRows.MIN_GAP_MS.has(id):
		lost.append("gap")
	_t.check("%s is on every mix list %s is on" % [id, standin], lost.is_empty(), "missing: %s" % [lost])


# The largest magnitude between samples, read by 4x oversampling with a 16-tap Hann-windowed sinc. Only the
# stretches near the loud samples are oversampled (a sample above a third of the peak, or its neighbour).
static func true_peak(buf: PackedFloat32Array) -> float:
	var top := 0.0
	for x in buf:
		top = maxf(top, absf(x))
	var taps: Array = []
	for k in [1, 2, 3]:
		var frac: float = k / 4.0
		var row: Array = []
		for j in range(-7, 9):
			var d: float = float(j) - frac
			var s: float = 1.0 if is_zero_approx(d) else sin(PI * d) / (PI * d)
			row.append(s * (0.5 + 0.5 * cos(PI * d / 8.0)))
		taps.append(row)
	var gate := top / 3.0
	var out := top
	for i in range(7, buf.size() - 9):
		if absf(buf[i]) < gate and absf(buf[i + 1]) < gate:
			continue
		for row in taps:
			var y := 0.0
			for j in 16:
				y += buf[i - 7 + j] * float(row[j])
			out = maxf(out, absf(y))
	return out


# Writes each cue at its bank level when OWN_SOUNDS_OUT names a folder.
func _write() -> void:
	var out := OS.get_environment("OWN_SOUNDS_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out)
	var written := 0
	var ids: Array = OWN.keys()
	for cue in MOTIF_STANDINS:
		for motif in Harmony.CLASS_MOTIFS:
			ids.append(SfxBank.motif_cue_id(cue, motif))
	for id in ids:
		var buf := SfxBank.samples(id).duplicate()
		var gain := db_to_linear(SfxBank.trim_db(id))
		for i in buf.size():
			buf[i] *= gain
		if Synth.to_wav(buf).save_to_wav(out.path_join(id + ".wav")) == OK:
			written += 1
	print("WROTE %d wavs to %s" % [written, out])
