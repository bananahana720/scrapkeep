extends Node3D

# Each row draws and damages with one committed Hazard, then lands its shared ground swap.

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Natural := preload("res://src/world/events/natural.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")

# Cones use [length, width]. The ring uses an [x, z] footprint with a safe eye.
const FALLOUT_EYE_FRACTION := 0.4
const SHAPES := {
	"steam_cone": {"form": "cone"}, "arc_steam_cone": {"form": "cone"},
	"burner_flare": {"form": "cone"},
	"fallout_ring": {"form": "ring", "inner_fraction": FALLOUT_EYE_FRACTION},
}
# Reach above the ground, the same for every shape this family commits.
const REACH_M := 3.0
# What a steam cone or a fallout ring takes from each enemy it catches (the silt boil's enemy damage).
const ENEMY_DAMAGE := 25.0

var world
# row id -> {hazard, site, at, hit, swap}
var active := {}
var _sites := {}
var _overlay_map: EventGround.OverlayMap
# The stage's swap overlays, projected on a worker from setup (EventGround.plan_overlays).
var _plan := {}
var _hits_enemies := false


func setup(world_ref) -> void:
	world = world_ref
	name = "IndustrialEvents"
	_hits_enemies = HazardHits.applies_to(world.ctx.run)
	for site in world.terrain.map().park.park_rows:
		_sites[site.id] = site
	var items := []
	for row in world.terrain.map().park.event_rows:
		var swap := String(row.get("effect", {}).get("swap", ""))
		if row.family == "industrial" and swap != "" and _sites.has(row.site):
			items.append({"id": str(row.id), "kind": row.kind, "geometry": _geometry(NaturalFootprint.resolve(row, _sites[row.site]))})
	_plan = EventGround.plan_overlays(world, items)


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	# The sluice commits no hazard: its water is the surge course's front (activities.gd), which never hurts.
	if row.kind == "sluice_surge":
		return
	match action:
		"telegraph":
			_telegraph(row)
		"land":
			_land(row, ctx)
		"step":
			_step(row, ctx)
		"end":
			_end(row)


func _telegraph(row: Dictionary) -> void:
	var spec: Dictionary = SHAPES.get(String(row.effect.get("hazard", "")), {})
	if spec.is_empty():
		push_error("industrial row %s names an unknown hazard %s" % [row.id, str(row.effect.get("hazard", ""))])
		return
	var site := NaturalFootprint.resolve(row, _sites[row.site])
	var at := _at(site)
	var size: Array = row.effect.hazard_m
	var hazard := Hazard.new()
	var terrain = world.terrain
	hazard.ground = func(point: Vector3) -> float: return terrain.height(point.x, point.z)
	var lead := float(row.telegraph.lead_s)
	var live := float(row.live_s)
	if spec.form == "cone":
		# The cone points along the site's local +x, which is world angle -yaw in the x-z plane.
		var axis := -deg_to_rad(float(site.yaw_deg))
		var spread := atan2(float(size[1]) * 0.5, float(size[0]))
		hazard.commit_sector(row.id, Threat.Type.INSTANT, at, Vector2(0.0, float(size[0])),
			axis - spread, axis + spread, REACH_M, lead, live)
	else:
		var outer := minf(float(size[0]), float(size[1])) * 0.5
		hazard.commit_annulus(row.id, Threat.Type.INSTANT, at, Vector2(outer * float(spec.inner_fraction), outer), REACH_M, lead, live)
	add_child(hazard)
	active[row.id] = {"hazard": hazard, "site": site, "at": at, "hit": false, "struck": {}, "swap": "", "overlay_record": {}}


func _land(row: Dictionary, ctx: Dictionary) -> void:
	var state: Dictionary = active.get(row.id, {})
	if state.is_empty():
		return
	var hazard: Hazard = state.hazard
	# The warning ends at land: the hazard is live from this moment for live_s.
	hazard.warn_seconds = hazard.age
	var swap := String(row.effect.get("swap", ""))
	if swap != "":
		_swap(row, state, swap)
	hazard.painter().paint(Threat.marks(hazard.descriptor(), false), Threat.STATIC_LAYERS)
	hazard.step(0.0)
	_strike(row, state, ctx)


func _step(row: Dictionary, ctx: Dictionary) -> void:
	var state: Dictionary = active.get(row.id, {})
	if state.is_empty():
		return
	state.hazard.step(float(ctx.get("delta_s", 0.0)))
	_strike(row, state, ctx)


func _end(row: Dictionary) -> void:
	if not active.has(row.id):
		return
	var state: Dictionary = active[row.id]
	if state.swap != "":
		EventGround.set_overlay(world, row, state.overlay_record, false)
	state.hazard.finish()
	state.hazard.free()
	active.erase(row.id)


func _swap(row: Dictionary, state: Dictionary, id: String) -> void:
	var site: Dictionary = state.site
	var record := {"site": site, "at": state.at, "overlay": null, "geometry": _geometry(site, state.at)}
	_overlay_map = EventGround.prepare_overlay(world, self, row, record, Callable(), EventGround.planned_overlay(world, _plan, str(row.id)))
	EventGround.set_overlay(world, row, record, true)
	state.overlay_record = record
	state.swap = id


func _geometry(site: Dictionary, at := Vector3.INF) -> Dictionary:
	return {"site": site, "at": _at(site) if at == Vector3.INF else at, "half": ParkMap.footprint_half_extents(site),
		"yaw": deg_to_rad(float(site.yaw_deg)), "strike_m": 0.0}


# The shared damage path (natural.gd's strike): lose_scrap for the row's damage, once per
# activation, and a vertical lift when no scrap is left to take. In the Spillway every enemy the live
# hazard contains is struck too, once per activation, thrown out from its centre (HazardHits).
func _strike(row: Dictionary, state: Dictionary, ctx: Dictionary) -> void:
	var hazard: Hazard = state.hazard
	if not hazard.is_live():
		return
	if _hits_enemies:
		HazardHits.strike(get_tree(), hazard.contains, row.kind, ENEMY_DAMAGE, Natural.ENEMY_TOSS, state.struck,
			func(point: Vector3) -> Vector3: return point - hazard.centre)
	if state.hit:
		return
	var ball: Vector3 = ctx.ball
	if not hazard.contains(ball):
		return
	state.hit = true
	var amount := maxi(0, ceili(float(row.effect.get("damage", 0.0))))
	var taken: int = world.ctx.run.lose_scrap(amount, ball, row.kind)
	if taken < amount or amount == 0:
		var velocity: Vector3 = world.ctx.player.state.velocity
		velocity.y = maxf(velocity.y, float(Natural.KINDS.impact.lift_mps))
		world.ctx.player.set_velocity_now(velocity, "industrial_event")


func _at(site: Dictionary) -> Vector3:
	var x := float(site.at[0])
	var z := float(site.at[1])
	return Vector3(x, float(site.y) if site.y != null else world.terrain.height(x, z), z)


func release() -> void:
	EventGround.settle_overlays(_plan)
	_plan = {}
	for id in active.keys():
		_end({"id": id})
	EventGround.restore_map(world, _overlay_map)
	_overlay_map = null
	active.clear()
	_sites.clear()
	world = null


func _exit_tree() -> void:
	EventGround.settle_overlays(_plan)
