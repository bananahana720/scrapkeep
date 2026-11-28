extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const WardenDress := preload("res://src/presentation/warden_dress.gd")
const T := preload("res://tests/support/t.gd")

# KF8a (wave 13): a park Warden of each kind (spec "harpoon_anchor": true) wears its recipe body
# (warden_reactor.glb, warden_swarm.glb plus warden_swarm_kit_drones.glb, warden_mind.glb) in
# place of the clamp base and kit, through warden_dress.gd's BODIES. A stepped headless
# fight on the alpha table checks, per kind and mounting:
#   body      HeroWarden at y -HALF_HEIGHT, the swarm's drone kit under it, no clamp or HeroKit;
#   point     the body's WeakPoint within 0.05 m of warden.family_point_at(), and the point where
#             the rows put it from the Warden's centre (reactor 5.2 = 6.8 in the body, swarm 5.1 =
#             6.7, mind hang -8, mind perch 6.086 with the perch clip held);
#   draws     mesh surfaces under HeroWarden equal the authored GLBs' and fit the class budget;
#   clips     a recorder on every AnimationPlayer sees, in order: pulse_warn on the charge (the
#             swarm's 2.4 s pulse is its charge), pulse then the mounting's extra (gates_open,
#             pour) then active on the pulse, hoist_ride on a ride, takeoff then land on a flight,
#             stagger_open or grip_falter on a stagger (the reactor's open seam lit), each chunk's
#             own clip, and final_quiet or break on the last chunk;
#   held      a lost chunk stays lost 2 s after its clip and again after a whole idle loop
#             (reactor jacket hidden, swarm shed ring at zero scale, mind finger at its end pose);
#   mind      the Pose node yaws to face the ball, the Lens bone looks at the ball, and on the
#             spires Pose carries PosePerch's transform with the perch pose under idle.
# A non-anchor Warden keeps the clamp (hero_warden_assets_test covers that path in full).

const AWAY := Vector3(70.0, 0.0, 70.0)
const BALL_OUT := Vector3(10.0, 1.2, 0.0)
const CASES := [
	{"family": "reactor", "stage": 1, "mounting": "dam_face", "point": 5.2, "body_point": 6.8, "fight": true},
	{"family": "reactor", "stage": 2, "mounting": "flume", "point": 5.2, "body_point": 6.8, "pulse_only": true},
	{"family": "swarm", "stage": 3, "mounting": "headframe", "point": 5.1, "body_point": 6.7, "fight": true},
	{"family": "swarm", "stage": 4, "mounting": "sinkhole", "point": 5.1, "body_point": 6.7},
	{"family": "mind", "stage": 5, "mounting": "under_island", "point": -8.0, "fight": true},
	{"family": "mind", "stage": 6, "mounting": "spires", "point": 6.086, "pulse_only": true},
]
const GLBS := {
	"reactor": ["res://assets/models/warden_reactor.glb"],
	"swarm": ["res://assets/models/warden_swarm.glb", "res://assets/models/warden_swarm_kit_drones.glb"],
	"mind": ["res://assets/models/warden_mind.glb"],
}
const CLASS_DRAWS := {"warden_base": 32, "warden_kit": 18}
const PULSE_EXTRA := {"dam_face": "gates_open", "flume": "pour"}
const STAGGER_CLIP := {"swarm": "stagger_open", "mind": "grip_falter"}
const FINAL_CLIP := {"reactor": "final_quiet", "swarm": "break", "mind": "final_quiet"}

var _t := T.new("warden_bodies_test")
var _game
var _player
var _combat
var _hook
var _source := Intent.Scripted.new()
var _seen: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(_ticks(0.4))
	_game.run.set_max_hp(99999.0)
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _game.flow.warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	await _frames(2)
	_hook = _game.presentation.hero_assets
	var bodies_named := WardenDress.BODIES.has("reactor") and WardenDress.BODIES.has("swarm") and WardenDress.BODIES.has("mind")
	_t.check("WardenDress.BODIES names the three bodies", bodies_named, "")
	if not bodies_named:
		_finish()
		return
	for case in CASES:
		await _case(case)
	await _clamp_stays()
	_finish()


func _finish() -> void:
	_t.check("the body test ran its checks", _t.checks >= 60, "%d checks" % _t.checks)
	_game.free()
	quit(_t.verdict())


func _spawn(case: Dictionary, anchor := true) -> Node3D:
	var base: Vector3 = _game.flow.warden.global_position if is_instance_valid(_game.flow.warden) else Vector3.ZERO
	var warden = WardenScript.new()
	_game.ctx.root.add_child(warden)
	warden.global_position = base + AWAY
	var spec := {"family": case.family, "stage": case.stage, "plating": 90.0, "hp": 650.0, "reach": 30.0}
	spec = _combat.fleet.dress("warden", spec)
	spec.merge({"harpoon_anchor": anchor, "family": case.family, "mounting": case.mounting, "variant": ""}, true)
	warden.setup(_player, _game.ctx.terrain, _game.ctx.root, Callable(_game.flow, "in_play"), 1.0, spec)
	warden.hit_player.connect(_combat._on_player_hit.bind("warden"))
	return warden


func _sit_ball(warden: Node3D) -> void:
	var at: Vector3 = warden.global_position + BALL_OUT
	_player.reset_to(_game.ctx.terrain.drop_point(at.x, at.z, 1.2))


func _label(case: Dictionary) -> String:
	return "%s %s" % [case.family, case.mounting]


func _record(name: StringName, player: AnimationPlayer) -> void:
	_seen.append([String(name), player.name, Engine.get_physics_frames()])


# The non-idle clip names seen since `from`, in order, once per name per run of repeats.
func _names(from: int) -> Array:
	var out: Array = []
	for i in range(from, _seen.size()):
		var n: String = _seen[i][0]
		if n == "idle":
			continue
		if out.is_empty() or out.back() != n:
			out.append(n)
	return out


func _in_order(got: Array, want: Array) -> bool:
	var at := 0
	for n in got:
		if at < want.size() and n == want[at]:
			at += 1
	return at == want.size()


func _wait_clip(name: String, from: int, seconds: float) -> bool:
	for i in _ticks(seconds):
		if _names(from).has(name):
			return true
		await physics_frame
	return _names(from).has(name)


func _case(case: Dictionary) -> void:
	var label := _label(case)
	var warden := _spawn(case)
	await _frames(3)
	_sit_ball(warden)
	await _frames(3)
	var rec: Dictionary = _hook.warden_of(warden)
	var body := warden.get_node_or_null("HeroWarden") as Node3D
	_t.check(label + ": the body dresses the Warden", not rec.is_empty() and body != null and rec.get("body") == body,
			"rec %s, body %s" % [not rec.is_empty(), body])
	if rec.is_empty() or body == null or rec.get("body") != body:
		warden.queue_free()
		await _frames(2)
		return
	_t.near(label + ": HeroWarden at -HALF_HEIGHT", body.position.y, -WardenScript.HALF_HEIGHT, 0.0001)
	_t.check(label + ": no clamp base or kit", body.find_child("Tower", true, false) == null and body.find_child("HeroKit", true, false) == null
			and warden.find_children("HeroWarden", "", false, false).size() == 1, "")
	if case.family == "swarm":
		_t.check(label + ": the drone kit rides under the body", body.find_child("SwarmDrones", true, false) != null, "")
	if case.family == "reactor":
		var dam: bool = case.mounting == "dam_face"
		_t.check(label + ": only this mounting's parts show", body.find_child("GateL", true, false).visible == dam
				and body.find_child("GateR", true, false).visible == dam and body.find_child("PourLip", true, false).visible == not dam, "")
	_check_draws(label, case, body)
	var players: Array = rec.get("players", [])
	_t.check(label + ": the body's players are driven", not players.is_empty(), "%d players" % players.size())
	for p in players:
		(p as AnimationPlayer).animation_started.connect(_record.bind(p))
	await _frames(_ticks(0.3))
	_check_point(label, case, warden, rec)
	if case.family == "mind":
		_check_mind_pose(label, case, warden, rec)
	if case.get("fight", false) or case.get("pulse_only", false):
		await _pulse(label, case, warden)
	if case.family == "swarm" and case.get("fight", false):
		var from := _seen.size()
		warden.mount_driver.rides += 1
		_t.check(label + ": a ride plays hoist_ride", await _wait_clip("hoist_ride", from, 1.0), str(_names(from)))
	if case.mounting == "spires":
		await _flight(label, warden)
		_check_point(label + " after the flight", case, warden, rec)
		_check_mind_pose(label + " after the flight", case, warden, rec)
	if case.get("fight", false):
		await _fight(label, case, warden, rec)
	var id := warden.get_instance_id()
	warden.queue_free()
	await _frames(3)
	_t.check(label + ": the record and body go with the Warden", not _hook._wardens.has(id) and not is_instance_valid(body), "")


func _check_draws(label: String, case: Dictionary, body: Node3D) -> void:
	var want := 0
	var cap := 0
	for path in GLBS[case.family]:
		var scene := (load(path) as PackedScene).instantiate()
		want += _surfaces(scene)
		scene.free()
		cap += CLASS_DRAWS["warden_kit" if path.ends_with("_kit_drones.glb") else "warden_base"]
	var got := _surfaces(body)
	_t.check(label + ": draws match the authored body and fit the class budget", got == want and got <= cap,
			"%d surfaces, authored %d, cap %d" % [got, want, cap])


func _surfaces(node: Node) -> int:
	var n := 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		n += (mi as MeshInstance3D).mesh.get_surface_count()
	return n


func _check_point(label: String, case: Dictionary, warden: Node3D, rec: Dictionary) -> void:
	var weak := rec.get("weak") as Node3D
	var at: Vector3 = warden.family_point_at()
	_t.check(label + ": the body's WeakPoint sits on the fight's point", weak != null and weak.global_position.distance_to(at) <= 0.05,
			"weak %s, point %s" % [weak.global_position if weak != null else Vector3.INF, at])
	var offset: Vector3 = at - warden.global_position
	_t.check(label + ": the point sits where the rows put it", offset.distance_to(Vector3(0, case.point, 0)) <= 0.05, "offset %s" % offset)
	if case.has("body_point") and weak != null:
		var local: Vector3 = rec.body.to_local(weak.global_position)
		_t.check(label + ": the WeakPoint in the body frame", local.distance_to(Vector3(0, case.body_point, 0)) <= 0.05, "local %s" % local)


func _check_mind_pose(label: String, case: Dictionary, warden: Node3D, rec: Dictionary) -> void:
	var body: Node3D = rec.body
	var pose := body.find_child("Pose", true, false) as Node3D
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var ball: Vector3 = _player.ball_position()
	var flat := Vector3(ball.x - warden.global_position.x, 0, ball.z - warden.global_position.z).normalized()
	var facing := -pose.global_basis.z
	facing.y = 0.0
	var yaw_err := rad_to_deg(facing.normalized().angle_to(flat))
	_t.check(label + ": the Pose node faces the ball", yaw_err <= 3.0, "%.2f degrees off" % yaw_err)
	var lens := skel.find_bone("Lens")
	var rest: Basis = skel.get_bone_global_rest(lens).basis
	var axis := rest.inverse() * Vector3.FORWARD
	var lens_xf: Transform3D = skel.global_transform * skel.get_bone_global_pose(lens)
	var look := (lens_xf.basis * axis).normalized()
	var want := (ball - lens_xf.origin).normalized()
	var lens_err := rad_to_deg(look.angle_to(want))
	_t.check(label + ": the Lens bone looks at the ball", lens_err <= 4.0, "%.2f degrees off" % lens_err)
	if case.mounting == "spires":
		var perch := body.find_child("PosePerch", true, false) as Node3D
		_t.check(label + ": Pose carries the perch transform", pose.position.distance_to(perch.position) <= 0.001
				and absf(pose.basis.y.y + 1.0) <= 0.001, "pose %s" % pose.transform)
		var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var held := _end_pose(player.get_animation("perch"), "Finger1_2")
		var bone := skel.find_bone("Finger1_2")
		var err := rad_to_deg(skel.get_bone_pose_rotation(bone).angle_to(held))
		# Positive control: idle alone keys that bone far from the perch grip, so the hold is what holds.
		var idle_gap := rad_to_deg(_end_pose(player.get_animation("idle"), "Finger1_2", 0.0).angle_to(held))
		_t.check(label + ": the perch grip holds under %s" % player.current_animation, err <= 1.0 and idle_gap >= 5.0,
				"%.2f degrees off; idle alone %.1f degrees away" % [err, idle_gap])


# The rotation a clip leaves on `bone` at its last frame (or at `at` seconds).
func _end_pose(anim: Animation, bone: String, at := -1.0) -> Quaternion:
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and path.get_subname_count() > 0 and String(path.get_subname(0)) == bone:
			return anim.rotation_track_interpolate(t, anim.length if at < 0.0 else at)
	return Quaternion.IDENTITY


func _pulse(label: String, case: Dictionary, warden: Node3D) -> void:
	var from := _seen.size()
	var pulses: int = warden.pulses
	warden._pulse_clock = WardenScript.PULSE_CYCLE - WardenScript.PULSE_TELEGRAPH - 0.05
	var guard := 0
	while warden.state_name() != "charging" and guard < _ticks(6.0):
		_sit_ball_if_strayed(warden)
		await physics_frame
		guard += 1
	_t.check(label + ": the charge starts", warden.state_name() == "charging", "after %d ticks" % guard)
	var charge_clip := "pulse" if case.family == "swarm" else "pulse_warn"
	_t.check(label + ": the charge plays " + charge_clip, await _wait_clip(charge_clip, from, 0.5), str(_names(from)))
	if case.family != "swarm":
		warden._charge_time = maxf(warden._charge_time, warden._charge_len - 0.05)
	guard = 0
	while warden.pulses == pulses and guard < _ticks(3.0):
		await physics_frame
		guard += 1
	_t.check(label + ": the pulse lands", warden.pulses == pulses + 1, "")
	await _wait_clip("active", from, 3.0)
	var want: Array = [charge_clip]
	if case.family != "swarm":
		want.append("pulse")
	if PULSE_EXTRA.has(case.mounting):
		want.append(PULSE_EXTRA[case.mounting])
	want.append("active")
	_t.check(label + ": the pulse plays " + " then ".join(want), _in_order(_names(from), want), str(_names(from)))


func _sit_ball_if_strayed(warden: Node3D) -> void:
	var ball: Vector3 = _player.ball_position()
	if Vector2(ball.x - warden.global_position.x, ball.z - warden.global_position.z).length() > 25.0:
		_sit_ball(warden)


func _flight(label: String, warden: Node3D) -> void:
	var from := _seen.size()
	var driver = warden.mount_driver
	driver.perch_clock = driver._cycle
	var guard := 0
	while driver.phase == "perched" and guard < _ticks(4.0):
		await physics_frame
		guard += 1
	while driver.phase != "perched" and guard < _ticks(8.0):
		await physics_frame
		guard += 1
	await _wait_clip("land", from, 1.0)
	_t.check(label + ": a flight plays takeoff then land", _in_order(_names(from), ["takeoff", "land"]), str(_names(from)))
	await _frames(_ticks(0.8))


func _stagger(warden: Node3D) -> void:
	warden._apply_posture({"gain": 1000.0})


func _shatter(warden: Node3D) -> void:
	warden._apply_posture({"shatter": true, "dealt": 0.0})


func _fight(label: String, case: Dictionary, warden: Node3D, rec: Dictionary) -> void:
	var from := _seen.size()
	_stagger(warden)
	await _frames(_ticks(0.2))
	_t.check(label + ": the stagger opens", warden.staggered(), "")
	if case.family == "reactor":
		var light: StandardMaterial3D = rec.materials.get("ancient_light")
		_t.check(label + ": the stagger lights the open seam", light != null and is_equal_approx(light.emission_energy_multiplier, WardenKit.SEAM_OPEN),
				"emission %s" % (light.emission_energy_multiplier if light != null else -1.0))
	else:
		_t.check(label + ": the stagger plays " + STAGGER_CLIP[case.family], _names(from).has(STAGGER_CLIP[case.family]), str(_names(from)))
	for n in range(1, 5):
		from = _seen.size()
		if not warden.staggered():
			_stagger(warden)
			await _frames(2)
		_shatter(warden)
		var clip := _chunk_clip(case.family, n)
		_t.check(label + ": chunk %d plays %s" % [n, clip], await _wait_clip(clip, from, 0.5), str(_names(from)))
		var waited := 0.0
		if case.family == "swarm" and n < 4:
			# Only the lost ring falls: the rings still on keep their rest place and size.
			var length: float = rec.body.find_child("AnimationPlayer", true, false).get_animation(clip).length
			await _frames(_ticks(0.5))
			_check_unlost(label + ": chunk %d mid-clip, the other rings stay on" % n, rec, n)
			await _frames(_ticks(maxf(length - 0.55, 0.0)))
			_check_unlost(label + ": chunk %d clip end, the other rings stay on" % n, rec, n)
			waited = maxf(length - 0.05, 0.5)
		if n == 1:
			await _frames(_ticks(maxf(1.0 + 2.0 - waited, 0.0)))
			_check_held(label + ": chunk 1 held 2 s after its clip", case, rec, 1)
			await _frames(_ticks(4.5))
			_t.check(label + ": an idle loop ran after chunk 1", _seen.slice(from).any(func(e): return e[0] == "idle"), "")
			_check_held(label + ": chunk 1 held after an idle loop", case, rec, 1)
		else:
			await _frames(_ticks(maxf(1.2 - waited, 0.0)))
	_t.check(label + ": the last chunk plays " + FINAL_CLIP[case.family], await _wait_clip(FINAL_CLIP[case.family], from, 1.5)
			and _in_order(_names(from), [_chunk_clip(case.family, 4), FINAL_CLIP[case.family]]), str(_names(from)))
	_check_held(label + ": every chunk held at the end", case, rec, 4)
	if case.family == "mind":
		var thumb: StandardMaterial3D = rec.materials.get("ancient_light_thumb")
		_t.check(label + ": the last seam goes out", thumb != null and thumb.emission_energy_multiplier <= 0.001, "")


func _chunk_clip(family: String, n: int) -> String:
	match family:
		"reactor":
			return "chunk_lost" if n == 1 else "chunk_lost_%d" % (n - 1)
		"swarm":
			return "chunk_shed"
		"mind":
			return WardenDress.MIND_CHUNK_FINGERS[n - 1].clip
	return ""


func _check_held(label: String, case: Dictionary, rec: Dictionary, lost: int) -> void:
	var body: Node3D = rec.body
	var ok := true
	var detail := ""
	for n in range(1, lost + 1):
		match case.family:
			"reactor":
				var jacket := body.find_child("Jacket%d" % (n - 1), true, false) as Node3D
				ok = ok and jacket != null and not jacket.is_visible_in_tree()
				detail += "Jacket%d %s " % [n - 1, jacket.visible if jacket != null else null]
			"swarm":
				var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
				var ring: String = WardenDress.BODIES.swarm.shed_rings[n - 1]
				var s := skel.get_bone_pose_scale(skel.find_bone(ring))
				ok = ok and s.length() <= 0.01
				detail += "%s %s " % [ring, s]
			"mind":
				var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
				var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
				var finger: Dictionary = WardenDress.MIND_CHUNK_FINGERS[n - 1]
				var digit: String = String(finger.seam).right(1)
				var bone := "Finger%s_2" % digit
				var held := _end_pose(player.get_animation(finger.clip), bone)
				var err := rad_to_deg(skel.get_bone_pose_rotation(skel.find_bone(bone)).angle_to(held))
				# Positive control: idle's own key for the bone is far from the curled end pose.
				var idle_gap := rad_to_deg(_end_pose(player.get_animation("idle"), bone, 0.0).angle_to(held))
				ok = ok and err <= 1.0 and idle_gap >= 5.0
				detail += "%s %.2f deg (idle %.1f away) " % [bone, err, idle_gap]
	_t.check(label, ok, detail)


# The shed rings not yet lost (shed_rings[lost ..]) sit at their rest place at full size.
func _check_unlost(label: String, rec: Dictionary, lost: int) -> void:
	var skel := (rec.body as Node3D).find_child("Skeleton3D", true, false) as Skeleton3D
	var rings: Array = WardenDress.BODIES.swarm.shed_rings
	var ok := skel != null and lost < rings.size()
	var detail := ""
	for i in range(lost, rings.size()):
		var bone := skel.find_bone(rings[i])
		var s := skel.get_bone_pose_scale(bone)
		var drift := skel.get_bone_pose_position(bone).distance_to(skel.get_bone_rest(bone).origin)
		ok = ok and bone >= 0 and s.distance_to(Vector3.ONE) <= 0.05 and drift <= 0.25
		detail += "%s scale %s drift %.3f " % [rings[i], s, drift]
	_t.check(label, ok, detail)


# A Warden that is no harpoon anchor keeps the clamp base and kit.
func _clamp_stays() -> void:
	var warden := _spawn({"family": "mind", "stage": 5, "mounting": "under_island"}, false)
	await _frames(3)
	var rec: Dictionary = _hook.warden_of(warden)
	var base = rec.get("base")
	_t.check("an authored (non-anchor) Warden keeps the clamp", not rec.is_empty() and rec.get("body") == null and base != null
			and base.find_child("Tower", true, false) != null and rec.get("kit") != null, "")
	_t.check("an authored mind keeps the kit's point", (warden.family_point_at() - warden.global_position).is_equal_approx(Vector3.UP * (WardenKit.DECK + 5.4)), "")
	warden.queue_free()
	await _frames(2)
