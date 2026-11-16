extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

# The demo-spec rows through presentation. Every new sound id bakes a non-silent
# stream; clank is not hit_thwack; a heft class reached mid-bar starts its three-note
# stinger on a beat boundary; each new fact reaches the cue its row names, now or on
# the beat; a bonus core warms the band; a discovery gets its fanfare, banner and
# ring; the outline stays the collider's size at every heft class. Signals the
# bus does not carry yet are added locally, the way the spine will add them.

const NEW_SOUNDS := ["stinger_unseal", "class_up", "clank", "scrap_rip", "threat_up", "core_socket", "synergy_fanfare",
	"found_chime", "element_resolved", "ice_form", "zap_hum", "shatter"]
const SIGNALS := {
	"beacon_unsealed": [["stage", TYPE_INT]],
	"heft_class_changed": [["heft_class", TYPE_INT], ["heft", TYPE_FLOAT]],
	"scrap_lost": [["amount", TYPE_INT], ["at", TYPE_VECTOR3], ["total", TYPE_INT], ["cause", TYPE_STRING]],
	"strike_deflected": [["enemy", TYPE_OBJECT], ["kind", TYPE_STRING], ["punch", TYPE_FLOAT], ["plating", TYPE_FLOAT]],
	"threat_rose": [["tier", TYPE_INT]],
	"core_gained": [["source", TYPE_STRING], ["at", TYPE_VECTOR3], ["count", TYPE_INT]],
	"synergy_discovered": [["id", TYPE_STRING], ["category", TYPE_STRING], ["first_time", TYPE_BOOL]],
	"interaction_found": [["description", TYPE_STRING]],
	"element_resolved": [["element", TYPE_STRING], ["material", TYPE_STRING], ["behaviour", TYPE_STRING], ["at", TYPE_VECTOR3]],
}

var _game
var _audio
var _failures := 0
var _step := 0
var _wait_until := 0
var _asked_at := 0
var _beat_origin := 0
var _beat_frames := 0
var _radius_before := 0.0


func _initialize() -> void:
	var silent: Array = []
	for id in NEW_SOUNDS:
		var wav := SfxBank.stream(id)
		var peak := Synth.wav_peak(wav)
		if peak < 0.1 or not SfxBank.has_recipe(id):
			silent.append("%s %.2f" % [id, peak])
	_check("new sounds baked", silent.is_empty(), "%d new sound ids baked non-silent from their own recipes; failing %s" % [NEW_SOUNDS.size(), silent])
	var clank := SfxBank.samples("clank")
	var thwack := SfxBank.samples("hit_thwack")
	var corr := _correlation(clank, thwack)
	var clank_hz := _pitch(clank)
	var thwack_hz := _pitch(thwack)
	var clank_tail := _tail(clank)
	var thwack_tail := _tail(thwack)
	_check("clank is not thwack", absf(corr) < 0.3 and clank_tail > thwack_tail * 3.0 and absf(clank_hz - thwack_hz) > 0.4 * minf(clank_hz, thwack_hz),
		"correlation %.2f; the clank rings (energy after 80 ms %.0f%% vs %.0f%%) at %.0f Hz against the punch's %.0f Hz" % [corr, clank_tail * 100.0, thwack_tail * 100.0, clank_hz, thwack_hz])
	var style: Dictionary = load("res://src/presentation/codex_style.gd").style()
	var icons_ok := true
	for id in ["build", "world", "enemy", "npc", "coop"]:
		var cat: Dictionary = style["categories"].get(id, {})
		icons_ok = icons_ok and cat.get("color") is Color and cat.get("icon") is ImageTexture and (cat["icon"] as ImageTexture).get_width() == 64
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_check("codex style", icons_ok and style.get("banner_script") is Script, "5 categories, each with a colour and a 64 px icon, plus the banner script")


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	if Time.get_ticks_msec() < _wait_until:
		return false
	var events = _game.events
	var engine: MusicEngine
	if _audio != null:
		engine = _audio.engine
	match _step:
		0:
			_game.tuning.set_option("music", "synth")
			_audio = _game.presentation.audio
			_audio.bake_now()
			for name in SIGNALS:
				if not events.has_signal(name):
					var args := []
					for arg in SIGNALS[name]:
						args.append({"name": arg[0], "type": arg[1]})
					events.add_user_signal(name, args)
			_game.presentation.wire_optional()
			_radius_before = _collider_radius()
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next(700)
		1:
			engine = _audio.engine
			# Wait for a play head that sits mid-bar, well away from a beat.
			_beat_origin = engine.grid.origin if engine.grid != null else engine.bar_origin
			_beat_frames = engine.grid.grid_beat if engine.grid != null else engine.beat_len()
			var bar: int = engine.grid.grid_bar if engine.grid != null else engine.bar_len()
			var in_bar := posmod(engine.clock - _beat_origin, bar)
			var in_beat := posmod(engine.clock - _beat_origin, _beat_frames)
			if in_bar < _beat_frames or in_beat < _beat_frames / 4 or in_beat > _beat_frames * 3 / 4:
				return false
			_audio.cue_log.clear()
			_asked_at = engine.clock
			events.emit_signal("heft_class_changed", 2, 1.6)
			_next(600)
		2:
			var starts: Array = engine.stinger_starts.filter(func(s: Array): return s[0] == "class_up")
			var start: int = starts[0][1] if starts.size() > 0 else -1
			var off := posmod(start - _beat_origin, _beat_frames)
			var on_beat := start > _asked_at and (off <= 1 or off >= _beat_frames - 1) and start - _asked_at <= _beat_frames
			_check("class up on the beat", on_beat, "asked mid-bar at sample %d (%.2f into its beat), stinger started at %d, %d frames off the beat" % [_asked_at, float(posmod(_asked_at - _beat_origin, _beat_frames)) / _beat_frames, start, mini(off, _beat_frames - off)])
			var juice = _game.presentation.juice
			_check("class up juice", _logged(juice, "class_up") and is_equal_approx(juice.shell_target(), 1.0) and _game.presentation.vfx.spawned.get("heft_class_changed", 0) >= 1,
				"squash-pop, a ripple ring and a shell target of %.2f" % juice.shell_target())
			_audio.cue_log.clear()
			var dummy := Node3D.new()
			_game.add_child(dummy)
			events.emit_signal("scrap_lost", 20, Vector3.ZERO, 5, "crane")
			events.emit_signal("strike_deflected", dummy, "ram", 20.0, 60.0)
			events.emit_signal("threat_rose", 1)
			events.emit_signal("core_gained", "vault", Vector3.ZERO, 1)
			events.emit_signal("interaction_found", "frost then kinetic")
			events.emit_signal("element_resolved", "frost", "water", "freeze", Vector3.ZERO)
			_audio._last_start.clear()
			events.emit_signal("element_resolved", "arc", "water", "electrify", Vector3.ZERO)
			_audio._last_start.clear()
			events.emit_signal("element_resolved", "kinetic", "ice", "shatter", Vector3.ZERO)
			var want := [["scrap_lost", "scrap_rip", "now"], ["strike_deflected", "clank", "now"], ["threat_rose", "threat_up", "beat"],
				["core_gained", "core_socket", "now"], ["interaction_found", "found_twinkle", "now"]]
			var missing: Array = []
			for w in want:
				if _audio.cue_log.filter(func(c: Array): return c[0] == w[0] and c[1] == w[1] and c[2] == w[2]).is_empty():
					missing.append(w[0])
			_check("rows reach cues", missing.is_empty(), "scrap_rip, clank and core_socket now; threat_up on the beat; found_twinkle now; missing %s" % [missing])
			var elements: Array = _audio.cue_log.filter(func(c: Array): return c[0] == "element_resolved").map(func(c: Array): return c[1])
			_check("element voices", elements == ["ice_form", "zap_hum", "shatter"], "freeze, electrify and shatter pick %s" % [elements])
			_check_overcharge(engine)
			events.emit_signal("synergy_discovered", "storm_lattice", "build", true)
			events.emit_signal("beacon_unsealed", 1)
			_next(600)
		3:
			var fanfare: Array = _audio.cue_log.filter(func(c: Array): return c[0] == "synergy_discovered" and c[1] == "synergy_fanfare" and c[2] == "beat")
			var banner = _game.presentation.banner
			_check("discovery moment", fanfare.size() == 1 and banner.shown == 1 and _game.presentation.vfx.ring_count() == 1,
				"the fanfare on the beat, the banner '%s', and one ring on the ball" % banner.last_title)
			var unseal: Array = _audio.cue_log.filter(func(c: Array): return c[0] == "beacon_unsealed" and c[1] == "stinger_unseal" and c[2] == "beat")
			var stop: Array = _game.presentation.juice.hit_stop_log.filter(func(e: Array): return e[2] == "beacon_unsealed")
			_check("unseal", unseal.size() == 1 and stop.size() == 1 and _game.presentation.vfx.spawned.get("beacon_unsealed", 0) >= 2,
				"the unseal stinger on the beat, a hit-stop request and a flash over the beacon")
			# The shell is read at rest. The ball is live: the scrap lost above kicked the shell's
			# spring (-0.22, still 1.02x 600 ms on, this check's old limit) and every piece of scrap
			# it rolls over kicks it again (0.05 and up), so the value passed or failed on the frame it
			# was read. Two seconds of the spring's own frames, with nothing between them, is rest.
			var springs = _game.presentation.juice
			for _i in 240:
				springs._process(1.0 / 120.0)
			var grown: float = springs.shell
			_check("outline stays the collider", absf(grown - 1.0) < 0.005 and is_equal_approx(_collider_radius(), _radius_before), "the shell reads %.2fx at heft II (fixed outline, no whole-ball growth); the collider radius stays %.2f m" % [grown, _collider_radius()])
			events.emit_signal("stage_entered", 1, true)
			_check("overcharge resets", engine.overcharge == 0, "a stage entry clears the warm pad")
			print("presentation_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			_game = null
			quit(0 if _failures == 0 else 1)
			return true
	return false


# 2026-10-13: KE10 merge f725a69, K-UNITS.md:368 strips low armour to drums/bass.
# Its music_params_test.gd:51-54 guards that phrase mask. The core count survives it.
func _check_overcharge(engine: MusicEngine) -> void:
	_audio.set_process(false)
	var skip := engine.bot_skip_samples
	engine.bot_skip_samples = true
	_game.run.armor_mode = true
	_game.run.mass = 20.0
	var phrase := engine.bar_len() * Harmony.PHRASE_BARS
	var origin := engine.grid_origin + ceili(float(engine.bar_origin - engine.grid_origin) / engine.step_len) * engine.step_len
	var boundary := origin + (floori(float(engine.clock - origin) / phrase) + 1) * phrase
	_advance(engine, boundary + 1)
	_check("low armour masks overcharge", engine.overcharge == 1
		and absf(float(engine.parameter_committed_values.get("armour", -1.0)) - 0.2) <= 0.0001
		and engine.layer_target(MusicEngine.WARM) == 0.0,
		"one bonus core remains stored while committed armour 0.2 strips the warm pad")
	_game.run.mass = 100.0
	_advance(engine, boundary + phrase)
	_check("warm pad waits for armour phrase", absf(float(engine.parameters.get("armour", -1.0)) - 1.0) <= 0.0001
		and absf(float(engine.parameter_committed_values.get("armour", -1.0)) - 0.2) <= 0.0001
		and engine.layer_target(MusicEngine.WARM) == 0.0,
		"recovered armour is sampled but the low-armour mask persists until the phrase")
	engine.render(1)
	_check("overcharge warms", engine.overcharge == 1
		and absf(engine.layer_target(MusicEngine.WARM) - 0.7) <= 0.0001
		and absf(float(engine.parameter_committed_values.get("armour", -1.0)) - 1.0) <= 0.0001,
		"one bonus core restores the existing 0.7 warm target at sample %d, got %.4f" % [boundary + phrase, engine.layer_target(MusicEngine.WARM)])
	_game.run.mass = 20.0
	_advance(engine, boundary + phrase * 2)
	_check("warm pad retains committed recovery", absf(engine.layer_target(MusicEngine.WARM) - 0.7) <= 0.0001,
		"pending armour loss cannot mute the warm pad early")
	engine.render(1)
	_check("low armour remasks warm pad on phrase", engine.overcharge == 1 and engine.layer_target(MusicEngine.WARM) == 0.0,
		"the phrase reapplies the armour mask without losing the core")
	engine.bot_skip_samples = skip
	_audio.set_process(true)


func _advance(engine: MusicEngine, at: int) -> void:
	while engine.clock < at:
		engine.render(mini(4096, at - engine.clock))


func _collider_radius() -> float:
	for child in _game.player.body().get_children():
		if child is CollisionShape3D and child.shape is SphereShape3D:
			return (child.shape as SphereShape3D).radius
	return -1.0


func _logged(juice, hook: String) -> bool:
	for entry in juice.hook_log:
		if entry[0] == hook:
			return true
	return false


static func _correlation(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var n := mini(a.size(), b.size())
	var ab := 0.0
	var aa := 0.0
	var bb := 0.0
	for i in n:
		ab += a[i] * b[i]
		aa += a[i] * a[i]
		bb += b[i] * b[i]
	return ab / maxf(sqrt(aa * bb), 0.000001)


# The dominant pitch just after the attack: the lag (1-10 ms) with the best
# normalized autocorrelation.
static func _pitch(buf: PackedFloat32Array) -> float:
	var start := 441
	var n := mini(2048, buf.size() - start - 441)
	var best := 0.0
	var best_lag := 44
	for lag in range(44, 441, 2):
		var ab := 0.0
		var aa := 0.0
		var bb := 0.0
		for i in n:
			var a := buf[start + i]
			var b := buf[start + i + lag]
			ab += a * b
			aa += a * a
			bb += b * b
		var score := ab / maxf(sqrt(aa * bb), 0.000001)
		if score > best:
			best = score
			best_lag = lag
	return Harmony.RATE / float(best_lag)


static func _tail(buf: PackedFloat32Array) -> float:
	var cut := int(0.08 * Harmony.RATE)
	var total := 0.0
	var late := 0.0
	for i in buf.size():
		total += buf[i] * buf[i]
		if i >= cut:
			late += buf[i] * buf[i]
	return late / maxf(total, 0.000001)


func _next(wait_ms: int) -> void:
	_step += 1
	_wait_until = Time.get_ticks_msec() + wait_ms


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
