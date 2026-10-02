extends Node3D

const ActivityView := preload("res://src/world/activity_view.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Interact := preload("res://src/world/interact.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")

# The standing activities (LEGIBILITY sections 7 and 9, wave R3): optional things on a map that
# stand lit from the stage's first frame, finish on an action the player already knows and pay
# one part at the spot. No timer, no prompt, no key. The map says where (StageMap.activity_sites),
# EventKinds.ACTIVITY_ROWS says how a site looks and sounds, RULES says how it starts, what
# finishes it and what it pays. A site whose id has no rule is not built (surge_run has no site
# on the Reach). A stage entry, so a retry and a new run too, builds every site unfinished; a
# finished site stays finished until the next stage entry.
#
# starts:   "ring" (the ball inside `ring` metres), "none" (nothing starts it) or
#           "near_or_hit" (the ball inside `wake` metres, or the brute is hit).
# finishes: "pack_dead" (every enemy the ring spawned is dead), "wall_broken" (the cache's wall
#           goes to a ram at cruise or a slam of at least that strength) or "brute_dead".
# pay:      `scrap` (180, so three activities lift the ball two heft classes), taken with one
#           part from `rarities`, as a pickup at `where`: the altar, the pedestal or the
#           place the brute fell. A roll with no part pays the scrap when the activity finishes. part_gained carries `source`, which is not in
#           EventKinds.CEREMONY_SOURCES, so no ceremony pauses the game for it.
const PAY_RARITIES := ["uncommon", "rare"]
const PAY_SCRAP := 180
const RULES := {
	"ambush_altar": {
		"starts": "ring", "ring": 8.0, "pack": ["chaser", "chaser", "lobber"], "finishes": "pack_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_ambush", "where": "altar"},
	},
	"cracked_cache": {
		"starts": "none", "ring": 5.0, "finishes": "wall_broken", "face": Vector2(0.0, -1.0),
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_cache", "where": "pedestal"},
	},
	"hauler_bounty": {
		"starts": "near_or_hit", "ring": 4.0, "wake": 30.0, "leash": 40.0, "return_speed": 9.0, "kind": "plated_brute",
		"finishes": "brute_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_bounty", "where": "fall"},
	},
}

const PICKUP_REACH := 1.7
const PICKUP_HEIGHT := 3.0
const RING_HEIGHT := 8.0
const BRUTE_DROP := 2.4
const SPAWN_CLEARANCE := 2.4
const PACK_TURN := PI / 6.0

# The cache's pocket: the cracked face, two side walls, a back wall and the pedestal, in the
# site's frame with +z out through the face.
const WALL_HALF_W := 6.0
const WALL_DEPTH := 8.0
const WALL_HEIGHT := 6.0
const WALL_SINK := 3.0
const WALL_REACH := 3.0
const SLAM_REACH := 7.0
# `slammed` carries the ball's own strength for the landing (player.slam_strength), not a speed.
# A slam breaks the wall at SLAM_MIN_PER_CRUISE times the strength of a flat landing at cruise speed,
# so a landing as fast as the ram that breaks it breaks it too and a slower one does not.
const SLAM_MIN_PER_CRUISE := 1.0
const PEDESTAL_BACK := 4.0

var ctx
var sites: Array = []
var _pending_stage := false


# One standing activity: its rule, its look, its state and, once it has finished, its pay.
class Site extends Node3D:
	var id := ""
	var rule := {}
	var view
	var done := false
	var started := false
	var pack: Array = []
	var brute
	var wall: Node3D
	var pedestal := Vector3.ZERO
	var pickup: Node3D
	var pickup_part := ""
	var cap: Node3D
	var pickup_taken := false
	var inside_pickup := true


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Activities"
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(func(_reason: String): clear())
	ctx.events.slammed.connect(func(at: Vector3, strength: float, _flatness: float): _slammed(at, strength))


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	clear()
	var map = ctx.terrain.map()
	if not "activity_sites" in map:
		return
	for spec in map.activity_sites:
		var id := String(spec["id"])
		if not RULES.has(id):
			continue
		# Calm mode spawns nothing, so the ambush and the bounty could never be paid there.
		if ctx.calm and String(RULES[id]["finishes"]) != "wall_broken":
			continue
		sites.append(_build(id, spec["at"]))
	_pending_stage = true


func clear() -> void:
	for site in sites:
		if is_instance_valid(site):
			site.queue_free()
	sites.clear()
	_pending_stage = false


func site(id: String) -> Site:
	for s in sites:
		if s.id == id:
			return s
	return null


# Enemies the activities keep standing that the director's cap does not count.
func standing() -> int:
	var n := 0
	for s in sites:
		if s.brute != null and is_instance_valid(s.brute) and not s.brute.is_dead():
			n += 1
	return n


func _build(id: String, at: Vector2) -> Site:
	var s := Site.new()
	s.id = id
	s.rule = RULES[id]
	s.name = "Activity_" + id
	add_child(s)
	s.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
	s.view = ActivityView.new()
	s.add_child(s.view)
	s.view.build(id, float(s.rule["ring"]))
	match id:
		"ambush_altar":
			_build_altar(s)
		"cracked_cache":
			_build_cache(s)
	return s


func _build_altar(s: Site) -> void:
	_mesh_cylinder(s, 0.45, 3.2, Vector3.UP * 1.6, Palette.solid(Palette.COPPER))
	s.cap = _mesh_box(s, Vector3(1.4, 0.6, 1.4), Vector3.UP * 3.5, Palette.solid(EventKinds.activity_color(s.id), 1.2))


func _build_cache(s: Site) -> void:
	var face: Vector2 = s.rule["face"]
	s.rotation.y = atan2(face.x, face.y)
	var concrete := Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL)
	var tall := WALL_HEIGHT + WALL_SINK
	var mid := tall * 0.5 - WALL_SINK
	s.wall = _mesh_box(s, Vector3(WALL_HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, 0.0),
		Palette.striped(Palette.SANDSTONE, Palette.VERDIGRIS), true)
	for k in 3:
		var crack := _mesh_box(s.wall, Vector3(WALL_HALF_W * 1.3, 0.2, 1.1), Vector3(0.0, -1.2 + k * 1.6, 0.0),
			Palette.solid(Palette.CHARCOAL))
		crack.rotation.z = 0.5 - k * 0.45
	for side in [-1.0, 1.0]:
		_mesh_box(s, Vector3(1.0, tall, WALL_DEPTH), Vector3(side * (WALL_HALF_W + 0.5), mid, -WALL_DEPTH * 0.5), concrete, true)
	_mesh_box(s, Vector3(WALL_HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -WALL_DEPTH - 0.5), concrete, true)
	var local := Vector3(0.0, 0.0, -PEDESTAL_BACK)
	s.pedestal = s.to_global(local)
	s.pedestal.y = ctx.terrain.height(s.pedestal.x, s.pedestal.z)
	_mesh_cylinder(s, 0.8, 0.6, s.to_local(s.pedestal) + Vector3.UP * 0.3, Palette.solid(Palette.CHARCOAL))


func _mesh_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, solid := false) -> Node3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	if not solid:
		mesh.position = at
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.add_child(mesh)
	body.position = at
	parent.add_child(body)
	return body


func _mesh_cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mesh.mesh = cm
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)


func _physics_process(_delta: float) -> void:
	if ctx == null or not ctx.flow.in_stage():
		return
	if _pending_stage and ctx.spawner != null and not ctx.calm:
		_pending_stage = false
		for s in sites:
			if s.id == "hauler_bounty":
				_spawn_bounty(s)
	var ball: Vector3 = ctx.player.ball_position()
	for s in sites:
		if not is_instance_valid(s):
			continue
		s.view.near(ball)
		if not s.done:
			match String(s.rule["finishes"]):
				"pack_dead":
					_watch_ambush(s, ball)
				"wall_broken":
					_watch_wall(s, ball)
		_watch_pickup(s, ball)


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---- The ambush ----

func _watch_ambush(s: Site, ball: Vector3) -> void:
	if not s.started:
		if ctx.calm or ctx.spawner == null or not ctx.spawner.has_method("spawn_enemy"):
			return
		if _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		_spawn_pack(s)
		return
	if _alive(s.pack) == 0:
		_finish(s, s.global_position)


func _spawn_pack(s: Site) -> void:
	var kinds: Array = s.rule["pack"]
	s.pack.clear()
	# The ring's first spot lies 30 degrees past the point opposite the ball's entry, so none of the
	# three stands within 4 m of the ball's straight line through the ring.
	var entry: Vector3 = ctx.player.ball_position() - s.global_position
	var first := atan2(entry.z, entry.x) + PI + PACK_TURN
	for i in kinds.size():
		var a := first + TAU * float(i) / kinds.size()
		var spot := s.global_position + Vector3(cos(a), 0.0, sin(a)) * float(s.rule["ring"])
		var enemy = ctx.spawner.spawn_enemy(kinds[i], ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			s.pack.append(enemy)
	s.started = not s.pack.is_empty()


static func _alive(pack: Array) -> int:
	var n := 0
	for enemy in pack:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			n += 1
	return n


# ---- The cache ----

func _watch_wall(s: Site, ball: Vector3) -> void:
	var v: Vector3 = ctx.player.state.velocity
	var toward := -(v.x * s.global_basis.z.x + v.z * s.global_basis.z.z)
	var local := s.to_local(ball)
	var ahead := local.z - 0.5
	if ahead < -1.0 or ahead > WALL_REACH + maxf(0.0, toward) / 30.0 or absf(local.x) > WALL_HALF_W + 1.0 or local.y > WALL_HEIGHT + 2.0:
		return
	if toward >= ctx.tuning.f("cruise"):
		_break_wall(s)


func _slammed(at: Vector3, strength: float) -> void:
	if strength < ctx.player.slam_strength(ctx.tuning.f("cruise")) * SLAM_MIN_PER_CRUISE:
		return
	for s in sites:
		if s.wall == null or s.done:
			continue
		var local: Vector3 = s.to_local(at)
		if local.z > 0.5 and local.z < 0.5 + SLAM_REACH and absf(local.x) <= WALL_HALF_W + 1.0:
			_break_wall(s)


func _break_wall(s: Site) -> void:
	if s.done:
		return
	s.wall.position += Vector3.DOWN * 400.0
	s.wall.visible = false
	ctx.events.world_fact.emit("wall_crumbled", s.global_position)
	_finish(s, s.pedestal)


# ---- The bounty ----

func _spawn_bounty(s: Site) -> void:
	var at: Vector3 = ctx.terrain.drop_point(s.global_position.x, s.global_position.z, BRUTE_DROP)
	var brute = ctx.spawner.spawn_enemy(String(s.rule["kind"]), at)
	if brute == null or not brute.has_method("carry_bounty"):
		return
	brute.carry_bounty(s.global_position, EventKinds.activity_color(s.id))
	brute.bounty_wake = float(s.rule["wake"])
	brute.bounty_leash = float(s.rule["leash"])
	brute.bounty_return_speed = float(s.rule["return_speed"])
	brute.died.connect(func(where: Vector3, _scrap: int): _bounty_died(s, where))
	s.brute = brute
	s.started = true


func _bounty_died(s: Site, where: Vector3) -> void:
	if not is_instance_valid(s) or s.done:
		return
	_finish(s, Vector3(where.x, ctx.terrain.height(where.x, where.z), where.z))


# ---- The pay ----

func _finish(s: Site, at: Vector3) -> void:
	s.done = true
	s.view.finish()
	if s.cap != null:
		s.cap.visible = false
	var pay: Dictionary = s.rule["pay"]
	s.pickup_part = _roll(s.id, pay["rarities"])
	if s.pickup_part != "":
		s.pickup = ActivityView.gem(s.id)
		s.add_child(s.pickup)
		s.pickup.global_position = at
		s.inside_pickup = _planar(ctx.player.ball_position(), at) <= PICKUP_REACH
	else:
		_pay_scrap(s, at)
	ctx.events.activity_done.emit(s.id, at)


# The rule's scrap, through the run's own add_scrap so it grows the ball and publishes a class up.
func _pay_scrap(s: Site, at: Vector3) -> void:
	var amount := int(s.rule["pay"].get("scrap", 0))
	if amount > 0:
		ctx.run.add_scrap(amount, at)


func _roll(id: String, rarities: Array) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, id)
	var picks: Array = Parts.roll(rng, rarities, ctx.run.class_id(), ctx.run.parts, 1)
	return String(picks[0]) if not picks.is_empty() else ""


# A pickup takes the ball that rolls onto it, not one already standing there when it appeared.
func _watch_pickup(s: Site, ball: Vector3) -> void:
	if s.pickup == null or s.pickup_taken:
		return
	var at: Vector3 = s.pickup.global_position
	var now := _planar(ball, at) <= PICKUP_REACH and absf(ball.y - at.y) < PICKUP_HEIGHT
	if now and not s.inside_pickup:
		s.pickup_taken = true
		s.pickup.queue_free()
		s.pickup = null
		ctx.run.add_part(s.pickup_part, String(s.rule["pay"]["source"]))
		_pay_scrap(s, at)
		return
	s.inside_pickup = now
