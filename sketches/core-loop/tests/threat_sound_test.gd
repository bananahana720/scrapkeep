extends SceneTree

const Game := preload("res://src/game.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# A committed threat of each type plays exactly one warn sound, its row's, on the game
# frame it was declared and not on the beat. An owner voice layers on top of it. The
# player's own ring and a harmless field stay silent.

var _game
var _audio
var _failures := 0
var _step := 0
var _frame := 0
var _made := -1


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	_frame += 1
	if _game.flow == null:
		return false
	match _step:
		0:
			_audio = _game.presentation.audio
			_audio.bake_now()
			_game.ctx.calm = true
			_audio.cue_log.clear()
			_commit_all()
			_made = _frame
			_step = 1
		1:
			_check()
			print("threat_sound_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _commit_all() -> void:
	var ground = _game.ctx.terrain
	var at: Vector3 = _game.player.ball_position()
	Telegraph.ring(_game, ground, Threat.Type.INSTANT, at + Vector3(4.0, 0.0, 0.0), 5.0)
	var shell: Node3D = Telegraph.ring(_game, ground, Threat.Type.PROJECTILE, at + Vector3(-4.0, 0.0, 0.0), 3.6)
	shell.set_flight(at + Vector3(-14.0, 3.0, 0.0), Threat.lob_bump(26.0, 1.9))
	var lane: Node3D = Telegraph.lane(_game, ground, Threat.Type.LANE, at, Vector3.FORWARD, 11.0, 3.0)
	lane.owner_voice = "boss_telegraph"
	var sweep: Node3D = Hazard.new()
	sweep.ground = func(_p: Vector3) -> float: return at.y
	sweep.color = Palette.BRASS
	sweep.commit_sector("crane_test", Threat.Type.WAVE, at, Vector2(3.0, 20.0), 0.0, 1.2, 5.0, 1.4, 1.2)
	_game.add_child(sweep)
	Telegraph.ring(_game, ground, Threat.Type.PROJECTILE, at + Vector3(0.0, 0.0, 6.0), 3.6, 3.5, Palette.AMBER)
	Telegraph.ring(_game, ground, Threat.Type.INSTANT, at, 30.0, 8.0, Palette.SAND)


func _check() -> void:
	var counts := {}
	var timing := true
	for cue in _audio.cue_log:
		var kind: String = cue[0]
		if not kind in EventKinds.THREAT_ROWS:
			continue
		var key := "%s/%s" % [kind, cue[1]]
		counts[key] = int(counts.get(key, 0)) + 1
		timing = timing and cue[2] == "now"
	var want := {
		"threat_instant/threat_tick": 1,
		"threat_wave/threat_whoosh": 1,
		"threat_projectile/threat_whistle": 1,
		"threat_lane/threat_hum": 1,
		"threat_lane/boss_telegraph": 1,
	}
	var same := counts.size() == want.size()
	for key in want:
		same = same and int(counts.get(key, 0)) == want[key]
	_report("one warn each", same,
		"six threats committed (four hostile, one amber, one bone); the cue log holds %s, one row sound per hostile type plus the lane's owner voice" % [counts])
	_report("on the frame", timing and _frame == _made + 1,
		"every warn played now, not on the beat, and was logged before the frame after the threats were declared (committed frame %d, checked %d)" % [_made, _frame])
