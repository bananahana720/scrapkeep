extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("companion_primer_refresh_cue_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	await process_frame
	var body = game.presentation.get_node("CompanionBody")
	body.set_process(false)
	body.seat_for_capture("primer_coil", "ram_prow")
	body._process(0.0)
	var combat = game.combat
	combat.set_physics_process(false)
	var enemy = combat.spawn_enemy("chaser", Vector3(100, 20, 100))
	enemy.set_physics_process(false)
	var result := {"dealt": 1.0}
	combat._clock = 0.0
	combat._primer_hit(enemy, "runner", "weapon", result)
	body._beats()
	_t.eq("prime sets the cue", String(body._anim.current_animation), "primer_set")
	combat._clock = 2.0
	combat._primer_hit(enemy, "runner", "weapon", result)
	body._beats()
	_t.eq("refresh commits a five-second combat deadline", combat._primed[enemy.get_instance_id()], 5.0)
	# Reproduce the old first-prime wall-clock age without waiting in real time.
	if "_primed_at" in body:
		body._primed_at = -3.1
	combat._clock = 3.1
	_t.eq("ram consumes the refreshed prime", combat._primer_hit(enemy, "ram", "contact", result), "primer_coil")
	body._beats()
	_t.eq("refreshed prime plays consume rather than expire", String(body._anim.current_animation), "primer_consume")
	combat._clock = 6.0
	combat._primer_hit(enemy, "runner", "weapon", result)
	body._beats()
	combat._clock = 9.0
	body._beats()
	_t.eq("combat deadline expiry plays expire", String(body._anim.current_animation), "primer_expire")
	_t.eq("presentation leaves expired combat state untouched", combat._primed[enemy.get_instance_id()], 9.0)
	var other = combat.spawn_enemy("chaser", Vector3(110, 20, 100))
	other.set_physics_process(false)
	combat._clock = 10.0
	combat._primer_hit(enemy, "runner", "weapon", result)
	combat._primer_hit(other, "runner", "weapon", result)
	body._beats()
	combat._clock = 12.0
	combat._primer_hit(other, "runner", "weapon", result)
	body._beats()
	combat._clock = 13.1
	body._beats()
	combat._primer_hit(other, "ram", "contact", result)
	body._beats()
	_t.eq("last refreshed enemy consumes after the earlier enemy expires", String(body._anim.current_animation), "primer_consume")
	other.free()
	enemy.free()
	game.free()
	quit(_t.verdict())
