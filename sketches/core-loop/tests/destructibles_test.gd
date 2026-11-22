extends SceneTree

const T := preload("res://tests/support/t.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const Activities := preload("res://src/world/activities.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const RunState := preload("res://src/core/run_state.gd")

# Heft destructibles, unit A (design-v3/HEFT-DESTRUCTIBLES.md sections 2 to 7 and 9; tests T1 to T7 and T12).
# The module is run against a real Jolt fixture floor and wall for the break and the bounce, and against
# fakes for scrap, combat and enemies for the payoffs. Every claim carries a planted control that must fail
# the same predicate: a class that is heavy enough, a collider forced on, a translucent shard, a cap of 100, a
# shared stream. Evidence limit: transforms and state in a headless run, not the look or the sound.

const CRUISE := 14.0
const DT := 1.0 / 60.0

var t := T.new("destructibles_test")


class FakeScrap extends RefCounted:
	var scrap: Array[int] = []
	var cogs: Array[int] = []
	var shared: RandomNumberGenerator = null

	func drop(_at: Vector3, amount: int, rng: RandomNumberGenerator) -> void:
		var stream := shared if shared != null else rng
		for i in amount:
			stream.randf_range(-2.0, 2.0)
			stream.randf_range(-2.0, 2.0)
		scrap.append(amount)

	func drop_cogs(_at: Vector3, amount: int) -> void:
		cogs.append(amount)

	func scrap_sum() -> int:
		var n := 0
		for a in scrap:
			n += a
		return n

	func cog_sum() -> int:
		var n := 0
		for a in cogs:
			n += a
		return n


class FakeCombat extends RefCounted:
	var strikes: Array[Dictionary] = []

	func strike(enemy: Node3D, kind: String, force: float, part := "", source := "", _impact := "") -> void:
		strikes.append({"enemy": enemy, "kind": kind, "force": force, "part": part, "source": source})


class FakeEnemy extends Node3D:
	var knocks := 0
	var last_push := Vector3.ZERO

	func knock(direction: Vector3, _force: float) -> void:
		knocks += 1
		last_push = direction

	func is_dead() -> bool:
		return false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parity()
	_rule()
	_exclusions()
	_blast_bonus()
	await _under_tier()
	await _zero_snag()
	await _debris()
	_loot_cap()
	_rng_isolation()
	await _teardown_and_determinism()
	quit(t.verdict())


# ---- fixtures -----------------------------------------------------------------------------------

func _row(id: String, tier: int, at: Vector3, size: Vector3 = Vector3(2.0, 3.0, 6.0), extra: Dictionary = {}) -> Dictionary:
	var row := {"id": id, "tier": tier, "at": at, "size": size}
	row.merge(extra, true)
	return row


func _ctx(extra: Dictionary = {}) -> Dictionary:
	var ctx := {"root": root, "cruise": CRUISE, "run_seed": 7, "run_id": "bot-9", "stage": 1,
		"scrap": FakeScrap.new(), "combat": FakeCombat.new(), "refused": func(_at: Vector3) -> void: pass}
	ctx.merge(extra, true)
	return ctx


func _make(rows: Variant, extra: Dictionary = {}) -> Node3D:
	var mod: Node3D = Destructibles.new()
	mod.build(rows, _ctx(extra))
	mod.finish_build()
	mod.set_process(false)
	return mod


func _drop(mod: Node3D) -> void:
	mod.teardown()
	mod.queue_free()


# A ball rolled straight along +x at `speed`, one tick at a time, from x0 to x1.
func _roll(mod: Node3D, x0: float, x1: float, speed: float, heft: int, y: float = 1.0, z: float = 0.0) -> void:
	var x := x0
	while x < x1:
		mod.on_ball(Vector3(x, y, z), Vector3(speed, 0.0, 0.0), heft, DT)
		x += speed * DT


func _enemy(at: Vector3) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.position = at
	e.add_to_group("enemy")
	root.add_child(e)
	return e


func _opaque(mod: Node3D) -> bool:
	var mat: StandardMaterial3D = mod.material()
	if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or not is_equal_approx(mat.albedo_color.a, 1.0):
		return false
	for node in mod.pool_nodes():
		if node.material_override != mat:
			return false
	for child in mod.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).material_override != mat:
			return false
	return true


# ---- constants this module copies from its owners -----------------------------------------------

func _parity() -> void:
	t.eq("WALL_REACH is the cracked cache's", Destructibles.WALL_REACH, CrackedCache.WALL_REACH)
	t.eq("WALL_SPEED is the cracked wall's", Destructibles.WALL_SPEED, Contraptions.WALL_SPEED)
	t.eq("the ram bar is the cracked face's", Destructibles.RAM_MIN_PER_CRUISE, Activities.RAM_MIN_PER_CRUISE)
	var refused: Dictionary = Activities.RULES["cracked_cache"]["refused"]
	t.check("the refused floor and gap are the roll cue's", Destructibles.REFUSED_FLOOR == float(refused["floor"]) and Destructibles.REFUSED_GAP_S == float(refused["gap_s"]),
		"%s / %s" % [refused["floor"], refused["gap_s"]])
	t.eq("the build slice is the park props'", Destructibles.BUILD_SLICE_USEC, ParkProps.BUILD_SLICE_USEC)
	t.eq("SPECK is the enemy death look's", Destructibles.SPECK, EnemyMotion.SPECK)
	t.eq("guarded societies are the schema's", Destructibles.GUARDED_SOCIETIES, ParkSchema.GUARDED_SOCIETIES)
	t.eq("the shard pool is the kick pool's", Destructibles.SHARD_POOL, 24)
	t.check("pool plus puffs fit the stage ceiling", Destructibles.SHARD_POOL + Destructibles.PUFF_POOL <= Destructibles.NODE_CEILING, "")
	t.eq("five heft classes map to five tiers", RunState.HEFT_CLASS_AT.size(), Destructibles.TIER_MAX)


# ---- the break rule -----------------------------------------------------------------------------

func _rule() -> void:
	var mod := _make([_row("t1", 1, Vector3(0, 1.5, 0)), _row("t2", 2, Vector3(0, 1.5, 40)), _row("t3", 3, Vector3(0, 1.5, 80)),
		_row("t3b", 3, Vector3(0, 1.5, 120)), _row("t3c", 3, Vector3(0, 1.5, 160))])
	# Tier 1 asks the sprint bar, WALL_SPEED.
	mod.on_ball(Vector3(-3, 1, 0), Vector3(7.5, 0, 0), 1, DT)
	t.eq("tier 1 holds under WALL_SPEED", mod.state_of("t1"), "intact")
	mod.on_ball(Vector3(-3, 1, 0), Vector3(8.0, 0, 0), 1, DT)
	t.eq("tier 1 breaks at WALL_SPEED for Class I", mod.state_of("t1"), "shattered")
	# Tier 2 asks 0.85 x cruise and Class II.
	var bar := CRUISE * Destructibles.RAM_MIN_PER_CRUISE
	mod.on_ball(Vector3(-3, 1, 40), Vector3(bar - 0.1, 0, 0), 2, DT)
	t.eq("tier 2 holds just under 0.85 x cruise", mod.state_of("t2"), "intact")
	mod.on_ball(Vector3(-3, 1, 40), Vector3(bar + 0.1, 0, 0), 1, DT)
	t.eq("tier 2 holds against Class I at speed", mod.state_of("t2"), "intact")
	mod.on_ball(Vector3(-3, 1, 40), Vector3(bar + 0.1, 0, 0), 2, DT)
	t.eq("tier 2 breaks for Class II at the bar", mod.state_of("t2"), "shattered")
	# A ball beside it, not heading at it, breaks nothing; one above it, in the air, none either.
	mod.on_ball(Vector3(-3, 1, 80 + 10), Vector3(CRUISE, 0, 0), 5, DT)
	t.eq("a ball passing 6 m wide of the wall's end breaks nothing", mod.state_of("t3"), "intact")
	mod.on_ball(Vector3(-3, 12, 120), Vector3(CRUISE, 0, 0), 5, DT)
	t.eq("a ball 10 m over it breaks nothing", mod.state_of("t3b"), "intact")
	mod.on_ball(Vector3(-3, 1, 160), Vector3(-CRUISE, 0, 0), 5, DT)
	t.eq("a ball heading away breaks nothing", mod.state_of("t3c"), "intact")
	mod.on_ball(Vector3(-3, 1, 80), Vector3(CRUISE, 0, 0), 5, DT)
	t.eq("control: the same ball level and heading in breaks tier 3 for Class V", mod.state_of("t3"), "shattered")
	_drop(mod)


# ---- T7: exclusions -----------------------------------------------------------------------------

func _exclusions() -> void:
	var at := Vector3(0, 1.5, 0)
	var forbidden := {
		"terrain flag": {"terrain": true},
		"heightfield flag": {"heightfield": true},
		"landform row": {"landform": "slot_canyon"},
		"ground element": {"element": "ground"},
		"bank element": {"element": "bank"},
		"terrace element": {"element": "terrace"},
		"terrain kind": {"kind": "heightfield"},
		"anchor_field": {"element": "anchor_field"},
		"world_anchor flag": {"world_anchor": true},
		"world_anchor group": {"groups": ["world_anchor"]},
		"flume bent": {"id": "flume_bent_3"},
		"flume pier": {"id": "flume_ride_pier_1"},
		"perch asset": {"asset": {"perch": [0, 1, 0]}},
		"tall asset tag": {"asset": {"tags": ["tall"]}},
		"guarded hohokam": {"society": "hohokam"},
		"guarded puebloan": {"society": "ancestral_puebloan"},
		"soft foliage": {"tags": ["plant"]},
		"park prop": {"source": "park_props"},
		"contraption id": {"id": "slot_bulkhead"},
		"no id": {"id": ""},
		"tier 0": {"tier": 0},
		"tier 6": {"tier": 6},
		"no size": {"size": [0, 0, 0]},
	}
	for element in ["kicker", "drop", "half_pipe", "rail", "grind_line", "elevated_line", "flow_line", "ledge", "bowl", "tunnel"]:
		forbidden["ridden " + element] = {"element": element}
	var rows: Array = []
	var n := 0
	for label in forbidden:
		var extra: Dictionary = forbidden[label]
		rows.append(_row(extra.get("id", "bad_%d" % n), 2, at + Vector3(0, 0, 10.0 * n), Vector3(2, 3, 6), extra))
		n += 1
	# A row with no id key at all, and a row that is not a row.
	rows.append({"tier": 2, "at": at, "size": Vector3.ONE})
	rows.append("nonsense")
	var mod := _make(rows, {"owned_ids": ["slot_bulkhead"]})
	t.eq("every forbidden family is refused", mod.refusals().size(), rows.size())
	t.eq("nothing forbidden is registered", mod.ids().size(), 0)
	var reasons := {}
	for r in mod.refusals():
		reasons[String(r["reason"])] = true
	t.check("each refusal names a reason", not reasons.has("") and reasons.size() >= 12, "%d distinct reasons" % reasons.size())
	for label in forbidden:
		var extra: Dictionary = forbidden[label]
		var why := Destructibles.validate_row(_row(extra.get("id", "x"), 2, at, Vector3(2, 3, 6), extra), {"slot_bulkhead": true})
		if why == "":
			t.check("validate_row refuses " + label, false, "accepted")
	t.check("validate_row refuses every family on its own", true, "%d rows" % forbidden.size())
	_drop(mod)
	# Planted control: valid rows of every tier, and the same rows twice, pass once.
	var good: Array = []
	for tier in range(1, 6):
		good.append(_row("ok_%d" % tier, tier, at + Vector3(0, 0, 10.0 * tier)))
	good.append(_row("ok_1", 2, at + Vector3(50, 0, 0)))
	var ok := _make(good)
	t.eq("control: valid rows of tiers 1 to 5 register", ok.ids().size(), 5)
	t.eq("control: a repeated id is the one refusal", ok.refusals().size(), 1)
	t.eq("control: its reason is the duplicate", ok.refusals()[0]["reason"], "id already taken")
	for tier in range(1, 6):
		t.eq("control: tier %d is kept" % tier, ok.tier_of("ok_%d" % tier), tier)
	# A map Dictionary carries its rows under destructible_rows.
	var map_ok := _make({"destructible_rows": good.slice(0, 2)})
	t.eq("a map's destructible_rows register", map_ok.ids().size(), 2)
	_drop(map_ok)
	_drop(ok)


# ---- the +1 rule --------------------------------------------------------------------------------

func _blast_bonus() -> void:
	var rows := [_row("a2", 2, Vector3(0, 1.5, 0)), _row("a3", 3, Vector3(0, 1.5, 10)), _row("far", 2, Vector3(0, 1.5, 100))]
	var mod := _make(rows)
	mod.on_blast(Vector3(-3, 1, 5), 12.0, "slam", 2, 1)
	t.eq("a Class I blast, bonus asked 2, breaks tier 2 (the bonus stops at +1)", mod.state_of("a2"), "shattered")
	t.eq("it never breaks tier 3", mod.state_of("a3"), "intact")
	t.eq("a piece outside the ring stands", mod.state_of("far"), "intact")
	mod.on_blast(Vector3(-3, 1, 5), 12.0, "slam", 99, 1)
	t.eq("a bonus of 99 still stops at +1: Class I, tier 3 holds", mod.state_of("a3"), "intact")
	mod.on_blast(Vector3(-3, 1, 5), 12.0, "slam", 0, 2)
	t.eq("no bonus: Class II is short of tier 3", mod.state_of("a3"), "intact")
	mod.on_blast(Vector3(-3, 1, 5), 12.0, "slam", -4, 2)
	t.eq("a negative bonus counts as none", mod.state_of("a3"), "intact")
	mod.on_blast(Vector3(-3, 1, 5), 12.0, "slam", 1, 2)
	t.eq("Class II with +1 breaks tier 3", mod.state_of("a3"), "shattered")
	t.eq("a blast reaching the box edge counts, a far one does not", mod.state_of("far"), "intact")
	mod.on_ball(Vector3(0, 100, 0), Vector3(1, 0, 0), 4, DT)
	mod.on_blast(Vector3(-3, 1, 100), 4.0, "rocket")
	t.eq("a blast with no class given reads the ball's last class: Class IV, +1, breaks tier 2", mod.state_of("far"), "shattered")
	_drop(mod)


# ---- T1: under tier -----------------------------------------------------------------------------

func _fixture(parent: Node, piece: Dictionary, ball_x: float, speed: float) -> Dictionary:
	var world := Node3D.new()
	parent.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(300, 1, 300)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	var ball := RigidBody3D.new()
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = 0.3
	ball.physics_material_override = mat
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp = 0.0
	ball.can_sleep = false
	var sphere := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	sphere.shape = shape
	ball.add_child(sphere)
	ball.collision_layer = 2
	ball.collision_mask = 1
	ball.position = Vector3(ball_x, 1.02, 0)
	world.add_child(ball)
	ball.linear_velocity = Vector3(speed, 0, 0)
	return {"world": world, "ball": ball}


# Steps the ball `ticks` physics frames, calling the module as the world tick does. Returns the speed and x per tick.
func _step(mod: Node3D, ball: RigidBody3D, heft: int, ticks: int, on_break: Callable = Callable()) -> Dictionary:
	var speeds: Array[float] = []
	var xs: Array[float] = []
	var vys: Array[float] = []
	var vxs: Array[float] = []
	var broke := -1
	var was: int = mod.intact_count()
	for i in ticks:
		await physics_frame
		mod.on_ball(ball.global_position, ball.linear_velocity, heft, DT)
		speeds.append(Vector3(ball.linear_velocity.x, 0, ball.linear_velocity.z).length())
		xs.append(ball.global_position.x)
		vys.append(absf(ball.linear_velocity.y))
		vxs.append(ball.linear_velocity.x)
		if broke < 0 and mod.intact_count() < was:
			broke = i
			if on_break.is_valid():
				on_break.call()
	return {"speeds": speeds, "xs": xs, "vys": vys, "vxs": vxs, "broke": broke}


func _under_tier() -> void:
	var cues: Array = []
	var ctx_extra := {"refused": func(at: Vector3) -> void: cues.append(at)}
	var mod := _make([_row("wall3", 3, Vector3(0, 1.5, 0), Vector3(2, 3, 8))], ctx_extra)
	var fix := _fixture(root, {}, -14.0, CRUISE)
	var ball: RigidBody3D = fix["ball"]
	var run: Dictionary = await _step(mod, ball, 2, 110)
	var speeds: Array = run["speeds"]
	var peak := 0.0
	for s in speeds:
		peak = maxf(peak, s)
	var after: float = speeds[speeds.size() - 1]
	var rebound := 0.0
	for vx in run["vxs"]:
		rebound = minf(rebound, vx)
	t.eq("T1: a tier 3 piece stands against a Class II ball at cruise", mod.state_of("wall3"), "intact")
	t.eq("T1: its collider is still on layer 1", mod.body_of("wall3").collision_layer, 1)
	t.check("T1: the ball met a wall and lost its speed", peak >= CRUISE * 0.95 and after < CRUISE * 0.5, "peak %.1f, after %.1f" % [peak, after])
	t.check("T1: and bounced back off it", rebound < -0.5, "rebound %.2f" % rebound)
	t.check("T1: the ball never got past the wall's face", ball.global_position.x < -1.0, "x %.2f" % ball.global_position.x)
	t.eq("T1: the refused cue fired once at the hit", cues.size(), 1)
	t.check("T1: the chips are 2 or 3 pooled shards", mod.live_shards() >= 2 and mod.live_shards() <= 3, "%d live" % mod.live_shards())
	t.eq("T1: a chip is no break: nothing paid, nothing struck", mod.loot(), {"scrap": 0, "cogs": 0})
	fix["world"].queue_free()
	_drop(mod)

	# Once per piece per 3.0 s: a ball held against the face at speed.
	var gate: Array = []
	var held := _make([_row("wall3", 3, Vector3(0, 1.5, 0), Vector3(2, 3, 8))], {"refused": func(_at: Vector3) -> void: gate.append(1)})
	var ticks := 0
	while ticks < int(2.9 / DT):
		held.on_ball(Vector3(-2.3, 1, 0), Vector3(CRUISE, 0, 0), 2, DT)
		ticks += 1
	t.eq("T1: one cue in the first 2.9 s of a ball held at the face", gate.size(), 1)
	while ticks < int(3.2 / DT):
		held.on_ball(Vector3(-2.3, 1, 0), Vector3(CRUISE, 0, 0), 2, DT)
		ticks += 1
	t.eq("T1: a second cue once 3.0 s have passed", gate.size(), 2)
	var slow := _make([_row("wall3", 3, Vector3(0, 1.5, 0), Vector3(2, 3, 8))], {"refused": func(_at: Vector3) -> void: gate.append(1)})
	var before := gate.size()
	slow.on_ball(Vector3(-2.3, 1, 0), Vector3(CRUISE * 0.39, 0, 0), 2, DT)
	t.eq("T1: a bump under 0.4 x cruise makes no cue", gate.size(), before)
	slow.on_ball(Vector3(-2.3, 1, 0), Vector3(CRUISE * 0.41, 0, 0), 2, DT)
	t.eq("T1: a bump over 0.4 x cruise does", gate.size(), before + 1)
	# Planted control: a hand-set Class III ball must break the same piece, so a no-op rule fails.
	held.on_ball(Vector3(-2.3, 1, 0), Vector3(CRUISE, 0, 0), 3, DT)
	t.eq("T1 control: a Class III ball breaks the tier 3 piece", held.state_of("wall3"), "shattered")
	_drop(held)
	_drop(slow)


# ---- T2: zero snag ------------------------------------------------------------------------------

func _snag_run(heft: int, force_solid: bool) -> Dictionary:
	var mod := _make([_row("wall2", 2, Vector3(0, 1.5, 0), Vector3(2, 3, 8))])
	var fix := _fixture(root, {}, -14.0, CRUISE)
	var ball: RigidBody3D = fix["ball"]
	if force_solid:
		# Planted: the collider is put back on the tick of the break, so the ball meets it.
		mod.piece_shattered.connect(func(_b: AABB) -> void:
			var body: StaticBody3D = mod.body_of("wall2")
			body.collision_layer = 1
			(body.get_child(0) as CollisionShape3D).set_deferred("disabled", false)
			# The module's own deferred disable is queued first; this one lands after it.
		)
	var run: Dictionary = await _step(mod, ball, heft, 120)
	var speeds: Array = run["speeds"]
	var xs: Array = run["xs"]
	var k: int = run["broke"]
	var cross := -1
	for i in xs.size():
		if float(xs[i]) >= -2.0:
			cross = i
			break
	var out := {"broke": k, "final_x": ball.global_position.x}
	if k >= 1:
		out["before"] = speeds[k - 1]
		var sample_at: int = (cross + 5) if (cross >= 0 and cross + 5 < speeds.size()) else mini(k + 5, speeds.size() - 1)
		out["after"] = speeds[sample_at]
		var min_vx := INF
		for i in range(k, speeds.size()):
			min_vx = minf(min_vx, speeds[i])
		out["min_speed"] = min_vx
		var peak_vy := 0.0
		for i in range(k, run["vys"].size()):
			peak_vy = maxf(peak_vy, run["vys"][i])
		out["peak_vy"] = peak_vy
	fix["world"].queue_free()
	_drop(mod)
	return out


func _zero_snag() -> void:
	var clean: Dictionary = await _snag_run(2, false)
	t.check("T2: the tier 2 piece breaks under a Class II ball at cruise", int(clean["broke"]) >= 1, "tick %s" % clean["broke"])
	t.check("T2: speed 5 ticks after is at least 0.99 x the speed before", float(clean.get("after", 0.0)) >= 0.99 * float(clean.get("before", 99.0)),
		"%.2f before, %.2f after" % [clean.get("before", 0.0), clean.get("after", 0.0)])
	t.check("T2: the ball never slowed through it and never bounced", float(clean.get("min_speed", 0.0)) >= 0.99 * float(clean.get("before", 99.0)) and float(clean.get("peak_vy", 99.0)) < 0.5,
		"min %.2f, vy %.2f" % [clean.get("min_speed", 0.0), clean.get("peak_vy", 99.0)])
	t.check("T2: the ball ended on the far side of the piece", float(clean["final_x"]) > 2.0, "x %.2f" % clean["final_x"])
	var forced: Dictionary = await _snag_run(2, true)
	var ok := float(forced.get("after", 0.0)) >= 0.99 * float(forced.get("before", 99.0)) and float(forced.get("min_speed", 0.0)) >= 0.99 * float(forced.get("before", 99.0)) and float(forced.get("final_x", 0.0)) > 2.0
	t.check("T2 control: with the collider forced on through the contact tick the same checks fail", not ok,
		"%.2f before, %.2f after, min %.2f, x %.2f" % [forced.get("before", 0.0), forced.get("after", 0.0), forced.get("min_speed", 0.0), forced["final_x"]])
	var light: Dictionary = await _snag_run(1, false)
	t.check("T2 control: a Class I ball meets the same piece as a wall", int(light["broke"]) < 0 and float(light["final_x"]) < -1.0,
		"broke %s, x %.2f" % [light["broke"], light["final_x"]])


# ---- T4: debris, the pool and shrapnel ----------------------------------------------------------

func _debris() -> void:
	var rows: Array = []
	for i in 14:
		rows.append(_row("h%d" % i, 3 + i % 3, Vector3(0, 1.5, 12.0 * i), Vector3(2, 3, 6)))
	rows.append(_row("l1", 1, Vector3(40, 1.0, 0), Vector3(1, 1, 1)))
	rows.append(_row("l2", 2, Vector3(40, 1.5, 20), Vector3(2, 3, 3)))
	var mod := _make(rows)
	t.eq("T4: the shard pool is 24 nodes", mod.shard_pool_size(), 24)
	t.check("T4: shards and dust puffs together stay under the ceiling of 32", mod.pool_nodes().size() <= Destructibles.NODE_CEILING, "%d nodes" % mod.pool_nodes().size())
	t.check("T4: every pooled node and intact mesh shares the one opaque material", _opaque(mod), "")
	t.check("T4: no pooled node is a physics body", mod.pool_nodes().all(func(n: Node) -> bool: return n is MeshInstance3D and not (n is PhysicsBody3D)), "")
	mod.on_blast(Vector3(40, 1, 0), 1.0, "test", 1, 1)
	t.eq("T4: a tier 1 break throws 4 shards", mod.live_shards(), 4)
	mod.on_blast(Vector3(40, 1, 20), 1.0, "test", 1, 2)
	t.eq("T4: a tier 2 break throws 4 more", mod.live_shards(), 8)
	mod.set_process(false)
	mod._run_fx(2.0)
	t.eq("T4: shards are done within 2 s", mod.live_shards(), 0)
	var specks := true
	for node in mod.pool_nodes():
		specks = specks and is_equal_approx(node.scale.x, Destructibles.SPECK) and is_equal_approx(node.scale.y, Destructibles.SPECK)
	t.check("T4: every pooled node ends at SPECK", specks, "")
	t.check("T4: the material is still opaque after use", _opaque(mod), "")
	mod.on_blast(Vector3(0, 1, 12.0 * 3), 1.0, "test", 1, 5)
	var heavy: int = mod.live_shards()
	t.eq("T4: a tier 3 to 5 break throws 6 shards", heavy, 6)
	mod.set_process(false)
	mod._run_fx(2.0)
	for i in 14:
		mod.on_blast(Vector3(0, 1, 12.0 * i), 1.0, "test", 1, 5)
	t.check("T4: twelve more heavy breaks leave at most 24 shards live", mod.live_shards() <= 24 and mod.live_shards() > 0, "%d live" % mod.live_shards())
	t.check("T4: live nodes never pass the ceiling of 32", mod.live_shards() + mod.live_puffs() <= Destructibles.NODE_CEILING, "%d" % (mod.live_shards() + mod.live_puffs()))
	t.eq("T4: the pool did not grow", mod.pool_nodes().size(), Destructibles.SHARD_POOL + Destructibles.PUFF_POOL)
	# Midway shards are mid-shrink, not faded.
	mod._run_fx(0.3)
	var shrinking := false
	for node in mod.pool_nodes():
		if node.visible and node.scale.x < 1.0 and node.scale.x > Destructibles.SPECK:
			shrinking = true
	t.check("T4: a live shard shrinks, it does not fade", shrinking and _opaque(mod), "")
	# Planted control: a translucent shard material fails the same predicate.
	var mat: StandardMaterial3D = mod.material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.5)
	t.check("T4 control: alpha below 1.0 fails the opaque check", not _opaque(mod), "")
	_drop(mod)

	# Shrapnel: one ball break, five enemies in the cone, one behind, one far.
	var combat := FakeCombat.new()
	var wall := _make([_row("w", 2, Vector3(0, 1.5, 0), Vector3(2, 3, 6))], {"combat": combat})
	var inside: Array[FakeEnemy] = []
	for at in [Vector3(0.2, 1, 0.3), Vector3(0.5, 1, -0.4), Vector3(1.0, 1, 0.2), Vector3(1.4, 1, -0.8), Vector3(0.8, 1, 1.0)]:
		inside.append(_enemy(at))
	var behind := _enemy(Vector3(-2.8, 1, 0.0))
	var far := _enemy(Vector3(6.0, 1, 0.0))
	var side := _enemy(Vector3(-1.0, 1, 2.3))
	_roll(wall, -3.0, -0.5, CRUISE, 2)
	t.eq("T4: the wall broke", wall.state_of("w"), "shattered")
	var struck := 0
	var knocked := 0
	for e in inside:
		struck += combat.strikes.filter(func(s: Dictionary) -> bool: return s["enemy"] == e).size()
		knocked += e.knocks
	t.eq("T4: at most 3 enemies are struck of the 5 in the cone", combat.strikes.size(), 3)
	t.eq("T4: each struck enemy is knocked once", knocked, 3)
	t.eq("T4: no enemy is struck twice", struck, 3)
	t.check("T4: every strike is the debris kind with a debris source", combat.strikes.all(func(s: Dictionary) -> bool: return s["kind"] == "debris" and String(s["source"]).begins_with("debris:")), "")
	t.eq("T4: shrapnel hits are counted", wall.shrapnel_hits(), 3)
	t.check("T4: nothing behind, beside or far from the break is hit", behind.knocks == 0 and far.knocks == 0 and side.knocks == 0, "")
	var nearest := inside.duplicate()
	nearest.sort_custom(func(a: FakeEnemy, b: FakeEnemy) -> bool: return a.position.distance_to(Vector3(-1, 1, 0)) < b.position.distance_to(Vector3(-1, 1, 0)))
	t.check("T4: the three struck are the three nearest", nearest.slice(0, 3).all(func(e: FakeEnemy) -> bool: return e.knocks == 1), "")
	t.check("T4: every push goes outward, along the ball's travel", inside.all(func(e: FakeEnemy) -> bool: return e.knocks == 0 or e.last_push.x > 0.0), "")
	var again := combat.strikes.size()
	wall.on_ball(Vector3(-3, 1, 0), Vector3(CRUISE, 0, 0), 5, DT)
	t.eq("T4: a shattered piece strikes no more", combat.strikes.size(), again)
	var force0: float = combat.strikes[0]["force"]
	t.near("T4: force is base x tier scale x speed share", force0, Destructibles.BASE_FORCE * 0.7 * 1.0, 0.001)
	# A blast is radial: the enemy behind the piece is struck too.
	var blast_combat := FakeCombat.new()
	var blast := _make([_row("b", 2, Vector3(0, 1.5, 0), Vector3(2, 3, 6))], {"combat": blast_combat})
	blast.on_blast(Vector3(-5, 1, 0), 6.0, "redline")
	var radial_hit := blast_combat.strikes.size()
	t.check("T4: a blast's shrapnel is radial and finds the enemies about the break point", radial_hit >= 1 and radial_hit <= 3, "%d struck" % radial_hit)
	for e in inside + [behind, far, side]:
		e.free()
	_drop(wall)
	_drop(blast)
	# With no enemies callable the module finds the "enemy" group in the tree.
	var grouped := FakeCombat.new()
	var wild := Destructibles.new()
	wild.build([_row("g", 2, Vector3(0, 1.5, 0), Vector3(2, 3, 6))], {"root": root, "cruise": CRUISE, "combat": grouped, "scrap": FakeScrap.new()})
	wild.finish_build()
	var lone := _enemy(Vector3(0.5, 1, 0))
	wild.on_blast(Vector3(-4, 1, 0), 8.0, "test", 1, 2)
	t.eq("T4: with no finder given, the enemy group is read", grouped.strikes.size(), 1)
	lone.free()
	_drop(wild)


# ---- T5: the loot cap ---------------------------------------------------------------------------

func _stage_rows() -> Array:
	var rows: Array = []
	var tiers := [1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 5, 5]
	for i in tiers.size():
		rows.append(_row("p%02d" % i, tiers[i], Vector3(0, 1.5, 12.0 * i), Vector3(2, 3, 6)))
	return rows


func _break_all(mod: Node3D, order: Array = []) -> void:
	var ids: Array = order if not order.is_empty() else mod.ids()
	for id in ids:
		var at: Vector3 = Vector3(0, 1.5, 12.0 * int(String(id).substr(1)))
		mod.on_blast(at + Vector3(-3, -0.5, 0), 5.0, "test", 1, 5)


func _loot_cap() -> void:
	var scrap := FakeScrap.new()
	var combat := FakeCombat.new()
	var mod := _make(_stage_rows(), {"scrap": scrap, "combat": combat})
	# One enemy by the last piece, to see a post-cap break still strike.
	var lone := _enemy(Vector3(1.0, 1, 12.0 * 19))
	_break_all(mod)
	t.eq("T5: every piece broke", mod.intact_count(), 0)
	var loot: Dictionary = mod.loot()
	t.check("T5: the stage paid at most 35 scrap", loot["scrap"] <= 35 and scrap.scrap_sum() == loot["scrap"], "%d (field saw %d)" % [loot["scrap"], scrap.scrap_sum()])
	t.check("T5: and at most 20 cogs", loot["cogs"] <= 20 and scrap.cog_sum() == loot["cogs"], "%d (field saw %d)" % [loot["cogs"], scrap.cog_sum()])
	t.eq("T5: the meter filled to 35 exactly by clamping a partial drop", loot["scrap"], 35)
	t.eq("T5: and to 20 cogs exactly", loot["cogs"], 20)
	t.check("T5: the field was called only while there was room", scrap.scrap.size() < 20 and not scrap.scrap.has(0), "%d drops for 20 pieces" % scrap.scrap.size())
	t.check("T5: the last piece broke after the cap and still struck the enemy beside it", combat.strikes.any(func(s: Dictionary) -> bool: return s["enemy"] == lone and s["source"] == "debris:p19"), "%d strikes" % combat.strikes.size())
	t.check("T5: a piece pays at most its tier's table", scrap.scrap.all(func(a: int) -> bool: return a <= 4) and scrap.cogs.all(func(a: int) -> bool: return a <= 2), "")
	# After the cap: one more piece shatters, pays nothing.
	lone.free()
	_drop(mod)

	# The cap is reached in order, with the last paying drop clamped to the room.
	var rows := [_row("p00", 4, Vector3(0, 1.5, 0)), _row("p01", 4, Vector3(0, 1.5, 12)), _row("p02", 4, Vector3(0, 1.5, 24))]
	var small_scrap := FakeScrap.new()
	var small_combat := FakeCombat.new()
	var small := _make(rows, {"scrap": small_scrap, "combat": small_combat, "scrap_cap": 6, "cog_cap": 3})
	var beside := _enemy(Vector3(1.0, 1, 24))
	_break_all(small)
	t.check("T5: the third piece, broken with the meter full, still strikes the enemy beside it", small_combat.strikes.any(func(s: Dictionary) -> bool: return s["enemy"] == beside and s["source"] == "debris:p02"), "")
	beside.free()
	t.eq("T5: three tier 4 pieces against a cap of 6 pay 4, then the 2 that fit, then nothing", small_scrap.scrap, [4, 2] as Array[int])
	t.eq("T5: and against 3 cogs pay 2, 1", small_scrap.cogs, [2, 1] as Array[int])
	t.eq("T5: all three still shattered", small.intact_count(), 0)
	_drop(small)

	# Planted controls: a cap of 0 pays nothing; a cap of 100 passes the 35 the cap check demands.
	var zero_scrap := FakeScrap.new()
	var zero := _make(_stage_rows(), {"scrap": zero_scrap, "scrap_cap": 0, "cog_cap": 0})
	_break_all(zero)
	t.check("T5 control: a cap of 0 pays 0 scrap and 0 cogs and calls the field never", zero.loot() == {"scrap": 0, "cogs": 0} and zero_scrap.scrap.is_empty() and zero_scrap.cogs.is_empty(), "")
	t.eq("T5 control: and every piece still broke", zero.intact_count(), 0)
	var wide_scrap := FakeScrap.new()
	var wide := _make(_stage_rows(), {"scrap": wide_scrap, "scrap_cap": 100, "cog_cap": 100})
	_break_all(wide)
	t.check("T5 control: a cap of 100 exceeds 35 scrap and 20 cogs, which the cap check would fail", wide.loot()["scrap"] > 35 and wide.loot()["cogs"] > 20,
		"%d scrap, %d cogs" % [wide.loot()["scrap"], wide.loot()["cogs"]])
	_drop(zero)
	_drop(wide)

	# Tier 1 is a 50 percent roll on the piece's own stream; the tables for the others are exact.
	var ones: Array = []
	for i in 40:
		ones.append(_row("p%02d" % i, 1, Vector3(0, 1.5, 12.0 * i), Vector3(1, 1, 1)))
	var one_scrap := FakeScrap.new()
	var one := _make(ones, {"scrap": one_scrap, "scrap_cap": 100})
	_break_all(one)
	var paid: int = one.loot()["scrap"]
	t.check("T5: tier 1 pays 0 or 1 scrap about half the time and never a cog", paid > 8 and paid < 32 and one.loot()["cogs"] == 0, "%d of 40" % paid)
	_drop(one)
	for tier in [2, 3, 4, 5]:
		var f := FakeScrap.new()
		var m := _make([_row("p00", tier, Vector3(0, 1.5, 0))], {"scrap": f})
		_break_all(m)
		var want: Array = [[2, 1], [3, 2], [4, 2], [4, 2]][tier - 2]
		t.check("T5: tier %d pays %d scrap and %d cogs" % [tier, want[0], want[1]], f.scrap_sum() == want[0] and f.cog_sum() == want[1], "%d, %d" % [f.scrap_sum(), f.cog_sum()])
		_drop(m)


# ---- T6: RNG isolation --------------------------------------------------------------------------

func _rng_isolation() -> void:
	var panel := RandomNumberGenerator.new()
	panel.seed = 424242
	var expect := RandomNumberGenerator.new()
	expect.seed = 424242
	var want: Array[float] = []
	for i in 8:
		want.append(expect.randf())
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 99
	var run_state := run_rng.state
	var mod := _make(_stage_rows(), {"scrap_cap": 100, "cog_cap": 100, "run_seed": null, "rng": run_rng})
	_break_all(mod)
	var got: Array[float] = []
	for i in 8:
		got.append(panel.randf())
	t.eq("T6: after every piece breaks the next panel roll is byte-identical", got, want)
	t.eq("T6: the run's own stream was only read for its seed", run_rng.state, run_state)
	_drop(mod)
	# Planted control: a drop drawn from the shared stream changes the roll.
	var shared := RandomNumberGenerator.new()
	shared.seed = 424242
	var leaky := FakeScrap.new()
	leaky.shared = shared
	var bad := _make(_stage_rows(), {"scrap": leaky, "scrap_cap": 100})
	_break_all(bad)
	var moved: Array[float] = []
	for i in 8:
		moved.append(shared.randf())
	t.check("T6 control: drawing from a shared stream changes the next roll", moved != want, "")
	_drop(bad)
	# A piece's loot does not depend on the order the others broke in.
	var fwd := FakeScrap.new()
	var back := FakeScrap.new()
	var a := _make(_stage_rows(), {"scrap": fwd, "scrap_cap": 1000, "cog_cap": 1000})
	var b := _make(_stage_rows(), {"scrap": back, "scrap_cap": 1000, "cog_cap": 1000})
	var ids: Array = a.ids()
	_break_all(a, ids)
	var rev: Array = ids.duplicate()
	rev.reverse()
	_break_all(b, rev)
	t.check("T6: a piece's roll is its own, so break order moves no total", a.loot() == b.loot(), "%s vs %s" % [a.loot(), b.loot()])
	_drop(a)
	_drop(b)
	# Another run id rolls differently, the same one rolls the same.
	var ones: Array = []
	for i in 60:
		ones.append(_row("p%02d" % i, 1, Vector3(0, 1.5, 12.0 * i), Vector3(1, 1, 1)))
	var totals: Array[int] = []
	for run_id in ["bot-1", "bot-1", "bot-2"]:
		var m := _make(ones, {"run_id": run_id, "scrap_cap": 1000})
		_break_all(m)
		totals.append(m.loot()["scrap"])
		_drop(m)
	t.check("T6: one run id rolls the same, another may differ", totals[0] == totals[1], str(totals))


# ---- T12: teardown and determinism --------------------------------------------------------------

func _signature(mod: Node3D) -> Dictionary:
	var colliders := []
	for id in mod.ids():
		var body: StaticBody3D = mod.body_of(id)
		colliders.append([id, mod.state_of(id), body.collision_layer])
	return {"order": mod.break_order(), "loot": mod.loot(), "hits": mod.shrapnel_hits(), "colliders": colliders}


func _scenario(extra: Dictionary) -> Dictionary:
	var combat := FakeCombat.new()
	var scrap := FakeScrap.new()
	var mod := _make(_stage_rows(), {"combat": combat, "scrap": scrap}.merged(extra, true))
	var enemies: Array[FakeEnemy] = []
	for i in [3, 9, 15]:
		enemies.append(_enemy(Vector3(0.5, 1, 12.0 * i)))
	# One ball down the line of pieces, at cruise, Class IV.
	for i in 20:
		var z := 12.0 * i
		var x := -6.0
		mod.on_ball(Vector3(1000.0, 1, z), Vector3.ZERO, 4, DT)
		while x < 0.0:
			mod.on_ball(Vector3(x, 1, z), Vector3(CRUISE, 0, 0), 4, DT)
			x += CRUISE * DT
	var sig := _signature(mod)
	sig["strikes"] = combat.strikes.map(func(s: Dictionary) -> String: return "%s:%s:%.3f" % [s["kind"], s["source"], s["force"]])
	sig["drops"] = scrap.scrap
	sig["visual_nodes"] = mod.pool_nodes().size() + mod.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D).size()
	for e in enemies:
		e.free()
	_drop(mod)
	return sig


func _teardown_and_determinism() -> void:
	await process_frame
	await process_frame
	var base := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mod := Destructibles.new()
	mod.build(_stage_rows(), _ctx())
	t.check("T12: build hands back with its visuals still queued", not mod.is_built(), "")
	t.eq("T12: but every collider is already built", _count_bodies(mod), 20)
	mod.finish_build()
	t.check("T12: finish_build completes the slices", mod.is_built() and mod.pool_nodes().size() == 32, "%d pooled" % mod.pool_nodes().size())
	var bodies: Array[StaticBody3D] = []
	for id in mod.ids():
		bodies.append(mod.body_of(id))
	var pooled := mod.pool_nodes()
	mod.on_blast(Vector3(-3, 1, 0), 40.0, "test", 1, 5)
	t.check("T12: an intact piece is one layer-1 body, a shattered one is on no layer", bodies[19].collision_layer == 1 and bodies[0].collision_layer == 0 and bodies[0].has_meta("destructible_id"), "")
	await process_frame
	var disabled := true
	for i in 4:
		disabled = disabled and (bodies[i].get_child(0) as CollisionShape3D).disabled
	t.check("T12: a shattered piece's shape is disabled (not parked 400 m away)", disabled and bodies[0].position.y < 100.0 and bodies[0].position.y > -1.0, "y %.1f" % bodies[0].position.y)
	t.eq("T12: a shattered piece's collider leaves layer 1", bodies[0].collision_layer, 0)
	mod.teardown()
	await process_frame
	await process_frame
	t.eq("T12: teardown leaves the module with no child", mod.get_child_count(), 0)
	var gone := true
	for b in bodies:
		gone = gone and not is_instance_valid(b)
	for n in pooled:
		gone = gone and not is_instance_valid(n)
	t.check("T12: every body, shard and puff is freed", gone, "")
	t.eq("T12: no piece is left in the registry", mod.ids().size(), 0)
	mod.on_ball(Vector3(-3, 1, 0), Vector3(CRUISE, 0, 0), 5, DT)
	mod.on_blast(Vector3.ZERO, 50.0, "late")
	t.check("T12: a torn-down module ignores the ball and blasts", mod.break_order().is_empty() and mod.loot() == {"scrap": 0, "cogs": 0}, "")
	mod.queue_free()
	await process_frame
	await process_frame
	t.eq("T12: the node count is where it began", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), base)

	# Leaving the tree is a teardown too.
	var leaving := Destructibles.new()
	leaving.build(_stage_rows(), _ctx())
	leaving.finish_build()
	leaving.on_blast(Vector3(-3, 1, 0), 40.0, "test", 1, 5)
	leaving.queue_free()
	await process_frame
	await process_frame
	t.eq("T12: freeing the module frees its bodies and shards with it", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), base)
	t.eq("T12: no orphan node is left", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 0.0)

	# Two seeded runs of one ball path break the same pieces in the same order for the same pay.
	var one := _scenario({})
	var two := _scenario({})
	t.eq("T12: two seeded runs break in the same order", one["order"], two["order"])
	t.check("T12: and pay the same loot, drops, strikes and hits", one["loot"] == two["loot"] and one["drops"] == two["drops"] and one["strikes"] == two["strikes"] and one["hits"] == two["hits"], str(one["loot"]))
	t.check("T12: the run broke pieces at all", one["order"].size() == 18 and one["hits"] > 0, "%d broke, %d hits" % [one["order"].size(), one["hits"]])
	var other := _scenario({"run_id": "bot-77"})
	t.eq("T12: another run id breaks the same pieces", other["order"], one["order"])
	# --bot-no-visuals=1 keeps every logic fact and skips the shards.
	var bare := _scenario({"no_visuals": true})
	t.check("T12: no-visuals keeps the break order, loot, colliders, drops, strikes and hits", bare["order"] == one["order"] and bare["loot"] == one["loot"] and bare["colliders"] == one["colliders"]
		and bare["drops"] == one["drops"] and bare["strikes"] == one["strikes"] and bare["hits"] == one["hits"], "")
	t.check("T12: no-visuals builds no mesh and no shard", int(bare["visual_nodes"]) == 0 and int(one["visual_nodes"]) > 0, "%d vs %d" % [bare["visual_nodes"], one["visual_nodes"]])
	# Planted control: a leaked shard is seen by the same node-count check.
	var leak := Node3D.new()
	leak.name = "LeakedShard"
	root.add_child(leak)
	await process_frame
	t.check("T12 control: a leaked node moves the node count", Performance.get_monitor(Performance.OBJECT_NODE_COUNT) != base, "")
	leak.free()
	await process_frame
	t.eq("T12: the stage ends where it began", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), base)
	# The piece_shattered signal and the oriented box.
	var sig_mod := _make([_row("y", 2, Vector3(10, 1.5, 0), Vector3(2, 3, 6), {"yaw_deg": 90.0})])
	var seen: Array[AABB] = []
	sig_mod.piece_shattered.connect(func(b: AABB) -> void: seen.append(b))
	t.check("T12: a yawed 2 x 6 box is 6 long in x", is_equal_approx(sig_mod.bounds_of("y").size.x, 6.0) and is_equal_approx(sig_mod.bounds_of("y").size.z, 2.0), str(sig_mod.bounds_of("y")))
	t.check("T12: contains_point follows the yaw", sig_mod.contains_point("y", Vector3(12.5, 1.5, 0.0)) and not sig_mod.contains_point("y", Vector3(10.0, 1.5, 2.5)), "")
	t.check("T12: and a margin grows it", sig_mod.contains_point("y", Vector3(10.0, 1.5, 1.25), 0.25) and not sig_mod.contains_point("y", Vector3(10.0, 1.5, 1.25)), "")
	sig_mod.on_blast(Vector3(10, 1, 0), 2.0, "test", 1, 2)
	t.check("T12: piece_shattered fires once with the piece's world box", seen.size() == 1 and seen[0] == sig_mod.bounds_of("y"), str(seen))
	t.check("T12: a shattered piece still answers contains_point for line release", sig_mod.contains_point("y", Vector3(10, 1.5, 0)), "")
	_drop(sig_mod)


func _count_bodies(mod: Node3D) -> int:
	var n := 0
	for child in mod.get_children():
		if child is StaticBody3D:
			n += 1
	return n
