extends SceneTree

# W47-E3 mag_trapper secondary: Polarity Repulse Ring (0.75 s pitch-flip to radial blast when
# heft >= rating rolls in un-dragged) -> slamming disc during flip punts magnetized disc into
# nearest enemy pack. Verifies tell floor >= 0.60 s, Palette.HAZARD, 0.2 s AttackBudget gap,
# ruling cu (rolling out before 0.75 s takes zero damage), radial blast on campers, and Disc Punt.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Palette := preload("res://src/core/palette.gd")
const MagTrapper := preload("res://src/combat/mag_trapper.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_mag_trapper_repulse_test")
var ball := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 11
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(4)
	_clear()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	if root.has_meta(AttackBudget.LAST_META):
		root.remove_meta(AttackBudget.LAST_META)


func _live_trapper(offset: Vector3) -> Node3D:
	var at := ball + offset
	var trapper: Node3D = game.combat.spawn_enemy("mag_trapper", game.ctx.terrain.drop_point(at.x, at.z, 1.8))
	trapper.hp = 10000.0
	trapper.target = game.player
	trapper._rest = 0.0
	trapper._warn(game.player.ball_position() - trapper.global_position)
	trapper.phase = trapper.Phase.LIVE
	trapper._t = 0.0
	trapper._go_live()
	return trapper


func _run() -> void:
	await _boot()
	var player = game.player
	var orig_heft: Callable = player.heft_of

	# 1. Tell floor invariant >= 0.60 s.
	t.check("Polarity Repulse warn >= 0.60 s", MagTrapper.REPULSE_WARN >= 0.60, str(MagTrapper.REPULSE_WARN))
	t.near("Polarity Repulse warn is 0.75 s", MagTrapper.REPULSE_WARN, 0.75, 0.001)

	# 2. Light ball (heft < rating) triggers normal pull, never polarity flip.
	_clear()
	player.heft_of = func() -> float: return 1.0
	player.reset_to(ball)
	var light_t := _live_trapper(Vector3(10.0, 0.0, 0.0))
	player.reset_to(light_t.telegraph().center + Vector3.UP * 1.05)
	light_t._live(1.0 / 90.0)
	t.eq("light ball does not trigger polarity flip", [light_t.polarity_flips, light_t._polarity_flip], [0, false])
	light_t._end()
	light_t.free()

	# 3. Heavy ball (heft >= rating) rolling in un-dragged triggers Polarity Repulse Ring (respecting 0.2 s gap).
	_clear()
	player.heft_of = func() -> float: return 2.5
	player.reset_to(ball)
	var trapper := _live_trapper(Vector3(12.0, 0.0, 0.0))
	var pit_center: Vector3 = trapper.telegraph().center
	player.reset_to(pit_center + Vector3.UP * 1.05)
	# Inside 0.2 s inter-warning gap: flip waits.
	root.set_meta(AttackBudget.LAST_META, Engine.get_physics_frames())
	trapper._live(1.0 / 90.0)
	t.eq("polarity flip respects 0.2 s AttackBudget inter-warning gap", trapper.polarity_flips, 0)
	# Once gap opens: flip commits 0.75 s Palette.HAZARD radial ring.
	root.remove_meta(AttackBudget.LAST_META)
	trapper._live(1.0 / 90.0)
	var repulse_ring: Node3D = trapper.telegraph()
	t.eq("heavy ball triggers Polarity Repulse Ring", [trapper.polarity_flips, trapper._polarity_flip], [1, true])
	t.check("repulse ring is Palette.HAZARD with 0.75 s warn and 6 m radius",
		repulse_ring != null and repulse_ring.color.is_equal_approx(Palette.HAZARD)
		and is_equal_approx(repulse_ring.warn_seconds, MagTrapper.REPULSE_WARN)
		and is_equal_approx(repulse_ring.radius, MagTrapper.REPULSE_RADIUS))

	# 4. Ruling cu: rolling out before 0.75 s takes zero damage from the blast.
	var hits := []
	trapper.hit_player.connect(func(amount: float, _shove: Vector3): hits.append(amount))
	player.reset_to(pit_center + Vector3(14.0, 1.05, 0.0))
	trapper._live(MagTrapper.REPULSE_WARN + 0.02)
	t.eq("heavy ball that rolled out takes zero repulse damage", [trapper.repulse_blasts, hits.size()], [1, 0])
	trapper._end()
	trapper.free()

	# 5. Camping inside the ring for full 0.75 s gets blasted outward.
	_clear()
	player.reset_to(ball)
	var camper_t := _live_trapper(Vector3(12.0, 0.0, 0.0))
	var camper_hits := []
	camper_t.hit_player.connect(func(amount: float, _shove: Vector3): camper_hits.append(amount))
	var c_center: Vector3 = camper_t.telegraph().center
	player.reset_to(c_center + Vector3(1.5, 1.05, 0.0))
	root.remove_meta(AttackBudget.LAST_META)
	camper_t._live(1.0 / 90.0)
	camper_t._live(MagTrapper.REPULSE_WARN + 0.02)
	t.eq("camping ball takes Polarity Repulse blast", [camper_t.repulse_blasts, camper_hits], [1, [MagTrapper.REPULSE_DAMAGE]])
	camper_t._end()
	camper_t.free()

	# 6. Practiced payoff: slamming the disc during the 0.75 s flip punts magnetized disc into nearest enemy pack.
	_clear()
	player.reset_to(ball)
	var punt_t := _live_trapper(Vector3(12.0, 0.0, 0.0))
	var p_center: Vector3 = punt_t.telegraph().center
	var pack_a: Node3D = game.combat.spawn_enemy("chaser", game.ctx.terrain.drop_point(p_center.x + 12.0, p_center.z, 1.8))
	var pack_b: Node3D = game.combat.spawn_enemy("chaser", game.ctx.terrain.drop_point(p_center.x + 14.0, p_center.z + 2.0, 1.8))
	pack_a.hp = 200.0
	pack_b.hp = 200.0
	var hp_a_before: float = pack_a.hp
	var hp_b_before: float = pack_b.hp
	var punted_events := []
	punt_t.disc_punted.connect(func(_at: Vector3, count: int): punted_events.append(count))
	player.reset_to(p_center + Vector3.UP * 1.05)
	root.remove_meta(AttackBudget.LAST_META)
	punt_t._live(1.0 / 90.0)
	t.check("flip active before slam", punt_t._polarity_flip)
	game.events.slammed.emit(p_center, 1.0, 1.0)
	t.eq("slamming flipping disc triggers Disc Punt and cancels blast", [punt_t.disc_punts, punt_t._polarity_flip, punt_t.broken_by], [1, false, "smash"])
	var puck: Node = game.ctx.root.find_child("PuntedMagDisc", true, false)
	var puck_mesh := puck.find_child("PuntedDiscMesh", true, false) as MeshInstance3D if puck != null else null
	t.check("punted disc reuses GLB ArrayMesh (zero PrimitiveMesh)", puck != null and puck_mesh != null and not (puck_mesh.mesh is PrimitiveMesh))
	# Step physics so the punted puck slides into the pack and detonates.
	await _frames(90)
	t.check("punted disc reached and struck the enemy pack", punted_events.size() == 1 and int(punted_events[0]) >= 2, str(punted_events))
	t.check("both pack enemies took damage and knockback", pack_a.hp < hp_a_before and pack_b.hp < hp_b_before and pack_a.knocks > 0 and pack_b.knocks > 0,
		"a=%.1f->%.1f b=%.1f->%.1f" % [hp_a_before, pack_a.hp, hp_b_before, pack_b.hp])

	player.heft_of = orig_heft
	_clear()
	game.free()
	quit(t.verdict())
