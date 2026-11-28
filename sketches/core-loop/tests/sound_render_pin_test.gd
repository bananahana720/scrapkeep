extends SceneTree

const T := preload("res://tests/support/t.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const SetDirector := preload("res://src/presentation/set_director.gd")

# Godot's float output can differ in the last bit between macOS and Linux, so only RECORDED_ON compares bytes.
const RECORDED_ON := "macOS arm64"
const STATIC_VAR := "(?m)^\\s*(?:@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*static\\s+(?:@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*var\\s+([A-Za-z_]\\w*)"
const SHARED_STATICS := {
	"res://src/presentation/synth.gd": ["_notes", "_lock"],
	"res://src/presentation/sfx_bank.gd": ["_samples", "_lock", "_streams", "_rendered", "_cache_lock", "bake_cancel", "_file_present"],
}
const REL_TOL := 1e-4
const ABS_TOL := 1e-3
const PINS := {
	"at class_down boss -5": ["9e8f120aeaa21c249f1e6cbd4e5b7a4485bb4f054c7d783d321978d6033b9016", 66765, -3.0997573116517287, 8757.604037440653, 2710.9936681480353, 0.9],
	"at class_up boss +2": ["03f1fbbf157c097abc1705036cd729d82596ba3508c5d94f441afca3644c6f25", 80714, 97.60329035426707, 8983.313007335602, 2424.670759762855, 0.9],
	"at event_start home +3": ["54ee9fe5df080cfd49c9b15968dabe52a8ba8dc8dd0a783bd2e7c8d0d9942566", 61536, -285.77539716111414, 12005.856998587107, 4446.489474109709, 0.9],
	"at gates_open boss": ["986c76ef0910f051ee4092fd7476832ded4c0ead69c4218738d46d9900c83da9", 126148, -140.1818941304275, 11010.030458008101, 2282.9709870810193, 0.9],
	"at hold_pit boss +2": ["9fcb14e27a795148c0fd09b4cdbe2da2677f4717de2425b2e4a64843d6bc8898", 30768, 0.6445900840465697, 8594.66601868198, 3229.7072176885285, 0.9],
	"at klaxon boss -3": ["3981707c5e1243f53d75349f345ebb0e2a8c8eaad4820abbccd7149597632dda", 79996, 179.93615065903208, 30664.506520096562, 19750.57276341486, 0.9],
	"at music_pressure boss": ["a255f1292a80415a8a10ea9da67121f07d9922af656c0054c59ff3c1dac33190", 20512, 0.0026690071330739418, 1216.7212048001252, 308.18053473137695, 0.9],
	"at pilot quote boss +1": ["8754e895828a3a8fd608596531b03157d8a1aa911ea9cd589cdc67b4d233e809", 83586, -178.02968882995816, 13391.301678936914, 4000.194901389004, 0.9],
	"at plate_tally home +3": ["b628b4ffdd9dbbe8961e72799427859fdfe196ef47c43ed00f45d7dd7a60ebba", 38561, -66.64874149358874, 5061.993161683727, 2215.6294551680553, 0.9],
	"at set answer boss": ["01d0f257d3fa6ab3bc48d58b307e94960693540c4519c9faa9382f1945798f50", 83586, -237.0920382970365, 11411.0604534391, 3440.220564897657, 0.9],
	"at stinger_clear boss +2": ["8323c41307b03744a1dee1cc3b940341661894375eb1170a48c6f52673290d01", 82506, 0.11382391626946031, 10378.844916758251, 2814.0036020794137, 0.9],
	"at stinger_unseal boss +5": ["780d180c0779f67c4f264b88264326905a12624df882006df4e6297471a8283f", 126148, -262.49313432992966, 13764.420385775342, 3618.61847924287, 0.9],
	"at stinger_world_up5 boss +1": ["f990b974d37b090fd52207479b8d18c8e55761dfb897119e40939ed76bd8f083", 67484, 73.54521143845523, 8457.512086879333, 2196.8354827647995, 0.9],
	"at threat_up home +4": ["295c0174884140144bb3e4feef384741c9dbb31ee0157b20e8c0520f83c8c09a", 8820, 4.865712070983818, 3695.112622723197, 2101.151169607103, 0.9],
	"at warden_theme_in boss": ["06a6b14309fa4d31159826bd778e926be60f06ee424c155e3875e5ce1e51633a", 117328, 417.9054467626768, 33345.34591530185, 16416.835248923722, 0.9],
	"bare score boss +3": ["7d324ceae9ccccb23dd4017a8068e338c110f518276fb6d11ac7ec0ae8a9055a", 48408, -33.04114243366621, 5818.92827644352, 1943.295088196497, 1.185766],
	"bare score": ["239c685744be401f80887833113c68efd3608a14dc8b88f70b0528ec98c67b74", 40716, -24.5393663414319, 5317.353529242746, 1884.3430726060187, 1.277249],
	"samples ceremony_build": ["67208564ba1a75fb70619b735502cc8e9945701123b618fda6629093f32b11c1", 63741, 59.23214176636324, 8724.294761506046, 2051.783254280738, 0.9],
	"samples crater_hold": ["2ca0a796f03dcdb72d781314b2d3af865b8950d89145d7bb342561ecf84dceef", 30768, -0.4772096282332541, 9831.483205444565, 4147.546523482862, 0.9],
	"samples event_start": ["db6aacc434965bbf603265ab84493781a9a1fc8e9551e71470484fb04f9f71ad", 61536, -383.15048934726804, 12522.83715379725, 4706.338976410968, 0.9],
	"samples find_radio": ["827e5a71e9d0689df92faf82999a364523f5ec91137f181ed9ebd9cbb0d046f1", 123072, -532.3491047001036, 18189.949858838452, 4427.4205001009705, 0.9],
	"samples gates_open": ["3a81fb53596ecb16122343884823d18dfe17f72759f5f8b7bf4c018dbb8622a9", 105636, -153.72331341955365, 10536.26818729127, 2566.3171685899792, 0.9],
	"samples hold_pit": ["e2f3b07f8840dbe1df314fa2683c836f5dcf39f6469485b6ccb26e4399f1a6bb", 30768, -2.331295267331825, 9414.462910701335, 3880.26724961707, 0.9],
	"samples kest_hihat_roll": ["367f8f75ebb458e559ce8f6d9d62df6cde1026c7045319e8a671758a8fa70817", 5292, -2.750983566340892, 1168.9400190743659, 460.077248651278, 0.9],
	"samples klaxon": ["134e8e59f9829eb232cfb5b025d2dfc5881d3529509910dc222ecb71256bbda0", 59997, 232.53778776460436, 24534.685256514687, 16565.253863460857, 0.9],
	"samples plate_tally": ["6b5fd463a8834731d8b67c328d399dc27e49b71bb4fe43801cc3ba23c36ef658", 38561, -61.34921104976627, 5462.953000870319, 2577.219766458867, 0.9],
	"samples rivet_hihat_roll": ["04a04491e039ec04f8dc01006c9ef532dced2ea6fa04e689134ef310864d750b", 81432, 139.3840305877557, 3014.2205514355383, 495.8705945895782, 0.9],
	"samples sable_break": ["6ce007e98417bc99b0502f7ff25ce5543f314c0f5a98a1783ba1bf434bef51be", 21486, -3.5939706234228765, 3206.3515563818924, 918.8446203141159, 0.9],
	"samples tarn_hihat_roll": ["14a7f3750485963b8ee419534791f0e2f96e50c24f54a90b4db1f5a4cdf876c1", 5292, 0.6766454383068776, 1171.597070460226, 462.841977107078, 0.9],
	"synergy score theme 1": ["ef41d25bef0907ef2f9ed3f5c86dc8ac3475f55c9eedec13225868a7f49add74", 154043, -730.9772949089091, 24909.44703429056, 13759.723008997735, 2.223624],
	"synergy score theme 2": ["27bdd18ce797b7132a9430464354d06c365fff7e105c7892c5252bfe45cb7b67", 154043, -742.3962734235009, 24973.128558595312, 13852.480239631328, 2.35233],
	"tally clip 62": ["0e9de4ad87662b8a7789a73867f91c7892ccf81514972e746e050fdc712fb379", 34715, -95.85352800561759, 5131.023206940538, 2197.4353625659705, 0.9],
	"tally plate 50 total": ["6b5fd463a8834731d8b67c328d399dc27e49b71bb4fe43801cc3ba23c36ef658", 38561, -61.34921104976627, 5462.953000870319, 2577.219766458867, 0.9],
	"tool bite 1": ["9edb0b0be44e0bb3f6b5af4197524a037ad48e0b8720138d3f7d33ef7f0ea295", 14112, -4.494047778933752, 1094.1997333438565, 235.1145724842915, 0.9],
	"tool crack 0": ["3bc8c7ccf2c9026d41cbe512af91af1a5c8ec07cdb90a0405f3911fafbacc674", 13230, 13.069280965507968, 796.7332331351336, 158.05603792026716, 0.9],
	"tool hold crater": ["2ca0a796f03dcdb72d781314b2d3af865b8950d89145d7bb342561ecf84dceef", 30768, -0.4772096282332541, 9831.483205444565, 4147.546523482862, 0.9],
	"tool twang": ["20d34448ba59d4b95583965e8fc3790d3fc22bac5b10cdbe891d897d11a64710", 26460, 24.814842327844637, 2912.10030095212, 842.5048904377996, 0.9],
	"voice sable": ["f3fb1e2fe37726b61ba02d58b47473934606975ba66b76e31066c81870acb1a3", 55926, 1.6696154720746108, 4553.639213411026, 1309.1234611179714, 1.0593032],
"at build_riser boss": ["6189e9e64184a8939a1336bb493e0bfebc30c05230c5645eee5a4e2d790a7d6a", 164096, 1.1516175249364733, 10096.523992118147, 1972.6436635467653, 0.9],
}

var _t := T.new("sound_render_pin_test")


func _initialize() -> void:
	_check_compare_fails_closed()
	_check_render_inputs_are_not_shared()
	var got := _renders()
	_t.check("the render spread is not empty", got.size() >= 20, "%d renders" % got.size())
	var labels: Array = got.keys()
	labels.sort()
	var pinned: Array = PINS.keys()
	pinned.sort()
	_t.eq("the rendered labels equal the pinned labels", labels, pinned)
	var exact := platform() == RECORDED_ON
	if not exact:
		_t.skip("every render matches its pin byte for byte", "the pins were recorded on %s and this is %s" % [RECORDED_ON, platform()])
	for label in labels:
		var row := stats(got[label])
		if not PINS.has(label):
			print("PIN \"%s\": %s," % [label, var_to_str(row)])
			_t.check(label + " has a pin", false, "paste the PIN line above into PINS")
			continue
		var fault := compare(row, PINS[label], exact)
		_t.check(label + " renders as pinned", fault == "", fault)
	quit(_t.verdict())


func _check_render_inputs_are_not_shared() -> void:
	var found := SourceScan.captures(_t, ["res://src/presentation"], STATIC_VAR)
	for path in SHARED_STATICS:
		var names: Array = []
		for row in found.get(path, []):
			names.append(row[1])
		_t.eq(path.get_file() + " keeps only its caches, locks and cancel flag in statics", names, SHARED_STATICS[path])


static func platform() -> String:
	return "%s %s" % [OS.get_name(), Engine.get_architecture_name()]


func _renders() -> Dictionary:
	var boss := Harmony.BOSS_STEP
	var home := Harmony.STEP
	var quote := SfxBank.pilot_quote_id("sable")
	var answer: String = SfxBank.SET_ANSWER + String(SetDirector.BOOK["lull"][0]["id"])
	return {
		"samples event_start": SfxBank.samples("event_start"),
		"samples hold_pit": SfxBank.samples("hold_pit"),
		"samples crater_hold": SfxBank.samples("crater_hold"),
		"samples find_radio": SfxBank.samples("find_radio"),
		"samples ceremony_build": SfxBank.samples("ceremony_build"),
		"samples rivet_hihat_roll": SfxBank.samples("rivet_hihat_roll"),
		"samples tarn_hihat_roll": SfxBank.samples("tarn_hihat_roll"),
		"samples kest_hihat_roll": SfxBank.samples("kest_hihat_roll"),
		"samples sable_break": SfxBank.samples("sable_break"),
		"samples plate_tally": SfxBank.samples("plate_tally"),
		"samples klaxon": SfxBank.samples("klaxon"),
		"samples gates_open": SfxBank.samples("gates_open"),
		"at gates_open boss": SfxBank.samples_at("gates_open", boss),
		"at klaxon boss -3": SfxBank.samples_at("klaxon", boss, -3),
		"at class_up boss +2": SfxBank.samples_at("class_up", boss, 2),
		"at class_down boss -5": SfxBank.samples_at("class_down", boss, -5),
		"at warden_theme_in boss": SfxBank.samples_at("warden_theme_in", boss),
		"at stinger_world_up5 boss +1": SfxBank.samples_at("stinger_world_up5", boss, 1),
		"at stinger_unseal boss +5": SfxBank.samples_at("stinger_unseal", boss, 5),
		"at build_riser boss": SfxBank.samples_at("build_riser", boss),
		"at music_pressure boss": SfxBank.samples_at("music_pressure", boss),
		"at threat_up home +4": SfxBank.samples_at("threat_up", home, 4),
		"at event_start home +3": SfxBank.samples_at("event_start", home, 3),
		"at hold_pit boss +2": SfxBank.samples_at("hold_pit", boss, 2),
		"at plate_tally home +3": SfxBank.samples_at("plate_tally", home, 3),
		"at stinger_clear boss +2": SfxBank.samples_at("stinger_clear", boss, 2),
		"at pilot quote boss +1": SfxBank.samples_at(quote, boss, 1),
		"at set answer boss": SfxBank.samples_at(answer, boss),
		"synergy score theme 1": _synergy_score(1),
		"synergy score theme 2": _synergy_score(2),
		"tally clip 62": SfxBank.new().tally_recipe("clip_tally", 62),
		"tally plate 50 total": SfxBank.new().tally_recipe("plate_tally", 50, true),
		"tool hold crater": SfxBank.new().hold("crater", home * Harmony.STEPS_PER_BEAT * 2),
		"tool bite 1": SfxBank.new().bite(1),
		"tool crack 0": SfxBank.new().crack(0),
		"tool twang": SfxBank.new().twang(),
		"bare score": Synth.render_score(BARE, 0.4),
		"bare score boss +3": _bare_at(boss, 3),
		"voice sable": VoiceSynth._say("sable", "Quick sync."),
	}


const BARE := [[0, 62, 2, "keys", 0.6], [2, 0, 2, "kick", 1.0], [2, 69, 4, "bell", 0.5]]


func _synergy_score(theme: int) -> PackedFloat32Array:
	return Synth.render_score(SfxBank.new(Harmony.STEP, 0, theme)._score_synergy(), 1.4)


func _bare_at(step: int, transpose: int) -> PackedFloat32Array:
	return Synth.render_score(BARE, 0.4, step, transpose)


static func stats(buf: PackedFloat32Array) -> Array:
	if buf.is_empty():
		return []
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf.to_byte_array())
	var sum := 0.0
	var mag := 0.0
	var energy := 0.0
	var peak := 0.0
	for x in buf:
		sum += x
		mag += absf(x)
		energy += x * x
		peak = maxf(peak, absf(x))
	return [ctx.finish().hex_encode(), buf.size(), sum, mag, energy, peak]


static func compare(got: Array, want: Array, exact: bool) -> String:
	if got.size() != 6:
		return "rendered nothing"
	if want.size() != 6:
		return "the pin row has %d fields, not 6" % want.size()
	if int(got[1]) != int(want[1]):
		return "%d samples, pinned %d" % [got[1], want[1]]
	if exact:
		return "" if String(got[0]) == String(want[0]) else "hash %s, pinned %s" % [got[0], want[0]]
	var names := ["", "", "sum", "magnitude", "energy", "peak"]
	for i in range(2, 6):
		var allowed := REL_TOL * absf(float(want[3])) + ABS_TOL if i < 5 else REL_TOL
		if absf(float(got[i]) - float(want[i])) > allowed:
			return "%s %.9f, pinned %.9f within %.9f" % [names[i], got[i], want[i], allowed]
	return ""


func _check_compare_fails_closed() -> void:
	var buf := PackedFloat32Array([0.0, 0.25, -0.5, 0.125])
	var pin := stats(buf)
	_t.check("compare passes a render against its own pin, exact and tolerant", compare(pin, pin, true) == "" and compare(pin, pin, false) == "")
	_t.check("compare fails an empty render", compare(stats(PackedFloat32Array()), pin, true) != "" and compare(stats(PackedFloat32Array()), pin, false) != "")
	_t.check("compare fails a short pin row", compare(pin, pin.slice(0, 5), true) != "" and compare(pin, [], false) != "")
	var longer := buf.duplicate()
	longer.append(0.0)
	_t.check("compare fails a different sample count", compare(stats(longer), pin, true) != "" and compare(stats(longer), pin, false) != "")
	var nudged := buf.duplicate()
	nudged[1] += 1e-6
	_t.check("an exact compare fails a one-sample nudge that a tolerant compare allows", compare(stats(nudged), pin, true) != "" and compare(stats(nudged), pin, false) == "")
	var moved := buf.duplicate()
	moved[1] += 0.05
	_t.check("a tolerant compare fails a real change", compare(stats(moved), pin, false) != "")
