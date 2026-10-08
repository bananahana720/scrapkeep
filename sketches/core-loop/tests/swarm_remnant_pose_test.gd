extends SceneTree

# VX7-2: a swarm remnant reads as a threat and its scattered state differs from its
# intact one. The slab stands at least 0.4 m with its underside on the ground, the faces
# toward its heading carry the threat stripe, and scattered drones hold at least 1.2 m
# between centres, each tilted, with the inlay dimmer than intact.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Remnant := preload("res://src/combat/swarm_remnant.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")
const SCATTER_FRAMES := 75

var _game
var _t := T.new("swarm_remnant_pose_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var terrain = _game.ctx.terrain
	var ball: Vector3 = terrain.drop_point(-100.0, -90.0, 1.2)
	_game.player.reset_to(ball)
	var drone = _game.ctx.spawner.spawn_enemy("swarm_remnant", terrain.drop_point(-100.0, -78.0, 0.5))
	var pack: Array = drone.swarm.alive()
	await _frames(20)
	var body := drone.find_child("RemnantBody", true, false) as MeshInstance3D
	var seam := drone.find_child("RemnantSeam", true, false) as MeshInstance3D
	if not _t.check("VX7-2 model", body != null and seam != null and pack.size() >= 2, "GLB drone with %d in its rack" % pack.size()):
		quit(_t.verdict())
		return
	var local: Transform3D = drone.global_transform.affine_inverse() * body.global_transform
	var box: AABB = local * body.mesh.get_aabb()
	_t.check("VX7-2 slab height", box.size.y >= 0.4, "slab stands %.3f m" % box.size.y)
	_t.check("VX7-2 grounded", is_equal_approx(Remnant.HOVER, drone.half_height) and absf(box.position.y + drone.half_height) <= 0.01,
		"rest height %.2f m over the ground, slab underside %.3f m below centre" % [Remnant.HOVER, -box.position.y])
	var lead := body.mesh.surface_get_material(1) as StandardMaterial3D if body.mesh.get_surface_count() == 2 else null
	var forward := lead != null
	if lead != null:
		for n in body.mesh.surface_get_arrays(1)[Mesh.ARRAY_NORMAL] as PackedVector3Array:
			forward = forward and n.z > 0.0
	_t.check("VX7-2 leading edge", lead != null and lead.albedo_texture == Threat.Painter.stripe_texture() and forward,
		"leading-edge surface is the threat stripe and faces the heading")
	var intact: float = (seam.get_active_material(0) as StandardMaterial3D).emission_energy_multiplier
	var intact_tilt = drone.get("_slab").basis if drone.get("_slab") != null else null
	drone.swarm.scatter(drone.swarm.centre)
	await _frames(SCATTER_FRAMES)
	var scattered: bool = drone.swarm.state == drone.swarm.State.SCATTERED
	var closest := INF
	var tilts := {}
	var dim := true
	for a in pack.size():
		var d = pack[a]
		if d.get("_slab") != null:
			tilts[snappedf(d._slab.basis.get_euler().length(), 0.01)] = true
		var s := d.find_child("RemnantSeam", true, false) as MeshInstance3D
		var mat := s.get_active_material(0) as StandardMaterial3D
		dim = dim and s.visible and mat != null and mat.emission_energy_multiplier < intact
		for b in range(a + 1, pack.size()):
			var gap: Vector3 = d.global_position - pack[b].global_position
			gap.y = 0.0
			closest = minf(closest, gap.length())
	_t.check("VX7-2 spread", scattered and closest >= 1.2,
		"after %d frames scattered %s, closest centres %.2f m" % [SCATTER_FRAMES, scattered, closest])
	_t.check("VX7-2 tilt", intact_tilt == Basis.IDENTITY and tilts.size() >= 2 and not tilts.has(0.0),
		"%d distinct scattered tilts" % tilts.size())
	_t.check("VX7-2 inlay dims", dim, "every scattered inlay stays visible below intact emission %.2f" % intact)
	quit(_t.verdict())
