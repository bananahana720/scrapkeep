extends Node3D

const Interact := preload("res://src/world/interact.gd")
const PropKicks := preload("res://src/presentation/prop_kicks.gd")
const Kit := preload("res://src/presentation/destructible_kit.gd")
const Consumables := preload("res://src/build/consumables.gd")

# Heft destructibles (Wave 45, W45-C unit A; design-v3/HEFT-DESTRUCTIBLES.md). A standalone, authored,
# non-load-bearing prop of tier 1 to 5 that a ball of that heft class or heavier breaks without losing a
# metre per second, and a lighter ball meets as a plain wall. The module owns the registry, the tier rule,
# the collider switch, the debris pool and the stage's loot meter; callers make three calls and listen to
# one signal:
#
#   build(map_or_rows, ctx)           once a stage: register rows, build colliders now, visuals in slices
#   on_ball(pos, velocity, heft, dt)  once a physics tick from the world tick
#   on_blast(at, radius, source, ...) from each blast source with the ring it already resolved
#   piece_shattered(bounds)           every break, the world box of the piece, for world-line release
#
# Two states and nothing between: intact (a layer-1 StaticBody3D and one opaque mesh) or shattered (the
# collider disabled, the mesh hidden, a few scripted shards that shrink to SPECK). The break is decided the
# tick before the solver meets the piece, so the ball keeps its speed. Heft is read, never written.
#
# ctx is the game's Context, or a Dictionary carrying any of these keys (a key wins over the Context
# field): root (the node to join when not yet in the tree), cruise, run_seed, run_id, stage, scrap (drop,
# drop_cogs), combat (strike), refused (Callable(at) for the roll's refused cue), enemies (Callable ->
# Array), owned_ids (ids a contraption owns), no_visuals (--bot-no-visuals=1). Without a key the Context's
# own refs answer: tuning.f("cruise"), rng.seed, run.run_id, run.stage, build.scrap, spawner, events.
# A break sends one world_fact("piece_shattered") at its point on events, plays its family's sound at that point
# (ctx "sfx", Callable(id, at)) and lands its tier's weight (ctx "weight", Callable(tier, at), else the game's
# presentation.juice.on_piece_shattered); the sound and the weight are never built under --bot-no-visuals=1.

signal piece_shattered(bounds: AABB)

const CELL_M := 12.0
const BUILD_SLICE_USEC := 3000
const WORLD_LAYER := 1
const BALL_RADIUS := 1.0
# cracked_cache.gd WALL_REACH; the reach grows by flat / 30 so it stays a tick ahead of the solver at any speed.
const WALL_REACH := 3.0
# contraptions.gd WALL_SPEED: the sprint bar a tier 1 piece asks.
const WALL_SPEED := 8.0
# activities.gd RAM_MIN_PER_CRUISE: the bar tiers 2 to 5 ask, the same the cracked face uses.
const RAM_MIN_PER_CRUISE := 0.85
# activities.gd "refused" rule: the floor under which a bump stays silent and the gap between cues.
const REFUSED_FLOOR := 0.4
const REFUSED_GAP_S := 3.0
# A ball this close (centre to the piece's surface) is touching it for the refused cue.
const CONTACT_M := BALL_RADIUS + 0.5
# The ball must be heading within 60 degrees of the nearest point of a piece for it to count as meeting it.
const HEADING_COS := 0.5
const JUMP_RESET_M := 20.0

const TIER_MIN := 1
const TIER_MAX := 5
const SHARDS_LIGHT := 4
const SHARDS_HEAVY := 6
const CHIPS_MIN := 2
const CHIPS_MAX := 3
const SHARD_POOL := PropKicks.LIVE_CAP
const PUFF_POOL := 8
const NODE_CEILING := 32
# enemy_motion.gd SPECK: pieces shrink to it and never fade alpha.
const SPECK := 0.01
const SHARD_LIFE := Vector2(0.7, 1.2)
const SHARD_CARRY := 0.5
const SHARD_LIFT := 3.0
const PUFF_LIFE := 0.6

const SHRAPNEL_M := 2.5
const SHRAPNEL_MAX := 3
const SHRAPNEL_COS := 0.7071
const BASE_FORCE := 12.0
const TIER_SCALE := [0.5, 0.7, 1.0, 1.3, 1.6]

const SCRAP_CAP := 35
const COG_CAP := 20
const CONSUMABLE_CAP := 3
# Tier -> [scrap, cogs]; tier 1 scrap is a 50 percent roll on the piece's own stream.
const LOOT := {1: [1, 0], 2: [2, 1], 3: [3, 2], 4: [4, 2], 5: [4, 2]}
const TIER1_CHANCE := 0.5

const FORBIDDEN_ELEMENTS := ["kicker", "drop", "half_pipe", "rail", "grind_line", "elevated_line", "flow_line",
	"ledge", "bowl", "tunnel", "anchor_field", "ground", "bank", "terrace"]
const TERRAIN_KINDS := ["terrain", "heightfield", "landform", "ground", "bank", "terrace"]
const FOOTING_PREFIXES := ["flume_bent_", "flume_ride_pier_"]
const FOOTING_KINDS := ["world_anchor", "hoodoo", "saguaro"]
const SOFT_TAGS := ["plant", "soft", "foliage"]
# park_schema.gd GUARDED_SOCIETIES.
const GUARDED_SOCIETIES := ["hohokam", "ancestral_puebloan"]

const FAMILY_BY_TIER := Kit.FAMILY_BY_TIER
const SHARD_SIZE := 0.35
# Crate and barricade meshes under BIG_EXTENT_M fade past VIEW_END_M so far landmark views skip distant scatter;
# giant breakable walls (e.g. a 64 m pond wall) stay unranged.
const VIEW_END_M := 320.0
const VIEW_MARGIN_M := 30.0
const BIG_EXTENT_M := 20.0

# The loot meter's ceilings for this stage; ctx keys scrap_cap and cog_cap plant others for a test.
var scrap_cap := SCRAP_CAP
var cog_cap := COG_CAP
var consumable_cap := CONSUMABLE_CAP

var _pieces := {}
var _order: Array[String] = []
var _grid := {}
var _refused: Array[Dictionary] = []
var _breaks: Array[String] = []
var _scrap_paid := 0
var _cogs_paid := 0
var _consumables_paid := 0
var _shrapnel_hits := 0
var _clock := 0.0
var _prev := Vector3.ZERO
var _have_prev := false
var _last_heft := 1
var _cruise := 14.0
var _cruise_override := false
var _ctx: Object = null
var _tuning: Object = null
var _build: Object = null
var _seed := 0
var _run_id := ""
var _stage := 0
var _scrap: Object = null
var _combat: Object = null
var _cue: Callable = Callable()
var _sfx: Callable = Callable()
var _weight: Callable = Callable()
var _events: Object = null
var _enemies: Callable = Callable()
var _no_visuals := false
var _exiting := false

var _queue: Array[Callable] = []
var _material: StandardMaterial3D = null
var _shard_meshes := {}
var _piece_meshes := {}
var _puff_mesh: Mesh = null
var _shards: Array = []
var _puffs: Array = []
var _live_serial := 0
var _fx := RandomNumberGenerator.new()


class Piece extends RefCounted:
	var id := ""
	var tier := 1
	var centre := Vector3.ZERO
	var half := Vector3.ONE * 0.5
	var basis := Basis.IDENTITY
	var bounds := AABB()
	var family := ""
	var order := 0
	var intact := true
	var refused_at := -1000.0
	var body: StaticBody3D = null
	var shape: CollisionShape3D = null
	var mesh: MeshInstance3D = null


class Shard extends RefCounted:
	var node: MeshInstance3D = null
	var live := false
	var serial := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var ground := 0.0
	var t := 0.0
	var life := 1.0
	var base := 1.0
	var puff := false


# ---- the registry -------------------------------------------------------------------------------

# The reason a row may not be a destructible, or "" when it may. `taken` holds the ids already spoken for
# (a registered piece, a contraption's id). One home for the exclusions of the spec's section 2.2.
static func validate_row(row: Dictionary, taken: Dictionary = {}) -> String:
	var id := String(row.get("id", ""))
	if id == "":
		return "no id"
	if taken.has(id):
		return "id already taken"
	var tier := int(row.get("tier", 0))
	if tier < TIER_MIN or tier > TIER_MAX:
		return "tier out of range"
	if _vec(row.get("at")) == Vector3.INF:
		return "no position"
	var size := _vec(row.get("size"))
	if size == Vector3.INF or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return "no size"
	var element := String(row.get("element", ""))
	if element != "" and element in FORBIDDEN_ELEMENTS:
		return "ridden or terrain element " + element
	if bool(row.get("terrain", false)) or bool(row.get("heightfield", false)) or String(row.get("landform", "")) != "" \
			or String(row.get("kind", "")) in TERRAIN_KINDS or String(row.get("source", "")) == "park_terrain":
		return "terrain"
	for key in ["parent_element", "under", "ridden_by"]:
		if String(row.get(key, "")) in FORBIDDEN_ELEMENTS:
			return "stands under a ridden element"
	if bool(row.get("world_anchor", false)) or "world_anchor" in (row.get("groups", []) as Array) \
			or String(row.get("kind", "")) in FOOTING_KINDS:
		return "grapple footing"
	for prefix in FOOTING_PREFIXES:
		if id.begins_with(prefix):
			return "grapple footing"
	var asset: Variant = row.get("asset", {})
	var tags: Array = (row.get("tags", []) as Array).duplicate()
	if asset is Dictionary:
		if (asset as Dictionary).has("perch"):
			return "perch asset"
		tags.append_array((asset as Dictionary).get("tags", []) as Array)
	if row.has("perch"):
		return "perch asset"
	if "tall" in tags:
		return "tall asset"
	for tag in tags:
		if String(tag) in SOFT_TAGS:
			return "soft foliage"
	if String(row.get("source", "")) == "park_props" or bool(row.get("foliage", false)):
		return "park prop"
	if String(row.get("society", "")) in GUARDED_SOCIETIES:
		return "guarded society"
	return ""


# Registers the stage's rows (an Array of rows, or a map Dictionary whose "destructible_rows" holds them),
# builds every collider now so a ball never meets a gap, and queues the meshes, the shard pool and the
# materials as slices of BUILD_SLICE_USEC (finish_build() runs the rest at once).
func build(map_or_rows: Variant, ctx: Variant) -> void:
	teardown()
	_exiting = false
	_bind(ctx)
	var rows: Array = []
	if map_or_rows is Array:
		rows = map_or_rows
	elif map_or_rows is Dictionary:
		rows = (map_or_rows as Dictionary).get("destructible_rows", (map_or_rows as Dictionary).get("rows", [])) as Array
	var taken := {}
	for id in _ctx_get(ctx, "owned_ids", []) as Array:
		taken[String(id)] = true
	var root: Variant = _ctx_get(ctx, "root", null)
	if not is_inside_tree() and root is Node and is_instance_valid(root):
		(root as Node).add_child(self)
	for row in rows:
		var why := validate_row(row, taken) if row is Dictionary else "not a row"
		if why != "":
			_refused.append({"id": String(row.get("id", "")) if row is Dictionary else "", "reason": why})
			continue
		var piece := _register(row)
		taken[piece.id] = true
	if not _no_visuals:
		_queue_visuals()
	set_process(true)


func finish_build() -> void:
	while not _queue.is_empty():
		(_queue.pop_front() as Callable).call()


func is_built() -> bool:
	return _queue.is_empty()


# Frees every collider, mesh and pooled node and forgets the stage: nothing outlives it.
func teardown() -> void:
	for piece in _pieces.values():
		var p := piece as Piece
		for node in [p.body, p.mesh]:
			if node != null and is_instance_valid(node):
				if not _exiting and node.get_parent() == self:
					remove_child(node)
				node.queue_free()
	for list in [_shards, _puffs]:
		for entry in list:
			var node: Node = (entry as Shard).node
			if node != null and is_instance_valid(node):
				if not _exiting and node.get_parent() == self:
					remove_child(node)
				node.queue_free()
	_pieces.clear()
	_order.clear()
	_grid.clear()
	_refused.clear()
	_breaks.clear()
	_shards.clear()
	_puffs.clear()
	_queue.clear()
	_shard_meshes.clear()
	_piece_meshes.clear()
	_puff_mesh = null
	_material = null
	_scrap_paid = 0
	_cogs_paid = 0
	_consumables_paid = 0
	_shrapnel_hits = 0
	_clock = 0.0
	_have_prev = false
	_live_serial = 0
	_ctx = null
	_tuning = null
	_build = null
	_cruise_override = false


func _exit_tree() -> void:
	_exiting = true
	teardown()


# ---- reads --------------------------------------------------------------------------------------

func ids() -> Array[String]:
	return _order.duplicate()


func state_of(id: String) -> String:
	if not _pieces.has(id):
		return ""
	return "intact" if (_pieces[id] as Piece).intact else "shattered"


func tier_of(id: String) -> int:
	return (_pieces[id] as Piece).tier if _pieces.has(id) else 0


func intact_count() -> int:
	var n := 0
	for piece in _pieces.values():
		if (piece as Piece).intact:
			n += 1
	return n


func body_of(id: String) -> StaticBody3D:
	return (_pieces[id] as Piece).body if _pieces.has(id) else null


func bounds_of(id: String) -> AABB:
	return (_pieces[id] as Piece).bounds if _pieces.has(id) else AABB()


# True when `point` lies inside the piece's oriented box grown by `margin`, intact or shattered.
func contains_point(id: String, point: Vector3, margin: float = 0.0) -> bool:
	if not _pieces.has(id):
		return false
	var p := _pieces[id] as Piece
	var local := p.basis.inverse() * (point - p.centre)
	var reach := p.half + Vector3.ONE * margin
	return absf(local.x) <= reach.x and absf(local.y) <= reach.y and absf(local.z) <= reach.z


# Rows the stage refused: [{id, reason}].
func refusals() -> Array[Dictionary]:
	return _refused.duplicate()


# The ids in the order they broke.
func break_order() -> Array[String]:
	return _breaks.duplicate()


func loot() -> Dictionary:
	return {"scrap": _scrap_paid, "cogs": _cogs_paid}


func consumables_paid() -> int:
	return _consumables_paid


func shrapnel_hits() -> int:
	return _shrapnel_hits


func live_shards() -> int:
	return _live_of(_shards)


func live_puffs() -> int:
	return _live_of(_puffs)


# Every pooled node (shards and dust puffs): at most NODE_CEILING.
func pool_nodes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for list in [_shards, _puffs]:
		for entry in list:
			out.append((entry as Shard).node)
	return out


func shard_pool_size() -> int:
	return _shards.size()


func material() -> StandardMaterial3D:
	return _material


# ---- the ball -----------------------------------------------------------------------------------

# One call a physics tick. Sweeps the ball's forward segment [last position, position + flat velocity x dt]
# against the intact pieces within WALL_REACH + flat / 30, and shatters the ones the ball's class and speed
# break. Anything else the ball meets is a wall; a bump at or over REFUSED_FLOOR x cruise answers with the
# chip and the refused cue, once a piece per REFUSED_GAP_S.
func on_ball(ball_pos: Vector3, velocity: Vector3, heft_class: int, dt: float = 1.0 / 60.0) -> void:
	_clock += dt
	_last_heft = heft_class
	var from := ball_pos
	if _have_prev and _prev.distance_to(ball_pos) <= JUMP_RESET_M:
		from = _prev
	_prev = ball_pos
	_have_prev = true
	if _pieces.is_empty():
		return
	var flat_v := Vector3(velocity.x, 0.0, velocity.z)
	var flat := flat_v.length()
	if flat < 0.01:
		return
	var heading := flat_v / flat
	var to := ball_pos + flat_v * dt
	var reach := WALL_REACH + flat / 30.0
	for p in _near(from, to, reach + BALL_RADIUS):
		if not p.intact:
			continue
		var seen := _sweep(p, from, to)
		var dir: Vector3 = seen["dir"]
		var dist: float = seen["dist"]
		if dist > reach or heading.dot(dir) < HEADING_COS:
			continue
		if heft_class >= p.tier and flat >= _bar(p.tier):
			_shatter(p, seen["at"], heading, flat, false)
		elif dist <= CONTACT_M and flat >= REFUSED_FLOOR * _live_cruise():
			_refuse(p, seen["at"], heading)


# A blast the source already resolved: every intact piece whose box the ring reaches breaks when the heft
# class plus the bonus (at most +1, never stacked) meets its tier. heft_class below zero reads the class the
# ball last reported.
func on_blast(at: Vector3, radius: float, source: String, tier_bonus: int = 1, heft_class: int = -1) -> void:
	var heft := heft_class if heft_class >= 0 else _last_heft
	var effective := TIER_MAX if source == Consumables.CAP_CHARGE else heft + clampi(tier_bonus, 0, 1)
	var cruise := _live_cruise()
	for p in _near(at, at, radius):
		if not p.intact or effective < p.tier:
			continue
		var near := _closest(p, at)
		if at.distance_to(near) > radius:
			continue
		var away := Vector3(p.centre.x - at.x, 0.0, p.centre.z - at.z)
		_shatter(p, near, away.normalized() if away.length() > 0.01 else Vector3.FORWARD, cruise, true, source)


# ---- the break ----------------------------------------------------------------------------------

func _live_cruise() -> float:
	if not _cruise_override and is_instance_valid(_tuning):
		return float(_tuning.f("cruise"))
	return _cruise


func _bar(tier: int) -> float:
	return WALL_SPEED if tier <= 1 else _live_cruise() * RAM_MIN_PER_CRUISE


func _shatter(p: Piece, at: Vector3, dir: Vector3, speed: float, radial: bool, source: String = "") -> void:
	p.intact = false
	_breaks.append(p.id)
	if p.body != null and is_instance_valid(p.body):
		p.body.collision_layer = 0
		p.body.collision_mask = 0
	if p.shape != null and is_instance_valid(p.shape):
		p.shape.set_deferred("disabled", true)
	if p.mesh != null and is_instance_valid(p.mesh):
		p.mesh.visible = false
	_unfile(p)
	if not _no_visuals:
		var n := SHARDS_LIGHT if p.tier <= 2 else SHARDS_HEAVY
		for i in n:
			_throw(_shards, p, at, dir, speed, FAMILY_BY_TIER.get(p.tier, "scrap"))
		_throw(_puffs, p, at, Vector3.UP, 0.0, "puff")
		if _sfx.is_valid():
			_sfx.call(Kit.sfx_id(p.tier), at)
		if _weight.is_valid():
			_weight.call(p.tier, at)
	_shrapnel(p, at, dir, speed, radial)
	_pay(p)
	piece_shattered.emit(p.bounds)
	if is_instance_valid(_events) and _events.has_signal("world_fact"):
		_events.emit_signal("world_fact", "piece_shattered", at)


func _refuse(p: Piece, at: Vector3, dir: Vector3) -> void:
	if _clock - p.refused_at < REFUSED_GAP_S:
		return
	p.refused_at = _clock
	if not _no_visuals:
		var n := CHIPS_MIN + int(_fx.randi() % (CHIPS_MAX - CHIPS_MIN + 1))
		for i in n:
			_throw(_shards, p, at, dir, 0.0, FAMILY_BY_TIER.get(p.tier, "scrap"), true)
	if _cue.is_valid():
		_cue.call(at)


# One outward check from the break: at most SHRAPNEL_MAX enemies within SHRAPNEL_M, inside the 90 degree cone
# around the travel direction (any direction for a blast), each knocked and struck once as a "debris" hit.
func _shrapnel(p: Piece, at: Vector3, dir: Vector3, speed: float, radial: bool) -> void:
	var found: Array = []
	for enemy in _enemy_list():
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var out: Vector3 = enemy.global_position - at
		var away := Vector3(out.x, 0.0, out.z)
		if out.length() > SHRAPNEL_M:
			continue
		if not radial and away.length() > 0.01 and dir.dot(away.normalized()) < SHRAPNEL_COS:
			continue
		found.append([out.length(), enemy.get_instance_id(), enemy, away])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var force := BASE_FORCE * float(TIER_SCALE[p.tier - 1]) * clampf(speed / maxf(_live_cruise(), 0.01), 0.6, 1.4)
	for i in mini(found.size(), SHRAPNEL_MAX):
		var enemy: Object = found[i][2]
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var away: Vector3 = found[i][3]
		var push := (away.normalized() if away.length() > 0.01 else dir) + Vector3.UP * 0.3
		if enemy.has_method("knock"):
			enemy.knock(push, force)
		if _combat != null and _combat.has_method("strike"):
			_combat.strike(enemy, "debris", force, "", "debris:" + p.id)
		_shrapnel_hits += 1


func _is_scrapless() -> bool:
	if is_instance_valid(_build) and _build.has_method("scrapless") and bool(_build.call("scrapless")):
		return true
	if is_instance_valid(_ctx):
		var b: Variant = _ctx.get("build")
		if b is Object and is_instance_valid(b) and (b as Object).has_method("scrapless") and bool((b as Object).call("scrapless")):
			return true
	return false


# The piece pays once at the break from its own spot, from its own stream, clamped to what the stage's
# meter still has room for. Past the cap it still shatters and hits and drops nothing.
func _pay(p: Piece) -> void:
	if _is_scrapless():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(_seed, _run_id, _stage, "destructible:" + p.id)
	var row: Array = LOOT[p.tier]
	var scrap_n := int(row[0])
	if p.tier == 1:
		scrap_n = 1 if rng.randf() < TIER1_CHANCE else 0
	var cogs_n := int(row[1])
	scrap_n = clampi(mini(scrap_n, scrap_cap - _scrap_paid), 0, scrap_n)
	cogs_n = clampi(mini(cogs_n, cog_cap - _cogs_paid), 0, cogs_n)
	var spot := Vector3(p.centre.x, p.centre.y - p.half.y, p.centre.z)
	if scrap_n > 0:
		_scrap_paid += scrap_n
		if _scrap != null:
			_scrap.drop(spot, scrap_n, rng)
	if cogs_n > 0:
		_cogs_paid += cogs_n
		if _scrap != null:
			_scrap.drop_cogs(spot, cogs_n)
	# High-tier Heft Destructibles (tiers 3-5) may drop a Pocket Consumable once per piece
	# (own deterministic stream so scrap/cog rolls stay unchanged; pays strictly once).
	if p.tier >= 3 and _consumables_paid < consumable_cap:
		var cons_id := Consumables.roll_for_destructible(_seed, _run_id, _stage, p.id, p.tier)
		if cons_id != "":
			_consumables_paid += 1
			if _combat != null and _combat.has_method("drop_consumable"):
				_combat.drop_consumable(cons_id, spot)


# ---- geometry -----------------------------------------------------------------------------------

func _closest(p: Piece, point: Vector3) -> Vector3:
	var local := p.basis.inverse() * (point - p.centre)
	return p.centre + p.basis * local.clamp(-p.half, p.half)


# The nearest the segment from to `to` comes to the piece: {dist, at (the box's nearest point), dir (flat, from
# that sample of the ball to the box)}.
func _sweep(p: Piece, from: Vector3, to: Vector3) -> Dictionary:
	var steps := maxi(1, ceili(from.distance_to(to) / 0.5))
	var best := {"dist": INF, "at": p.centre, "dir": Vector3.ZERO}
	for i in steps + 1:
		var s := from.lerp(to, float(i) / float(steps))
		var near := _closest(p, s)
		var d := s.distance_to(near)
		if d < float(best["dist"]):
			var flat := Vector3(near.x - s.x, 0.0, near.z - s.z)
			best = {"dist": d, "at": near, "dir": flat.normalized() if flat.length() > 0.01 else Vector3.ZERO}
	if (best["dir"] as Vector3) == Vector3.ZERO:
		best["dir"] = Vector3(p.centre.x - to.x, 0.0, p.centre.z - to.z).normalized()
	return best


func _cells_of(box: AABB) -> Array[Vector3i]:
	var lo := box.position
	var hi := box.end
	var out: Array[Vector3i] = []
	for x in range(floori(lo.x / CELL_M), floori(hi.x / CELL_M) + 1):
		for y in range(floori(lo.y / CELL_M), floori(hi.y / CELL_M) + 1):
			for z in range(floori(lo.z / CELL_M), floori(hi.z / CELL_M) + 1):
				out.append(Vector3i(x, y, z))
	return out


func _near(a: Vector3, b: Vector3, reach: float) -> Array[Piece]:
	var box := AABB(a, Vector3.ZERO).expand(b).grow(reach)
	var seen := {}
	var out: Array[Piece] = []
	for cell in _cells_of(box):
		for p in _grid.get(cell, []):
			if not seen.has(p.id):
				seen[p.id] = true
				out.append(p)
	out.sort_custom(func(x: Piece, y: Piece) -> bool: return x.order < y.order)
	return out


func _unfile(p: Piece) -> void:
	for cell in _cells_of(p.bounds):
		if _grid.has(cell):
			(_grid[cell] as Array).erase(p)


func _register(row: Dictionary) -> Piece:
	var p := Piece.new()
	p.id = String(row["id"])
	p.tier = int(row["tier"])
	p.centre = _vec(row["at"])
	p.half = _vec(row["size"]) * 0.5
	p.basis = Basis(Vector3.UP, deg_to_rad(float(row.get("yaw_deg", 0.0))))
	p.family = String(row.get("family", FAMILY_BY_TIER.get(p.tier, "scrap")))
	p.order = _order.size()
	var box := AABB()
	var first := true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner: Vector3 = p.centre + p.basis * Vector3(p.half.x * sx, p.half.y * sy, p.half.z * sz)
				box = AABB(corner, Vector3.ZERO) if first else box.expand(corner)
				first = false
	p.bounds = box
	_pieces[p.id] = p
	_order.append(p.id)
	for cell in _cells_of(box):
		if not _grid.has(cell):
			_grid[cell] = []
		(_grid[cell] as Array).append(p)
	_build_collider(p)
	return p


func _build_collider(p: Piece) -> void:
	var body := StaticBody3D.new()
	body.name = "Destructible_" + p.id
	body.collision_layer = 1 << (WORLD_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("destructible_id", p.id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = p.half * 2.0
	shape.shape = box
	body.add_child(shape)
	body.transform = Transform3D(p.basis, p.centre)
	add_child(body)
	p.body = body
	p.shape = shape


# ---- visuals, built in slices -------------------------------------------------------------------

func _queue_visuals() -> void:
	_queue.append(_make_material)
	for id in _order:
		_queue.append(_make_mesh.bind(_pieces[id] as Piece))
	for family in FAMILY_BY_TIER.values():
		if not _shard_meshes.has(family):
			_shard_meshes[family] = null
			_queue.append(_make_shard_mesh.bind(String(family)))
	_queue.append(_make_puff_mesh)
	for i in SHARD_POOL:
		_queue.append(_make_pooled.bind(_shards, false))
	for i in PUFF_POOL:
		_queue.append(_make_pooled.bind(_puffs, true))


func _process(delta: float) -> void:
	_slice(BUILD_SLICE_USEC)
	_run_fx(delta)


func _slice(budget_usec: int) -> void:
	var start := Time.get_ticks_usec()
	while not _queue.is_empty() and Time.get_ticks_usec() - start < budget_usec:
		(_queue.pop_front() as Callable).call()


func _make_material() -> void:
	_material = Kit.material()


# One mesh per (tier, size): two crates of one size share a mesh, so the stage builds each shape once.
func _make_mesh(p: Piece) -> void:
	if p.intact and is_instance_valid(p.body):
		var node := MeshInstance3D.new()
		node.name = "Intact_" + p.id
		var size := p.half * 2.0
		var key := "%d:%.3f:%.3f:%.3f" % [p.tier, size.x, size.y, size.z]
		if not _piece_meshes.has(key):
			_piece_meshes[key] = Kit.piece_mesh(p.tier, size)
		node.mesh = _piece_meshes[key]
		node.material_override = _material
		node.transform = Transform3D(p.basis, p.centre)
		if maxf(size.x, maxf(size.y, size.z)) < BIG_EXTENT_M:
			node.visibility_range_end = VIEW_END_M
			node.visibility_range_end_margin = VIEW_MARGIN_M
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(node)
		p.mesh = node


func _make_shard_mesh(family: String) -> void:
	_shard_meshes[family] = Kit.shard_mesh(family)


func _make_puff_mesh() -> void:
	_puff_mesh = Kit.puff_mesh()


func _make_pooled(list: Array, puff: bool) -> void:
	var s := Shard.new()
	s.puff = puff
	s.node = MeshInstance3D.new()
	s.node.name = ("Puff%d" if puff else "Shard%d") % list.size()
	s.node.mesh = _puff_mesh if puff else _shard_meshes.get("scrap")
	s.node.material_override = _material
	s.node.visible = false
	s.node.scale = Vector3.ONE * SPECK
	s.node.top_level = true
	add_child(s.node)
	list.append(s)


# ---- the shards: scripted, never a body, never a fade --------------------------------------------

func _live_of(list: Array) -> int:
	var n := 0
	for entry in list:
		if (entry as Shard).live:
			n += 1
	return n


# One pooled node thrown from `at`. A full pool reuses its oldest live node, which finishes at once.
func _throw(list: Array, p: Piece, at: Vector3, dir: Vector3, speed: float, family: String, chip: bool = false) -> void:
	if list.is_empty():
		return
	var pick: Shard = null
	for entry in list:
		var s := entry as Shard
		if not s.live:
			pick = s
			break
	if pick == null:
		for entry in list:
			var s := entry as Shard
			if pick == null or s.serial < pick.serial:
				pick = s
		_finish(pick)
	_live_serial += 1
	pick.serial = _live_serial
	pick.live = true
	pick.t = 0.0
	pick.ground = p.centre.y - p.half.y
	pick.pos = at + Vector3(_fx.randf_range(-0.3, 0.3), _fx.randf_range(0.0, 0.4), _fx.randf_range(-0.3, 0.3))
	var scatter := Vector3(_fx.randf_range(-1.0, 1.0), 0.0, _fx.randf_range(-1.0, 1.0)) * 0.5
	if pick.puff:
		pick.vel = Vector3.ZERO
		pick.life = PUFF_LIFE
		pick.base = 1.0
		pick.pos = Vector3(p.centre.x, pick.ground + 0.3, p.centre.z)
	else:
		var carry := (dir + scatter).normalized() * (maxf(speed, 3.0) * SHARD_CARRY * (0.4 if chip else 1.0))
		pick.vel = carry + Vector3.UP * (SHARD_LIFT * (0.5 if chip else 1.0) + _fx.randf() * 1.5)
		pick.life = clampf(_fx.randf_range(SHARD_LIFE.x, SHARD_LIFE.y), 0.01, PropKicks.FLY_MAX_S)
		pick.base = 1.0
		pick.node.mesh = _shard_meshes.get(family, _shard_meshes.get("scrap"))
	pick.spin = Vector3(_fx.randf_range(-9.0, 9.0), _fx.randf_range(-9.0, 9.0), _fx.randf_range(-9.0, 9.0))
	pick.node.position = pick.pos
	pick.node.scale = Vector3.ONE * pick.base
	pick.node.visible = true


func _finish(s: Shard) -> void:
	s.live = false
	s.node.scale = Vector3.ONE * SPECK
	s.node.visible = false


func _run_fx(delta: float) -> void:
	for list in [_shards, _puffs]:
		for entry in list:
			var s := entry as Shard
			if not s.live:
				continue
			s.t += delta
			if s.t >= s.life or s.t >= PropKicks.FLY_MAX_S:
				_finish(s)
				continue
			if not s.puff:
				s.vel.y -= PropKicks.GRAVITY * delta
				s.pos += s.vel * delta
				if s.pos.y <= s.ground + SHARD_SIZE * 0.5 and s.vel.y < 0.0:
					s.pos.y = s.ground + SHARD_SIZE * 0.5
					s.vel = Vector3(s.vel.x * PropKicks.FLY_SKID, -s.vel.y * PropKicks.FLY_BOUNCE, s.vel.z * PropKicks.FLY_SKID)
					s.spin *= PropKicks.FLY_SKID
				s.node.rotation += s.spin * delta
			else:
				s.pos.y += 0.6 * delta
			s.node.position = s.pos
			s.node.scale = Vector3.ONE * clampf(1.0 - s.t / s.life, SPECK, 1.0)


# ---- ctx ----------------------------------------------------------------------------------------

func last_shattered_id() -> String:
	return _breaks[-1] if not _breaks.is_empty() else ""


func _bind(ctx: Variant) -> void:
	_no_visuals = bool(_ctx_get(ctx, "no_visuals", false))
	scrap_cap = int(_ctx_get(ctx, "scrap_cap", SCRAP_CAP))
	cog_cap = int(_ctx_get(ctx, "cog_cap", COG_CAP))
	var raw_ctx: Variant = (ctx as Dictionary).get("ctx", ctx) if ctx is Dictionary else ctx
	_ctx = raw_ctx as Object if raw_ctx is Object else null
	_cruise_override = ctx is Dictionary and (ctx as Dictionary).has("cruise") and (ctx as Dictionary)["cruise"] != null
	var tuning_val: Variant = _ctx_get(ctx, "tuning", null)
	_tuning = tuning_val as Object if tuning_val is Object and (tuning_val as Object).has_method("f") else null
	_cruise = float(_ctx_get(ctx, "cruise", _tuned_cruise(ctx)))
	_seed = int(_ctx_get(ctx, "run_seed", _chain(ctx, ["rng", "seed"], 0)))
	_run_id = String(_ctx_get(ctx, "run_id", _chain(ctx, ["run", "run_id"], "")))
	_stage = int(_ctx_get(ctx, "stage", _chain(ctx, ["run", "stage"], 0)))
	var build_val: Variant = _ctx_get(ctx, "build", null)
	if build_val == null and _ctx != null and _ctx.has_method("build_module"):
		build_val = _ctx.call("build_module")
	_build = build_val as Object if build_val is Object else null
	_scrap = _ctx_get(ctx, "scrap", _chain(ctx, ["build", "scrap"], null)) as Object
	if _scrap == null and _build != null:
		_scrap = _build.get("scrap") as Object
	_combat = _ctx_get(ctx, "combat", _ctx_get(ctx, "spawner", null)) as Object
	var finder: Variant = _ctx_get(ctx, "enemies", null)
	_enemies = finder if finder is Callable else Callable()
	var cue: Variant = _ctx_get(ctx, "refused", null)
	if cue is Callable:
		_cue = cue
	else:
		var events: Variant = _ctx_get(ctx, "events", null)
		_cue = Callable()
		if events != null and (events as Object).has_signal("verb_failed"):
			_cue = func(at: Vector3) -> void: (events as Object).emit_signal("verb_failed", "roll", "under_bar", at)
	_sfx = _sfx_of(ctx)
	_weight = _weight_of(ctx)
	var bus: Variant = _ctx_get(ctx, "events", null)
	_events = bus as Object if bus is Object else null
	_fx.seed = hash("destructibles_fx")


# The shatter sound: ctx "sfx" (Callable(id, at)), or the game's audio (ctx.presentation.audio or
# ctx.root.presentation.audio, matching game.gd:128 / world.gd:507) when present. Silent with neither,
# and never built under --bot-no-visuals=1.
func _sfx_of(ctx: Variant) -> Callable:
	if _no_visuals:
		return Callable()
	var given: Variant = _ctx_get(ctx, "sfx", null)
	if given is Callable:
		return given
	var audio: Variant = _chain(ctx, ["presentation", "audio"], null)
	if audio == null:
		audio = _chain(ctx, ["root", "presentation", "audio"], null)
	if audio is Object and (audio as Object).has_method("play_at"):
		return func(id: String, at: Vector3) -> void: (audio as Object).call("play_at", "destructible_shatter", at, 0.0, 1.0, "SFX", id)
	if audio is Object and (audio as Object).has_method("play"):
		return func(id: String, _at: Vector3) -> void: (audio as Object).call("play", "destructible_shatter", 0.0, 1.0, "SFX", id)
	return Callable()


# The break's weight (hit-stop, shake, kick by tier): ctx "weight" (Callable(tier, at)), or the game's juice
# (presentation.juice, found as the sound's audio is). None with neither, and never under --bot-no-visuals=1.
func _weight_of(ctx: Variant) -> Callable:
	if _no_visuals:
		return Callable()
	var given: Variant = _ctx_get(ctx, "weight", null)
	if given is Callable:
		return given
	var juice: Variant = _chain(ctx, ["presentation", "juice"], null)
	if juice == null:
		juice = _chain(ctx, ["root", "presentation", "juice"], null)
	if juice is Object and (juice as Object).has_method("on_piece_shattered"):
		return Callable(juice as Object, "on_piece_shattered")
	return Callable()


func _tuned_cruise(ctx: Variant) -> float:
	var tuning: Variant = _ctx_get(ctx, "tuning", null)
	if tuning != null and (tuning as Object).has_method("f"):
		return float(tuning.f("cruise"))
	return _cruise


static func _ctx_get(ctx: Variant, key: String, fallback: Variant) -> Variant:
	if ctx is Dictionary:
		var d := ctx as Dictionary
		if d.has(key) and d[key] != null:
			return d[key]
		if key != "ctx" and d.has("ctx") and d["ctx"] != null:
			return _ctx_get(d["ctx"], key, fallback)
		return fallback
	if ctx is Object:
		var value: Variant = (ctx as Object).get(key)
		return fallback if value == null else value
	return fallback


static func _chain(ctx: Variant, path: Array, fallback: Variant) -> Variant:
	var at: Variant = ctx
	for key in path:
		at = _ctx_get(at, String(key), null)
		if at == null:
			return fallback
	return at


func _enemy_list() -> Array:
	if _enemies.is_valid():
		return _enemies.call()
	return get_tree().get_nodes_in_group("enemy") if is_inside_tree() else []


static func _vec(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.INF
