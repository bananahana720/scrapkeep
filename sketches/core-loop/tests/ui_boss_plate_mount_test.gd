extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The HUD seats the boss plate itself (LEGIBILITY section 4):
# - on the slice, striking the posture Warden engages it and the plate goes up top-centre,
#   bound to that Warden, with the objective plate under it;
# - a retry takes it down, and engaging again puts it back;
# - breaking the Warden takes it down;
# - a rogue machine that wakes (world.gd _watch_rogue) with the slot free puts the plate up in the
#   Rogue's hand, stencilled with its crew number; an engaged Warden takes the plate from it and the
#   rogue does not take it back; the rogue's death takes its plate down.

var _t := T.new("ui_boss_plate_mount_test")
# F6 2026-10-04: the local plating row is gone; every Warden gets a plate.

var _game
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _start(table: String) -> Node3D:
	_game = Game.new()
	_game.test_mode = true
	if table != "":
		_game.table = table
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(36)
	_game.run.set_max_hp(99999.0)
	return _game.flow.warden


func _plates() -> Array:
	return _game.hud.get_children().filter(func(child): return child is BossPlate)


func _strike(warden: Node3D) -> void:
	_game.ctx.spawner.strike(warden, "ram", 1.0)
	await _frames(2)


func _slice() -> void:
	var warden: Node3D = await _start("slice")
	_t.check("the slice Warden fights by posture", is_instance_valid(warden) and warden.fight() == "posture")
	_t.eq("before the fight no plate is up", _plates().size(), 0)
	await _strike(warden)
	var up := _plates()
	_t.eq("striking the Warden puts one plate up", up.size(), 1)
	if up.size() == 1:
		var plate: Control = up[0]
		_t.check("it is bound to that Warden and shows its name", plate.active() and plate.drawn_words().size() > 0, "words %s" % [plate.drawn_words()])
		var screen: Vector2 = _game.hud._screen_size()
		var mounted := Rect2(plate.position, plate.size)
		_t.check("it sits top-centre inside the screen", absf(mounted.get_center().x - screen.x * 0.5) < 2.0 and mounted.position.y >= 0.0 and mounted.end.y < screen.y * 0.5,
			"plate %s on a %s screen" % [mounted, screen])
		var objective: Control = _game.hud._objective
		_t.check("the objective plate sits under it", objective.position.y >= mounted.end.y, "objective at y %.0f, plate ends at y %.0f" % [objective.position.y, mounted.end.y])
	_game.flow.retry_stage()
	await _frames(4)
	_t.eq("a retry takes the plate down", _plates().size(), 0)
	warden = _game.flow.warden
	await _strike(warden)
	_t.eq("engaging again puts it back", _plates().size(), 1)
	var guard := 0
	while is_instance_valid(warden) and not warden.is_dead() and guard < 60:
		# The slice row's rams do not shatter, so these are smashes: a smash fills the bar and, once it
		# is open, shatters the chunk at once.
		_game.player.smash_landing = warden
		_game.ctx.spawner.strike(warden, "ram", 40.0)
		await _frames(2)
		guard += 1
	_t.check("the Warden broke", not is_instance_valid(warden) or warden.is_dead(), "%d strikes" % guard)
	await _frames(4)
	_t.eq("breaking the Warden takes the plate down", _plates().size(), 0)
	_game.free()
	await _frames(2)


# The world wakes this attempt's rogue as it does in play: a plan whose site is under the ball.
func _wake_rogue() -> Node3D:
	var ball: Vector3 = _game.player.global_position
	_game.ctx.calm = false
	_game.world.rogue_plan = {"kind": "rogue_crane", "site": "test", "at": Vector2(ball.x, ball.z), "radius_m": 12.0, "trigger_m": 20.0}
	_game.world._watch_rogue(ball)
	_game.ctx.calm = true
	await _frames(3)
	return _game.world.rogue


func _rogue() -> void:
	var warden: Node3D = await _start("slice")
	_t.eq("before the rogue wakes no plate is up", _plates().size(), 0)
	var rogue: Node3D = await _wake_rogue()
	_t.check("the rogue machine woke", is_instance_valid(rogue) and not rogue.is_dead())
	var up := _plates()
	_t.eq("a woken rogue puts one plate up", up.size(), 1)
	if up.size() == 1:
		var plate: Control = up[0]
		_t.check("the HUD mounts it top-centre", _game.hud.boss_plate == plate and _game.hud._plate == plate)
		_t.eq("the rogue's plate is in the Rogue's hand", plate.hand(), UiTokens.Hand.ROGUE)
		_t.eq("it stencils the rogue's crew number", plate.drawn_number(), String(Rogue.ROWS["rogue_crane"]["crew"]))
	await _strike(warden)
	up = _plates()
	_t.eq("striking the Warden leaves one plate up", up.size(), 1)
	if up.size() == 1:
		_t.eq("the engaged Warden takes the plate from the rogue", up[0].hand(), UiTokens.Hand.OLD_WORKS)
		_t.check("the plate shows the Warden's name", up[0].drawn_words().size() > 0, str(up[0].drawn_words()))
	await _frames(4)
	_t.check("the rogue does not take it back while the Warden is engaged", _plates().size() == 1 and _plates()[0].hand() == UiTokens.Hand.OLD_WORKS)
	_game.flow.retry_stage()
	await _frames(4)
	_t.eq("a retry takes the plate down", _plates().size(), 0)
	rogue = await _wake_rogue()
	_t.check("the next attempt's rogue wakes with its plate up", is_instance_valid(rogue) and _plates().size() == 1 and _plates()[0].hand() == UiTokens.Hand.ROGUE)
	var guard := 0
	while is_instance_valid(rogue) and not rogue.is_dead() and guard < 120:
		rogue.take_damage(rogue.max_hp)
		await _frames(2)
		guard += 1
	_t.check("the rogue died", not is_instance_valid(rogue) or rogue.is_dead(), "%d hits" % guard)
	await _frames(2)
	_t.eq("the rogue's death takes its plate down", _plates().size(), 0)
	_t.check("the HUD lets the plate go", _game.hud.boss_plate == null and _game.hud._plate == null)
	_game.free()
	await _frames(2)


func _run() -> void:
	await _slice()
	await _rogue()
	quit(_t.verdict())
