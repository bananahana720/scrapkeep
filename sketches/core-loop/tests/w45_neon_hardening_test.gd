extends SceneTree

# World 1 Hardening Unit P6 (Gemini 4 Neon Audit 1 + Fable 5.2 review fixes): real live
# checks + planted controls covering all 7 fixes, evidence-tool cue_log_total/cues_since,
# and Sticky.is_idle() seam:
#   1. TarnClaw world-drag advances drag["at"] to shape["to"] with 0 live enemies.
#   2. Indicator bounds last_shape at LAST_SHAPE_CAP, clears it on clear_all(), and skips
#      ImmediateMesh rebuilds on static frames while preserving breathing frames.
#   3. Bolts strips hoar/hoar_spared on split_children without aliasing, guards zero-length
#      dir in both fire() and instance(), and preserves offset weak-point hits on slow bolts
#      whose origin is outside body-only broad-phase reach.
#   4. ElementField pools wedge/torus meshes and unshaded materials (with verified world-space
#      cone orientation), caps _puffs (MAX_PUFFS) and _shards (MAX_SHARDS, preserving earlier
#      bursts), and keeps detonate_crossed_slabs accurate with AABB early-out.
#   5. Sticky.is_idle() tracks both live charges and evicted payloads; KestKit uses is_idle()
#      (no private reach), drains evicted payloads cleanly, and clears/caps roll_log & volley_log.
#   6. Destructibles skips dead enemies mid-_shrapnel, reads live tuning.f("cruise"), and
#      respects build.scrapless() in _pay().
#   7. Audio & Juice cap logs at LOG_CAP (2048) under 2,500 rapid events; Audio tracks monotonic
#      cue_log_total, slices accurately via cues_since(mark) across the 2048 wrap, supports
#      uncapped cue_log_cap = 0, and clears _posture_seen/_guard_steps/_guard_warned on
#      stage_entered and run_started.
# Evidence limit: rules, state, pooling identity and caps in headless Godot, not visual/audio feel.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Devices := preload("res://src/core/devices.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Sticky := preload("res://src/combat/sticky.gd")
const ElementField := preload("res://src/build/element_field.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const TarnClaw := preload("res://src/combat/tarn_claw.gd")
const KestKit := preload("res://src/combat/kest_kit.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Juice := preload("res://src/presentation/juice.gd")
const Audio := preload("res://src/presentation/audio.gd")
const T := preload("res://tests/support/t.gd")

const DT := 1.0 / 60.0
const EXPECTED_CHECKS := 33

var _t := T.new("w45_neon_hardening_test")
var _game
var _source := Intent.Scripted.new()
var _started := false
var _done := false


class FakeTuning extends RefCounted:
	var cruise := 10.0
	func f(key: String) -> float:
		return cruise if key == "cruise" else 0.0


class FakeBuild extends RefCounted:
	var is_scrapless := false
	func scrapless() -> bool:
		return is_scrapless


class FakeScrap extends RefCounted:
	var drops := 0
	var cogs := 0
	func drop(_at: Vector3, amount: int, _rng = null) -> void:
		drops += amount
	func drop_cogs(_at: Vector3, amount: int) -> void:
		cogs += amount


class FakeEnemy extends Node3D:
	var dead := false
	var knocks := 0
	var radius := 0.8
	var half_height := 1.0
	var weak: Array = []
	func is_dead() -> bool:
		return dead
	func knock(_dir: Vector3, _force: float) -> void:
		knocks += 1
	func weak_points() -> Array:
		return weak


class FakeCombat extends RefCounted:
	var struck: Array = []
	var kill_on_first: FakeEnemy = null
	func strike(enemy: Object, _kind: String, _force: float, _part := "", _source := "") -> void:
		struck.append(enemy)
		if kill_on_first != null and is_instance_valid(kill_on_first):
			kill_on_first.dead = true
			kill_on_first = null


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _done:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = _source
		_game.flow.press_start()
		var tarn_idx := 0
		var classes := ClassDef.all()
		for i in classes.size():
			if String(classes[i].id) == "tarn":
				tarn_idx = i
				break
		_game.flow.choose_class(tarn_idx)
		return false
	_done = true
	_check_tarn_world_drag()
	_check_indicator()
	_check_bolts()
	_check_element_field()
	_check_kest_kit()
	_check_destructibles()
	_check_audio_and_juice()
	if _t.checks != EXPECTED_CHECKS:
		_t.check("check count guard", false, "ran %d of %d expected checks" % [_t.checks, EXPECTED_CHECKS])
	var code := _t.verdict()
	_game.free()
	quit(code)
	return true


# --- 1. Tarn world-drag indentation fix ---------------------------------------------------

func _check_tarn_world_drag() -> void:
	# Clear any live enemies so we explicitly test 0 enemies alive.
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.free()
	var claw = _game.combat.get_node_or_null("TarnClaw")
	_t.check("tarn claw node exists", claw != null and get_nodes_in_group("enemy").is_empty(),
		"claw=%s enemies=%d" % [claw != null, get_nodes_in_group("enemy").size()])
	if claw == null:
		return
	var ball: Vector3 = _game.player.ball_position()
	var anchor := ball + Vector3.FORWARD * 15.0
	_game.player.grapple_to(anchor, Vector3.UP, null)
	claw.on_world(anchor, 1.0, 1.0)
	var moved := false
	var elapsed := 0.0
	for _i in 120:
		claw.step(DT)
		elapsed += DT
		if not claw.drag.is_empty():
			var at: Vector3 = claw.drag["at"]
			if at.distance_to(anchor) > 1.0:
				moved = true
		else:
			break
	_t.check("tarn world-drag advances and finishes before timeout with 0 enemies",
		moved and claw.drag.is_empty() and elapsed < 1.0,
		"moved=%s finished=%s elapsed=%.3fs" % [moved, claw.drag.is_empty(), elapsed])
	# Planted control: anchor 100 m out (beyond 30 m/s * 1.5 s = 45 m) cannot arrive early and times out.
	var far_anchor := ball + Vector3.FORWARD * 100.0
	_game.player.grapple_to(far_anchor, Vector3.UP, null)
	claw.on_world(far_anchor, 1.0, 1.0)
	var far_elapsed := 0.0
	for _i in 120:
		claw.step(DT)
		far_elapsed += DT
		if claw.drag.is_empty():
			break
	_t.check("planted control: out-of-range world-drag hits 1.5s timeout",
		claw.drag.is_empty() and far_elapsed > 1.5,
		"finished=%s elapsed=%.3fs" % [claw.drag.is_empty(), far_elapsed])
	_game.player.release_grapple()


# --- 2. Indicator bounded last_shape & dirty flag ----------------------------------------

func _check_indicator() -> void:
	var ind := Indicator.new()
	root.add_child(ind)
	for i in 200:
		var layer := "verb_strip_%d" % i
		ind.set_shape(layer, {"kind": "line", "from": Vector3.ZERO, "to": Vector3.FORWARD * 4.0, "width": 1.0, "fill": 0.5})
		ind.clear(layer)
	_t.check("indicator last_shape stays bounded after 200 monotonic layers",
		ind.last_shape.size() <= Indicator.LAST_SHAPE_CAP and ind.last_shape.has("verb_strip_199") and not ind.last_shape.has("verb_strip_0"),
		"size=%d cap=%d has_newest=%s has_oldest=%s" % [ind.last_shape.size(), Indicator.LAST_SHAPE_CAP,
			ind.last_shape.has("verb_strip_199"), ind.last_shape.has("verb_strip_0")])
	ind.clear_all()
	_t.eq("indicator clear_all empties last_shape", ind.last_shape.size(), 0)
	# Dirty flag: static shape (fill < 1.0) rebuilds once, then 0 times on static frames.
	ind._process(DT)
	var before: int = int(ind.get("_rebuild_count"))
	ind.set_shape("static_ring", {"kind": "ring", "centre": Vector3.ZERO, "radius": 3.0, "fill": 0.5})
	ind._process(DT)
	var after_set: int = int(ind.get("_rebuild_count"))
	for _i in 10:
		ind._process(DT)
	var after_static: int = int(ind.get("_rebuild_count"))
	_t.check("indicator dirty flag skips redundant rebuilds on static frames",
		after_set == before + 1 and after_static == after_set,
		"before=%d after_set=%d after_10_static=%d" % [before, after_set, after_static])
	# Planted control: breathing shape (fill >= 1.0, not blocked) still animates every frame.
	ind.set_shape("static_ring", {"kind": "ring", "centre": Vector3.ZERO, "radius": 3.0, "fill": 1.0})
	for _i in 3:
		ind._process(DT)
	var after_breathe: int = int(ind.get("_rebuild_count"))
	_t.eq("planted control: breathing shape rebuilds each frame", after_breathe, after_static + 3)
	ind.clear("static_ring")
	ind._process(DT)
	var after_clear: int = int(ind.get("_rebuild_count"))
	for _i in 5:
		ind._process(DT)
	_t.eq("cleared idle indicator stops rebuilding", int(ind.get("_rebuild_count")), after_clear)
	ind.free()


# --- 3. Bolts split_children Hoar strip, broad-phase & zero-dir guard --------------------

func _check_bolts() -> void:
	var spared := [42]
	var parent := {
		"dir": Vector3.FORWARD, "max_dist": 30.0, "damage": 12.0,
		"bits": ShotBits.bit("split") | ShotBits.bit("pierce"), "spent": 0,
		"knock": 4.0, "exclude": [11], "hoar": true, "hoar_spared": spared,
	}
	var kids: Array = Bolts.split_children(parent, Vector3.ZERO, 99, 2.0)
	_t.check("Bolts.split_children strips hoar and hoar_spared",
		kids.size() == 2 and kids.all(func(k): return not k.has("hoar") and not k.has("hoar_spared")),
		"count=%d kids=%s" % [kids.size(), kids.map(func(k): return [k.has("hoar"), k.has("hoar_spared")])])
	spared.append(99)
	(kids[0]["exclude"] as Array).append(777)
	_t.check("parent keeps hoar_spared and split children do not alias parent or sibling arrays",
		bool(parent.get("hoar", false)) and parent["hoar_spared"] == [42, 99]
		and not kids[0].has("hoar_spared") and not (kids[1]["exclude"] as Array).has(777)
		and not (parent["exclude"] as Array).has(777),
		"parent_spared=%s kid0_excl=%s kid1_excl=%s" % [parent["hoar_spared"], kids[0]["exclude"], kids[1]["exclude"]])
	# Zero-dir guard in instance(): finite non-degenerate basis + origin offset along Vector3.FORWARD.
	var shown := Vector3(1.0, 2.0, 3.0)
	var zero_bolt := {"dir": Vector3.ZERO, "speed": 40.0, "travelled": 5.0, "shown": shown, "color": Color.WHITE, "bits": 0}
	var xf_zero: Transform3D = Bolts.instance(zero_bolt, 1.0)[0]
	var right_bolt := zero_bolt.duplicate()
	right_bolt["dir"] = Vector3.RIGHT
	var xf_right: Transform3D = Bolts.instance(right_bolt, 1.0)[0]
	var want_streak := minf(maxf(Bolts.MIN_STREAK, 40.0 * Bolts.STREAK_SECONDS), 5.0)
	var want_origin := shown - Vector3.FORWARD * want_streak * 0.5
	_t.check("Bolts.instance handles zero-length dir with finite non-degenerate FORWARD fallback",
		xf_zero.is_finite() and absf(xf_zero.basis.determinant()) > 1e-6
		and xf_zero.origin.distance_to(want_origin) < 0.001
		and not is_equal_approx(xf_zero.basis.z.normalized().dot(xf_right.basis.z.normalized()), 1.0),
		"det=%.6f origin=%s want=%s" % [xf_zero.basis.determinant(), xf_zero.origin, want_origin])
	# Dedicated Bolts.fire() zero-dir guard: normalizes to Vector3.FORWARD with unit orthonormal axes and advances on step().
	var bolts := Bolts.new()
	root.add_child(bolts)
	bolts.setup()
	bolts.fire({"origin": Vector3(0.0, 2.0, 0.0), "dir": Vector3.ZERO, "speed": 30.0, "max_dist": 10.0,
		"damage": 10.0, "kind": "kinetic", "weapon_id": "test", "radius": 0.25, "knock": 0.0,
		"chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0, "color": Color.WHITE,
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": 0})
	var stored: Dictionary = (bolts.get("_bolts") as Array)[0]
	var stored_dir: Vector3 = stored["dir"]
	var stored_right: Vector3 = stored["right"]
	var stored_up: Vector3 = stored["up"]
	bolts.step(DT, _game.get_world_3d().direct_space_state, [])
	var moved_to: Vector3 = stored["shown"]
	_t.check("Bolts.fire guards zero-length dir with unit orthonormal axes and forward travel",
		stored_dir == Vector3.FORWARD and stored_right.is_finite() and stored_up.is_finite()
		and is_equal_approx(stored_right.length(), 1.0) and is_equal_approx(stored_up.length(), 1.0)
		and absf(stored_right.dot(stored_up)) < 1e-5 and moved_to.distance_to(Vector3(0.0, 2.0, -0.5)) < 0.01,
		"dir=%s right=%s up=%s moved_to=%s" % [stored_dir, stored_right, stored_up, moved_to])
	bolts.clear()
	# Broad-phase weak point safety with a SLOW bolt (0.5 m per tick):
	# Enemy body sits at (0, 2, -10) (radius 0.8, inner 0.2 -> naive body-only cutoff = 0.5 + 0.8 + 0.25 + 0.2 + 0.5 = 2.25 m).
	# Weak point sits 5 m right at (5, 2, -10), and bolt starts at (5, 2, -9.8) (distance to body centre = 5.004 m > 2.25 m!).
	var near_enemy := FakeEnemy.new()
	root.add_child(near_enemy)
	near_enemy.global_position = Vector3(0.0, 2.0, -10.0)
	near_enemy.weak = [{"id": "turret", "at": Vector3(5.0, 2.0, -10.0), "radius": 0.6}]
	var far_enemy := FakeEnemy.new()
	root.add_child(far_enemy)
	far_enemy.global_position = Vector3(0.0, 2.0, -250.0)
	far_enemy.weak = [{"id": "far_wp", "at": Vector3(0.0, 2.0, -250.0), "radius": 0.6}]
	var hit_parts: Array = []
	bolts.on_hit = func(_b: Dictionary, enemy: Node3D, _pt: Vector3, part: String) -> void:
		hit_parts.append([enemy, part])
		enemy.dead = true
	var slow_origin := Vector3(5.0, 2.0, -9.8)
	var body_dist := slow_origin.distance_to(near_enemy.global_position)
	var naive_body_cutoff := 30.0 * DT + near_enemy.radius + 0.25 + maxf(0.0, near_enemy.half_height - near_enemy.radius) + 0.5
	for _k in 2:
		bolts.fire({"origin": slow_origin, "dir": Vector3.FORWARD, "speed": 30.0, "max_dist": 10.0,
			"damage": 10.0, "kind": "kinetic", "weapon_id": "test", "radius": 0.25, "knock": 0.0,
			"chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0, "color": Color.WHITE,
			"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": 0})
	bolts.step(DT, _game.get_world_3d().direct_space_state, [far_enemy, near_enemy])
	_t.check("broad-phase hits slow-bolt offset weak point beyond body cutoff and skips killed enemy",
		body_dist > naive_body_cutoff and hit_parts.size() == 1 and hit_parts[0][0] == near_enemy and hit_parts[0][1] == "turret",
		"body_dist=%.2f naive_cutoff=%.2f hits=%s" % [body_dist, naive_body_cutoff, hit_parts])
	near_enemy.free()
	far_enemy.free()
	bolts.free()


# --- 4. ElementField pooling, caps & AABB early-out --------------------------------------

func _check_element_field() -> void:
	var field := ElementField.new()
	root.add_child(field)
	field.setup(null)
	for i in 100:
		field.flash_ring(Vector3(float(i), 0.0, 0.0), 2.5, ElementField.FROST)
	var puffs_after_rings: Array = field.get("_puffs")
	var r1: MeshInstance3D = puffs_after_rings[-2]["node"]
	var r2: MeshInstance3D = puffs_after_rings[-1]["node"]
	_t.check("ElementField enforces MAX_PUFFS on flash_ring",
		puffs_after_rings.size() == ElementField.MAX_PUFFS,
		"puffs=%d cap=%d" % [puffs_after_rings.size(), ElementField.MAX_PUFFS])
	_t.check("ElementField shares lighter TorusMesh (24x8) and material across flash_rings",
		is_same(r1.mesh, r2.mesh) and is_same(r1.material_override, r2.material_override)
		and (r1.mesh as TorusMesh).rings == 24 and (r1.mesh as TorusMesh).ring_segments == 8,
		"same_mesh=%s same_mat=%s rings=%d segs=%d" % [is_same(r1.mesh, r2.mesh), is_same(r1.material_override, r2.material_override),
			(r1.mesh as TorusMesh).rings, (r1.mesh as TorusMesh).ring_segments])
	# Cones share mesh and material, respect MAX_PUFFS, and aim world-space forward along diagonal dir.
	var diag := Vector3(1.0, 0.0, 1.0).normalized()
	var c1: MeshInstance3D = field._draw_cone({"at": Vector3.ZERO, "dir": Vector3.FORWARD, "length": ElementField.SHARD_CONE_LENGTH, "half_angle": deg_to_rad(ElementField.SHARD_CONE_DEG)})
	var c2: MeshInstance3D = field._draw_cone({"at": Vector3.RIGHT * 3.0, "dir": diag, "length": ElementField.SHARD_CONE_LENGTH, "half_angle": deg_to_rad(ElementField.SHARD_CONE_DEG)})
	var world_dir_c2 := (c2.global_transform.basis * Vector3.FORWARD).normalized()
	_t.check("ElementField shares wedge ArrayMesh and material and aims world forward along dir",
		is_same(c1.mesh, c2.mesh) and is_same(c1.material_override, c2.material_override)
		and (field.get("_puffs") as Array).size() == ElementField.MAX_PUFFS
		and world_dir_c2.distance_to(diag) < 0.001,
		"same_mesh=%s same_mat=%s puffs=%d world_dir=%s want=%s" % [is_same(c1.mesh, c2.mesh), is_same(c1.material_override, c2.material_override),
			(field.get("_puffs") as Array).size(), world_dir_c2, diag])
	# Shards capped at MAX_SHARDS under 20 rapid bursts without freeing earlier bursts.
	field.shard_burst(Vector3.ZERO)
	var first_shard: Node3D = (field.get("_shards") as Array)[0]["node"]
	for i in range(1, 20):
		field.shard_burst(Vector3(float(i), 0.0, 0.0))
	var shards: Array = field.get("_shards")
	_t.check("ElementField enforces MAX_SHARDS by dropping overflow without freeing earlier bursts",
		shards.size() == ElementField.MAX_SHARDS and is_instance_valid(first_shard) and not first_shard.is_queued_for_deletion(),
		"shards=%d cap=%d first_alive=%s" % [shards.size(), ElementField.MAX_SHARDS, is_instance_valid(first_shard) and not first_shard.is_queued_for_deletion()])
	# AABB early-out in detonate_crossed_slabs: miss far slab, hit crossed slab.
	field.register_material("water", func(_p: Vector3) -> Dictionary: return {"surface_y": 0.0})
	field.apply("frost", Vector3(100.0, 0.0, 100.0), "test")
	var miss: Dictionary = field.detonate_crossed_slabs(Vector3.ZERO, Vector3(0.0, 0.0, -10.0), Vector3.FORWARD, Vector3(0.0, 0.0, -50.0), 1.0)
	var hit: Dictionary = field.detonate_crossed_slabs(Vector3(100.0, 0.5, 95.0), Vector3(100.0, 0.5, 105.0), Vector3.BACK, Vector3(0.0, 0.0, -50.0), 1.0)
	_t.check("detonate_crossed_slabs AABB early-out skips distant slab and detonates crossed slab",
		int(miss["detonated"]) == 0 and int(hit["detonated"]) == 1 and field.slab_count() == 0,
		"miss=%d hit=%d slabs=%d" % [int(miss["detonated"]), int(hit["detonated"]), field.slab_count()])
	field.clear()
	field.free()


# --- 5. Sticky.is_idle() seam & KestKit idle skip / log hygiene --------------------------

func _check_kest_kit() -> void:
	var kest = _game.combat.ultimate
	_t.check("ultimate is KestKit", kest is KestKit, str(kest))
	if not (kest is KestKit):
		return
	kest.roll_log.append({"at": 1.0, "index": 0})
	kest.volley_log.append({"beat": 1, "targets": 2, "centre": Vector3.ZERO})
	kest.clear_payloads()
	_t.check("KestKit.clear_payloads clears roll_log and volley_log",
		kest.roll_log.is_empty() and kest.volley_log.is_empty(),
		"roll=%d volley=%d" % [kest.roll_log.size(), kest.volley_log.size()])
	# Sticky.is_idle() transitions cleanly for live charges AND evicted charges with 0 live charges.
	var sticky := Sticky.new()
	root.add_child(sticky)
	var ledger := Devices.new()
	sticky.ledger = ledger
	var idle_start := sticky.is_idle()
	var cap: int = int(Devices.ROWS["mini"]["cap"])
	for i in cap + 1:
		sticky.drop(Vector3(float(i), 0.0, 0.0), 10.0, 2.0, 10.0, 10.0)
	var busy_live := not sticky.is_idle()
	for c in sticky.charges.duplicate():
		sticky.take(c)
	# charges is now empty, but the cap-evicted charge is still queued to detonate -> NOT idle!
	var busy_evicted := sticky.charges.is_empty() and not sticky.is_idle()
	var popped: Array = sticky.step(DT, null, [])
	var idle_after := sticky.is_idle()
	_t.check("Sticky.is_idle tracks live and evicted charges across cap eviction and drain",
		idle_start and busy_live and busy_evicted and popped.size() == 1 and idle_after,
		"start=%s live=%s evicted_busy=%s popped=%d after=%s" % [idle_start, busy_live, busy_evicted, popped.size(), idle_after])
	sticky.clear()
	sticky.free()
	# KestKit._step_payloads drains a pending evicted payload even when charges is empty.
	var evicted_charge := {"pos": _game.player.ball_position() + Vector3.RIGHT * 20.0, "damage": 10.0, "radius": 2.0, "crit": false, "mini": true}
	(kest.payloads.get("_evicted") as Array).append(evicted_charge)
	var kest_busy_before: bool = kest.payloads.charges.is_empty() and not kest.payloads.is_idle()
	kest._step_payloads(DT)
	_t.check("KestKit._step_payloads drains evicted payload when charges empty and returns to idle",
		kest_busy_before and kest.payloads.is_idle(),
		"busy_before=%s idle_after=%s" % [kest_busy_before, kest.payloads.is_idle()])


# --- 6. Destructibles dead-enemy guard, live cruise & scrapless --------------------------

func _check_destructibles() -> void:
	# (a) Dead-enemy guard mid-_shrapnel + planted control.
	var e1 := FakeEnemy.new()
	var e2 := FakeEnemy.new()
	root.add_child(e1)
	root.add_child(e2)
	e1.global_position = Vector3(0.0, 1.0, -1.0)
	e2.global_position = Vector3(0.0, 1.0, -1.8)
	var fc := FakeCombat.new()
	fc.kill_on_first = e2
	var mod := Destructibles.new()
	mod.build([{"id": "p1", "tier": 1, "at": [0.0, 1.0, 0.0], "size": [1.0, 2.0, 1.0]}],
		{"root": root, "no_visuals": true, "combat": fc, "enemies": func() -> Array: return [e1, e2]})
	mod.on_blast(Vector3.ZERO, 3.0, "test", 1, 1)
	_t.check("Destructibles._shrapnel skips enemy killed mid-loop",
		fc.struck == [e1] and e2.knocks == 0 and mod.shrapnel_hits() == 1,
		"struck=%d e2_knocks=%d hits=%d" % [fc.struck.size(), e2.knocks, mod.shrapnel_hits()])
	# Planted control: both enemies alive -> both struck.
	e2.dead = false
	fc.struck.clear()
	var mod_ctrl := Destructibles.new()
	mod_ctrl.build([{"id": "p2", "tier": 1, "at": [0.0, 1.0, 0.0], "size": [1.0, 2.0, 1.0]}],
		{"root": root, "no_visuals": true, "combat": fc, "enemies": func() -> Array: return [e1, e2]})
	mod_ctrl.on_blast(Vector3.ZERO, 3.0, "test", 1, 1)
	_t.check("planted control: both live enemies are struck by shrapnel",
		fc.struck.size() == 2 and e2.knocks == 1 and mod_ctrl.shrapnel_hits() == 2,
		"struck=%d e2_knocks=%d hits=%d" % [fc.struck.size(), e2.knocks, mod_ctrl.shrapnel_hits()])
	mod.teardown()
	mod.free()
	mod_ctrl.teardown()
	mod_ctrl.free()
	e1.free()
	e2.free()

	# (b) Live tuning.f("cruise") mid-stage upgrade.
	var tuning := FakeTuning.new()
	tuning.cruise = 10.0
	var live_mod := Destructibles.new()
	live_mod.build([
		{"id": "t2a", "tier": 2, "at": [0.0, 1.0, -5.0], "size": [1.0, 2.0, 1.0]},
		{"id": "t2b", "tier": 2, "at": [20.0, 1.0, -5.0], "size": [1.0, 2.0, 1.0]},
	], {"root": root, "no_visuals": true, "tuning": tuning})
	# Upgrade cruise mid-stage from 10 to 20 -> tier 2 bar rises from 8.5 to 17.0!
	tuning.cruise = 20.0
	live_mod.on_ball(Vector3(0.0, 1.0, -2.5), Vector3(0.0, 0.0, -14.0), 2, DT)
	var held_at_14 := live_mod.state_of("t2a") == "intact"
	live_mod.on_ball(Vector3(0.0, 1.0, -2.5), Vector3(0.0, 0.0, -18.0), 2, DT)
	var broke_at_18 := live_mod.state_of("t2a") == "shattered"
	_t.check("Destructibles reads live tuning.f('cruise') for tier 2 bar",
		held_at_14 and broke_at_18,
		"at 14 m/s intact=%s (bar 17.0), at 18 m/s shattered=%s" % [held_at_14, broke_at_18])
	live_mod.teardown()
	live_mod.free()

	# (c) scrapless() guard + planted control.
	var fb := FakeBuild.new()
	fb.is_scrapless = true
	var fs := FakeScrap.new()
	var sc_mod := Destructibles.new()
	sc_mod.build([
		{"id": "s1", "tier": 3, "at": [0.0, 1.0, 0.0], "size": [1.0, 2.0, 1.0]},
		{"id": "s2", "tier": 3, "at": [30.0, 1.0, 0.0], "size": [1.0, 2.0, 1.0]},
	], {"root": root, "no_visuals": true, "build": fb, "scrap": fs})
	sc_mod.on_blast(Vector3.ZERO, 3.0, "test", 1, 3)
	var scrapless_ok: bool = int(sc_mod.loot()["scrap"]) == 0 and int(sc_mod.loot()["cogs"]) == 0 and fs.drops == 0 and fs.cogs == 0
	_t.check("Destructibles._pay drops nothing when build.scrapless() is true",
		scrapless_ok, "loot=%s drops=%d cogs=%d" % [sc_mod.loot(), fs.drops, fs.cogs])
	fb.is_scrapless = false
	sc_mod.on_blast(Vector3(30.0, 1.0, 0.0), 3.0, "test", 1, 3)
	_t.check("planted control: Destructibles._pay drops loot when scrapless is false",
		int(sc_mod.loot()["scrap"]) > 0 and fs.drops > 0 and fs.cogs > 0,
		"loot=%s drops=%d cogs=%d" % [sc_mod.loot(), fs.drops, fs.cogs])
	sc_mod.teardown()
	sc_mod.free()


# --- 7. Audio & Juice log caps, cue_log_total/cues_since & per-run/stage cleanup ---------

func _check_audio_and_juice() -> void:
	var juice = _game.presentation.juice
	var audio = _game.presentation.audio
	for i in 2500:
		juice.request_hit_stop(0.01, "non_strike_test")
		juice._camera("kick", "test_cap", Vector3.DOWN, 0.01)
		Juice._log_push(juice.multi_log, [2, i])
	_t.check("Juice caps hit_stop_log, hook_log, and multi_log at LOG_CAP",
		juice.hit_stop_log.size() == Juice.LOG_CAP and juice.hook_log.size() == Juice.LOG_CAP
		and juice.multi_log.size() == Juice.LOG_CAP,
		"hit_stop=%d hook=%d multi=%d cap=%d" % [juice.hit_stop_log.size(), juice.hook_log.size(), juice.multi_log.size(), Juice.LOG_CAP])

	audio.reset_cue_log()
	for i in 2500:
		audio._log_cue(["test", "cap_%d" % i, "now", i, 1.0])
		audio._log_drop([i, i + 1])
	_t.check("Audio caps cue_log and drop_log at LOG_CAP while cue_log_total grows monotonically",
		audio.cue_log.size() == Audio.LOG_CAP and audio.drop_log.size() == Audio.LOG_CAP
		and audio.cue_log_total == 2500,
		"cue=%d total=%d drop=%d cap=%d" % [audio.cue_log.size(), audio.cue_log_total, audio.drop_log.size(), Audio.LOG_CAP])

	var mark: int = audio.cue_log_total
	for k in 3:
		audio._log_cue(["wrap_test", "after_%d" % k, "now", mark + k, 1.0])
	var delta_cues: Array = audio.cues_since(mark)
	var delta_names: Array = delta_cues.map(func(r): return String(r[1]))
	var empty_at_head: Array = audio.cues_since(audio.cue_log_total)
	var clamped_old: Array = audio.cues_since(0)
	_t.check("Audio.cues_since translates cue_log_total marks accurately across the 2048 wrap",
		audio.cue_log_total - mark == 3 and delta_names == ["after_0", "after_1", "after_2"]
		and empty_at_head.is_empty() and clamped_old.size() == Audio.LOG_CAP,
		"delta=%s empty=%d clamped=%d" % [delta_names, empty_at_head.size(), clamped_old.size()])

	audio.cue_log_cap = 0
	for k in 10:
		audio._log_cue(["uncapped", "u_%d" % k, "now", k, 1.0])
	var grew_past_cap: bool = audio.cue_log.size() == Audio.LOG_CAP + 10
	audio.cue_log_cap = Audio.LOG_CAP
	_t.check("Audio cue_log_cap = 0 opts out of eviction for full offline bounce capture",
		grew_past_cap, "size=%d expected=%d" % [audio.cue_log.size(), Audio.LOG_CAP + 10])

	audio._posture_seen[12345] = [false, 3]
	audio._guard_steps[12345] = 3
	audio._guard_warned[12345] = true
	_game.events.stage_entered.emit(1, false)
	_t.check("Audio clears posture/guard tracking dicts on stage_entered",
		audio._posture_seen.is_empty() and audio._guard_steps.is_empty() and audio._guard_warned.is_empty(),
		"seen=%d steps=%d warned=%d" % [audio._posture_seen.size(), audio._guard_steps.size(), audio._guard_warned.size()])

	audio._posture_seen[67890] = [true, 1]
	audio._guard_steps[67890] = 1
	audio._guard_warned[67890] = true
	_game.events.run_started.emit("tarn")
	_t.check("Audio clears posture/guard tracking dicts on run_started",
		audio._posture_seen.is_empty() and audio._guard_steps.is_empty() and audio._guard_warned.is_empty(),
		"seen=%d steps=%d warned=%d" % [audio._posture_seen.size(), audio._guard_steps.size(), audio._guard_warned.size()])
