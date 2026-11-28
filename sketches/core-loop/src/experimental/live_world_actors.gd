extends Node3D


const EnvTags := preload("res://src/experimental/env_tags.gd")
const Ecology := preload("res://src/experimental/ecology_actors.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ActorCraft := preload("res://src/experimental/live_world_actor_craft.gd")
const Comfort := preload("res://src/core/comfort.gd")

signal fact_emitted(fact: Dictionary)

const NODE_NAME := "ExperimentalLiveActors"
const KIND_DEFENDER := &"defender"
const KIND_APEX := &"apex"
const KIND_ELITE := &"elite"
const KIND_PROP := &"prop"
const KIND_HAULER := &"hauler"
const VERB_SHOT := &"shot"
const VERB_SLAM := &"slam"
const VERB_RAM := &"ram"
const VERB_BLAST := &"blast"
const VERB_HAZARD := &"hazard"

const LOCKDOWN_ID := "salvage_press"
const LOCKDOWN_KIND := &"scrap_beacon_lockdown"
const BEACON_LOCAL := Vector3(12.0, 0.0, 12.0)
const BEACON_TRIGGER_M := 4.5
const BEACON_TRIGGER_RISE_M := 3.0
const APEX_OFFSET := Vector3(8.0, 0.0, 0.0)
const APEX_RADIUS_M := 3.4
const APEX_CENTER_Y := 2.6
const APEX_PLATE_NODES := 4
const FLOOR_CLAMP_M := 26.0
const BALL_RADIUS_M := 1.0

const SHOT_DAMAGE := 18.0
const SHOT_SLACK_M := 0.4
const SLAM_DAMAGE := 34.0
const SLAM_RADIUS_M := 7.5
const RAM_MIN_SPEED_MPS := 12.0
const RAM_DAMAGE := 22.0
const RAM_SPEED_DAMAGE := 0.8
const RAM_COOLDOWN_S := 0.35
const RAM_RESTITUTION := 0.85
const RAM_REACH_SLACK_M := 0.3
const RUPTURE_RADIUS_M := 6.5
const RUPTURE_DAMAGE := 20.0
const CONDUIT_FIELD_RADIUS_M := 5.0
const CONDUIT_FIELD_TTL_S := 3.0
const FLASH_S := 0.12
const RING_LIFE_S := 0.45

const ELITE_CAP := 6
const ELITE_RADIUS_M := 2.0
const ELITE_ORBIT_M := 14.0
const ELITE_AGGRO_ORBIT_M := 6.0
const ELITE_ORBIT_RATE := 0.35
const ELITE_SPEED_MPS := 9.0
const ELITE_HOVER_M := 1.8
const ELITE_AGGRO_S := 3.0
const ELITE_AGGRO_REACH_M := 26.0
const ELITE_PLATE_NODES := 3

const HAULER_RADIUS_M := 1.4
const HAULER_HOVER_M := 1.6
const DEFENDER_RADIUS_M := 1.3
const DEFENDER_CENTER_Y := 1.0

const HAZARD_COOLDOWN_S := 1.2
const SLAG_HULL_DAMAGE := 6.0
const CRANE_HULL_DAMAGE := 10.0
const CRANE_IMPACT_RADIUS_M := 5.5
const CRANE_CONSTRUCT_DAMAGE := 65.0
const CRANE_MAGNET_REACH_M := 11.0
const SLAG_CONSTRUCT_DPS := 30.0
const SLAG_ZONE_RISE_M := 3.0
const KNOCKBACK_MPS := 7.0
const KNOCKBACK_UP_MPS := 3.5

const STREAK_COUNT := 10

const SLAG_SOURCE := "slag_pour"
const CRANE_SOURCE := "crane_magnet"
const SOLID_NAME := "ExpSolid"
const APEX_SOLID_SIZE := Vector3(4.6, 5.0, 5.6)
const APEX_SOLID_CENTER_Y := 2.5


const PROP_LAYOUT: Array[Dictionary] = [
	{"kind": &"coolant_tank", "at": Vector3(-6.0, 0.0, 14.0), "radius": 1.25, "center_y": 1.15},
	{"kind": &"slag_drum", "at": Vector3(8.0, 0.0, -16.0), "radius": 1.15, "center_y": 0.7},
	{"kind": &"power_conduit", "at": Vector3(16.0, 0.0, 4.0), "radius": 1.3, "center_y": 1.3},
	{"kind": &"slag_drum", "at": Vector3(-17.0, 0.0, -14.0), "radius": 1.15, "center_y": 0.7},
]
const HAULER_LANES: Array[Dictionary] = [
	{"a": Vector3(-10.0, 0.0, -20.0), "b": Vector3(10.0, 0.0, -20.0), "escape": Vector3(0.0, 0.0, -29.0)},
	{"a": Vector3(-20.0, 0.0, -2.0), "b": Vector3(-20.0, 0.0, 10.0), "escape": Vector3(-29.0, 0.0, 4.0)},
]
const WAVE_ROLES := {
	&"chaser": &"swarmer",
	&"winch_drone": &"swarmer",
	&"lobber": &"arc_sniper",
	&"jolt_layer": &"arc_sniper",
	&"hooker": &"weld_healer",
	&"boom_tender": &"weld_healer",
	&"plated_brute": &"shielded_bulwark",
}
const RUPTURE_TAGS := {
	&"coolant_tank": &"coolant_brittle",
	&"slag_drum": &"burning",
	&"power_conduit": &"electrified",
}

var _craft := ActorCraft.new()

var _bridge: Node = null
var _ctx = null
var _chunk: Node3D = null
var _stage := 0
var _clock := 0.0
var _serial := 0
var _floor_y := 0.0
var _beacon_pos := Vector3.ZERO
var _beacon: Node3D = null
var _beacon_glow: Node3D = null
var _lockdown := "armed"
var _apex_id := ""
var _apex_plates_left := APEX_PLATE_NODES
var _targets: Dictionary = {}
var _rings: Array[Dictionary] = []
var _streaks: Node3D = null
var _links: Array[Dictionary] = []
var _hazard_cd := 0.0
var _hazard_times: Array[float] = []
var _construct_hazard_damage := 0.0
var _paid_scrap := 0
var _paid_cogs := 0
var _rings_spawned := 0
var _ruptures := 0
var _reactions: Array[StringName] = []
var _kills: Dictionary = {}
var _prev_ball_vel := Vector3.ZERO


func setup(bridge_ref: Node, ctx_ref, chunk_ref: Node3D, stage_num: int) -> void:
	name = NODE_NAME
	_bridge = bridge_ref
	_ctx = ctx_ref
	_chunk = chunk_ref
	_stage = stage_num
	_floor_y = _chunk.global_position.y
	_beacon_pos = _chunk.to_global(BEACON_LOCAL)
	_build_beacon()
	_spawn_props()
	_spawn_haulers()
	_build_streaks()
	_link(_bridge.ecology, &"prop_ruptured", _on_prop_ruptured)


func teardown() -> void:
	for link in _links:
		var obj: Variant = (link["obj"] as WeakRef).get_ref()
		var cb: Callable = link["cb"]
		if obj != null and is_instance_valid(obj) and obj.is_connected(link["signal"], cb):
			obj.disconnect(link["signal"], cb)
	_links.clear()
	for id in _targets:
		var solid := (_targets[id] as Dictionary).get("solid") as StaticBody3D
		if solid != null and is_instance_valid(solid):
			if solid.get_parent() != null:
				solid.get_parent().remove_child(solid)
			solid.queue_free()
	_targets.clear()
	_rings.clear()
	_beacon = null
	_beacon_glow = null
	_streaks = null
	_bridge = null
	_ctx = null
	_chunk = null


func step(delta: float, result: Dictionary) -> void:
	if delta <= 0.0 or _bridge == null or not _bridge.configured or _ctx == null:
		return
	_clock += delta
	_hazard_cd = maxf(0.0, _hazard_cd - delta)
	var ball_pos: Vector3 = _ctx.player.ball_position()
	var ball_vel: Vector3 = _ctx.player.state.velocity
	_step_beacon(ball_pos)
	_ingest_encounters(result.get("encounters", {}))
	_sync_defenders()
	_sync_elites(delta, ball_pos)
	_sync_props()
	_sync_haulers()
	_step_rams(ball_pos, ball_vel)
	_prev_ball_vel = ball_vel
	_step_slag_zones(delta)
	_apply_setpiece_facts(result.get("setpieces", []), ball_pos, ball_vel)
	_step_squall(ball_pos)
	_step_fx(delta)


func on_shot(from: Vector3, to: Vector3) -> void:
	if _bridge == null:
		return
	var best: Dictionary = {}
	var best_t := INF
	for id in _targets:
		var t: Dictionary = _targets[id]
		var hit_t := _segment_sphere(from, to, _center(t), float(t["radius"]) + SHOT_SLACK_M)
		if hit_t >= 0.0 and hit_t < best_t:
			best_t = hit_t
			best = t
	if not best.is_empty():
		_hit(best, SHOT_DAMAGE, from, VERB_SHOT)


func on_slam(at: Vector3, strength: float) -> void:
	if _bridge == null:
		return
	var power := clampf(strength, 0.6, 1.6)
	var reach := SLAM_RADIUS_M * power
	for id in _targets.keys():
		if not _targets.has(id):
			continue
		var t: Dictionary = _targets[id]
		var c := _center(t)
		if Vector2(c.x - at.x, c.z - at.z).length() <= reach + float(t["radius"]) and absf(c.y - at.y) <= reach:
			_hit(t, SLAM_DAMAGE * power, at, VERB_SLAM)
	_try_magnet_drop(at)


func spawn_elite(inst: RefCounted) -> bool:
	if inst == null or _bridge == null or _count_kind(KIND_ELITE) >= ELITE_CAP:
		return false
	var id := "elite:%s" % String(inst.instance_id)
	while _targets.has(id):
		_serial += 1
		id = "elite:%s#%d" % [String(inst.instance_id), _serial]
	var root := Node3D.new()
	root.name = "ExpElite_%s" % String(inst.instance_id).validate_node_name()
	add_child(root)
	var views: Array = [_view(root, "Hull", _craft.elite_body_mesh())]
	var plates: Array = []
	for i in ELITE_PLATE_NODES:
		var plate := _view(root, "Plate%d" % i, _craft.elite_plate_mesh())
		var side := -1.0 if i == 0 else 1.0
		plate.position = Vector3(side * 1.18, 0.1, 0.0) if i < 2 else Vector3(0.0, 0.86, 0.0)
		plate.rotation = Vector3(0.0, 0.0, 0.0) if i < 2 else Vector3(0.0, 0.0, PI * 0.5)
		views.append(plate)
		plates.append(plate)
	var solid := _solid(root, _sphere(ELITE_RADIUS_M), 0.0)
	var ball_pos: Vector3 = _ctx.player.ball_position()
	var start: Vector3 = inst.origin
	start.y = ball_pos.y + ELITE_HOVER_M
	root.global_position = start
	inst.origin = start
	_targets[id] = _target(id, KIND_ELITE, root, views, ELITE_RADIUS_M, 0.0, inst, {
		"plates": plates,
		"solid": solid,
		"phase": float(_serial) * 1.7 + float(_count_kind(KIND_ELITE)) * 1.05,
		"aggro_s": 0.0,
	})
	return true


func beacon_position() -> Vector3:
	return _beacon_pos


func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	var counts := {KIND_DEFENDER: 0, KIND_APEX: 0, KIND_ELITE: 0, KIND_PROP: 0, KIND_HAULER: 0}
	for id in _targets:
		var t: Dictionary = _targets[id]
		counts[t["kind"]] = int(counts[t["kind"]]) + 1
		rows.append({"id": id, "kind": t["kind"], "pos": _center(t), "radius": float(t["radius"]), "solid": _is_solid(t)})
	var streaks_visible := 0
	if is_instance_valid(_streaks) and _streaks.visible:
		streaks_visible = _streaks.get_child_count()
	return {
		"stage": _stage,
		"beacon_pos": _beacon_pos,
		"lockdown": _lockdown,
		"defenders": int(counts[KIND_DEFENDER]),
		"apex": int(counts[KIND_APEX]) > 0,
		"apex_plates_left": _apex_plates_left,
		"elites": int(counts[KIND_ELITE]),
		"props": int(counts[KIND_PROP]),
		"haulers": int(counts[KIND_HAULER]),
		"targets": rows,
		"rings_spawned": _rings_spawned,
		"rings_live": _rings.size(),
		"ruptures": _ruptures,
		"reactions": _reactions.duplicate(),
		"kills": _kills.duplicate(),
		"paid_scrap": _paid_scrap,
		"paid_cogs": _paid_cogs,
		"hazard_times": _hazard_times.duplicate(),
		"construct_hazard_damage": _construct_hazard_damage,
		"streaks_visible": streaks_visible,
	}


func _link(obj: Object, sig: StringName, cb: Callable) -> void:
	if obj == null or not obj.has_signal(sig):
		return
	obj.connect(sig, cb)
	_links.append({"obj": weakref(obj), "signal": sig, "cb": cb})


func _target(id: String, kind: StringName, node: Node3D, views: Array, radius: float, center_y: float, ref, extra: Dictionary = {}) -> Dictionary:
	var t := {
		"id": id,
		"kind": kind,
		"node": node,
		"views": views,
		"radius": radius,
		"center_y": center_y,
		"ref": ref,
		"flash_s": 0.0,
		"ram_cd": 0.0,
	}
	t.merge(extra)
	return t


func _center(t: Dictionary) -> Vector3:
	var node := t["node"] as Node3D
	if not is_instance_valid(node):
		return Vector3.INF
	return node.global_position + Vector3(0.0, float(t["center_y"]), 0.0)


func _count_kind(kind: StringName) -> int:
	var n := 0
	for id in _targets:
		if (_targets[id] as Dictionary)["kind"] == kind:
			n += 1
	return n


func _view(parent: Node3D, node_name: String, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _solid(root: Node3D, shape: Shape3D, center_y: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = SOLID_NAME
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, center_y, 0.0)
	body.add_child(col)
	root.add_child(body)
	return body


static func _sphere(radius: float) -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return shape


func _is_solid(t: Dictionary) -> bool:
	var body := t.get("solid") as StaticBody3D
	return body != null and is_instance_valid(body) and body.is_inside_tree() \
		and body.collision_layer == 1 and body.collision_mask == 0 and body.get_parent() == t["node"]


func _floor_point(local: Vector3) -> Vector3:
	return _chunk.to_global(Vector3(local.x, 0.0, local.z))


func _clamp_to_floor(world: Vector3) -> Vector3:
	var local := _chunk.to_local(world)
	return _floor_point(Vector3(clampf(local.x, -FLOOR_CLAMP_M, FLOOR_CLAMP_M), 0.0, clampf(local.z, -FLOOR_CLAMP_M, FLOOR_CLAMP_M)))


func _cruise() -> float:
	return float(_ctx.tuning.f("cruise")) if _ctx != null and _ctx.tuning != null else Tuning.CRUISE_MPS


func _ball_speed() -> float:
	if _ctx == null:
		return 0.0
	var v: Vector3 = _ctx.player.state.velocity
	return Vector2(v.x, v.z).length()


func _award(scrap: int, cogs: int, at: Vector3) -> void:
	if _ctx == null or _ctx.run == null:
		return
	if scrap > 0:
		_ctx.run.add_scrap(scrap, at)
		_paid_scrap += scrap
	if cogs > 0:
		_ctx.run.add_cogs(cogs)
		_paid_cogs += cogs


func _emit_fact(fact: Dictionary) -> void:
	fact_emitted.emit(fact)


func _note_kill(kind: StringName) -> void:
	_kills[kind] = int(_kills.get(kind, 0)) + 1


func _remove_target(id: String) -> void:
	if not _targets.has(id):
		return
	var node := (_targets[id] as Dictionary)["node"] as Node3D
	_targets.erase(id)
	if is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "SalvagePressBeacon"
	add_child(_beacon)
	_beacon.global_position = _beacon_pos
	_view(_beacon, "Pad", _craft.beacon_pad_mesh())
	_beacon_glow = _view(_beacon, "Core", _craft.beacon_core_mesh())


func _step_beacon(ball_pos: Vector3) -> void:
	if is_instance_valid(_beacon_glow):
		_beacon_glow.rotation.y = _clock * (2.4 if _lockdown == "locked" else 0.8)
		_beacon_glow.position.y = (0.6 if _lockdown == "locked" else 0.0) + sin(_clock * 2.0) * 0.06
	if _lockdown == "locked":
		if not _bridge.encounters.has_active_lockdown():
			_end_lockdown()
		return
	if _lockdown != "armed":
		return
	var flat := Vector2(ball_pos.x - _beacon_pos.x, ball_pos.z - _beacon_pos.z).length()
	if flat > BEACON_TRIGGER_M or ball_pos.y - _beacon_pos.y > BEACON_TRIGGER_RISE_M:
		return
	var encounters = _bridge.encounters
	if encounters.register_triggered_volume(LOCKDOWN_ID, LOCKDOWN_KIND, _beacon_pos, _bridge.biome_id).is_empty():
		_lockdown = "unavailable"
		return
	var act: Dictionary = encounters.activate_triggered(LOCKDOWN_ID, {"active_lockdown": false, "warden_awake": false})
	if not bool(act.get("started", false)):
		_lockdown = "unavailable"
		return
	_lockdown = "locked"
	_spawn_wave(act.get("spawns", []))


func _end_lockdown() -> void:
	_lockdown = "spent"
	if _apex_id != "":
		_remove_target(_apex_id)
		_apex_id = ""
	if is_instance_valid(_beacon_glow):
		_beacon_glow.visible = false


func _ingest_encounters(enc_res: Dictionary) -> void:
	if enc_res.is_empty():
		return
	_spawn_wave(enc_res.get("spawns", []))
	for fact in enc_res.get("facts", []):
		if String((fact as Dictionary).get("kind", "")) == "apex_construct_spawned":
			_spawn_apex()


func _spawn_wave(spawns: Array) -> void:
	for spawn in spawns:
		var row := spawn as Dictionary
		if String(row.get("source", "")) != LOCKDOWN_ID:
			continue
		_serial += 1
		var role: StringName = StringName(WAVE_ROLES.get(StringName(row.get("kind", &"chaser")), &"swarmer"))
		var eid := "live_def_%d" % _serial
		var at := _clamp_to_floor(row.get("at", _beacon_pos) as Vector3)
		_bridge.ecology.spawn_enemy(eid, role, at, false)
		var root := Node3D.new()
		root.name = "ExpDefender_%d" % _serial
		add_child(root)
		root.global_position = at
		var views: Array = [_view(root, "Body", _craft.defender_mesh(role == &"shielded_bulwark"))]
		var solid := _solid(root, _sphere(DEFENDER_RADIUS_M), DEFENDER_CENTER_Y)
		_targets["defender:" + eid] = _target("defender:" + eid, KIND_DEFENDER, root, views, DEFENDER_RADIUS_M, DEFENDER_CENTER_Y, eid, {"solid": solid, "phase": float(_serial % 7)})


func _spawn_apex() -> void:
	if _apex_id != "":
		return
	var root := Node3D.new()
	root.name = "ForemanRig"
	add_child(root)
	root.global_position = _clamp_to_floor(_beacon_pos + APEX_OFFSET)
	var views: Array = [_view(root, "Chassis", _craft.foreman_body_mesh())]
	var pivot := Node3D.new()
	pivot.name = "HazardPlates"
	pivot.position = Vector3(0.0, 2.6, 0.0)
	root.add_child(pivot)
	var plates: Array = []
	for i in APEX_PLATE_NODES:
		var arm := Node3D.new()
		arm.name = "PlateArm%d" % i
		arm.rotation.y = TAU * float(i) / float(APEX_PLATE_NODES)
		pivot.add_child(arm)
		var plate := _view(arm, "Plate", _craft.foreman_plate_mesh())
		plate.position = Vector3(0.0, 0.0, 3.1)
		views.append(plate)
		plates.append(plate)
	var box := BoxShape3D.new()
	box.size = APEX_SOLID_SIZE
	var solid := _solid(root, box, APEX_SOLID_CENTER_Y)
	_apex_id = "apex:" + LOCKDOWN_ID
	_apex_plates_left = APEX_PLATE_NODES
	_targets[_apex_id] = _target(_apex_id, KIND_APEX, root, views, APEX_RADIUS_M, APEX_CENTER_Y, null, {"pivot": pivot, "plates": plates, "solid": solid})


func _spawn_props() -> void:
	for i in PROP_LAYOUT.size():
		var row: Dictionary = PROP_LAYOUT[i]
		var kind: StringName = row["kind"]
		var pid := "live_prop_%d" % i
		var at := _floor_point(row["at"] as Vector3)
		_bridge.ecology.spawn_prop(pid, kind, at)
		var root := Node3D.new()
		root.name = "ExpProp_%s_%d" % [String(kind), i]
		add_child(root)
		root.global_position = at
		var views: Array = [_view(root, "Body", _craft.prop_mesh(kind))]
		var solid := _solid(root, _sphere(float(row["radius"])), float(row["center_y"]))
		_targets["prop:" + pid] = _target("prop:" + pid, KIND_PROP, root, views, float(row["radius"]), float(row["center_y"]), pid, {"prop_kind": kind, "solid": solid})


func _spawn_haulers() -> void:
	var count := 1 if _stage <= 2 else 2
	for i in count:
		var lane: Dictionary = HAULER_LANES[i]
		var cid := "live_hauler_%d" % i
		var a := _floor_point(lane["a"] as Vector3)
		var c = _bridge.ecology.spawn_courier(cid, Ecology.COURIER_HAULER_DRONE, a, _floor_point(lane["escape"] as Vector3))
		c.patrol_b = _floor_point(lane["b"] as Vector3)
		var root := Node3D.new()
		root.name = "ExpHauler_%d" % i
		add_child(root)
		root.global_position = a + Vector3.UP * HAULER_HOVER_M
		var views: Array = [_view(root, "Cargo", _craft.hauler_body_mesh())]
		var rotors: Array = []
		for r in 4:
			var rotor := _view(root, "Rotor%d" % r, _craft.hauler_rotor_mesh())
			rotor.position = Vector3(-1.15 if r % 2 == 0 else 1.15, 0.42, -0.85 if r < 2 else 0.85)
			views.append(rotor)
			rotors.append(rotor)
		_targets["hauler:" + cid] = _target("hauler:" + cid, KIND_HAULER, root, views, HAULER_RADIUS_M, 0.0, cid, {"rotors": rotors})


func _build_streaks() -> void:
	_streaks = Node3D.new()
	_streaks.name = "SquallStreaks"
	_streaks.visible = false
	add_child(_streaks)
	for i in STREAK_COUNT:
		_view(_streaks, "Streak%d" % i, _craft.streak_mesh())


func _sync_defenders() -> void:
	for id in _targets.keys():
		if not _targets.has(id):
			continue
		var t: Dictionary = _targets[id]
		if t["kind"] != KIND_DEFENDER:
			continue
		var e = _bridge.ecology.enemy(String(t["ref"]))
		if e == null or e.is_dead():
			_defender_down(t)
			continue
		var clamped := _clamp_to_floor(e.pos)
		e.pos = clamped
		var node := t["node"] as Node3D
		node.global_position = clamped
		if e.facing.length_squared() > 0.01:
			node.rotation.y = atan2(e.facing.x, e.facing.z)
		(t["views"][0] as Node3D).position.y = 0.12 + sin(_clock * 4.0 + float(t["phase"])) * 0.08


func _sync_elites(delta: float, ball_pos: Vector3) -> void:
	for id in _targets.keys():
		if not _targets.has(id):
			continue
		var t: Dictionary = _targets[id]
		if t["kind"] != KIND_ELITE:
			continue
		var inst = t["ref"]
		if inst == null or inst.is_defeated():
			_elite_down(t, {})
			continue
		t["aggro_s"] = maxf(0.0, float(t["aggro_s"]) - delta)
		var orbit := ELITE_AGGRO_ORBIT_M if float(t["aggro_s"]) > 0.0 else ELITE_ORBIT_M
		var a := float(t["phase"]) + _clock * ELITE_ORBIT_RATE
		var goal := ball_pos + Vector3(cos(a), 0.0, sin(a)) * orbit
		goal.y = ball_pos.y + ELITE_HOVER_M
		var node := t["node"] as Node3D
		var cur := node.global_position
		var to := goal - cur
		var reach := ELITE_SPEED_MPS * delta
		node.global_position = cur + (to if to.length() <= reach else to.normalized() * reach)
		var face := ball_pos - node.global_position
		if Vector2(face.x, face.z).length() > 0.1:
			node.rotation.y = atan2(face.x, face.z)
		inst.origin = node.global_position
		_show_plates(t["plates"], inst.plates)


func _show_plates(nodes: Array, plates: Array) -> void:
	for i in nodes.size():
		(nodes[i] as Node3D).visible = i < plates.size() and bool((plates[i] as Dictionary)["intact"])


func _sync_props() -> void:
	for id in _targets.keys():
		if not _targets.has(id):
			continue
		var t: Dictionary = _targets[id]
		if t["kind"] != KIND_PROP:
			continue
		var p = _bridge.ecology.prop(String(t["ref"]))
		if p == null or not p.intact:
			_remove_target(id)
			continue
		(t["node"] as Node3D).global_position = _clamp_to_floor(p.pos)


func _sync_haulers() -> void:
	for id in _targets.keys():
		if not _targets.has(id):
			continue
		var t: Dictionary = _targets[id]
		if t["kind"] != KIND_HAULER:
			continue
		var c = _bridge.ecology.courier(String(t["ref"]))
		if c == null or c.state == Ecology.ST_ESCAPED:
			_remove_target(id)
			continue
		if c.state == Ecology.ST_DISABLED:
			_hauler_down(t)
			continue
		var node := t["node"] as Node3D
		node.global_position = _clamp_to_floor(c.pos) + Vector3.UP * (HAULER_HOVER_M + sin(_clock * 3.0) * 0.12)
		if c.vel.length_squared() > 0.04:
			node.rotation.y = atan2(c.vel.x, c.vel.z)
		for rotor in t["rotors"]:
			(rotor as Node3D).rotation.y += 0.0 if Comfort.reduced_motion else 0.6


func _step_rams(ball_pos: Vector3, ball_vel: Vector3) -> void:
	var speed := maxf(Vector2(ball_vel.x, ball_vel.z).length(), Vector2(_prev_ball_vel.x, _prev_ball_vel.z).length())
	for id in _targets.keys():
		if not _targets.has(id):
			continue
		var t: Dictionary = _targets[id]
		if float(t["ram_cd"]) > 0.0 or speed < RAM_MIN_SPEED_MPS:
			continue
		var c := _center(t)
		if ball_pos.distance_to(c) > float(t["radius"]) + BALL_RADIUS_M + RAM_REACH_SLACK_M:
			continue
		t["ram_cd"] = RAM_COOLDOWN_S
		if t["kind"] != KIND_PROP:
			_rebound(ball_pos, ball_vel, c)
		_hit(t, RAM_DAMAGE + speed * RAM_SPEED_DAMAGE, ball_pos, VERB_RAM)
		return


func _rebound(ball_pos: Vector3, ball_vel: Vector3, center: Vector3) -> void:
	var n := Vector3(ball_pos.x - center.x, 0.0, ball_pos.z - center.z)
	if n.length_squared() < 1e-4:
		n = -Vector3(ball_vel.x, 0.0, ball_vel.z)
	n = n.normalized()
	var vn := ball_vel.dot(n)
	if vn >= 0.0:
		return
	var body: RigidBody3D = _ctx.player.body()
	body.apply_central_impulse(-n * vn * (1.0 + RAM_RESTITUTION) * body.mass)


func _hit(t: Dictionary, damage: float, from: Vector3, verb: StringName) -> void:
	if damage <= 0.0 or not _targets.has(String(t["id"])):
		return
	if verb != VERB_HAZARD:
		t["flash_s"] = FLASH_S
		_set_flash(t, true)
	match t["kind"]:
		KIND_DEFENDER:
			_hit_defender(t, damage, from, verb)
		KIND_APEX:
			_hit_apex(t, damage)
		KIND_ELITE:
			_hit_elite(t, damage, from)
		KIND_PROP:
			_hit_prop(t, verb)
		KIND_HAULER:
			_hit_hauler(t, damage, from)


func _hit_defender(t: Dictionary, damage: float, from: Vector3, verb: StringName) -> void:
	var kind := &"kinetic"
	if verb == VERB_SLAM:
		kind = &"slam"
	elif verb == VERB_RAM:
		kind = &"ram"
	var res: Dictionary = _bridge.ecology.damage_enemy(String(t["ref"]), damage, from, kind)
	if bool(res.get("dead", false)):
		_defender_down(t)


func _defender_down(t: Dictionary) -> void:
	var c := _center(t)
	_bridge.encounters.report_encounter_kill(_ball_speed(), _cruise())
	_note_kill(KIND_DEFENDER)
	_spawn_ring(c, &"electrified", 3.0)
	_remove_target(String(t["id"]))


func _hit_apex(t: Dictionary, damage: float) -> void:
	var c := _center(t)
	var tags: Array[StringName] = _bridge.env_tags.tags_at(c, APEX_RADIUS_M)
	var res: Dictionary = _bridge.encounters.damage_apex_construct(damage, _ball_speed(), _cruise(), tags)
	var hit: Dictionary = res.get("hit", {})
	if hit.is_empty():
		return
	var broken := int(hit.get("plates_broken", 0))
	if broken > 0:
		_apex_plates_left = maxi(0, _apex_plates_left - broken)
		var plates: Array = t["plates"]
		for i in plates.size():
			(plates[i] as Node3D).visible = i < _apex_plates_left
	_award(int(hit.get("scrap_spilled", 0)), 0, c)
	var payout: Dictionary = res.get("payout", {})
	if not bool(hit.get("defeated", false)) and payout.is_empty():
		return
	_award(int(payout.get("scrap", 0)), int(payout.get("cogs", 0)), c)
	_note_kill(KIND_APEX)
	_spawn_ring(c, &"burning", 7.0)
	_emit_fact({"kind": "foreman_rig_scrapped", "scrap": int(payout.get("scrap", 0)), "cogs": int(payout.get("cogs", 0)), "at": c})
	_end_lockdown()


func _hit_elite(t: Dictionary, damage: float, from: Vector3) -> void:
	var inst = t["ref"]
	var c := _center(t)
	var tags: Array[StringName] = _bridge.env_tags.tags_at(c, ELITE_RADIUS_M)
	var res: Dictionary = inst.apply_hit(damage, _ball_speed(), _cruise(), tags, from)
	_award(int(res.get("scrap_spilled", 0)), 0, c)
	_show_plates(t["plates"], inst.plates)
	if bool(res.get("defeated", false)):
		_elite_down(t, res.get("bounty", {}))


func _elite_down(t: Dictionary, bounty: Dictionary) -> void:
	var c := _center(t)
	_award(int(bounty.get("scrap", 0)), int(bounty.get("cogs", 0)), c)
	_note_kill(KIND_ELITE)
	_spawn_ring(c, &"magnetic", 4.5)
	_emit_fact({"kind": "refurbished_elite_scrapped", "id": String(t["id"]), "scrap": int(bounty.get("scrap", 0)), "cogs": int(bounty.get("cogs", 0)), "at": c})
	_remove_target(String(t["id"]))


func _hit_prop(t: Dictionary, verb: StringName) -> void:
	var pid := String(t["ref"])
	var ecology = _bridge.ecology
	var ball_vel: Vector3 = _ctx.player.state.velocity
	if verb == VERB_SLAM:
		ecology.interact_prop_with_ball(pid, ball_vel, true)
	elif verb == VERB_RAM:
		ecology.interact_prop_with_ball(pid, ball_vel, false)
	else:
		ecology.rupture_prop(pid, String(verb))


func _on_prop_ruptured(receipt: Dictionary) -> void:
	var pid := String(receipt.get("prop_id", ""))
	var id := "prop:" + pid
	if not _targets.has(id):
		return
	var t: Dictionary = _targets[id]
	var origin: Vector3 = receipt.get("origin", _center(t))
	var kind: StringName = t["prop_kind"]
	_ruptures += 1
	if StringName(receipt.get("action", &"")) == &"conduit_discharge":
		var field: Dictionary = _bridge.env_tags.apply_tag(EnvTags.make_payload(EnvTags.TAG_MAGNETIC, origin, CONDUIT_FIELD_RADIUS_M, "conduit_field:" + pid, 1.0, CONDUIT_FIELD_TTL_S))
		for reaction in field.get("reactions", []):
			_reactions.append(StringName((reaction as Dictionary).get("reaction_id", &"")))
		_spawn_ring(origin + Vector3.UP * 1.2, &"electrified", CONDUIT_FIELD_RADIUS_M)
	else:
		_award(int(receipt.get("scrap", 0)), int(receipt.get("cogs", 0)), origin)
		_spawn_ring(origin + Vector3.UP * 0.6, RUPTURE_TAGS.get(kind, &"burning"), RUPTURE_RADIUS_M)
		_remove_target(id)
	for other_id in _targets.keys():
		if not _targets.has(other_id):
			continue
		var other: Dictionary = _targets[other_id]
		if other["kind"] == KIND_PROP:
			continue
		var c := _center(other)
		if Vector2(c.x - origin.x, c.z - origin.z).length() <= RUPTURE_RADIUS_M + float(other["radius"]):
			_hit(other, RUPTURE_DAMAGE, origin, VERB_BLAST)


func _hit_hauler(t: Dictionary, damage: float, from: Vector3) -> void:
	var res: Dictionary = _bridge.ecology.strike_courier(String(t["ref"]), damage, from)
	if not bool(res.get("ok", false)):
		return
	var c := _center(t)
	_award(int(res.get("spilled_scrap", 0)), int(res.get("spilled_cogs", 0)), c)
	for other_id in _targets:
		var other: Dictionary = _targets[other_id]
		if other["kind"] == KIND_ELITE and _center(other).distance_to(c) <= ELITE_AGGRO_REACH_M:
			other["aggro_s"] = ELITE_AGGRO_S
	if StringName(res.get("state", &"")) == Ecology.ST_DISABLED:
		_hauler_down(t)


func _hauler_down(t: Dictionary) -> void:
	var c := _center(t)
	_note_kill(KIND_HAULER)
	_spawn_ring(c, &"electrified", 3.5)
	_emit_fact({"kind": "hauler_scrapped", "id": String(t["id"]), "at": c})
	_remove_target(String(t["id"]))


func _try_magnet_drop(at: Vector3) -> void:
	var setpieces = _bridge.setpieces
	if setpieces == null or not is_instance_valid(setpieces):
		return
	var crane: Dictionary = setpieces.snapshot().get("crane", {})
	if crane.is_empty() or String(crane.get("state", "")) != "sweep_active":
		return
	var hull: Vector3 = crane.get("hull_position", Vector3.INF)
	if Vector2(hull.x - at.x, hull.z - at.z).length() > CRANE_MAGNET_REACH_M:
		return
	var ball_pos: Vector3 = _ctx.player.ball_position()
	_apply_setpiece_facts(setpieces.strike_crane_magnet([], ball_pos), ball_pos, _ctx.player.state.velocity)


func _step_slag_zones(delta: float) -> void:
	var setpieces = _bridge.setpieces
	if setpieces == null or not is_instance_valid(setpieces):
		return
	for zone in setpieces.active_env_tags():
		if StringName(zone.get("tag", &"")) != EnvTags.TAG_BURNING or not String(zone.get("source_id", "")).begins_with("slag_furnace:"):
			continue
		var origin: Vector3 = zone["origin"]
		var radius := float(zone["radius_m"])
		for id in _targets.keys():
			if not _targets.has(id):
				continue
			var t: Dictionary = _targets[id]
			if t["kind"] == KIND_PROP:
				continue
			var c := _center(t)
			if Vector2(c.x - origin.x, c.z - origin.z).length() <= radius and c.y - origin.y <= SLAG_ZONE_RISE_M + float(t["center_y"]):
				_construct_hazard_damage += SLAG_CONSTRUCT_DPS * delta
				_hit(t, SLAG_CONSTRUCT_DPS * delta, origin, VERB_HAZARD)


func _slag_origin(near: Vector3) -> Vector3:
	var setpieces = _bridge.setpieces
	if setpieces != null and is_instance_valid(setpieces):
		for zone in setpieces.active_env_tags():
			if String(zone.get("source_id", "")).begins_with("slag_furnace:"):
				return zone["origin"]
	return near


func _apply_setpiece_facts(facts: Array, ball_pos: Vector3, ball_vel: Vector3) -> void:
	for fact in facts:
		var row := fact as Dictionary
		match String(row.get("kind", "")):
			"slag_stall_burn":
				_hull_hazard(_slag_origin(ball_pos), SLAG_HULL_DAMAGE, SLAG_SOURCE)
			"crane_magnet_dropped", "cover_relocated":
				_crane_impact(row.get("position", Vector3.INF), ball_pos, ball_vel)


func _crane_impact(at: Vector3, ball_pos: Vector3, ball_vel: Vector3) -> void:
	if at == Vector3.INF:
		return
	for id in _targets.keys():
		if not _targets.has(id):
			continue
		var t: Dictionary = _targets[id]
		var c := _center(t)
		if Vector2(c.x - at.x, c.z - at.z).length() <= CRANE_IMPACT_RADIUS_M + float(t["radius"]):
			_construct_hazard_damage += CRANE_CONSTRUCT_DAMAGE
			_hit(t, CRANE_CONSTRUCT_DAMAGE, at, VERB_HAZARD)
	_spawn_ring(Vector3(at.x, _floor_y + 0.3, at.z), &"electrified", CRANE_IMPACT_RADIUS_M)
	var sits := Vector2(ball_vel.x, ball_vel.z).length() < _cruise() * float(SpeedTier.MULTIPLES[SpeedTier.CRUISE])
	if sits and Vector2(ball_pos.x - at.x, ball_pos.z - at.z).length() <= CRANE_IMPACT_RADIUS_M:
		_hull_hazard(at, CRANE_HULL_DAMAGE, CRANE_SOURCE)


func _hull_hazard(origin: Vector3, damage: float, source: String) -> void:
	if _hazard_cd > 0.0 or _ctx == null:
		return
	_hazard_cd = HAZARD_COOLDOWN_S
	_hazard_times.append(_clock)
	_ctx.run.damage(damage, source)
	var player = _ctx.player
	var ball_pos: Vector3 = player.ball_position()
	var out := Vector3(ball_pos.x - origin.x, 0.0, ball_pos.z - origin.z)
	if out.length_squared() < 1e-4:
		var v: Vector3 = player.state.velocity
		out = Vector3(v.x, 0.0, v.z) if Vector2(v.x, v.z).length() > 0.1 else Vector3.FORWARD
	player.set_velocity_now(player.state.velocity + out.normalized() * KNOCKBACK_MPS + Vector3.UP * KNOCKBACK_UP_MPS, source)


func _step_squall(ball_pos: Vector3) -> void:
	if not is_instance_valid(_streaks):
		return
	var director = _bridge.director
	var phase: int = director.hazard_phase if director != null else AdversityDirector.HazardPhase.IDLE
	var active := (phase == AdversityDirector.HazardPhase.RAMP or phase == AdversityDirector.HazardPhase.PEAK) and not Comfort.reduced_motion
	_streaks.visible = active
	if not active:
		return
	for i in _streaks.get_child_count():
		var streak := _streaks.get_child(i) as Node3D
		var a := TAU * float(i) / float(STREAK_COUNT) + _clock * 1.4
		var r := 3.5 + float(i % 3) * 1.2
		streak.global_position = ball_pos + Vector3(cos(a) * r, 0.6 + sin(_clock * 2.0 + float(i)) * 0.8, sin(a) * r)
		streak.rotation = Vector3(0.0, -a, 0.0)


func _step_fx(delta: float) -> void:
	for id in _targets:
		var t: Dictionary = _targets[id]
		t["ram_cd"] = maxf(0.0, float(t["ram_cd"]) - delta)
		if float(t["flash_s"]) > 0.0:
			t["flash_s"] = float(t["flash_s"]) - delta
			if float(t["flash_s"]) <= 0.0:
				_set_flash(t, false)
		if t["kind"] == KIND_APEX:
			var pivot := t["pivot"] as Node3D
			pivot.rotation.y += delta * 0.9
			pivot.position.y = 2.6 + (0.0 if Comfort.reduced_motion else sin(_clock * 2.2) * 0.3)
	var kept: Array[Dictionary] = []
	for ring in _rings:
		var node := ring["node"] as Node3D
		if not is_instance_valid(node):
			continue
		ring["age"] = float(ring["age"]) + delta
		var k := clampf(float(ring["age"]) / RING_LIFE_S, 0.0, 1.0)
		var grow := 1.0 if Comfort.reduced_motion else lerpf(0.35, 1.0, k)
		node.scale = Vector3.ONE * maxf(0.05, float(ring["radius"]) * grow)
		if k >= 1.0:
			remove_child(node)
			node.queue_free()
			continue
		kept.append(ring)
	_rings = kept


func _set_flash(t: Dictionary, on: bool) -> void:
	var mat: Material = _craft.flash_material() if on else null
	for view in t["views"]:
		if is_instance_valid(view):
			(view as MeshInstance3D).material_overlay = mat


func _spawn_ring(at: Vector3, tag: StringName, radius: float) -> void:
	var node := MeshInstance3D.new()
	node.name = "ShockRing"
	node.mesh = _craft.shock_ring_mesh()
	node.material_override = _craft.ring_material(tag)
	add_child(node)
	node.global_position = at
	node.scale = Vector3.ONE * radius * (1.0 if Comfort.reduced_motion else 0.35)
	_rings.append({"node": node, "age": 0.0, "radius": radius})
	_rings_spawned += 1


static func _segment_sphere(from: Vector3, to: Vector3, center: Vector3, radius: float) -> float:
	if center == Vector3.INF:
		return -1.0
	var d := to - from
	var f := from - center
	var a := d.dot(d)
	var c := f.dot(f) - radius * radius
	if c <= 0.0:
		return 0.0
	if a < 1e-8:
		return -1.0
	var b := 2.0 * f.dot(d)
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var hit_t := (-b - sqrt(disc)) / (2.0 * a)
	return hit_t if hit_t >= 0.0 and hit_t <= 1.0 else -1.0
