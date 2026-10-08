extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("companion_primer_expiry_test")


func _initialize() -> void:
	_run.call_deferred()


func _settle(body) -> void:
	body._anim.advance(body._anim.current_animation_length + 0.1)
	body._anim.stop()


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
	_t.eq("prime plays primer_set", String(body._anim.current_animation), "primer_set")
	_settle(body)
	combat._clock = 1.0
	_t.eq("ram consumes the prime", combat._primer_hit(enemy, "ram", "contact", result), "primer_coil")
	body._beats()
	_t.eq("consume plays primer_consume, not primer_expire", String(body._anim.current_animation), "primer_consume")
	_settle(body)
	body._beats()
	_t.check("consume cue does not replay", String(body._anim.current_animation) != "primer_consume" and not body._anim.is_playing(), "")
	combat._clock = 10.0
	combat._primer_hit(enemy, "runner", "weapon", result)
	body._beats()
	_settle(body)
	combat._clock = 12.9
	body._beats()
	_t.check("the window still open plays no expiry", String(body._anim.current_animation) != "primer_expire" and not body._anim.is_playing(), "")
	combat._clock = 13.1
	body._beats()
	_t.eq("the window ending unused plays primer_expire", String(body._anim.current_animation), "primer_expire")
	_settle(body)
	body._beats()
	_t.check("expiry cue fires once", String(body._anim.current_animation) != "primer_expire" and not body._anim.is_playing(), "")
	enemy.free()
	game.free()
	quit(_t.verdict())
