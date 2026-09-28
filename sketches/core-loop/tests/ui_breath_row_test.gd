extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")

# The ACE music in the game (--music=ace), driven by real keys and clicks:
#   - a missing package falls back to the synth: one warning names the file, the band
#     stays unmuted and the game plays on;
#   - with the package, stage 1 starts the ACE band and mutes the synth band;
#   - the title's B and the pause menu's Breath row cycle raw, hard, gentle, and the
#     sequencer's style follows; with --music=synth the row is hidden;
#   - the launch flags parse (--music=ace --breath=raw), and keyed SFX read the ACE key;
#   - the game's Warden facts reach the sequencer through the audio director:
#     warden_engaged pivots, warden_state_changed moves the state, warden_drop_landed
#     drops on the next beat (logged in drop_log), beacon_unsealed starts the set piece;
#   - stage 2 hands back to the synth at once (band unmuted, no ACE grid), even from
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
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_packaged = _audio.AceSequencer.new().ready()
			_game.tuning.set_option(LoopMode.MUSIC_KEY, "ace")
			_game.screens._on_flow_changed("title")
			_audio.ace_manifest = "res://tests/no_such_package/manifest.json"
			_next("title")
		"title":
			var button: Button = _game.screens.button_for("breath")
			var before: String = button.text if button != null else ""
			_game._screen_key(KEY_B)
			var after: String = button.text if button != null else ""
			_report("title B", before == "Breath: hard" and after == "Breath: gentle" and _game.tuning.option(LoopMode.BREATH_KEY) == "gentle",
				"with music ace the title shows %s; B made it %s" % [before, after])
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
			var shown: bool = _menu.is_open() and row.visible and row.text == "Breath: gentle"
			var words: int = WordBudget.count(_menu)["hud"]
			Push.key(root, KEY_B)
			var by_b: String = row.text
			var ace_b: String = _audio.ace.breath if _audio.ace != null else "-"
			Push.click(root, row)
			var by_click: String = row.text
			var ace_click: String = _audio.ace.breath if _audio.ace != null else "-"
			Push.key(root, KEY_B)
			var back: String = row.text
			var ace_back: String = _audio.ace.breath if _audio.ace != null else "-"
			_report("pause row cycles the style", shown and by_b == "Breath: raw" and ace_b == "raw" and by_click == "Breath: hard"
					and ace_click == "hard" and back == "Breath: gentle" and ace_back == "gentle" and _game.tuning.option(LoopMode.BREATH_KEY) == "gentle"
					and words <= CALM_BUDGET,
				"open with the row shown %s (%d words, budget %d); B made it %s (sequencer %s), a click %s (sequencer %s), B again %s (sequencer %s)" % [
				shown, words, CALM_BUDGET, by_b, ace_b, by_click, ace_click, back, ace_back])
			Push.key(root, KEY_P)
			_next("wiring")
		"wiring":
			var parsed: Dictionary = LoopMode.apply_args(_game.tuning, PackedStringArray(["--music=ace", "--breath=raw"]))
			var flags_ok: bool = parsed == {"music": "ace", "breath": "raw"} and _game.tuning.option(LoopMode.BREATH_KEY) == "raw"
			_audio.set_breath("gentle")
			var ace = _audio.ace
			var key_ok: bool = ace.key_log.size() > 0 and _audio.live_key() == 0 and _audio.engine.grid == ace
			_report("flags and key", flags_ok and key_ok,
				"apply_args gave %s; ACE key log %s, live key %d (D = 0), engine grid is ACE %s" % [parsed, ace.key_log, _audio.live_key(), _audio.engine.grid == ace])
			var events = _game.events
			events.warden_engaged.emit(1)
			var engaged: bool = ace.mode == "warden" and ace.pending.get("section", "") == "pivot"
			events.warden_state_changed.emit("telegraph", Vector3.ZERO)
			var state_ok: bool = ace.warden_state == "telegraph"
			var drops_before: int = _audio.drop_log.size()
			events.warden_drop_landed.emit(Vector3.ZERO, 20.0, 3, 4)
			var dropped: bool = ace.pending.get("section", "") == "drop" and _audio.drop_log.size() == drops_before + 1 \
				and int(_audio.drop_log[-1][1]) > ace.clock
			events.beacon_unsealed.emit(1)
			_report("Warden facts reach the sequencer", engaged and state_ok and dropped,
				"warden_engaged: mode %s, pivot pending %s; warden_state_changed: state %s; warden_drop_landed: drop pending %s, drop_log %d -> %d" % [
				ace.mode, engaged, ace.warden_state, dropped, drops_before, _audio.drop_log.size()])
			_next("unseal")
		"unseal":
			var ace = _audio.ace
			if ace.mode != "piece" and _clock < 2.0:
				return false
			_report("beacon_unsealed starts the set piece", ace.mode == "piece" and ace.piece_after_drop,
				"after the unseal: mode %s, waiting for the drop's end %s" % [ace.mode, ace.piece_after_drop])
			_game.flow.enter_stage(2, _game.ctx.terrain.spawn_point(2), false)
			_next("stage2")
		"stage2":
			if not _audio._flow_queue.is_empty():
				return false
			var ace = _audio.ace
			_report("stage 2 plays the synth", _game.run.stage == 2 and ace.mode == "off" and not _audio.engine.band_muted and _audio.engine.grid == null
					and not _audio.ace_playing(),
				"stage %d: ACE mode %s, synth band muted %s, ACE grid %s" % [_game.run.stage, ace.mode, _audio.engine.band_muted, _audio.engine.grid != null])
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
			_game.tuning.set_option(LoopMode.MUSIC_KEY, "synth")
			Push.key(root, KEY_P)
			_next("hidden")
		"hidden":
			var row: Button = _menu.row("breath")
			_report("row hidden with the synth", _menu.is_open() and not row.visible, "music synth: pause open %s, Breath row shown %s" % [_menu.is_open(), row.visible])
			Push.key(root, KEY_P)
			print("ui_breath_row_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
	return false
