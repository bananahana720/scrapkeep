extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const MusicPhrases := preload("res://src/presentation/music_phrases.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")

# The music gems ledger (src/presentation/MUSIC-GEMS.md): each gem Andrew reacted to
# keeps its defining features, and the rejected wubs stay out. Engine state on the
# dummy driver; how it sounds is Andrew's to judge.

var _failures := 0


func _initialize() -> void:
	MusicPrebake.prepare()
	_g1_band()
	_g2_rice_cooker()
	_g3_g4_warden_club()
	_g5_palettes()
	_g6_brindle_quotes()
	_g7_escalation()
	_g8_bass_lines()
	_g10_layers()
	_r1_r2_no_wubs()
	_g11_reference()
	print("presentation_gems_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _level(theme: int, pressure: float) -> MusicEngine:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY, theme)
	engine.set_pressure(pressure)
	engine.render(1)
	return engine


func _g1_band() -> void:
	var names: Array = Harmony.PROGRESSION.map(func(c: Dictionary): return c["name"])
	var engine := _level(0, 0.0)
	engine.render(Harmony.BAR * 2)
	var ok: bool = names == ["Dm9", "G13", "Dm9", "Cmaj9", "Bbmaj9", "G13", "Em7b5", "A7b9"] and absf(engine.bpm() - 172.0) < 0.1 and engine._lead_voice == "lead" and engine.layer_starts[MusicEngine.KEYS] > 0
	_check("G1 the band", ok, "172 BPM, %s, electric piano in from calm, the synth sax on the lead" % [names])


func _g2_rice_cooker() -> void:
	var score := SfxBank._score_clear(0)
	var last: Array = score[score.size() - 1]
	var climb: Array = score.filter(func(e: Array): return e[3] == "mallet" and e[0] < 8).map(func(e: Array): return e[1])
	var cadence_ok: bool = Harmony.CADENCE[0]["name"] == "A7b9" and posmod(int(Harmony.CADENCE[1]["root"]), 12) == 2
	var jingle_ok: bool = int(last[1]) == 86 and climb.slice(0, 4) == [69, 73, 76, 81]
	# A launch build holds the dominant and the landing drop resolves it to D.
	var engine := _level(0, 0.6)
	engine.render(Harmony.BAR + 999)
	engine.start_build(1.6, true)
	engine.render(Harmony.BEAT)
	var held: String = engine._chord(engine._bar_step / 16)["name"]
	var at := engine.drop_now(4, 0.85, {}, 0)
	engine.render(at - engine.clock + 64)
	var landed: int = posmod(int(engine._chord(0)["root"]), 12)
	_check("G2 rice cooker", cadence_ok and jingle_ok and held == "A7b9" and landed == 2,
		"the clear climbs A7 %s and ends on high D (%d); the cadence is A7b9 to D; a launch build holds %s and the landing resolves to D" % [climb.slice(0, 4), int(last[1]), held])


func _g3_g4_warden_club() -> void:
	var engine := _level(0, 0.8)
	engine.render(Harmony.BAR + Harmony.BEAT * 2 + 1234)
	var begin := engine.begin_boss("warden")
	engine.render(begin - engine.clock + Harmony.BAR * 2)
	var tempo: Array = engine.events_log.filter(func(e: Array): return e[0] == "tempo")
	var pivot: int = tempo[0][1] if tempo.size() > 0 else -1
	var pivot_ok: bool = pivot == begin + Harmony.BAR and pivot % Harmony.BEAT == 0 and absf(engine.bpm() - 129.0) < 0.1 and engine.section == "build"
	var build_pump := engine._pump_depth > 0.0
	var drop := MusicEngine.new()
	drop.force_track("warden", 0, "drop", true)
	var kicks := drop.layer_starts[MusicEngine.KICK]
	drop.render(drop.bar_len() * 2)
	kicks = drop.layer_starts[MusicEngine.KICK] - kicks
	var club: bool = drop.section == "drop" and drop._pump_depth > 0.0 and int(drop.bass_log.get("fbass", 0)) > 0 and kicks >= 8 and drop.layer_starts[MusicEngine.WOB] == 0
	var brindle := MusicEngine.new()
	brindle.force_track("brindle", 0, "1", true)
	brindle.set_brindle_phase(2)
	while not brindle.in_drop():
		brindle.render(brindle.step_len)
	brindle.render(brindle.bar_len())
	var brindle_club: bool = brindle._pump_depth > 0.0 and int(brindle.bass_log.get("fbass", 0)) > 0
	_check("G3 G4 Warden club", pivot_ok and build_pump and club and brindle_club,
		"the pivot lands at 129 on a 172 beat (%d); the build pumps; the unseal drop is four on the floor (%d kicks in 2 bars) with the funk octave bass, the pump on and no wobble; Brindle's drop pumps with the funk bass too" % [pivot, kicks])


func _g5_palettes() -> void:
	var voices: Array = []
	for theme in 3:
		var engine := _level(theme, 1.0)
		engine.render(Harmony.BAR)
		voices.append(engine._lead_voice)
	_check("G5 level palettes", voices == ["lead", "brass", "talk"], "Spillway sax, Sluice brass over the clav riff, Weir talkbox: %s" % [voices])


func _g6_brindle_quotes() -> void:
	var ok := true
	var quotes := {"1": [MusicPhrases.MOTIF_WEIR, Harmony.BRINDLE], "2": [MusicPhrases.MOTIF_SLUICE, Harmony.BRINDLE_PHRYGIAN], "3": [MusicPhrases.MOTIF, Harmony.BRINDLE]}
	for section in quotes:
		var engine := MusicEngine.new()
		engine.force_track("brindle", 0, section, true)
		ok = ok and engine._lead == MusicPhrases.make_lead(engine.phrase_index, quotes[section][0], quotes[section][1], 73)
	var last: Array = MusicEngine.VICTORY_LEAD[MusicEngine.VICTORY_LEAD.size() - 1]
	_check("G6 Brindle quotes the run in reverse", ok and int(last[1]) == 86, "phase 1 quotes Weir, 2 Sluice, 3 Spillway; the victory lands on high D (%d)" % int(last[1]))


func _g7_escalation() -> void:
	var engine := MusicEngine.new()
	engine.force_track("warden", 0, "build", true)
	engine.render(engine.bar_len() + 777)
	engine.warden_charge(0.55)
	engine.render(engine.bar_len() * 3)
	var lifted: bool = engine.key == 1 and engine.section == "lift"
	var key_changes: Array = engine.events_log.filter(func(e: Array): return e[0] == "key")
	var on_bar: bool = key_changes.size() > 0 and (int(key_changes[0][1]) - engine.grid_origin) % engine.bar_len() == 0
	engine.warden_charge(0.8)
	engine.render(engine.bar_len() * 3)
	var broke: bool = engine.section == "break" and engine.building()
	var at := engine.unseal_drop()
	engine.render(at - engine.clock + 64)
	var home: bool = engine.section == "drop" and engine.key == 0
	var brindle := MusicEngine.new()
	brindle.force_track("brindle", 0, "1", true)
	brindle.set_brindle_phase(2)
	while not brindle.in_drop():
		brindle.render(brindle.step_len)
	var k2 := brindle.key
	brindle.render(brindle.bar_len() * 5)
	brindle.set_brindle_phase(3)
	while brindle.section != "3":
		brindle.render(brindle.step_len)
	_check("G7 escalation", lifted and on_bar and broke and home and k2 == 1 and brindle.key == 2 and absf(brindle.bpm() - 150.0) < 0.5,
		"the Warden half broken lifts a half step on a bar line, three quarters starts the sinister break with its build, the unseal drops home to D; Brindle phase 2 is up %d, phase 3 up %d at %.0f BPM" % [k2, brindle.key, brindle.bpm()])


func _g8_bass_lines() -> void:
	var instruments: Array = []
	var ok := true
	for theme in 3:
		for p in [0.0, 1.0]:
			var engine := _level(theme, p)
			engine.render(Harmony.BAR)
			var subs := engine.layer_starts[MusicEngine.SUB]
			engine.bass_log.clear()
			engine.render(Harmony.BAR * 2)
			var name: String = engine.bass_log.keys()[0] if engine.bass_log.size() == 1 else str(engine.bass_log.keys())
			var notes := int(engine.bass_log.get(name, 0))
			ok = ok and notes >= 6 and engine.layer_starts[MusicEngine.SUB] - subs >= 2
			if p == 1.0:
				instruments.append(name)
	_check("G8 bass lines", ok and instruments == ["reese", "fbass", "reese"], "Spillway reese roll, Sluice funk slap, Weir root-octave ladder, each at least 3 notes a bar over a sub on every downbeat, calm and full: %s" % [instruments])


func _g10_layers() -> void:
	var counts: Array = []
	for i in 6:
		counts.append(MusicEngine.melodic_layers(i / 5.0))
	var mono := true
	for i in range(1, counts.size()):
		mono = mono and counts[i] >= counts[i - 1]
	_check("G10 layering", mono and counts[0] == 0 and counts[5] == MusicEngine.MELODIC.size(), "melodic layers by pressure %s; the re-voicing cycle is checked in presentation_bass_test" % [counts])


func _r1_r2_no_wubs() -> void:
	var loud: Array = []
	for theme in 3:
		var engine := _level(theme, 1.0)
		engine.render(Harmony.BAR * 8)
		if engine.layer_starts[MusicEngine.WOB] > 0:
			loud.append(Harmony.THEMES[theme])
	var growl := false
	for method in (Synth as GDScript).get_script_method_list():
		growl = growl or String(method["name"]).contains("growl")
	_check("R1 R2 no wubs", loud.is_empty() and not growl, "no wobble voice in any level theme at full pressure over 8 bars, and no growl voice left in the synth; offenders %s" % [loud])


func _g11_reference() -> void:
	var ledger := FileAccess.get_file_as_string("res://src/presentation/MUSIC-GEMS.md")
	var files := ["res://src/presentation/music_engine.gd", "res://src/presentation/audio.gd", "res://tests/presentation_escalation_test.gd"]
	var present := files.all(func(f: String): return FileAccess.file_exists(f))
	var engine := MusicEngine.new()
	var api: bool = ["escalate", "warden_charge", "miniboss_drop", "resolve_event", "brindle_hp", "chase", "set_heft_lift"].all(func(m: String): return engine.has_method(m))
	_check("G11 Warden Spillway B is the reference", ledger.contains("| G11 |") and present and api, "the ledger names B's grammar as the reference; its one escalation API and its test exist")


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
