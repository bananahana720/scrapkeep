extends SceneTree

# A crew stands on the ground, never in it (Andrew, 13 Nov 2026: "the enemies are clipping into
# the terrain"). Each walking crew is set on a slope of the slice and on the flat; its drawn
# model's lowest points are compared with the terrain under them while it stands and turns. The
# model may not sink more than SINK_MAX into the ground nor float more than FLOAT_MAX above it.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const T := preload("res://tests/support/t.gd")

const KINDS := ["chaser", "hooker", "swatter", "mag_trapper", "netcaster", "bola_thrower", "catch_trap", "jolt_layer", "plated_brute", "deflector", "gyro_jammer"]
const SINK_MAX := 0.12
const FLOAT_MAX := 0.25
const FOOTPRINT := 1.5
const SLOPE_MIN := 14.0
const SLOPE_MAX := 26.0

var _game
var _t := T.new("enemy_ground_contact_test")
var report := false


func _initialize() -> void:
	report = "--report" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	await _boot()
	EnemyMotion.headless_idle = true
	var terrain = _game.ctx.terrain
	var ball: Vector3 = _game.player.ball_position()
	var slope := _find(terrain, ball, true)
	var flat := _find(terrain, ball, false)
	_t.check("the slice has a slope and a flat to stand on", slope != Vector3.INF and flat != Vector3.INF, "%s %s" % [slope, flat])
	if slope == Vector3.INF or flat == Vector3.INF:
		quit(_t.verdict())
		return
	for kind in KINDS:
		for place in [["slope", slope], ["flat", flat]]:
			var got := await _stand(kind, place[1])
			var line := "%s on the %s: sinks %.2f m, floats %.2f m" % [kind, place[0], got.x, got.y]
			if report:
				print("REPORT ", line)
			_t.check(kind + " stands on the " + place[0], got.x <= SINK_MAX and got.y <= FLOAT_MAX, line)
	EnemyMotion.headless_idle = false
	quit(_t.verdict())


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	for i in 3:
		await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _slope_at(terrain, x: float, z: float) -> float:
	var e := 0.5
	var dx: float = terrain.height(x + e, z) - terrain.height(x - e, z)
	var dz: float = terrain.height(x, z + e) - terrain.height(x, z - e)
	return rad_to_deg(atan(Vector2(dx, dz).length() / (2.0 * e)))


# A spot 12 to 90 m from the ball whose ground, 2 m around, is a steady slope (or flat).
func _find(terrain, ball: Vector3, sloped: bool) -> Vector3:
	for r in range(12, 90, 3):
		for a in 24:
			var x := ball.x + cos(TAU * a / 24.0) * r
			var z := ball.z + sin(TAU * a / 24.0) * r
			var steady := true
			for o in [Vector2.ZERO, Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
				var s := _slope_at(terrain, x + o.x, z + o.y)
				steady = steady and (s >= SLOPE_MIN and s <= SLOPE_MAX if sloped else s < 6.0)
			if steady:
				return Vector3(x, terrain.height(x, z), z)
	return Vector3.INF


# x: the deepest the model's points go under the ground; y: the most its lowest point floats.
func _stand(kind: String, at: Vector3) -> Vector2:
	var terrain = _game.ctx.terrain
	var enemy = _game.combat.spawn_enemy(kind, at + Vector3.UP * 1.6)
	enemy.hp = 100000.0
	enemy._rest = 999.0
	# It holds the spot so the read is the spot's slope; it still turns to watch the ball.
	if kind == "chaser":
		# A rolling ball rams this light body off its feet on the flat. Measure its planted stance.
		_game.player.body().freeze = true
		enemy._age = enemy.ENTRY_GRACE_S
		enemy.run_speed = 0.0
	else:
		enemy.walk_speed = 0.0
	var sink := 0.0
	var float_up := 0.0
	for i in 150:
		await physics_frame
		if i < 60 or not enemy.is_on_floor():
			continue
		var lowest := INF
		for mi: MeshInstance3D in enemy.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree() or mi.mesh == null or mi.layers == 0:
				continue
			var faces := mi.mesh.get_faces()
			var step := maxi(1, faces.size() / 300)
			for v in range(0, faces.size(), step):
				var p: Vector3 = mi.global_transform * faces[v]
				# Only the crew's own footprint: the swatter's paddle is a long arm that sweeps the ground.
				if Vector2(p.x - enemy.global_position.x, p.z - enemy.global_position.z).length() > FOOTPRINT:
					continue
				var gap: float = p.y - terrain.height(p.x, p.z)
				sink = maxf(sink, -gap)
				lowest = minf(lowest, gap)
		if lowest < INF:
			float_up = maxf(float_up, lowest)
	enemy.free()
	if kind == "chaser":
		_game.player.body().freeze = false
	await physics_frame
	return Vector2(sink, float_up)
