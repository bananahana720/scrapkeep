extends Node3D

# Industrial family (KE5): boiler_burst and reactor_blow rows. Each row commits one Hazard
# (src/boss/hazard.gd) at telegraph, makes it live at land, and ends it at end. The drawn
# warning and the damaging area are that same node, so one commit call serves both.
# Damage goes through the shared scrap path natural.gd uses for its own strikes; the swap
# overlay goes through natural.gd's overlay path (_prepare_overlay / _set_overlay).

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Natural := preload("res://src/world/events/natural.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

# Each authored hazard names its shape. A cone (length, far-end width) and an arc cone are
# sectors from the site; a fallout ring is an annulus ([outer, inner] radius).
const SHAPES := {"steam_cone": "cone", "arc_steam_cone": "cone", "burner_flare": "cone", "fallout_ring": "ring"}
# Reach above the ground, the same for every shape this family commits.
const REACH_M := 3.0

var world
# Seeded-control seam: the damage path reads the committed zone with probes scaled about its
# centre by this factor. 1.0 is the real path; the drawn zone is never touched.
var damage_length_scale := 1.0
# Commit calls per row id: the one-commit check reads this.
var commits := {}
# row id -> {hazard, site, at, hit, swap}
var active := {}
var _sites := {}


func setup(world_ref) -> void:
	world = world_ref
	name = "IndustrialEvents"
	for site in world.terrain.map().park.park_rows:
		_sites[site.id] = site


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
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
	var shape: String = SHAPES.get(String(row.effect.get("hazard", "")), "")
	if shape == "":
		push_error("industrial row %s names an unknown hazard %s" % [row.id, str(row.effect.get("hazard", ""))])
		return
	var site := NaturalFootprint.resolve(row, _sites[row.site])
	var at := _at(site)
	var size: Array = row.effect.hazard_m
	var hazard := Hazard.new()
	hazard.ground = func(_point: Vector3) -> float: return at.y
	var lead := float(row.telegraph.lead_s)
	var live := float(row.live_s)
	if shape == "cone":
		# The cone points along the site's local +x, which is world angle -yaw in the x-z plane.
		var axis := -deg_to_rad(float(site.yaw_deg))
		var spread := atan2(float(size[1]) * 0.5, float(size[0]))
		hazard.commit_sector(row.id, Threat.Type.INSTANT, at, Vector2(0.0, float(size[0])),
			axis - spread, axis + spread, REACH_M, lead, live)
	else:
		hazard.commit_annulus(row.id, Threat.Type.INSTANT, at, Vector2(float(size[1]), float(size[0])), REACH_M, lead, live)
	commits[row.id] = commits.get(row.id, 0) + 1
	add_child(hazard)
	active[row.id] = {"hazard": hazard, "site": site, "at": at, "hit": false, "swap": ""}


func _land(row: Dictionary, ctx: Dictionary) -> void:
	var state: Dictionary = active.get(row.id, {})
	if state.is_empty():
		return
	var hazard: Hazard = state.hazard
	# The warning ends at land: the hazard is live from this moment for live_s.
	hazard.warn_seconds = hazard.age
	hazard.step(0.0)
	var swap := String(row.effect.get("swap", ""))
	if swap != "":
		_swap(row, state, swap)
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
		# natural releases before industrial in families.gd and clears its overlay record, so
		# a missing record means there is no overlay left to take down.
		var natural = _natural()
		if natural != null and natural._prepared.has(row.id):
			natural._set_overlay(row, false)
			natural._prepared.erase(row.id)
	state.hazard.finish()
	state.hazard.free()
	active.erase(row.id)


# The overlay is the one natural.gd builds for its own swaps: a record in natural's
# _prepared table, then its prepare and set calls.
func _swap(row: Dictionary, state: Dictionary, id: String) -> void:
	var natural = _natural()
	if natural == null:
		push_error("industrial row %s needs the natural family's overlay path" % row.id)
		return
	var site: Dictionary = state.site
	var record := {"site": site, "at": state.at, "overlay": null,
		"geometry": {"site": site, "at": state.at, "half": ParkMap.footprint_half_extents(site),
			"yaw": deg_to_rad(float(site.yaw_deg)), "strike_m": 0.0}}
	natural._prepared[row.id] = record
	natural._prepare_overlay(row, record)
	natural._set_overlay(row, true)
	state.swap = id


# The shared damage path (natural.gd's strike): lose_scrap for the row's damage, once per
# activation, and a vertical lift when no scrap is left to take.
func _strike(row: Dictionary, state: Dictionary, ctx: Dictionary) -> void:
	var hazard: Hazard = state.hazard
	if not hazard.is_live() or state.hit:
		return
	var ball: Vector3 = ctx.ball
	if not _hits(hazard, ball):
		return
	state.hit = true
	var amount := maxi(0, ceili(float(row.effect.get("damage", 0.0))))
	var taken: int = world.ctx.run.lose_scrap(amount, ball, row.kind)
	if taken < amount or amount == 0:
		var velocity: Vector3 = world.ctx.player.state.velocity
		velocity.y = maxf(velocity.y, float(Natural.KINDS.impact.lift_mps))
		world.ctx.player.set_velocity_now(velocity, "industrial_event")


func _hits(hazard: Hazard, point: Vector3) -> bool:
	var centre: Vector3 = hazard.centre
	return hazard.contains(centre + (point - centre) / damage_length_scale)


func _natural():
	var families = world.get("event_families")
	return families.get("natural") if families is Dictionary else null


func _at(site: Dictionary) -> Vector3:
	var x := float(site.at[0])
	var z := float(site.at[1])
	return Vector3(x, float(site.y) if site.y != null else world.terrain.height(x, z), z)


func release() -> void:
	for id in active.keys():
		_end({"id": id})
	active.clear()
	_sites.clear()
	world = null
