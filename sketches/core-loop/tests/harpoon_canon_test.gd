extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The harpoon canon (design-v3/LEGIBILITY.md section 3), through a real Game, real physics and
# scripted input, for Sable, Rivet and Kest:
#   states     every LINE_ROWS id reaches line_state_changed, in an order that makes sense, and a
#              forced break names its cause
#   failures   a right mouse press with no aim, one during the rewind, an uncharged Shift and a
#              Shift while mounted each emit verb_failed with a reason; a Ctrl with no line is the
#              brake or the slam and emits nothing
#   momentum   planar speed just after a bite, a smash commit, a let-go and a forced break is
#              never below its planar speed just before; a smash commit never lowers total speed
#   world line right mouse holds it, Ctrl winches it; the Rope Anchor knob plants from that winch
#   ready      verb_ready is true and false at the right ticks on the ground, in the air, on a
#              world line, on a body line, in a committed haul and in the rewind
#   prompts    on every physics frame of that walk the verbs the HUD's key prompts draw are a subset
#              of the verbs for which player.verb_ready is true (this reaches KeyGlyphs.view_of, the
#              code that reads verb_ready); the harpoon is not ready mounted or planted, E is ready
#              where it would mount, Space where it would jump, air-jump or slingshot
#   ctrl       a Ctrl press on a world line and on a body line neither brakes nor slams
# Evidence limit: rules through real contacts from placed starts and a fixed camera, not a
# player's run; how the states look and sound is the next unit's.

const PILOTS := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster"}
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
# Free-flight drag at 20 m/s takes about 0.012 m/s over the two ticks a check spans; the line
# may take none of the rest.
const SPEED_SLACK := 0.03

var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _origin := FLAT_SHELF
var _states: Array = []
var _fails: Array = []
var _seen := {}
var _counts := {"sprint_started": 0, "blink_used": 0, "boosted": 0}
var _wall: StaticBody3D = null
var _audit := false
var _audit_frames := 0
var _audit_drawn := 0
var _audit_last: Array = []
var _audit_bad: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame
		if _audit:
			_audit_tick()


# Every prompt the HUD draws must be one the player says would work. A violation counts only
# when the same verb is drawn unready on two frames running, so the one tick the ball and the
# prompt can disagree by does not trip it.
func _audit_tick() -> void:
	var drawn: Array = _game.hud.key_glyphs.shown_verbs()
	var wrong: Array = []
	for verb in drawn:
		if not _player.verb_ready(verb):
			wrong.append(verb)
	_audit_frames += 1
	_audit_drawn += drawn.size()
	for verb in wrong:
		if verb in _audit_last and not verb in _audit_bad:
			_audit_bad.append(verb)
	_audit_last = wrong


func _never() -> bool:
	return false


func _on_state(state: String, target: Node3D, _at: Vector3, cause: String) -> void:
	_states.append([state, target, cause])
	_seen[state] = true


func _on_fail(verb: String, reason: String, _at: Vector3) -> void:
	_fails.append([verb, reason])


func _pilot(name: String) -> void:
	var def: Resource = ClassDef.by_id(PILOTS[name])
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_player.state.boost_cooldown = 0.0
	_source.hold = {}
	_source.press = {}
	_player.kit.rewind_left = 0.0


func _spawn(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, at)
	enemy.live = Callable(self, "_never")
	return enemy


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_origin.x + dx, _origin.z + dz, lift)


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_player.reset_to(at, velocity)
	_source.hold = {}
	_source.press = {}


func _cam(from: Vector3, to: Vector3) -> void:
	# Shots and the harpoon aim from the lens rest (W16-1): pose the mount the lens
	# sits on and hold the spring arm still, so the per-tick aim reads the posed eye.
	_game.camera.set_process(false)
	_game.camera.arm.set_physics_process_internal(false)
	(_game.camera.cam.get_parent() as Node3D).global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	_game.camera.cam.transform = Transform3D.IDENTITY


func _look(ball: Vector3, at: Vector3) -> void:
	_cam(ball + Vector3(0, 0.8, 4.0), at)


func _sky(ball: Vector3) -> void:
	_cam(ball + Vector3(0, 0.8, 4.0), ball + Vector3(0, 60.0, -10.0))


func _planar() -> float:
	var v: Vector3 = _player.body().linear_velocity
	return Vector2(v.x, v.z).length()


func _ids() -> Array:
	var ids := []
	for entry in _states:
		ids.append(entry[0])
	return ids


# Whether `wanted` appears in `ids` in this order, not necessarily next to each other.
func _in_order(ids: Array, wanted: Array) -> bool:
	var at := 0
	for id in ids:
		if at < wanted.size() and id == wanted[at]:
			at += 1
	return at == wanted.size()


func _last_state() -> String:
	return _states[-1][0] if not _states.is_empty() else ""


func _failed(verb: String, reason: String) -> bool:
	return [verb, reason] in _fails


func _mark() -> void:
	_states.clear()
	_fails.clear()


func _wall_at(ball: Vector3, ahead: float) -> void:
	_wall = StaticBody3D.new()
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 60, 1)
	box.shape = shape
	_wall.add_child(box)
	root.add_child(_wall)
	_wall.global_position = Vector3(ball.x, ball.y + 5.0, ball.z - ahead)


func _drop_wall() -> void:
	if _wall != null:
		_wall.free()
		_wall = null


func _clear_field() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_game.events.line_state_changed.connect(_on_state)
	_game.events.verb_failed.connect(_on_fail)
	_game.events.sprint_started.connect(func(_dir: Vector3): _counts["sprint_started"] += 1)
	_game.events.blink_used.connect(func(_from: Vector3, _to: Vector3): _counts["blink_used"] += 1)
	_game.events.boosted.connect(func(_dir: Vector3): _counts["boosted"] += 1)
	_clear_field()
	await _sim(0.2)

	for name in PILOTS:
		await _route(name)
		await _body_reel(name)
		await _world_line(name)
		await _shift(name)
		await _ready_walk(name)
		await _ctrl_on_lines(name)
	await _prompt_verbs()
	await _device_claim()
	await _rope_anchor()
	await _death_cuts()
	_all_rows()

	print("harpoon_canon_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


# Every state the ground line passes through, on a body: searching, locked, dry fire, latched,
# let go, a break by distance and by death, then a smash through its landing and rewind.
func _route(name: String) -> void:
	var kit = _player.kit
	_pilot(name)
	var ball := _point(0, 0, 6.0)
	var chaser := _spawn("chaser", _point(0, -22, 1.5))
	await _sim(0.1)
	_mark()
	_place(ball, Vector3(0, 0, -10))
	_sky(ball)
	await _sim(0.1)
	var searching: bool = _last_state() == "searching" and not _player.verb_ready("harpoon")
	_place(ball, Vector3(0, 0, -10))
	_look(ball, chaser.global_position)
	await _sim(0.1)
	var locked: bool = _last_state() == "locked" and _states[-1][1] == chaser and _player.verb_ready("harpoon")
	_check("%s: aim publishes searching then locked" % name, searching and locked and _in_order(_ids(), ["searching", "locked"]),
		"searching %s, locked on the chaser %s, states %s" % [searching, locked, _ids()])

	_mark()
	_place(ball, Vector3(0, 0, -10))
	_sky(ball)
	await _sim(0.05)
	_source.press = {"harpoon_pressed": true}
	await _sim(0.05)
	_check("%s: a press with no aim is a dry fire and a refusal" % name,
		"dry_fire" in _ids() and _failed("harpoon", "no_aim") and not kit.hooked,
		"states %s, fails %s, hooked %s" % [_ids(), _fails, kit.hooked])

	_mark()
	_place(ball, Vector3(0, 0, -10))
	_look(ball, chaser.global_position)
	await _sim(0.05)
	var before := _planar()
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await physics_frame
	await physics_frame
	var after := _planar()
	_check("%s: a bite latches the body and keeps the speed" % name,
		kit.hooked and kit.anchor_body == chaser and "latched_body" in _ids() and after >= before - SPEED_SLACK,
		"states %s, planar %.3f -> %.3f m/s" % [_ids(), before, after])
	_source.hold = {"harpoon_held": true}
	await _sim(0.3)
	_check("%s: holding right mouse keeps the body line" % name, kit.hooked and kit.anchor_body == chaser,
		"hooked %s after 0.3 s held" % kit.hooked)

	_source.hold = {}
	before = _planar()
	_source.press = {"harpoon_released": true}
	await physics_frame
	await physics_frame
	after = _planar()
	_check("%s: release lets go and keeps the speed" % name, not kit.hooked and _in_order(_ids(), ["latched_body", "let_go"]) and after >= before - SPEED_SLACK,
		"states %s, planar %.3f -> %.3f m/s" % [_ids(), before, after])
	await _sim(0.3)

	_mark()
	_place(ball, Vector3(0, 0, -10))
	_look(ball, chaser.global_position)
	await _sim(0.05)
	_source.press = {"harpoon_pressed": true}
	await _sim(0.05)
	var home := chaser.global_position
	before = _planar()
	chaser.global_position += Vector3(0, 0, -100)
	await physics_frame
	await physics_frame
	after = _planar()
	var far_cut: bool = _states.any(func(e): return e[0] == "broke" and e[2] == "out_of_reach")
	_check("%s: a stretched line breaks naming out_of_reach, speed kept" % name, not kit.hooked and far_cut and after >= before - SPEED_SLACK,
		"states %s causes %s, planar %.3f -> %.3f m/s" % [_ids(), _states.map(func(e): return e[2]), before, after])
	chaser.global_position = home
	await _sim(0.5)

	_mark()
	_place(ball, Vector3(0, 0, -10))
	_look(ball, chaser.global_position)
	await _sim(0.05)
	_source.press = {"harpoon_pressed": true}
	await _sim(0.05)
	before = _planar()
	_combat.strike(chaser, "runner", 99999.0)
	await physics_frame
	await physics_frame
	after = _planar()
	var death_cut: bool = _states.any(func(e): return e[0] == "broke" and e[2] == "body_died")
	_check("%s: a dead body breaks the line naming body_died, speed kept" % name, not kit.hooked and death_cut and after >= before - SPEED_SLACK,
		"states %s causes %s, planar %.3f -> %.3f m/s" % [_ids(), _states.map(func(e): return e[2]), before, after])
	await _sim(0.5)

	await _smash(name)


func _smash(name: String) -> void:
	var kit = _player.kit
	_pilot(name)
	var chaser := _spawn("chaser", _point(0, -22, 1.5))
	# The body outlives the smash: a kill clears the rewind (player_ball's enemy_killed hook), and
	# whether a 40 hp chaser died turned on the landing speed (red unloaded and under load, w33).
	chaser.max_hp = 1.0e6
	chaser.hp = chaser.max_hp
	_combat.heft_override = 0.4
	await _sim(0.1)
	_mark()
	var ground := _point(0, 0, 1.4)
	_place(ground, Vector3(0, 0, -6))
	_look(_point(0, 0, 2.2), chaser.global_position)
	await _sim(0.05)
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await _sim(0.1)
	var before := _planar()
	_source.hold = {"harpoon_held": true, "brake_held": true}
	await physics_frame
	await physics_frame
	var after := _planar()
	_check("%s: Ctrl commits the smash and keeps the speed" % name,
		kit.line_state == Augments.LINE_SMASH and "smash_committed" in _ids() and after >= before - SPEED_SLACK,
		"states %s, planar %.3f -> %.3f m/s" % [_ids(), before, after])
	_check("%s: a committed haul cannot haul again" % name, not _player.verb_ready("haul"), "verb_ready(haul) %s mid-haul" % _player.verb_ready("haul"))
	_fails.clear()
	_source.hold = {"harpoon_held": true}
	await physics_frame
	_source.hold = {"harpoon_held": true, "brake_held": true}
	await physics_frame
	await physics_frame
	_check("%s: Ctrl pressed again on a committed haul is refused" % name,
		_failed("haul", "committed") and kit.hooked and kit.line_state == Augments.LINE_SMASH,
		"fails %s, hooked %s, line_state %s" % [_fails, kit.hooked, kit.line_state])
	if name == "sable":
		_player.state.boost_cooldown = 5.0
		_fails.clear()
		_source.press = {"shift_pressed": true}
		await physics_frame
		_source.press = {}
		await physics_frame
		_check("sable: a Shift refused on cooldown mid-haul leaves the smash committed",
			_failed("boost", "cooldown") and kit.hooked and kit.line_state == Augments.LINE_SMASH,
			"fails %s, hooked %s, line_state %s" % [_fails, kit.hooked, kit.line_state])
		_player.state.boost_cooldown = 0.0
	if name != "sable":
		_player.abilities.slot(AbilityState.MOVEMENT).charges = 0
		_fails.clear()
		_source.press = {"shift_pressed": true}
		await physics_frame
		_source.press = {}
		await physics_frame
		_check("%s: a refused Shift mid-haul leaves the smash committed" % name,
			not _fails.is_empty() and kit.hooked and kit.line_state == Augments.LINE_SMASH,
			"fails %s, hooked %s, line_state %s" % [_fails, kit.hooked, kit.line_state])
		_player.abilities.refill()
	for tick in roundi(1.6 * Engine.physics_ticks_per_second):
		await physics_frame
		if not kit.hooked:
			break
	_source.hold = {}
	await _sim(0.3)
	_check("%s: the smash lands then the hook rewinds" % name, _in_order(_ids(), ["latched_body", "smash_committed", "smash_lands", "rewinding"]),
		"states %s" % [_ids()])

	_mark()
	_look(_point(0, 0, 2.2), chaser.global_position)
	_source.press = {"harpoon_pressed": true}
	await _sim(0.05)
	_check("%s: a press during the rewind is refused" % name, kit.rewind_left > 0.0 and _failed("harpoon", "rewinding") and not kit.hooked
		and not _player.verb_ready("harpoon") and not _player.verb_ready("haul"),
		"rewind left %.2f s, fails %s, hooked %s" % [kit.rewind_left, _fails, kit.hooked])
	await _sim(_game.tuning.f("harpoon_rewind") + 0.2)
	_check("%s: after the rewind the aim state returns" % name, _last_state() in ["locked", "searching"] and kit.rewind_left == 0.0,
		"last state %s, rewind left %.2f s" % [_last_state(), kit.rewind_left])

	await _no_line_ctrl(name)
	await _fast_commit(name)
	_combat.heft_override = 1.0
	if is_instance_valid(chaser):
		chaser.queue_free()
	await _sim(0.2)


# A commit from above the smash floor: a level approach at 30 m/s keeps its total speed.
func _fast_commit(name: String) -> void:
	var kit = _player.kit
	_pilot(name)
	var chaser := _spawn("chaser", _point(0, -36, 1.5))
	await _sim(0.1)
	_mark()
	var ground := _point(0, 0, 1.4)
	_place(ground, Vector3(0, 0, -30))
	_look(_point(0, 0, 2.2), chaser.global_position)
	await _sim(0.05)
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await physics_frame
	_source.press = {}
	var before: float = _player.body().linear_velocity.length()
	_source.hold = {"harpoon_held": true, "brake_held": true}
	await physics_frame
	await physics_frame
	var after: float = _player.body().linear_velocity.length()
	_check("%s: a commit from 30 m/s never lowers total speed" % name,
		kit.line_state == Augments.LINE_SMASH and before > 25.0 and after >= before - SPEED_SLACK,
		"line_state %s, total %.3f -> %.3f m/s" % [kit.line_state, before, after])
	_source.hold = {}
	_player.release_grapple()
	if is_instance_valid(chaser):
		chaser.queue_free()
	await _sim(0.3)


# Ctrl with no line stands is the brake on the ground, never a refused haul.
func _no_line_ctrl(name: String) -> void:
	_pilot(name)
	var ground := _point(0, 0, 1.4)
	_sky(ground)
	_mark()
	_place(ground, Vector3(0, 0, -10))
	await _sim(0.3)
	_place(ground, Vector3(0, 0, -10))
	await _sim(0.4)
	var coast := _planar()
	_mark()
	_place(ground, Vector3(0, 0, -10))
	await _sim(0.3)
	_place(ground, Vector3(0, 0, -10))
	_source.hold = {"brake_held": true}
	await _sim(0.4)
	var braked := _planar()
	_source.hold = {}
	_check("%s: Ctrl with no line brakes and emits no verb_failed" % name,
		_fails.is_empty() and braked < coast - 0.5,
		"fails %s, planar after 0.4 s %.2f coasting, %.2f with Ctrl" % [_fails, coast, braked])


# A held line on a body reels the ball in: from rest, the gap closes and planar speed only rises.
func _body_reel(name: String) -> void:
	var kit = _player.kit
	_pilot(name)
	var chaser := _spawn("chaser", _point(0, -22, 1.5))
	_combat.heft_override = 0.4
	await _sim(0.1)
	var ball := _point(0, 0, 4.0)
	_mark()
	_place(ball)
	_look(ball, chaser.global_position)
	await _sim(0.05)
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await physics_frame
	_source.press = {}
	var latched: bool = kit.hooked and kit.on_body and kit.line_state == Augments.LINE_LATCHED
	var gap_before: float = _player.ball_position().distance_to(chaser.global_position)
	var start := _planar()
	var prev := start
	var drops := 0
	for tick in 30:
		await physics_frame
		var now := _planar()
		if now < prev - SPEED_SLACK:
			drops += 1
		prev = now
	var gap_after: float = _player.ball_position().distance_to(chaser.global_position)
	_check("%s: a held body line reels the ball in, planar speed never drops" % name,
		latched and kit.hooked and gap_after < gap_before - 0.5 and prev > start + 0.5 and drops == 0,
		"latched %s, gap %.2f -> %.2f m, planar %.3f -> %.3f m/s, drops %d" % [latched, gap_before, gap_after, start, prev, drops])
	_source.hold = {}
	_source.press = {"harpoon_released": true}
	await _sim(0.1)
	_combat.heft_override = 1.0
	if is_instance_valid(chaser):
		chaser.queue_free()
	await _sim(0.3)


# A world line: right mouse bites and holds it, Ctrl winches it, release lets go.
# An interactable that takes E is not a mount: the press is ready, the pylon prompt is not.
func _device_claim() -> void:
	_pilot("rivet")
	var held: Callable = _player.interact_claim
	_player.interact_claim = func(face: bool) -> bool: return not face
	_place(_point(0, 0, 1.4))
	await _sim(0.2)
	var ready: bool = _player.verb_ready("interact")
	var view: Dictionary = _game.hud.key_glyphs.view_of(_player)
	var drawn: Array = _game.hud.key_glyphs.shown_verbs()
	_check("rivet: a device takes E, and no mount prompt is drawn", ready and not view["ready"]["interact"] and not drawn.has("interact"),
		"verb_ready(interact) %s, prompt view %s, drawn %s" % [ready, view["ready"]["interact"], drawn])
	_player.interact_claim = held


# Death ends the latch, so nothing that follows the line (its sight, its hum, a prompt)
# outlives the pilot.
func _death_cuts() -> void:
	var kit = _player.kit
	_pilot("sable")
	var ball := _point(0, 0, 24.0)
	_wall_at(ball, 28.0)
	await _sim(0.1)
	_place(ball, Vector3(0, 0, -10))
	_look(ball, _wall.global_position)
	await _sim(0.05)
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await physics_frame
	await physics_frame
	var latched: bool = kit.hooked
	_game.events.player_died.emit()
	_check("death drops the line", latched and not kit.hooked, "hooked %s before the death, %s after" % [latched, kit.hooked])
	_source.hold = {}


func _world_line(name: String) -> void:
	var kit = _player.kit
	_pilot(name)
	var ball := _point(0, 0, 24.0)
	_wall_at(ball, 28.0)
	await _sim(0.1)
	_mark()
	_place(ball, Vector3(0, 0, -10))
	_look(ball, _wall.global_position)
	await _sim(0.05)
	var before := _planar()
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await physics_frame
	await physics_frame
	var after := _planar()
	_check("%s: a bite on the world latches it and keeps the speed" % name,
		kit.hooked and not kit.on_body and "latched_world" in _ids() and _states[-1][1] == null and after >= before - SPEED_SLACK,
		"states %s, planar %.3f -> %.3f m/s" % [_ids(), before, after])
	_source.hold = {"harpoon_held": true}
	await _sim(0.3)
	var held: bool = kit.hooked
	var rope_before: float = kit.rope
	_source.hold = {"harpoon_held": true, "brake_held": true}
	var slammed := false
	var slowest := INF
	for tick in roundi(0.5 * Engine.physics_ticks_per_second):
		await physics_frame
		slammed = slammed or kit.slamming
		slowest = minf(slowest, _player.body().linear_velocity.length())
	_check("%s: right mouse holds a world line and Ctrl winches it" % name,
		held and kit.hooked and kit.winching and kit.rope < rope_before - 0.5 and not slammed,
		"held 0.3 s %s, winching %s, rope %.2f -> %.2f m, slammed %s" % [held, kit.winching, rope_before, kit.rope, slammed])
	_source.hold = {"harpoon_held": true}
	await _sim(0.1)
	_check("%s: letting go of Ctrl stops the winch, the line stays" % name, kit.hooked and not kit.winching,
		"hooked %s, winching %s" % [kit.hooked, kit.winching])
	_source.hold = {}
	before = _planar()
	_source.press = {"harpoon_released": true}
	await physics_frame
	await physics_frame
	after = _planar()
	_check("%s: release lets the world line go and keeps the speed" % name,
		not kit.hooked and _in_order(_ids(), ["latched_world", "let_go"]) and after >= before - SPEED_SLACK,
		"states %s, planar %.3f -> %.3f m/s" % [_ids(), before, after])
	await _sim(0.3)
	_drop_wall()


# Shift is one verb per pilot: Sable boosts, Rivet sprints, Kest blinks. A press the verb cannot
# take is refused out loud.
func _shift(name: String) -> void:
	_pilot(name)
	var ball := _point(0, 0, 3.0)
	for kind in _counts:
		_counts[kind] = 0
	_mark()
	_place(ball, Vector3(0, 0, -6))
	_source.press = {"shift_pressed": true, "shift_held": true}
	await _sim(0.1)
	var fired: String = {"sable": "boosted", "rivet": "sprint_started", "kest": "blink_used"}[name]
	var others: int = 0
	for kind in _counts:
		if kind != fired:
			others += _counts[kind]
	_check("%s: Shift fires its one verb (%s)" % [name, fired], _counts[fired] == 1 and others == 0 and _fails.is_empty(),
		"%s, fails %s" % [_counts, _fails])
	_pilot(name)
	_mark()
	_place(ball, Vector3(0, 0, -6))
	var reason := "cooldown"
	if name == "sable":
		_player.state.boost_cooldown = 5.0
	else:
		_player.abilities.slot(AbilityState.MOVEMENT).charges = 0
		reason = "uncharged"
	for kind in _counts:
		_counts[kind] = 0
	var ready: bool = _player.verb_ready("boost")
	_source.press = {"shift_pressed": true}
	await _sim(0.1)
	_check("%s: an uncharged Shift is refused" % name, not ready and _failed("boost", reason) and _counts[fired] == 0,
		"verb_ready(boost) %s, fails %s, %s fired %d" % [ready, _fails, fired, _counts[fired]])
	if name == "sable":
		_pilot(name)
		_mark()
		_place(ball, Vector3(0, 0, -6))
		_player.kit.mounted = true
		_source.press = {"shift_pressed": true}
		await physics_frame
		_check("sable: Shift while mounted is refused as busy", _failed("boost", "busy"), "fails %s" % [_fails])
		_player.kit.mounted = false
		_source.press = {}


# verb_ready on the ground, in the air, on a world line, on a body line, in a haul and in the rewind.
func _ready_walk(name: String) -> void:
	var kit = _player.kit
	_pilot(name)
	_game.hud.profile.glyph_uses = {}
	_game.hud.key_glyphs.new_run()
	_audit = true
	_audit_frames = 0
	_audit_drawn = 0
	_audit_bad = []
	_audit_last = []
	var chaser := _spawn("chaser", _point(0, -22, 1.5))
	await _sim(0.1)
	var ground := _point(0, 0, 1.4)
	_place(ground)
	_look(_point(0, 0, 2.2), chaser.global_position)
	await _sim(0.2)
	var on_ground: bool = _player.state.grounded
	var row := [_player.verb_ready("harpoon"), _player.verb_ready("haul"), _player.verb_ready("boost")]
	_check("%s: ready on the ground with a target" % name, on_ground and row == [true, false, true], "grounded %s, harpoon/haul/boost %s" % [on_ground, row])
	_sky(ground)
	await _sim(0.1)
	row = [_player.verb_ready("harpoon"), _player.verb_ready("haul"), _player.verb_ready("boost")]
	_check("%s: ready on the ground with no aim" % name, row == [false, false, true], "harpoon/haul/boost %s" % [row])

	var high := _point(0, 0, 8.0)
	_place(high)
	_look(high, chaser.global_position)
	await _sim(0.05)
	var airborne: bool = not _player.state.grounded
	row = [_player.verb_ready("harpoon"), _player.verb_ready("haul"), _player.verb_ready("boost")]
	_check("%s: ready in the air with a target" % name, airborne and row == [true, false, true], "airborne %s, harpoon/haul/boost %s" % [airborne, row])

	_place(high)
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	await _sim(0.05)
	row = [_player.verb_ready("harpoon"), _player.verb_ready("haul"), _player.verb_ready("boost")]
	_check("%s: ready on a latched body line" % name, kit.on_body and kit.line_state == Augments.LINE_LATCHED and not row[0] and row[1] and row[2],
		"harpoon/haul/boost %s" % [row])
	_player.release_grapple()

	_place(high)
	kit.slamming = true
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	_check("%s: a bite ends a slam in flight" % name, kit.hooked and not kit.slamming, "hooked %s, slamming %s" % [kit.hooked, kit.slamming])
	_player.release_grapple()
	await _sim(0.05)

	var wall_ball := _point(0, 0, 6.0)
	_wall_at(wall_ball, 28.0)
	await _sim(0.1)
	_place(wall_ball)
	_player.grapple_to(_wall.global_position + Vector3(0, 0, 0.6), Vector3(0, 0, 1), null)
	await _sim(0.05)
	row = [_player.verb_ready("harpoon"), _player.verb_ready("haul"), _player.verb_ready("boost")]
	_check("%s: ready on a world line" % name, kit.hooked and not kit.on_body and row == [false, true, true], "harpoon/haul/boost %s" % [row])
	_player.release_grapple()
	_drop_wall()

	_place(_point(0, 0, 1.4))
	kit.rewind_left = 0.8
	_look(_point(0, 0, 2.2), chaser.global_position)
	await _sim(0.05)
	row = [_player.verb_ready("harpoon"), _player.verb_ready("haul")]
	_check("%s: not ready in the rewind" % name, row == [false, false], "harpoon/haul %s" % [row])
	kit.rewind_left = 0.0

	_place(high)
	_look(high, chaser.global_position)
	kit.slingshot.charging = true
	await _sim(0.05)
	_check("%s: not ready while a gauge charges" % name, not _player.verb_ready("harpoon"), "verb_ready(harpoon) %s" % _player.verb_ready("harpoon"))
	kit.slingshot.charging = false

	if name == "sable":
		_player.state.boost_cooldown = 5.0
	else:
		_player.abilities.slot(AbilityState.MOVEMENT).charges = 0
	_check("%s: boost is not ready while its verb is spent" % name, not _player.verb_ready("boost"), "verb_ready(boost) %s" % _player.verb_ready("boost"))
	if is_instance_valid(chaser):
		chaser.queue_free()
	await _sim(0.1)
	_audit = false
	_check("%s: every prompt drawn over the walk is one verb_ready answers" % name, _audit_bad.is_empty() and _audit_drawn > 0,
		"%d frames, %d prompts drawn, drawn while not ready %s" % [_audit_frames, _audit_drawn, _audit_bad])


# Ctrl on a standing line: it is the smash or the winch, never the brake or the slam. The brake
# is the intent field the ball reads, so a Ctrl that braked would leave brake_held true.
func _ctrl_on_lines(name: String) -> void:
	var kit = _player.kit
	_pilot(name)
	var chaser := _spawn("chaser", _point(0, -22, 1.5))
	await _sim(0.1)
	var high := _point(0, 0, 8.0)
	_place(high)
	_look(high, chaser.global_position)
	await _sim(0.05)
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	var braked := false
	var slammed := false
	for tick in 20:
		await physics_frame
		braked = braked or _player.intent.brake_held
		slammed = slammed or kit.slamming or kit.plant_time > 0.0
	_check("%s: Ctrl on a body line neither brakes nor slams" % name, kit.on_body and not braked and not slammed,
		"on body %s, braked %s, slammed %s" % [kit.on_body, braked, slammed])
	_source.hold = {}
	_player.release_grapple()
	if is_instance_valid(chaser):
		chaser.queue_free()
	var ball := _point(0, 0, 24.0)
	_wall_at(ball, 28.0)
	await _sim(0.1)
	_place(ball)
	_look(ball, _wall.global_position)
	await _sim(0.05)
	_player.grapple_to(_wall.global_position + Vector3(0, 0, 0.6), Vector3(0, 0, 1), null)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	braked = false
	slammed = false
	for tick in 20:
		await physics_frame
		braked = braked or _player.intent.brake_held
		slammed = slammed or kit.slamming or kit.plant_time > 0.0
	_check("%s: Ctrl on a world line neither brakes nor slams" % name, kit.hooked and not kit.on_body and not braked and not slammed,
		"hooked %s, braked %s, slammed %s" % [kit.hooked, braked, slammed])
	_source.hold = {}
	_player.release_grapple()
	_drop_wall()
	await _sim(0.2)


# E, Space and the harpoon where they would and would not work: Sable at a steep face, mounted,
# on the ground, in the air with and without an air action left; Rivet at the same face.
func _prompt_verbs() -> void:
	var kit = _player.kit
	_pilot("sable")
	_game.hud.profile.glyph_uses = {}
	_game.hud.key_glyphs.new_run()
	var ball := _point(0, 0, 24.0)
	_wall_at(ball, 2.4)
	await _sim(0.1)
	_place(ball)
	_look(ball, _wall.global_position)
	_audit = true
	_audit_frames = 0
	_audit_drawn = 0
	_audit_bad = []
	_audit_last = []
	await _sim(0.1)
	_check("sable: E is ready at a steep face and Space is not a prompt unmounted", _player.verb_ready("interact") and not _game.hud.key_glyphs.shown_verbs().has("jump"),
		"interact %s, drawn %s" % [_player.verb_ready("interact"), _game.hud.key_glyphs.shown_verbs()])
	_check("sable: the mount prompt is drawn at the face", _game.hud.key_glyphs.shown_verbs().has("interact"), "drawn %s" % [_game.hud.key_glyphs.shown_verbs()])
	_player.state.air_actions = 0
	_player.state.grounded = false
	_player.state.coyote = 0.0
	_check("sable: Space is not ready in the air with no air action", not _player.verb_ready("jump"), "verb_ready(jump) %s" % _player.verb_ready("jump"))
	_player.state.air_actions = 1
	_check("sable: Space is ready for an air jump", _player.verb_ready("jump"), "verb_ready(jump) %s" % _player.verb_ready("jump"))
	_source.press = {"mount_pressed": true}
	await _sim(0.15)
	var mounted: bool = kit.mounted
	_check("sable: mounted, the harpoon is not ready, Space is the slingshot and E drops off",
		mounted and not _player.verb_ready("harpoon") and _player.verb_ready("jump") and not _player.verb_ready("interact") and not _player.verb_ready("boost"),
		"mounted %s, harpoon %s, jump %s, interact %s, boost %s" % [mounted, _player.verb_ready("harpoon"), _player.verb_ready("jump"), _player.verb_ready("interact"), _player.verb_ready("boost")])
	_check("sable: mounted, only the slingshot prompt is drawn", _game.hud.key_glyphs.shown_verbs() == ["jump"], "drawn %s" % [_game.hud.key_glyphs.shown_verbs()])
	_source.press = {"mount_pressed": true}
	await _sim(0.3)
	_audit = false
	_check("sable: every prompt drawn at the face and mounted is one verb_ready answers", _audit_bad.is_empty() and _audit_drawn > 0,
		"%d frames, %d prompts drawn, drawn while not ready %s" % [_audit_frames, _audit_drawn, _audit_bad])
	_player.release_grapple()
	_pilot("rivet")
	_place(ball)
	await _sim(0.1)
	_check("rivet: E is not ready at the same face, there is no pylon", not _player.verb_ready("interact"), "verb_ready(interact) %s" % _player.verb_ready("interact"))
	_drop_wall()
	await _sim(0.2)


# Sable's Rope Anchor knob (winch_mount): winching a world line up to a wall with Ctrl plants the
# pylon there. Off, the same winch plants nothing.
func _rope_anchor() -> void:
	var kit = _player.kit
	for knob_on in [false, true]:
		_pilot("sable")
		_player.tree._knobs["winch_mount"] = knob_on
		var ball := _point(0, 0, 1.4)
		_wall_at(ball, 10.0)
		await _sim(0.2)
		_place(ball)
		_look(_point(0, 0, 2.2), _wall.global_position)
		await _sim(0.1)
		_player.grapple_to(_wall.global_position + Vector3(0, 0, 0.6), Vector3(0, 0, 1), null)
		_source.hold = {"harpoon_held": true, "brake_held": true}
		await _sim(2.0)
		var planted: bool = kit.mounted
		_check("rope anchor knob %s: the Ctrl winch %s" % ["on" if knob_on else "off", "plants the pylon at the wall" if knob_on else "plants nothing"],
			planted == knob_on, "mounted %s, distance to the wall %.2f m" % [planted, _player.ball_position().distance_to(_wall.global_position)])
		_source.hold = {}
		_source.press = {"mount_pressed": true}
		await _sim(0.2)
		_source.press = {}
		_player.release_grapple()
		_drop_wall()
		_player.tree._knobs["winch_mount"] = false
		await _sim(0.2)


# Every row of LINE_ROWS was published across the three pilots.
func _all_rows() -> void:
	var missing := []
	for id in EventKinds.LINE_ROWS:
		if not _seen.has(id):
			missing.append(id)
	_check("every LINE_ROWS state was published", missing.is_empty(), "missing %s of %d rows" % [missing, EventKinds.LINE_ROWS.size()])
