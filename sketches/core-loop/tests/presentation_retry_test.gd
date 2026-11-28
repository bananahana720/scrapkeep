extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

# Fix wave C3, through the real game on the dummy driver.
# - After a death in Brindle's arena, the retry brings the band back to play mode on
#   the boss track (drums, bass, lead), not the keys alone for the whole fight.
# - Arena entry clears the stage's overcharge pad.
# - Hit-stop reads the plating the hit resolved against: a stomp on a weak-point cap
#   (plating 0 there, 50 on the body) freezes harder than a body break-through (v3 W11:
#   weak points get the crit's stop).

class Capped extends Node3D:
	var part_hit := "cap"

	func plating_for(_kind: String, part: String) -> float:
		return 0.0 if part == "cap" else 50.0

	func contact_part(_at: Vector3, _kind: String) -> String:
		return part_hit

	func plating_now() -> float:
		return 50.0

	func take_damage(_amount: float) -> void:
		pass


var _game
var _audio
var _failures := 0
var _step := 0
var _wait_until := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _step < 4 and (_game == null or _game.flow == null):
		return false
	if Time.get_ticks_msec() < _wait_until:
		return false
	var engine: MusicEngine = _audio.engine if _audio != null else null
	match _step:
		0:
			_audio = _game.presentation.audio
			_audio.bake_now()
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next(900)
		1:
			engine.set_overcharge(2)
			_game.events.stage_content_cleared.emit("arena")
			var pad_cleared: bool = engine.overcharge == 0
			_check("arena clears the pad", pad_cleared, "stage_content_cleared resets the stage's overcharge pad (overcharge %d)" % engine.overcharge)
			_game.events.boss_arena_entered.emit()
			for i in 200:
				if engine.track == "brindle":
					break
				engine.render(engine.step_len)
			_game.events.player_died.emit()
			_next(50)
		2:
			engine.render(engine.beat_len() * 2)
			var dead: bool = engine.mode == MusicEngine.DEAD and engine.track == "brindle"
			_check("death drops the band", dead, "a death in the arena drops the band to the keys (mode %s)" % MusicEngine.MODE_NAMES[engine.mode])
			# R in the arena: flow goes back to boss, clears the stage content, and the
			# boss module re-enters the arena.
			_game.events.flow_changed.emit("boss")
			_game.events.stage_content_cleared.emit("arena")
			_game.events.boss_arena_entered.emit()
			engine.render(engine.beat_len() + 64)
			engine.render(engine.bar_len())
			var back: bool = engine.mode == MusicEngine.PLAY and engine.track == "brindle" and engine.section == "1" and engine.layer_target(MusicEngine.KICK) > 0.5 and engine.layer_target(MusicEngine.REESE) > 0.5
			_check("retry plays the fight", back, "after R the band is back in play mode on Brindle's phase 1 (mode %s, %s:%s, kick %.2f, bass %.2f)" % [MusicEngine.MODE_NAMES[engine.mode], engine.track, engine.section, engine.layer_target(MusicEngine.KICK), engine.layer_target(MusicEngine.REESE)])
			_next(50)
		3:
			var juice = _game.presentation.juice
			var resolver: Callable = juice.resolve_of
			var capped := Capped.new()
			_game.add_child(capped)
			juice.hit_stops.reset()
			_game.events.enemy_struck.emit(capped, "stomp", 40.0)
			juice.flush()
			var cap_stop: float = juice.hit_stops.entries.back()[0]
			juice.hit_stops.reset()
			capped.part_hit = ""
			var body: Dictionary = resolver.call(capped, "stomp", 40.0) if resolver.is_valid() else {}
			_game.events.enemy_struck.emit(capped, "stomp", 40.0)
			juice.flush()
			var body_stop: float = juice.hit_stops.entries.back()[0]
			var ok: bool = resolver.is_valid() and bool(body.get("full", false)) and cap_stop > body_stop and body_stop > 0.0
			_check("weak points freeze harder", ok, "a stomp on the cap (plating 0 where it landed, 50 on the body) asks for a %.0f ms stop; the body break-through (full %s) %.0f ms" % [cap_stop * 1000.0, body.get("full", "?"), body_stop * 1000.0])
			_game.free()
			_game = null
			_step = 4
			_wait_until = Time.get_ticks_msec() + 300
		4:
			print("presentation_retry_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _next(wait_ms: int) -> void:
	_step += 1
	_wait_until = Time.get_ticks_msec() + wait_ms


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
