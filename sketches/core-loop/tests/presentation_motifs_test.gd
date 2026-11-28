extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Audio := preload("res://src/presentation/audio.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# The leitmotif table (SOUND-STORY.md section 2) resolves every id the sound story
# names, with the notes it names; the class rows' W5 ids bake; every new cue has a
# recipe and the pitched ones follow the live key; the new band layers enter on their
# thresholds. Engine state and buffers, not ears.

const STORY_IDS := ["sable", "rivet", "kest", "fleet", "reactor", "swarm", "mind"]
const NEW_CUES := ["sable_arpeggio", "rivet_hihat_roll", "kest_low_thump", "sable_ready", "rivet_ready", "kest_ready",
	"sable_break", "rivet_break", "kest_break", "fleet_motif", "reactor_tick", "reactor_erupt", "swarm_buzz", "swarm_lock",
	"swarm_scatter", "mind_sable", "mind_rivet", "mind_kest", "hold_pit", "hold_bola", "hold_tether", "hold_net",
	"hold_riser", "tenacity_choke", "callout_chime", "shop_bell", "bench_clank", "babble"]
const UNPITCHED := ["reactor_tick", "tenacity_choke", "bench_clank", "babble"]

var _failures := 0


func _initialize() -> void:
	var missing := STORY_IDS.filter(func(id: String): return Harmony.motif(id).is_empty())
	_check("ids resolve", missing.is_empty(), "%s resolve through Harmony.motif; missing %s" % [STORY_IDS, missing])

	var notes_ok: bool = Harmony.motif_notes("sable") == [62, 65, 69, 72, 76] and Harmony.motif_notes("rivet") == [69, 69, 69, 74] \
		and Harmony.motif_notes("kest") == [62, 57, 53, 50] and Harmony.motif_notes("tarn") == [50, 50, 51, 57] and Harmony.motif_notes("tally") == [62, 64, 65, 67, 74] and Harmony.motif_notes("cannon") == [59, 64, 67, 74] and Harmony.motif_notes("reactor") == [44, 56] \
		and Harmony.motif("swarm")["chord"] == [74, 79, 84, 89] and Harmony.motif_notes("swarm") == [79]
	var fleet: Array = Harmony.motif_notes("fleet")
	notes_ok = notes_ok and fleet[0] == 50 and fleet.has(51) and fleet[fleet.size() - 1] == 50
	_check("notes", notes_ok, "Sable D F A C E, Rivet A A A D, Kest D A F D, Tarn D D Eb A, Tally D E F G D, Cannon B E G D, the Fleet's D Eb D, the reactor's Ab pedal, the swarm's G into stacked fourths")

	var quote: Array = Harmony.mind_quote("sable").map(func(c: Array): return c[1])
	_check("the Mind quotes wrong", quote == [62, 59, 55, 52, 47], "Sable inverted, last note a semitone flat: %s (D B G E B)" % [quote])

	# A class row names its leitmotif (`motif`); its ready and break cues are built from it.
	var unbaked: Array = []
	for def in ClassDef.all():
		if Harmony.motif(def.motif).is_empty():
			unbaked.append(def.motif)
		for cue in [def.motif + "_ready", def.motif + "_break"]:
			if not SfxBank.has_recipe(cue) or Synth.peak(SfxBank.samples(cue)) < 0.1:
				unbaked.append(cue)
	_check("class rows bake", unbaked.is_empty(), "every class row's motif resolves and its ready and break cues bake; failing %s" % [unbaked])

	var silent: Array = []
	var unkeyed: Array = []
	for id in NEW_CUES:
		var has_own: bool = VoiceSynth.has_recipe(id) if id == "babble" else SfxBank.has_recipe(id)
		var buf: PackedFloat32Array = VoiceSynth.samples(id) if id == "babble" else SfxBank.samples(id)
		if not has_own or Synth.peak(buf) < 0.1:
			silent.append(id)
		if not id in UNPITCHED and not id in Audio.KEYED_SOUNDS:
			unkeyed.append(id)
	_check("new cues", silent.is_empty() and unkeyed.is_empty(), "%d cues bake non-silent; unbaked %s; pitched but not keyed %s" % [NEW_CUES.size(), silent, unkeyed])

	var babble := [VoiceSynth.babble("Still no. Pick one.", 1).size(), VoiceSynth.babble("Still no. Pick one.", 5).size()]
	_check("babble hurries", babble[1] < babble[0] and VoiceSynth.babble("Still no. Pick one.", 1) == VoiceSynth.babble("Still no. Pick one.", 1),
		"a line babbles the same way twice, and faster at beat 5 (%d then %d samples)" % babble)

	_class_counter()
	_fleet()
	_lounge()
	print("presentation_motifs_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _band(pressure: float) -> MusicEngine:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY, 0)
	engine.set_pressure(pressure)
	engine.render(1)
	return engine


func _class_counter() -> void:
	var engine := _band(1.0)
	engine.set_class_motif("sable")
	var line: Array = engine._class_counter
	var shape_ok := line.size() == 20
	for k in 4:
		for i in 4:
			shape_ok = shape_ok and int(line[k * 5 + i + 1][1]) > int(line[k * 5 + i][1])
	engine.render(Harmony.BAR * 8)
	var off := _band(1.0)
	off.render(Harmony.BAR * 8)
	_check("class motif is a layer", shape_ok and engine._lead == off._lead and engine.layer_starts[MusicEngine.COUNTER] > 0,
		"Sable's rising arpeggio four times per phrase on the counter rotation; the lead is untouched")


func _fleet() -> void:
	var engine := _band(0.6)
	engine.render(Harmony.BAR / 2)
	var at := engine.set_fleet_ticks(2)
	engine.render(Harmony.BAR * 2)
	_check("fleet ticks add", at == Harmony.BAR and engine.fleet_ticks == 2 and engine.layer_starts[MusicEngine.FLEET] > 0,
		"the second tick's anvil and brass enter on the next bar line and play")


func _lounge() -> void:
	var engine := _band(0.6)
	engine.set_lounge(true)
	engine.render(Harmony.BAR * 2)
	var kicks := engine.layer_starts[MusicEngine.KICK]
	engine.render(Harmony.BAR * 2)
	var in_lounge: bool = engine._lead_voice == "sax_lounge" and engine.layer_target(MusicEngine.KICK) == 0.0 and engine.layer_starts[MusicEngine.KICK] == kicks
	engine.drop_now(4, 0.85, {}, 0)
	engine.render(Harmony.BAR)
	_check("the lounge masks, the drop returns", in_lounge and not engine.lounge and engine._lead_voice == "lead" and engine.layer_starts[MusicEngine.KICK] > kicks,
		"the sax leads with no kick in the bay; the landing drop ends the lounge on the beat into the full band")


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", name, detail])
