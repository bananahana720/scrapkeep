extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")

# Ruling BL2 (card BOT-LINE): a remembered-cannon weapon lane fired while the ball's line holds a body
# strikes that body when the lane's footprint covers it, however high the body hangs. The lane itself
# reaches only 3 m over the ground (hazard.gd reach), and the stage-2 flume relic hangs 12 m over the
# drum floor, so on 540a55a4 latched lanes landed 0 of about 80 on the park table.
# Here a held chaser stands HANG m over the ground, LEAD m down the aim, and one held-fire tick commits
# one lane at it:
#   latched   the line holds the chaser: the lane strikes it once (kind "cannon") and it loses HP.
#             Red at cac3f3de: no strike.
#   control   the same lane at a second chaser in the same place with no line on it: no strike.

const HANG := 12.0
const LEAD := 10.0
const WAIT_S := 2.5

var _t := T.new("cannon_line_lane_test")
var _game
var _source := Intent.Scripted.new()
var _struck: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	await physics_frame
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var def: Resource = ClassDef.by_id("remembered_cannon")
	_game.run.class_def = def
	_game.player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_game.player.reset_to(at)
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float): _struck.append([enemy, kind]))
	await physics_frame

	var held := await _lane_at(true)
	_t.eq("latched: the lane strikes the held body %.0f m up once" % HANG, held["strikes"], 1)
	_t.check("latched: the held body loses HP", held["hp_after"] < held["hp_before"], "hp %.1f from %.1f" % [held["hp_after"], held["hp_before"]])
	var loose := await _lane_at(false)
	_t.eq("control, no line: the same lane misses the body %.0f m up" % HANG, loose["strikes"], 0)
	_t.eq("control, no line: the body keeps its HP", loose["hp_after"], loose["hp_before"])
	var inside := await _forced_at(1.0)
	_t.check("latched, body inside the lane at its real position: not forced", inside["entries"] > 0 and not inside["forced"], str(inside))
	var high := await _forced_at(HANG)
	_t.check("latched, body %.0f m up: still forced" % HANG, high["entries"] > 0 and high["forced"], str(high))
	print("[report] latched %s; control %s" % [held, loose])
	quit(_t.verdict())


# One lane at a fresh chaser HANG m over the ground LEAD m down the aim, the line on it or not.
func _lane_at(latched: bool) -> Dictionary:
	var player = _game.player
	var ball: Vector3 = player.ball_position()
	var aim: Vector3 = _game.ctx.aim_forward()
	aim.y = 0.0
	aim = aim.normalized()
	var flat := Vector3(ball.x, 0.0, ball.z) + aim * LEAD
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	var target: Node3D = _game.combat.spawn_enemy("chaser", Vector3(flat.x, ground + HANG, flat.z))
	target.max_hp = 100000.0
	target.hp = 100000.0
	target.process_mode = Node.PROCESS_MODE_DISABLED
	var before: float = target.hp
	var from := _struck.size()
	_game.combat._cooldown = 0.0
	_game.combat.weapon_driver.reset()
	_game.combat._free_cannon()
	player.abilities.refill()
	var ticks := ceili(WAIT_S * Engine.physics_ticks_per_second)
	for i in ticks:
		if latched:
			_latch(target)
		_source.press = {"fire_pressed": true} if i == 0 else {}
		_source.hold = {}
		await physics_frame
	_unlatch()
	var strikes := _struck.slice(from).filter(func(s): return s[0] == target and s[1] == "cannon").size()
	var out := {"strikes": strikes, "hp_before": before, "hp_after": target.hp}
	target.remove_from_group("enemy")
	return out


func _latch(body: Node3D) -> void:
	var kit = _game.player.kit
	kit.hooked = true
	kit.on_body = true
	kit.anchor_body = body
	kit.line_state = Augments.LINE_LATCHED
	kit.anchor = body.global_position


func _unlatch() -> void:
	var kit = _game.player.kit
	kit.hooked = false
	kit.on_body = false
	kit.anchor_body = null
	kit.line_state = Augments.LINE_IDLE


# One held-fire tick with the line on a fresh chaser HANG_M over the ground; reports whether the lane entry forces it.
func _forced_at(hang_m: float) -> Dictionary:
	var player = _game.player
	var ball: Vector3 = player.ball_position()
	var aim: Vector3 = _game.ctx.aim_forward()
	aim.y = 0.0
	aim = aim.normalized()
	var flat := Vector3(ball.x, 0.0, ball.z) + aim * LEAD
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	var target: Node3D = _game.combat.spawn_enemy("chaser", Vector3(flat.x, ground + hang_m, flat.z))
	target.max_hp = 100000.0
	target.hp = 100000.0
	target.process_mode = Node.PROCESS_MODE_DISABLED
	_game.combat._cooldown = 0.0
	_game.combat.weapon_driver.reset()
	_game.combat._free_cannon()
	player.abilities.refill()
	var forced := false
	var entries := 0
	for i in 3:
		_latch(target)
		_source.press = {"fire_pressed": true} if i == 0 else {}
		_source.hold = {}
		await physics_frame
		for entry in _game.combat._cannon:
			entries += 1
			if entry["options"].get("forced") == target:
				forced = true
	_unlatch()
	_game.combat._free_cannon()
	target.remove_from_group("enemy")
	return {"forced": forced, "entries": entries}
