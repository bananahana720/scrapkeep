extends SceneTree

# Rule: real default-table stage entries choose the zone row's synth theme and ACE
# manifest together. Stage overrides must agree with the alpha's zone rows; swapping
# the zone themes must fail. This checks selection without requiring packaged Oggs.
const Game := preload("res://src/game.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Intent := preload("res://src/movement/intent.gd")

var _game
var _done := false
var _failures := 0


func _initialize() -> void:
	# Game.test_mode owns this process-specific subfolder and removes it on exit.
	var folder := "user://test-%d" % OS.get_process_id()
	var dir := DirAccess.open(folder)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.tuning.set_option(Tuning.MUSIC_KEY, "synth")
	var audio = _game.presentation.audio
	audio.set_process(false)
	audio.bake_now()
	_report("default alpha table", _game.ctx.stages == StageDefs and _game.ctx.stages.COUNT == StageDefs.COUNT, "%d-zone default table" % StageDefs.COUNT)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for stage in range(1, StageDefs.COUNT + 1):
		if stage > 1:
			_game.flow.enter_stage(stage, Vector3.ZERO, false)
		var world: int = StageDefs.world_of(stage)
		var theme := StageDefs.local(stage) - 1 if world == 1 else world - 1
		_check_stage(stage, theme, audio)
	_game.free()
	print("audio_music_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _check_stage(stage: int, theme: int, audio) -> void:
	var zone := MusicRows.zone_id(stage, _game.ctx.stages)
	var pack := MusicRows.resolve(zone)
	audio._flush_flow()
	_report("stage entered", _game.run.stage == stage and _game.flow.in_stage(), "stage %d" % stage)
	_report("alpha theme preserved", pack["synth_theme"] == theme, "%s theme %s, want %d" % [zone, pack["synth_theme"], theme])
	_report("audio theme uses zone row", audio._stage_theme(stage) == pack["synth_theme"], "%s audio %d, row %d" % [zone, audio._stage_theme(stage), pack["synth_theme"]])
	_report("audio manifest uses zone row", audio.ace_manifest == pack["ace_manifest"], "%s audio '%s', row '%s'" % [zone, audio.ace_manifest, pack["ace_manifest"]])
	var track: String = ["spillway", "cable_reach", "dig_upper", "dig_deep", "highdraft", "highdraft_crown"][stage - 1]
	var want_manifest := MusicRows.resolve_manifest("res://assets/music_ace/%s/manifest.json" % track)
	_report("alpha manifest selects zone track", audio.ace_manifest == want_manifest and want_manifest != "", "%s manifest '%s'" % [zone, audio.ace_manifest])
	_report("synth option keeps fallback active", not audio.ace_playing() and audio.engine.grid == null and not audio.engine.band_muted, zone)
	# Advance the band's sample clock to its queued restart, without a wall-clock wait.
	var at := -1
	for action in audio.engine._actions:
		if action["type"] == "restart":
			at = maxi(at, int(action["at"]))
	_report("entry schedules the band", at >= audio.engine.clock, "restart at %d, clock %d" % [at, audio.engine.clock])
	if at >= audio.engine.clock:
		audio.engine.render(at - audio.engine.clock + 1)
	_report("band plays row theme", audio.engine.theme == pack["synth_theme"], "%s band %d, row %d" % [zone, audio.engine.theme, pack["synth_theme"]])
