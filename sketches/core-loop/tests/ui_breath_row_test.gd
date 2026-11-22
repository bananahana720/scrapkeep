extends SceneTree
# smoke: solo (audio.gd static _baked persists across warm-batch tests and can trigger title ACE load before boot pins ace_manifest; needs Audio.reset_for_tests() from Sound thread)

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")

# The ACE music in the game (--music=ace), driven by real keys and clicks:
#   - a missing package falls back to the synth: one warning names the file, the band
#     stays unmuted and the game plays on;
#   - with the package, stage 1 starts the ACE band and mutes the synth band;
#   - the settings page's B (the title carries no Breath button) and the pause menu's Breath row cycle raw, hard, gentle, and the
#     sequencer's style follows; with --music=synth the row is hidden;
#   - the launch flags parse (--music=ace --breath=raw), and keyed SFX read the ACE key;
#   - the game's Warden facts reach the sequencer through the audio director:
#     warden_engaged pivots, beacon_unsealed starts the set piece;
#   - stage 2 leaves the set piece for its own track (Cable Reach), even from
#     inside the set piece; back on stage 1 the ACE band returns;
#   - a death stops the ACE band and unmutes the synth band in the same frame, so the
#     death boom is not dropped.
# Without the packaged Oggs (tools/ace/package_music.py) the ACE checks SKIP.

const CALM_BUDGET := 40
const SETTLE := 0.45

var _game
var _menu
var _audio
var _failures := 0
var _phase := "boot"
var _clock := 0.0
var _packaged := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _next(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	if _clock < SETTLE and _phase != "boot":
		return false
	match _phase:
		"boot":
			_menu = _game.get_node("PauseMenu")
			_audio = _game.presentation.audio
			_game.dev = true  # the pause menu's Breath row is a --dev lab row since wave 36 (the column is six rows)
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_packaged = _audio.AceSequencer.new().ready()
			_game.tuning.set_option(Tuning.MUSIC_KEY, "ace")
			_game.screens._on_flow_changed("title")
			_audio.ace_manifest = "res://tests/no_such_package/manifest.json"
			_next("title")
		"title":
			var on_title: bool = _game.screens.button_for("breath") == null
			_game.screens.toggle_settings()
			var button: Button = _game.screens.button_for("breath")
			var before: String = button.text if button != null else ""
			_game._screen_key(KEY_B)
			var after: String = button.text if button != null else ""
			_report("settings B", on_title and before == "Breath hard" and after == "Breath gentle" and _game.tuning.option(Tuning.BREATH_KEY) == "gentle",
				"the title has no Breath button; with music ace the settings page shows %s; B made it %s" % [before, after])
			_game.screens.toggle_settings()
			Push.click(root, _game.screens.button_for("start"))
			_next("class")
		"class":
			Push.click(root, _game.screens.class_cards()[0])
			_next("fallback")
		"fallback":
			if not _audio.sound_ready or not _audio._flow_queue.is_empty():
				return false
			_report("missing package falls back", _game.flow.in_play() and _game.run.stage == 1 and _audio.ace == null
					and _audio.ace_missing.ends_with("no_such_package/manifest.json") and not _audio.engine.band_muted and _audio.engine.grid == null,
				"in play at stage %d; ACE loaded %s, missing %s; synth band muted %s" % [_game.run.stage, _audio.ace != null, _audio.ace_missing, _audio.engine.band_muted])
			if not _packaged:
				print("[ace package] not packaged; run tools/ace/package_music.py -> SKIP")
				_next("synth")
				return false
			_audio.ace_manifest = _audio.AceSequencer.MANIFEST
			_audio._ace_failed = false
			_game.flow.enter_stage(1, _game.ctx.terrain.spawn_point(1), true)
			_next("ace_on")
		"ace_on":
			var ace = _audio.ace
			# The synth band fades out over STOP_RAMP after the ACE band's first fade-in.
			if ace == null or ace.section == "" or not _audio.engine.band_muted:
				if _clock < 5.0:
					return false
			_report("stage 1 plays ACE", ace != null and ace.mode == "level" and ace.section in ["calm", "travel"] and _audio.engine.band_muted
					and _audio.engine.grid == ace and ace.breath == "gentle" and ace.clock == _audio.engine.clock,
				"ACE %s in %s, section %s, breath %s; synth band muted %s; clocks %s / %s" % [ace != null, ace.mode if ace else "-",
				ace.section if ace else "-", ace.breath if ace else "-", _audio.engine.band_muted, ace.clock if ace else -1, _audio.engine.clock])
			Push.key(root, KEY_P)
			_next("row")
		"row":
			var row: Button = _menu.row("breath")
			var shown: bool = _menu.is_open() and row.visible and _menu.read("breath")["value"] == "gentle"
			var words: int = WordBudget.count(_menu)["hud"]
			Push.key(root, KEY_B)
			var by_b: String = _menu.read("breath")["value"]
			var ace_b: String = _audio.ace.breath if _audio.ace != null else "-"
			Push.click(root, row)
			var by_click: String = _menu.read("breath")["value"]
			var ace_click: String = _audio.ace.breath if _audio.ace != null else "-"
			Push.key(root, KEY_B)
			var back: String = _menu.read("breath")["value"]
			var ace_back: String = _audio.ace.breath if _audio.ace != null else "-"
			_report("pause row cycles the style", shown and by_b == "raw" and ace_b == "raw" and by_click == "hard"
					and ace_click == "hard" and back == "gentle" and ace_back == "gentle" and _game.tuning.option(Tuning.BREATH_KEY) == "gentle"
					and words <= CALM_BUDGET,
				"open with the row shown %s (%d words, budget %d); B made it %s (sequencer %s), a click %s (sequencer %s), B again %s (sequencer %s)" % [
				shown, words, CALM_BUDGET, by_b, ace_b, by_click, ace_click, back, ace_back])
			Push.key(root, KEY_P)
			_next("wiring")
		"wiring":
			var parsed: Dictionary = _game.tuning.apply_args(PackedStringArray(["--music=ace", "--breath=raw"]), "launch")
			var flags_ok: bool = parsed == {"music": "ace", "breath": "raw"} and _game.tuning.option(Tuning.BREATH_KEY) == "raw"
			_audio.set_breath("gentle")
			var ace = _audio.ace
			var key_ok: bool = ace.key_log.size() > 0 and _audio.live_key() == 0 and _audio.engine.grid == ace
			_report("flags and key", flags_ok and key_ok,
				"apply_args gave %s; ACE key log %s, live key %d (D = 0), engine grid is ACE %s" % [parsed, ace.key_log, _audio.live_key(), _audio.engine.grid == ace])
			var events = _game.events
			events.warden_engaged.emit(1)
			var engaged: bool = ace.mode == "warden" and ace.pending.get("section", "") == "pivot"
			events.beacon_unsealed.emit(1)
			_report("Warden facts reach the sequencer", engaged,
				"warden_engaged: mode %s, pivot pending %s" % [ace.mode, engaged])
			_next("unseal")
		"unseal":
			var ace = _audio.ace
			if ace.mode != "piece" and _clock < 2.0:
				return false
			_report("beacon_unsealed starts the set piece", ace.mode == "piece",
				"after the unseal: mode %s" % [ace.mode])
			_game.flow.enter_stage(2, _game.ctx.terrain.spawn_point(2), false)
			_next("stage2")
		"stage2":
			if not _audio._flow_queue.is_empty():
				return false
			var ace = _audio.ace
			# Since the dress push every alpha stage has its own track: stage 2 leaves the
			# set piece for a level band instead of handing back to the synth. This test pinned
			# ace_manifest above, and a pinned manifest is kept, so it checks the row, not the file
			# (audio_worlds_test covers the real per-stage switch).
			if (ace.mode != "level" or not _audio.engine.band_muted) and _clock < 5.0:
				return false
			_report("stage 2 leaves the set piece for its own row's band", _game.run.stage == 2 and ace.mode == "level" and _audio.engine.band_muted
					and _audio._ace_package_for(2) == "cable_reach",
				"stage %d: ACE mode %s, synth band muted %s, row package %s" % [_game.run.stage, ace.mode, _audio.engine.band_muted, _audio._ace_package_for(2)])
			_game.flow.enter_stage(1, _game.ctx.terrain.spawn_point(1), true)
			_next("back1")
		"back1":
			var ace = _audio.ace
			if (ace.section == "" or not _audio.engine.band_muted) and _clock < 5.0:
				return false
			var back_ok: bool = ace.mode == "level" and ace.section in ["calm", "travel"] and _audio.engine.band_muted
			_audio._flow_queue.append(["dead"])
			_audio._flush_flow()
			_report("stage 1 again, then a death unmutes the synth at once", back_ok and ace.mode == "off" and not _audio.engine.band_muted and _audio.engine.grid == null,
				"back on stage 1: %s; after the death flush: ACE mode %s, synth band muted %s" % [back_ok, ace.mode, _audio.engine.band_muted])
			_next("synth")
		"synth":
			_game.tuning.set_option(Tuning.MUSIC_KEY, "synth")
			Push.key(root, KEY_P)
			_next("hidden")
		"hidden":
			var row: Button = _menu.row("breath")
			_report("row hidden with the synth", _menu.is_open() and not row.visible, "music synth: pause open %s, Breath row shown %s" % [_menu.is_open(), row.visible])
			Push.key(root, KEY_P)
			print("ui_breath_row_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
	return false
