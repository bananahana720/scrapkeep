extends RefCounted

# One test double that drives any boss module answering BossContract.MODULE to victory,
# headless, through flow's own seams: a run started, a world's last stage entered, the
# world's module entered with flow.enter_boss, and its TARGET struck once per physics frame
# until it falls. Waking-fight, mind-fight and the bands measure through this instead of
# each rediscovering flow. Brindle's own fight stays in boss_harness.gd.
#
# Evidence limit: a hit is the TARGET calls (judge_hit, on_struck, take_damage on a
# shatter), not a ball contact; frames are counted, never timed.


# What the bus said during a fight. Connect it before entering the world so the arena entry
# is counted.
class Counter extends RefCounted:
	var posture_changed := 0
	var points: Array = []
	var arenas := 0
	var defeated := 0
	var run_ended := 0
	var won: Array = []

	func connect_to(events) -> void:
		events.posture_changed.connect(func(_enemy, _posture, _staggered): posture_changed += 1)
		events.weak_point_opened.connect(func(id: String, _at, _seconds): points.append(id))
		events.boss_arena_entered.connect(func(): arenas += 1)
		events.boss_defeated.connect(func(): defeated += 1)
		events.run_ended.connect(func(was_won: bool):
			run_ended += 1
			won.append(was_won))


static func boot(game) -> void:
	game.flow.press_start()
	game.flow.choose_class(0)


static func counter(game) -> Counter:
	var c := Counter.new()
	c.connect_to(game.ctx.events)
	return c


# World w's last stage, then its arena, as a launch off that stage lands there.
static func enter_world(game, w: int) -> void:
	game.flow.enter_stage(game.ctx.stages.last_of(w), Vector3.ZERO, false)
	game.flow.enter_boss(Vector3.ZERO)


static func module(game, w: int) -> Node:
	return game.flow._module_for(w)


# The body a hit lands on: the stub family's Warden, else a module's own target().
static func target(mod):
	if mod == null:
		return null
	if "warden" in mod and is_instance_valid(mod.warden):
		return mod.warden
	if mod.has_method("target"):
		return mod.target()
	return null


static func _alive(body) -> bool:
	return body != null and is_instance_valid(body) and not body.is_dead()


# BossContract.TARGET: the hit judged, applied, and on a shatter the chunk's damage taken.
static func hit(mod) -> void:
	var body = target(mod)
	if not _alive(body):
		return
	var result: Dictionary = body.judge_hit("slam", 9999.0, true, 3)
	body.on_struck("slam", String(result.get("part", "")), result)
	if bool(result.get("shatter", false)):
		body.take_damage(float(result.get("dealt", 0.0)))


# One hit per physics frame while the target lives and frames stay under the cap. points are
# the weak_point_opened ids seen during the fight; victory_state is flow's state on the
# frame the fight ended.
static func fight(game, mod, frame_cap: int, c: Counter = null) -> Dictionary:
	var tree: SceneTree = game.get_tree()
	var seen := c if c != null else counter(game)
	var points_before: int = seen.points.size()
	var defeated_before: int = seen.defeated
	var hits := 0
	var frames := 0
	while _alive(target(mod)) and frames < frame_cap:
		hit(mod)
		hits += 1
		frames += 1
		await tree.physics_frame
	return {
		"hits": hits,
		"frames": frames,
		"defeated": seen.defeated > defeated_before and not _alive(target(mod)),
		"points": seen.points.slice(points_before),
		"victory_state": game.flow.state_name(),
	}


static func conforms(mod) -> Dictionary:
	return {
		"module": BossContract.conforms(mod, BossContract.MODULE),
		"target": BossContract.conforms(target(mod), BossContract.TARGET),
	}
