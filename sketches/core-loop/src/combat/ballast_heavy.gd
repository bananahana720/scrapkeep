extends "res://src/combat/counter.gd"

const IslandEdge := preload("res://src/combat/island_edge.gd")
const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")

# The ballast heavy (roster_highdraft.gd, design-v3/WORLD-ROSTERS.md): a slab crew that posts up
# on an island rim. Damage barely touches it (DAMAGE_TAKEN of every hit, on a deep pool), but a
# knock that carries it RING_DROP below the rim it stood on finishes it: a ring-out (Andrew,
# "Ring-outs", 2026-10-17 20:03:50Z). The throw is PR #43's ram knock divided by its weight.
#
# - Planted it weighs PLANT_WEIGHT: a small ball rebounds off it (contact.gd), a grown one
#   (heft 2.2 and up, class 3) rams it a few metres, enough from the rim.
# - Before it slams it braces for warn_seconds, an interruptible cast. Braced, and through the
#   stagger a hard knock leaves it in, it weighs BRACE_WEIGHT, so any ram at cruise lands in
#   full and throws it about 10 m (blazing, about 20 m).
# - The slam is a ring round it that shoves the ball outward, toward the edge it guards.
# - It never walks off a rim on its own, and walks to the nearest rim within SEEK to post up.
#   With no rim in reach (the net deck, a flat stage) it is beached: it drops its ballast and
#   takes damage in full on BEACHED_HP, so no stage ever holds one nobody can finish.
# - Grown remix: on posting up it stakes a cable STAKE_BACK behind it, toward the island. The
#   cable reels it back to its post from one ring-out and snaps doing it; a ball that rolls
#   over the stake (the island side) cuts it first.

const HP := 900.0
const WALK := 3.0
const DAMAGE_TAKEN := 0.1
const BEACHED_HP := 140.0
const PLANT_WEIGHT := 2.4
const BRACE_WEIGHT := 0.9
const RING_DROP := 3.0
const RIM_DROP := 4.0
const SEEK := 90.0
const POST_IN := 1.5
const POST_NEAR := 1.0
const EDGE_GUARD := 1.5
const RESCAN := 1.0
const SLAM_RADIUS := 5.0
const SLAM_REACH := 2.5
const SLAM_DAMAGE := 12.0
const SLAM_SHOVE := 16.0
const SLAM_LIFT := 5.0
const STAKE_BACK := 4.0
const STAKE_REACH := 1.8
const SLAB_SIZE := Vector3(2.2, 0.5, 1.2)
const BRAKE_DROP := 0.3

var ring_outs := 0
var reeled := 0
var slams := 0
var beached := false
var posted := false
# The rim this heavy guards: {at, dir, dist} from IslandEdge, or {} while none is known.
var rim := {}
# The ground height and point of the last settled footing; a fall RING_DROP below it rings out.
var perch_y := INF
var perch_at := Vector3.ZERO
var stake: Node3D
var staked := false

var _scan := 0.0
var _slab: MeshInstance3D
var _brakes: MeshInstance3D
var _brakes_y := 0.0
static var _warned_asset := false
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 8
	weight = PLANT_WEIGHT
	walk_speed = WALK
	warn_seconds = 1.1
	live_seconds = 0.2
	rest_seconds = 3.2
	first_rest = 2.0
	attack_range = SLAM_RADIUS + 2.5
	interruptible = true
	impact_resist = 0.6


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.name == "BallastBrakes":
				_brakes = mi
				_brakes_y = mi.position.y
		return
	_slab = _box(SLAB_SIZE, Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.6, 0.0), 0.0, _visual_parent())
	for side in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.7, 0.5), Palette.RUST.darkened(0.3), Vector3(side * 0.75, 0.35 - CREW_HALF + 0.35, 0.0), 0.0, _visual_parent())


func _physics_process(delta: float) -> void:
	weight = BRACE_WEIGHT if phase == Phase.WARN or stunned() else PLANT_WEIGHT
	super(delta)
	if _dead or not _in_play() or target == null:
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = RESCAN
		_read_rim()
	_watch_stake()
	_watch_footing()


func _watch_footing() -> void:
	if is_on_floor() and _knocked_speed() < 1.0:
		perch_y = global_position.y
		perch_at = global_position
	elif perch_y != INF and global_position.y < perch_y - RING_DROP:
		_ring_out()


func _ring_out() -> void:
	if is_instance_valid(stake):
		_snap_stake()
		reeled += 1
		global_position = perch_at + Vector3.UP * 0.2
		velocity = Vector3.ZERO
		_knock = Vector3.ZERO
		return
	ring_outs += 1
	last_damage_source = "ring_out"
	if fleet != null:
		fleet.discover("ring_out", global_position)
	_die()


func _read_rim() -> void:
	if not rim.is_empty():
		return
	rim = IslandEdge.nearest_rim(terrain, global_position, SEEK, RIM_DROP)
	if rim.is_empty() and not beached:
		_beach()


# No rim to ring it out over: the ballast comes off and it is an ordinary heavy.
func _beach() -> void:
	beached = true
	hp = minf(hp, BEACHED_HP * float(spec.get("stage_threat", 1.0)))
	max_hp = hp
	keep_near = 0.0
	keep_far = SLAM_RADIUS * 0.6
	if _slab != null:
		_slab.visible = false


func take_damage(amount: float) -> float:
	return super(amount if beached else amount * DAMAGE_TAKEN)


func _post() -> Vector3:
	var at: Vector3 = rim["at"]
	return at - (rim["dir"] as Vector3) * POST_IN


func _roam(to_ball: Vector3) -> Vector3:
	_facing(to_ball)
	if beached:
		return super(to_ball)
	if rim.is_empty():
		return Vector3.ZERO
	var to := _post() - global_position
	to.y = 0.0
	if posted and to.length() > POST_NEAR * 3.0:
		posted = false
	if posted:
		return Vector3.ZERO
	if to.length() <= POST_NEAR:
		posted = true
		_plant_stake()
		return Vector3.ZERO
	return to.normalized() * walk_speed


# Its own feet never carry it off a rim: a step that would fall is dropped. Knockback is not
# its feet, so a knock still carries it over.
func _move(delta: float, desired: Vector3) -> void:
	if desired.length_squared() > 0.0 and IslandEdge.falls_ahead(terrain, global_position, desired, EDGE_GUARD, RING_DROP * 0.5):
		desired = Vector3.ZERO
	super(delta, desired)


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range and is_on_floor()


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_ring(Threat.Type.INSTANT, global_position, SLAM_RADIUS, SLAM_REACH)


func _go_live() -> void:
	slams += 1
	var ring := telegraph()
	var ball := _real_ball()
	if ring == null or not ring.contains(ball):
		return
	var away := ball - global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -global_transform.basis.z
	hit_player.emit(SLAM_DAMAGE, away * SLAM_SHOVE + Vector3.UP * SLAM_LIFT)


func _live(_delta: float) -> bool:
	return _t < live_seconds


func _pose() -> void:
	var lift := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
	# The body's brake claws bite the deck through the brace (the recipe's 0.3 m drop).
	if _brakes != null:
		_brakes.position.y = _brakes_y - BRAKE_DROP * lift
	if _slab == null or beached:
		return
	_slab.position.y = CREW_HALF + 0.6 + 1.0 * lift
	_slab.rotation.x = -0.3 * lift


# --- Grown remix: the stake cable ------------------------------------------------------------

func _plant_stake() -> void:
	if staked or rim.is_empty() or not RosterHighdraft.grown(self):
		return
	staked = true
	var back := global_position - (rim["dir"] as Vector3) * STAKE_BACK
	stake = Node3D.new()
	stake.name = "BallastStake"
	world_root.add_child(stake)
	stake.global_position = Vector3(back.x, terrain.height(back.x, back.z) if terrain != null else back.y, back.z)
	_cylinder(0.12, 1.4, Palette.BRASS, Vector3(0.0, 0.7, 0.0), 0.6, stake)


func _watch_stake() -> void:
	if not is_instance_valid(stake):
		return
	var ball := _real_ball()
	if Vector2(ball.x - stake.global_position.x, ball.z - stake.global_position.z).length() <= STAKE_REACH \
			and absf(ball.y - stake.global_position.y) < 2.5:
		_snap_stake()


func _snap_stake() -> void:
	if is_instance_valid(stake):
		stake.queue_free()
	stake = null


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_three/enemy_ballast_heavy.glb"
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var flash := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("ballast_heavy: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		_shared.append({"name": mi.name, "mesh": mesh, "xform": mi.transform, "flash": flash})
	scene.free()
	return _shared


func _exit_tree() -> void:
	_snap_stake()
	super._exit_tree()
