extends Node3D


const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const EnvTags := preload("res://src/experimental/env_tags.gd")
const ChunkSockets := preload("res://src/experimental/arena_chunk_socket.gd")
const SetpieceCraft := preload("res://src/presentation/craft/experimental_setpiece_craft.gd")
const PropMotionRig := preload("res://src/presentation/prop_motion_rig.gd")
const Comfort := preload("res://src/core/comfort.gd")

signal env_tag_emitted(payload: Dictionary)
signal cover_relocated(from_slot: String, to_slot: String, world_pos: Vector3)
signal slag_berms_changed(active_count: int)
signal prop_interaction_triggered(prop_id: String, interaction: String, world_origin: Vector3)


const WORLD_LAYER := 1
const MIN_WARN_FLOOR_S := 0.6
const DEFAULT_CRUISE_MPS := 14.0
const BALL_CLEAR_HOLD_M := 4.6
const MAX_ACTIVE_TAGS := 32

const CRANE_IDLE_S := 5.0
const CRANE_TELEGRAPH_S := 1.2
const CRANE_SWEEP_S := 2.6
const CRANE_DROP_S := 0.8
const CRANE_MAGNET_RADIUS_M := 11.0
const CRANE_PULL_SPEED_MPS := 14.0
const CRANE_BRIDGE_HEIGHT_M := 14.0
const CARGO_HULL_SIZE := Vector3(5.0, 3.2, 3.4)
const CRANE_DROP_CRUSH_RADIUS_M := 5.5
const CRANE_DROP_CRUSH_DAMAGE := 65.0

const CRYO_PIPE_RADIUS_M := 14.0
const CRYO_PIPE_COOLDOWN_S := 12.0
const CRYO_PIPE_TAG_TTL_S := 3.0

const SLAG_DORMANT_S := 4.5
const SLAG_TELEGRAPH_S := 1.6
const SLAG_MOLTEN_S := 4.0
const SLAG_BERM_LIFE_S := 8.5
const SLAG_BASIN_RADIUS_M := 11.0
const SLAG_BERM_SIZE := Vector3(4.2, 2.4, 1.8)
const SLAG_BERM_RING_R := 7.0
const SLAG_BERM_COUNT := 3
const SLAG_STALL_DAMAGE_PER_S := 12.0

const COMPACTOR_SEALED_S := 3.0
const COMPACTOR_OPEN_WARN_S := 0.8
const COMPACTOR_OPEN_S := 3.5
const COMPACTOR_CLOSE_WARN_S := 1.2
const COMPACTOR_CRUSH_S := 0.6
const COMPACTOR_HALF_WIDTH_M := 3.2
const COMPACTOR_HALF_LENGTH_M := 5.0
const COMPACTOR_BOOST_ACCEL := 10.0
const COMPACTOR_STALL_ENEMY_DMG := 45.0
const COMPACTOR_STALL_BALL_DMG := 14.0

const PAD_TRIGGER_RADIUS_M := 2.4
const PAD_TRIGGER_HEIGHT_M := 2.6
const PAD_BODY_MASK := 7
const PAD_REARM_S := 0.45
const PAD_MIN_UP_MPS := 16.5
const PAD_APEX_CLEAR_M := 1.4
const PAD_MAX_PLANAR_MPS := 9.0
const PAD_FLIGHT_MAX_S := 3.0
const PAD_DECK_CLEAR_M := 0.1
const PAD_DEFAULT_BODY_RADIUS_M := 1.0

var cruise_speed := DEFAULT_CRUISE_MPS
var _rng := RandomNumberGenerator.new()
var _berm_phase_offset := 0.0
var _active_tags: Array[Dictionary] = []
var _clock_s := 0.0
var _exiting := false

var _crane: Dictionary = {}
var _furnace: Dictionary = {}
var _compactor: Dictionary = {}
var _cryo_pipes: Array[Dictionary] = []
var _pads: Array[Dictionary] = []
var _pad_decks: Array[StaticBody3D] = []
var _pad_flights: Array[Dictionary] = []
var _pad_facts: Array[Dictionary] = []


func _to_local_point(world_pos: Vector3) -> Vector3:
	return to_local(world_pos) if is_inside_tree() else world_pos


func _to_world_point(local_pos: Vector3) -> Vector3:
	return to_global(local_pos) if is_inside_tree() else local_pos


func _to_local_dir(world_vec: Vector3) -> Vector3:
	return (global_transform.basis.inverse() * world_vec) if is_inside_tree() else world_vec


func _to_world_dir(local_vec: Vector3) -> Vector3:
	return (global_transform.basis * local_vec) if is_inside_tree() else local_vec



func setup_from_chunk(chunk_root: Node, opts: Dictionary = {}) -> Dictionary:
	teardown()
	_exiting = false
	name = "DynamicSetpieces"
	cruise_speed = float(opts.get("cruise_speed", DEFAULT_CRUISE_MPS))
	_rng.seed = int(opts.get("seed", 20261126))
	_berm_phase_offset = _rng.randf() * (PI / 3.0)

	var sockets := ChunkSockets.discover_sockets(chunk_root)
	var cover_slots: Array[Dictionary] = []
	var crane_pos := Vector3(0.0, 19.5, 0.0)
	var furnace_pos := Vector3(0.0, 0.2, 0.0)
	var compactor_pos := Vector3(0.0, 0.2, 23.0)
	var crane_id := "setpiece_em_crane"
	var furnace_id := "setpiece_slag_furnace"
	var compactor_id := "setpiece_compactor_vent"
	var cryo_specs: Array[Dictionary] = []
	var pad_sockets: Array[Dictionary] = []
	var local_by_id := {}

	for s in sockets:
		local_by_id[String(s["id"])] = _to_local_point(s["position"] as Vector3)
		if s["kind"] == ChunkSockets.SOCKET_JUMP_PAD:
			pad_sockets.append(s)
	for s in sockets:
		var local_pos := _to_local_point(s["position"] as Vector3)
		if s["kind"] == ChunkSockets.SOCKET_COVER_SLOT:
			var slot_copy := s.duplicate()
			slot_copy["position"] = local_pos
			cover_slots.append(slot_copy)
		elif s["kind"] == ChunkSockets.SOCKET_SETPIECE_TRIGGER:
			var sp_kind := String((s["meta"] as Dictionary).get(ChunkSockets.META_SETPIECE_KIND, ""))
			match sp_kind:
				"em_crane":
					crane_pos = local_pos
					crane_id = String(s["id"])
				"slag_furnace":
					furnace_pos = local_pos
					furnace_id = String(s["id"])
				"compactor_vent":
					compactor_pos = local_pos
					compactor_id = String(s["id"])
				"cryo_pipe":
					cryo_specs.append({"id": String(s["id"]), "origin": local_pos})

	cover_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai := int((a["meta"] as Dictionary).get(ChunkSockets.META_COVER_SLOT_INDEX, 0))
		var bi := int((b["meta"] as Dictionary).get(ChunkSockets.META_COVER_SLOT_INDEX, 0))
		return ai < bi or (ai == bi and String(a["id"]) < String(b["id"]))
	)
	if cover_slots.size() < 2:
		cover_slots = [
			{"id": "fallback_slot_a", "position": Vector3(-14.0, 0.0, 6.0)},
			{"id": "fallback_slot_b", "position": Vector3(14.0, 0.0, -6.0)},
		]

	_build_crane(crane_id, crane_pos, cover_slots)
	_build_furnace(furnace_id, furnace_pos)
	_build_compactor(compactor_id, compactor_pos)
	if cryo_specs.is_empty():
		cryo_specs.append({"id": "prop_cryo_pipe", "origin": furnace_pos + Vector3(-11.0, 1.4, -2.0)})
	for cspec in cryo_specs:
		_cryo_pipes.append({
			"id": String(cspec["id"]),
			"origin": cspec["origin"],
			"cooldown_left": 0.0,
			"ruptures": 0,
		})
	_pad_decks = _collect_decks(chunk_root)
	for pad_socket in pad_sockets:
		_build_jump_pad(pad_socket, local_by_id)

	return {
		"crane_id": crane_id,
		"furnace_id": furnace_id,
		"compactor_id": compactor_id,
		"cryo_pipe_id": String(_cryo_pipes[0]["id"]),
		"cover_slot_count": cover_slots.size(),
		"jump_pad_count": _pads.size(),
	}


func teardown() -> void:
	_active_tags.clear()
	_clock_s = 0.0
	for flight in _pad_flights:
		_end_pad_flight(flight)
	_pad_flights.clear()
	_pads.clear()
	_pad_decks.clear()
	_pad_facts.clear()
	for child in get_children():
		_disable_colliders_recursive(child)
		if not _exiting:
			remove_child(child)
			child.queue_free()
	var crane_rig: Variant = _crane.get("motion_rig")
	if crane_rig is PropMotionRig:
		(crane_rig as PropMotionRig).clear()
	_crane.clear()
	_furnace.clear()
	_compactor.clear()
	_cryo_pipes.clear()


func _exit_tree() -> void:
	_exiting = true
	teardown()


static func _disable_colliders_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	elif node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_disable_colliders_recursive(child)



func trigger_setpiece(setpiece_id: String, _by := "player") -> bool:
	if not _crane.is_empty() and String(_crane["id"]) == setpiece_id:
		if String(_crane["state"]) == "idle":
			_enter_crane_telegraph()
			return true
		return false
	if not _furnace.is_empty() and String(_furnace["id"]) == setpiece_id:
		if String(_furnace["state"]) == "dormant":
			_enter_furnace_telegraph()
			return true
		return false
	if not _compactor.is_empty() and String(_compactor["id"]) == setpiece_id:
		if String(_compactor["state"]) == "sealed":
			_enter_compactor_open_warn()
			return true
		return false
	for pipe in _cryo_pipes:
		if String(pipe["id"]) == setpiece_id:
			return not rupture_cryo_pipe(setpiece_id).is_empty()
	return false


func strike_crane_magnet(actors: Array = [], ball_pos: Vector3 = Vector3(9999.0, 0.0, 9999.0)) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	if _crane.is_empty() or String(_crane["state"]) != "sweep_active":
		return facts
	var trolley_local: Vector3 = _crane["trolley_pos"]
	var drop_local := Vector3(trolley_local.x, 0.0, trolley_local.z)
	var ball_local := _to_local_point(ball_pos)
	var to_ball := Vector2(ball_local.x - drop_local.x, ball_local.z - drop_local.z)
	if to_ball.length() < BALL_CLEAR_HOLD_M:
		var push_dir := (to_ball.normalized() if to_ball.length() > 0.01 else Vector2(1.0, 0.0))
		drop_local.x -= push_dir.x * BALL_CLEAR_HOLD_M
		drop_local.z -= push_dir.y * BALL_CLEAR_HOLD_M

	var hb: StaticBody3D = _crane["hull_body"]
	var hs: CollisionShape3D = _crane["hull_shape"]
	hb.position = Vector3(drop_local.x, CARGO_HULL_SIZE.y * 0.5, drop_local.z)
	hb.collision_layer = 1 << (WORLD_LAYER - 1)
	hs.disabled = false
	_crane["hull_origin"] = drop_local
	(_crane["telegraph_mesh"] as MeshInstance3D).visible = false
	(_crane["bridge_mesh"] as MeshInstance3D).visible = false
	(_crane["hoist_root"] as Node3D).visible = false
	_crane["bridge_open"] = false
	_crane["state"] = "idle"
	_crane["timer"] = CRANE_IDLE_S
	_crane["magnet_drops"] = int(_crane.get("magnet_drops", 0)) + 1
	_on_cargo_touchdown(1.35)

	var drop_world := _to_world_point(drop_local)
	var hull_world := _to_world_point(hb.position)
	var enemies_crushed := 0
	for actor in actors:
		if actor is Dictionary and String((actor as Dictionary).get("kind", "")) == "enemy":
			var apos_local := _to_local_point(actor["position"] as Vector3)
			if Vector2(apos_local.x - drop_local.x, apos_local.z - drop_local.z).length() <= CRANE_DROP_CRUSH_RADIUS_M:
				actor["hp"] = maxf(0.0, float(actor.get("hp", 100.0)) - CRANE_DROP_CRUSH_DAMAGE)
				enemies_crushed += 1
				facts.append({
					"kind": "crane_magnet_drop_crush",
					"setpiece_id": _crane["id"],
					"target_id": actor.get("id", ""),
					"damage": CRANE_DROP_CRUSH_DAMAGE,
					"position": drop_world,
				})

	_publish_tag(EnvTags.TAG_ELECTRIFIED, drop_local + Vector3.UP * 1.0, CRANE_DROP_CRUSH_RADIUS_M, "crane_magnet_drop:" + String(_crane["id"]), 1.2, 0.6, facts)
	prop_interaction_triggered.emit(String(_crane["id"]), "magnet_drop", drop_world)
	facts.append({
		"kind": "harpoon_bridge_closed",
		"setpiece_id": _crane["id"],
	})
	facts.append({
		"kind": "crane_magnet_dropped",
		"setpiece_id": _crane["id"],
		"position": hull_world,
		"enemies_crushed": enemies_crushed,
	})
	return facts


func rupture_cryo_pipe(pipe_id := "") -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	for pipe in _cryo_pipes:
		if pipe_id != "" and String(pipe["id"]) != pipe_id:
			continue
		if float(pipe["cooldown_left"]) > 0.0:
			if pipe_id != "":
				return facts
			continue
		pipe["cooldown_left"] = CRYO_PIPE_COOLDOWN_S
		pipe["ruptures"] = int(pipe["ruptures"]) + 1
		var origin_local: Vector3 = pipe["origin"]
		var origin_world := _to_world_point(origin_local)
		var pid := String(pipe["id"])
		_publish_tag(EnvTags.TAG_COOLANT_BRITTLE, origin_local, CRYO_PIPE_RADIUS_M, "cryo_pipe:" + pid, 1.2, CRYO_PIPE_TAG_TTL_S, facts)
		var world_payload := EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, origin_world, CRYO_PIPE_RADIUS_M, "cryo_pipe:" + pid, 1.2, CRYO_PIPE_TAG_TTL_S, EnvTags.BOUNDS_SETPIECE)
		var reactions := apply_external_tag(world_payload)
		facts.append_array(reactions)
		prop_interaction_triggered.emit(pid, "cryo_rupture", origin_world)
		facts.append({
			"kind": "cryo_pipe_ruptured",
			"prop_id": pid,
			"origin": origin_world,
		})
		return facts
	return facts


func apply_external_tag(payload: Dictionary) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	if not EnvTags.is_valid_payload(payload, EnvTags.BOUNDS_SETPIECE):
		return facts
	var tag: StringName = payload["tag"]
	var world_origin: Vector3 = payload["origin"]
	var local_origin := _to_local_point(world_origin)
	var radius: float = float(payload["radius_m"])
	_upsert_active_tag(payload)

	if not _furnace.is_empty() and String(_furnace["state"]) == "molten_pour" and not bool(_furnace["quenched_this_cycle"]):
		if tag == EnvTags.TAG_COOLANT_BRITTLE or tag == EnvTags.TAG_SOAKED_CONDUCTIVE:
			var f_local: Vector3 = _furnace["origin"]
			var dist := Vector2(local_origin.x - f_local.x, local_origin.z - f_local.z).length()
			if dist <= SLAG_BASIN_RADIUS_M + radius:
				_furnace["quenched_this_cycle"] = true
				_enter_furnace_cooling(1, facts)
				facts.append({
					"kind": "slag_flash_quenched",
					"setpiece_id": _furnace["id"],
					"by_tag": tag,
					"berm_tier": 1,
					"origin": _to_world_point(f_local),
				})

	if not _crane.is_empty() and String(_crane["state"]) == "sweep_active" and not bool(_crane["supercharged_this_cycle"]):
		if tag == EnvTags.TAG_ELECTRIFIED:
			var trolley_local: Vector3 = _crane["trolley_pos"]
			var dist := Vector2(local_origin.x - trolley_local.x, local_origin.z - trolley_local.z).length()
			if dist <= CRANE_MAGNET_RADIUS_M + radius:
				_crane["supercharged_this_cycle"] = true
				facts.append({
					"kind": "crane_magnet_supercharged",
					"setpiece_id": _crane["id"],
					"origin": _to_world_point(trolley_local),
				})
	return facts


func on_blast(at: Vector3, radius: float, heft_class: int, tier_bonus: int = 1) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	if _furnace.is_empty():
		return facts
	var local_at := _to_local_point(at)
	var effective := heft_class + clampi(tier_bonus, 0, 1)
	for berm in _furnace["berms"]:
		if not bool(berm["intact"]):
			continue
		if effective < int(berm["tier"]):
			continue
		var d := local_at.distance_to(berm["origin"] as Vector3)
		if d <= radius + SLAG_BERM_SIZE.x * 0.5:
			_shatter_slag_berm(berm, "blast", facts)
	return facts


func active_env_tags() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in _active_tags:
		out.append(t.duplicate())
	return out


func tags_at(world_point: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in _active_tags:
		var o: Vector3 = t["origin"]
		var r: float = float(t["radius_m"])
		if Vector2(world_point.x - o.x, world_point.z - o.z).length() <= r:
			out.append(t.duplicate())
	return out


func snapshot() -> Dictionary:
	var crane_snap := {}
	if not _crane.is_empty():
		var slots: Array = _crane["cover_slots"]
		var cur_idx: int = int(_crane["slot_index"])
		crane_snap = {
			"id": _crane["id"],
			"state": _crane["state"],
			"slot_index": cur_idx,
			"slot_id": String(slots[cur_idx]["id"]),
			"hull_position": _to_world_point((_crane["hull_body"] as StaticBody3D).position),
			"hull_layer": (_crane["hull_body"] as StaticBody3D).collision_layer,
			"harpoon_bridge_open": bool(_crane["bridge_open"]),
			"harpoon_bridge_pos": _to_world_point(_crane["bridge_pos"] as Vector3),
			"relocations": int(_crane["relocations"]),
			"telegraph_visible": (_crane["telegraph_mesh"] as MeshInstance3D).visible,
			"warn_elapsed": float(_crane["warn_elapsed"]),
		}
	var furnace_snap := {}
	if not _furnace.is_empty():
		var intact_berms := 0
		var berm_tiers: Array[int] = []
		for b in _furnace["berms"]:
			if bool(b["intact"]):
				intact_berms += 1
				berm_tiers.append(int(b["tier"]))
		furnace_snap = {
			"id": _furnace["id"],
			"state": _furnace["state"],
			"intact_berms": intact_berms,
			"berm_tiers": berm_tiers,
			"cycles_completed": int(_furnace["cycles_completed"]),
			"berms_shattered": int(_furnace["berms_shattered"]),
			"molten_active": String(_furnace["state"]) == "molten_pour",
			"basin_clear": String(_furnace["state"]) != "molten_pour" and intact_berms == 0,
			"telegraph_visible": (_furnace["telegraph_mesh"] as MeshInstance3D).visible,
		}
	var compactor_snap := {}
	if not _compactor.is_empty():
		compactor_snap = {
			"id": _compactor["id"],
			"state": _compactor["state"],
			"lane_open": String(_compactor["state"]) == "high_speed_open",
			"ram_layer": (_compactor["ram_body"] as StaticBody3D).collision_layer,
			"stalled_crushes": int(_compactor["stalled_crushes"]),
			"fast_boosts": int(_compactor["fast_boosts"]),
		}
	var pad_snaps: Array[Dictionary] = []
	for pad in _pads:
		pad_snaps.append({
			"id": pad["id"],
			"origin": _to_world_point(pad["origin"] as Vector3),
			"launches": int(pad["launches"]),
			"armed": float(pad["cooldown_left"]) <= 0.0,
		})
	return {
		"clock_s": _clock_s,
		"active_tag_count": _active_tags.size(),
		"crane": crane_snap,
		"furnace": furnace_snap,
		"compactor": compactor_snap,
		"jump_pads": pad_snaps,
	}



func step(delta: float, ball_pos: Vector3, ball_vel: Vector3, heft_class: int = 1, actors: Array = []) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	if delta <= 0.0:
		return facts
	_clock_s += delta
	_expire_tags(delta)

	var ball_local := _to_local_point(ball_pos)
	var vel_local := _to_local_dir(ball_vel)
	var planar_speed := Vector2(vel_local.x, vel_local.z).length()
	var fast_enough := planar_speed >= cruise_speed * SpeedTier.MULTIPLES[SpeedTier.CRUISE]

	if not _crane.is_empty():
		_step_crane(delta, ball_local, actors, facts)
	if not _furnace.is_empty():
		_step_furnace(delta, ball_local, ball_pos, planar_speed, fast_enough, heft_class, facts)
	if not _compactor.is_empty():
		_step_compactor(delta, ball_local, vel_local, fast_enough, actors, facts)
	for pipe in _cryo_pipes:
		pipe["cooldown_left"] = maxf(0.0, float(pipe["cooldown_left"]) - delta)
	facts.append_array(_pad_facts)
	_pad_facts.clear()

	return facts


func _physics_process(delta: float) -> void:
	_step_pad_flights(delta)
	for pad in _pads:
		pad["cooldown_left"] = maxf(0.0, float(pad["cooldown_left"]) - delta)
		if float(pad["cooldown_left"]) > 0.0:
			continue
		var area := pad["area"] as Area3D
		if not is_instance_valid(area) or not area.is_inside_tree():
			continue
		for body in area.get_overlapping_bodies():
			if body is RigidBody3D and not (body as RigidBody3D).freeze:
				_launch_from_pad(pad, body as RigidBody3D)


static func _collect_decks(chunk_root: Node) -> Array[StaticBody3D]:
	var decks: Array[StaticBody3D] = []
	if chunk_root == null or not is_instance_valid(chunk_root):
		return decks
	var stack: Array[Node] = [chunk_root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is StaticBody3D and String(cur.get_meta(ChunkSockets.META_COVER_KIND, "")) == "deck":
			decks.append(cur as StaticBody3D)
		for child in cur.get_children():
			stack.append(child)
	return decks


func _build_jump_pad(socket: Dictionary, local_by_id: Dictionary) -> void:
	var id := String(socket["id"])
	var origin: Vector3 = local_by_id[id]
	var has_target := false
	var target := origin
	for link in socket["route_links"]:
		if local_by_id.has(String(link)):
			target = local_by_id[String(link)]
			has_target = true
			break

	var area := Area3D.new()
	area.name = "JumpPadTrigger_" + id
	area.collision_layer = 0
	area.collision_mask = PAD_BODY_MASK
	area.monitorable = false
	area.position = Vector3(origin.x, origin.y + PAD_TRIGGER_HEIGHT_M * 0.5 - 0.3, origin.z)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = PAD_TRIGGER_RADIUS_M
	cyl.height = PAD_TRIGGER_HEIGHT_M
	shape.shape = cyl
	area.add_child(shape)
	add_child(area)

	_pads.append({
		"id": id,
		"origin": origin,
		"target": target,
		"has_target": has_target,
		"area": area,
		"cooldown_left": 0.0,
		"launches": 0,
	})


static func _body_radius(body: RigidBody3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is SphereShape3D:
			return ((child as CollisionShape3D).shape as SphereShape3D).radius
	return PAD_DEFAULT_BODY_RADIUS_M


static func _body_gravity(body: RigidBody3D) -> float:
	var base := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	return maxf(0.5, base * body.gravity_scale)


func _pad_launch_velocity(pad: Dictionary, from_local: Vector3, gravity_mps2: float, body_radius_m: float) -> Vector3:
	var gravity := maxf(0.5, gravity_mps2)
	if not bool(pad["has_target"]):
		return Vector3(0.0, PAD_MIN_UP_MPS, 0.0)
	var target: Vector3 = pad["target"]
	var land_y := target.y + body_radius_m
	var rise := maxf(0.0, land_y + PAD_APEX_CLEAR_M - from_local.y)
	var up := maxf(PAD_MIN_UP_MPS, sqrt(2.0 * gravity * rise))
	var climb := land_y - from_local.y
	var flight_s := (up + sqrt(maxf(0.0, up * up - 2.0 * gravity * climb))) / gravity
	var planar := Vector3(target.x - from_local.x, 0.0, target.z - from_local.z) / maxf(flight_s, 0.05)
	if planar.length() > PAD_MAX_PLANAR_MPS:
		planar = planar.normalized() * PAD_MAX_PLANAR_MPS
	return Vector3(planar.x, up, planar.z)


func _launch_from_pad(pad: Dictionary, body: RigidBody3D) -> void:
	var radius := _body_radius(body)
	var from_world := body.global_position
	var velocity := _to_world_dir(_pad_launch_velocity(pad, _to_local_point(from_world), _body_gravity(body), radius))
	pad["cooldown_left"] = PAD_REARM_S
	pad["launches"] = int(pad["launches"]) + 1
	_begin_pad_flight(body, radius)
	var rider := body.get_parent()
	if rider != null and rider.has_method("set_velocity_now"):
		rider.call("set_velocity_now", velocity)
	elif body.has_method("set_velocity_now"):
		body.call("set_velocity_now", velocity)
	else:
		body.linear_velocity = velocity
	var pad_world := _to_world_point(pad["origin"] as Vector3)
	prop_interaction_triggered.emit(String(pad["id"]), "jump_pad_launch", pad_world)
	_pad_facts.append({
		"kind": "jump_pad_launched",
		"pad_id": pad["id"],
		"position": pad_world,
		"velocity": velocity,
	})


func _begin_pad_flight(body: RigidBody3D, radius: float) -> void:
	for flight in _pad_flights:
		if flight["body"] == body:
			_end_pad_flight(flight)
	_pad_flights = _pad_flights.filter(func(f: Dictionary) -> bool: return f["body"] != body)
	var held: Array[StaticBody3D] = []
	for deck in _pad_decks:
		if is_instance_valid(deck):
			_set_deck_exception(body, deck, true)
			held.append(deck)
	_pad_flights.append({"body": body, "radius": radius, "decks": held, "left_s": PAD_FLIGHT_MAX_S})


func _step_pad_flights(delta: float) -> void:
	if _pad_flights.is_empty():
		return
	var kept: Array[Dictionary] = []
	for flight in _pad_flights:
		var body: Variant = flight["body"]
		if not is_instance_valid(body):
			continue
		var rigid := body as RigidBody3D
		flight["left_s"] = float(flight["left_s"]) - delta
		var radius := float(flight["radius"])
		var y := rigid.global_position.y
		var falling := rigid.linear_velocity.y <= 0.0
		var still_held: Array[StaticBody3D] = []
		for deck in flight["decks"]:
			if not is_instance_valid(deck):
				continue
			var slab := _deck_slab(deck)
			var above := y - radius >= slab.y + PAD_DECK_CLEAR_M
			var below := y + radius <= slab.x - PAD_DECK_CLEAR_M
			if above or (below and falling) or float(flight["left_s"]) <= 0.0:
				_set_deck_exception(rigid, deck, false)
			else:
				still_held.append(deck)
		flight["decks"] = still_held
		if not still_held.is_empty():
			kept.append(flight)
	_pad_flights = kept


func _end_pad_flight(flight: Dictionary) -> void:
	var body: Variant = flight["body"]
	if not is_instance_valid(body):
		return
	for deck in flight["decks"]:
		if is_instance_valid(deck):
			_set_deck_exception(body as RigidBody3D, deck, false)
	flight["decks"] = []


static func _set_deck_exception(body: RigidBody3D, deck: StaticBody3D, held: bool) -> void:
	if held:
		body.add_collision_exception_with(deck)
	else:
		body.remove_collision_exception_with(deck)
	for child in body.get_children():
		if child is ShapeCast3D:
			if held:
				(child as ShapeCast3D).add_exception(deck)
			else:
				(child as ShapeCast3D).remove_exception(deck)


static func _deck_slab(deck: StaticBody3D) -> Vector2:
	var low := INF
	var high := -INF
	for child in deck.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var cs := child as CollisionShape3D
			var half := (cs.shape as BoxShape3D).size.y * 0.5
			var centre := cs.global_position.y if cs.is_inside_tree() else deck.position.y + cs.position.y
			low = minf(low, centre - half)
			high = maxf(high, centre + half)
	if low == INF:
		var at := deck.global_position.y if deck.is_inside_tree() else deck.position.y
		return Vector2(at, at)
	return Vector2(low, high)



func _build_crane(id: String, origin_local: Vector3, cover_slots: Array[Dictionary]) -> void:
	var root := Node3D.new()
	root.name = "EMCrane_" + id
	add_child(root)

	var first_pos: Vector3 = cover_slots[0]["position"]
	var hull_body := StaticBody3D.new()
	hull_body.name = "SalvageCargoHull"
	hull_body.collision_layer = 1 << (WORLD_LAYER - 1)
	hull_body.collision_mask = 0
	hull_body.set_meta(ChunkSockets.META_COVER_KIND, "hard")
	hull_body.position = Vector3(first_pos.x, first_pos.y + CARGO_HULL_SIZE.y * 0.5, first_pos.z)
	var hull_shape := CollisionShape3D.new()
	var hull_box := BoxShape3D.new()
	hull_box.size = CARGO_HULL_SIZE
	hull_shape.shape = hull_box
	hull_body.add_child(hull_shape)
	var hull_pivot := Node3D.new()
	hull_pivot.name = "CargoVisualPivot"
	hull_body.add_child(hull_pivot)
	var hull_mesh := MeshInstance3D.new()
	hull_mesh.name = "CargoHullMesh"
	hull_mesh.mesh = SetpieceCraft.get_cargo_hull_mesh(CARGO_HULL_SIZE)
	SetpieceCraft.bind_surface_materials(hull_mesh)
	hull_pivot.add_child(hull_mesh)
	root.add_child(hull_body)

	var cargo_rig := PropMotionRig.new()
	cargo_rig.reduced_motion = Comfort.reduced_motion
	cargo_rig.add_part("cargo_hull", hull_pivot, {
		"sway": true,
		"sway_stiffness": 18.0,
		"sway_damping": 3.4,
		"sway_gain": 0.028,
		"sway_max_rad": 0.34,
		"sway_ambient_amp": 0.0,
		"sway_ambient_hz": 0.55,
		"jolt_stiffness": 140.0,
		"jolt_damping": 12.0,
		"jolt_max_offset": 0.28,
		"jolt_rot_gain": 0.35,
	})

	var tele := MeshInstance3D.new()
	tele.name = "CraneHazardCorridor"
	tele.mesh = SetpieceCraft.build_hazard_strip_pad(7.0, 28.0, 0.05)
	SetpieceCraft.bind_surface_materials(tele)
	tele.position = Vector3(origin_local.x, 0.12, origin_local.z)
	tele.visible = false
	root.add_child(tele)

	var bridge := MeshInstance3D.new()
	bridge.name = "AirborneHarpoonBridge"
	bridge.mesh = SetpieceCraft.get_harpoon_bridge_mesh(1.4, 0.8)
	SetpieceCraft.bind_surface_materials(bridge)
	bridge.position = Vector3(origin_local.x, CRANE_BRIDGE_HEIGHT_M, origin_local.z)
	bridge.visible = false
	root.add_child(bridge)

	var hoist_root := Node3D.new()
	hoist_root.name = "CargoHoistRigging"
	hoist_root.visible = false
	root.add_child(hoist_root)

	var trolley_mi := MeshInstance3D.new()
	trolley_mi.name = "CraneTrolleyCarriage"
	trolley_mi.mesh = SetpieceCraft.get_hoist_trolley_mesh()
	SetpieceCraft.bind_surface_materials(trolley_mi)
	hoist_root.add_child(trolley_mi)

	var main_cable := MeshInstance3D.new()
	main_cable.name = "MainHoistCable"
	main_cable.mesh = SetpieceCraft.get_hoist_cable_mesh()
	SetpieceCraft.bind_surface_materials(main_cable)
	hoist_root.add_child(main_cable)

	var sling_cables: Array[MeshInstance3D] = []
	for ci in 4:
		var sc := MeshInstance3D.new()
		sc.name = "SlingCable_%d" % ci
		sc.mesh = SetpieceCraft.get_hoist_cable_mesh()
		SetpieceCraft.bind_surface_materials(sc)
		hoist_root.add_child(sc)
		sling_cables.append(sc)

	_crane = {
		"id": id,
		"origin": origin_local,
		"root": root,
		"cover_slots": cover_slots,
		"slot_index": 0,
		"target_slot_index": 1 % cover_slots.size(),
		"hull_body": hull_body,
		"hull_shape": hull_shape,
		"hull_pivot": hull_pivot,
		"hull_mesh": hull_mesh,
		"motion_rig": cargo_rig,
		"prev_sweep_xz": first_pos,
		"hull_origin": first_pos,
		"telegraph_mesh": tele,
		"bridge_mesh": bridge,
		"hoist_root": hoist_root,
		"trolley_mesh": trolley_mi,
		"main_cable": main_cable,
		"sling_cables": sling_cables,
		"bridge_open": false,
		"bridge_pos": Vector3(origin_local.x, CRANE_BRIDGE_HEIGHT_M, origin_local.z),
		"trolley_pos": Vector3(first_pos.x, origin_local.y, first_pos.z),
		"state": "idle",
		"timer": CRANE_IDLE_S,
		"warn_elapsed": 0.0,
		"tag_cooldown": 0.0,
		"relocations": 0,
		"supercharged_this_cycle": false,
	}


static func _orient_cable_segment(cable: MeshInstance3D, p_start: Vector3, p_end: Vector3, radius_scale: float = 1.0) -> void:
	var delta := p_end - p_start
	var length := maxf(delta.length(), 0.05)
	var y_axis := delta / length if delta.length() > 0.001 else Vector3.UP
	var ref := Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x_axis := ref.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	cable.position = (p_start + p_end) * 0.5
	cable.basis = Basis(x_axis * radius_scale, y_axis * length, z_axis * radius_scale)


func _update_crane_hoist_rigging() -> void:
	var hoist_root := _crane.get("hoist_root") as Node3D
	if hoist_root == null:
		return
	var state := String(_crane.get("state", "idle"))
	var active := state == "sweep_active" or state == "relocate_drop"
	hoist_root.visible = active
	if not active:
		return
	var hb := _crane["hull_body"] as StaticBody3D
	var hp := _crane["hull_pivot"] as Node3D
	var bridge_pos: Vector3 = _crane["bridge_pos"]
	var trolley_pos: Vector3 = _crane["trolley_pos"]
	var trolley_mi := _crane["trolley_mesh"] as MeshInstance3D
	trolley_mi.position = Vector3(trolley_pos.x, trolley_pos.y + 0.18, trolley_pos.z)
	var main_cable := _crane["main_cable"] as MeshInstance3D
	_orient_cable_segment(
		main_cable,
		bridge_pos + Vector3(0.0, 0.36, 0.0),
		Vector3(trolley_pos.x, trolley_pos.y - 0.38, trolley_pos.z),
		1.55
	)
	var lug_x := CARGO_HULL_SIZE.x * 0.22
	var lug_y := CARGO_HULL_SIZE.y * 0.5 + 0.22
	var lug_z := CARGO_HULL_SIZE.z * 0.18
	var corners := [
		Vector3(-lug_x, lug_y, -lug_z),
		Vector3(lug_x, lug_y, -lug_z),
		Vector3(lug_x, lug_y, lug_z),
		Vector3(-lug_x, lug_y, lug_z),
	]
	var slings: Array = _crane["sling_cables"]
	for i in mini(slings.size(), 4):
		var local_lug: Vector3 = corners[i]
		var lug_root := hb.position + (hp.transform * local_lug)
		var top_shackle := bridge_pos + Vector3(local_lug.x * 0.58, -0.34, local_lug.z * 0.58)
		_orient_cable_segment(slings[i] as MeshInstance3D, lug_root, top_shackle, 1.0)


func _on_cargo_touchdown(impulse_strength: float) -> void:
	var rig: Variant = _crane.get("motion_rig")
	if not (rig is PropMotionRig):
		return
	var pr := rig as PropMotionRig
	pr.reduced_motion = Comfort.reduced_motion
	var part := pr.part("cargo_hull")
	if part != null:
		part.sway_ambient_amp = 0.0
	if Comfort.reduced_motion:
		pr.reset()
	else:
		pr.apply_impulse(Vector3.DOWN, impulse_strength, "cargo_hull")


func _enter_crane_telegraph() -> void:
	var slots: Array = _crane["cover_slots"]
	var cur_idx: int = int(_crane["slot_index"])
	var next_idx := (cur_idx + 1) % slots.size()
	_crane["target_slot_index"] = next_idx
	_crane["state"] = "telegraph"
	_crane["timer"] = CRANE_TELEGRAPH_S
	_crane["warn_elapsed"] = 0.0
	_crane["supercharged_this_cycle"] = false

	var from_p: Vector3 = _crane.get("hull_origin", slots[cur_idx]["position"])
	var to_p: Vector3 = slots[next_idx]["position"]
	var mid := (from_p + to_p) * 0.5
	var dir := Vector3(to_p.x - from_p.x, 0.0, to_p.z - from_p.z)
	var dist := maxf(6.0, dir.length())
	var tele: MeshInstance3D = _crane["telegraph_mesh"]
	tele.mesh = SetpieceCraft.build_hazard_strip_pad(7.0, dist + 4.0, 0.05)
	SetpieceCraft.bind_surface_materials(tele)
	tele.position = Vector3(mid.x, 0.12, mid.z)
	if dir.length() > 0.01:
		tele.rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)
	tele.visible = true


func _step_crane(delta: float, ball_local: Vector3, actors: Array, facts: Array[Dictionary]) -> void:
	var slots: Array = _crane["cover_slots"]
	var cur_idx: int = int(_crane["slot_index"])
	var next_idx: int = int(_crane["target_slot_index"])
	var from_p: Vector3 = _crane.get("hull_origin", slots[cur_idx]["position"])
	var to_p: Vector3 = slots[next_idx]["position"]

	var rig: PropMotionRig = _crane.get("motion_rig") as PropMotionRig
	if rig != null:
		rig.reduced_motion = Comfort.reduced_motion

	match String(_crane["state"]):
		"idle":
			if rig != null:
				rig.step(delta, Vector3.ZERO)
			_crane["timer"] = float(_crane["timer"]) - delta
			if float(_crane["timer"]) <= 0.0:
				_enter_crane_telegraph()
				facts.append({
					"kind": "setpiece_telegraph",
					"setpiece_id": _crane["id"],
					"from_slot": slots[cur_idx]["id"],
					"to_slot": slots[next_idx]["id"],
					"lead_s": CRANE_TELEGRAPH_S,
				})
		"telegraph":
			if rig != null:
				rig.step(delta, Vector3.ZERO)
			_crane["warn_elapsed"] = float(_crane["warn_elapsed"]) + delta
			_crane["timer"] = float(_crane["timer"]) - delta
			if float(_crane["timer"]) <= 0.0 and float(_crane["warn_elapsed"]) >= MIN_WARN_FLOOR_S:
				_crane["state"] = "sweep_active"
				_crane["timer"] = CRANE_SWEEP_S
				_crane["tag_cooldown"] = 0.0
				_crane["bridge_open"] = true
				_crane["prev_sweep_xz"] = from_p
				if rig != null:
					var part := rig.part("cargo_hull")
					if part != null:
						part.sway_ambient_amp = 0.035
				(_crane["bridge_mesh"] as MeshInstance3D).visible = true
				var hb: StaticBody3D = _crane["hull_body"]
				var hs: CollisionShape3D = _crane["hull_shape"]
				hb.collision_layer = 0
				hs.disabled = true
				_update_crane_hoist_rigging()
				facts.append({
					"kind": "harpoon_bridge_opened",
					"setpiece_id": _crane["id"],
					"anchor": _to_world_point(_crane["bridge_pos"] as Vector3),
				})
		"sweep_active":
			_crane["timer"] = float(_crane["timer"]) - delta
			var frac := clampf(1.0 - float(_crane["timer"]) / CRANE_SWEEP_S, 0.0, 1.0)
			var sweep_xz := from_p.lerp(to_p, frac)
			var prev_xz: Vector3 = _crane.get("prev_sweep_xz", sweep_xz)
			var move_vel_local := (sweep_xz - prev_xz) / maxf(delta, 0.001)
			_crane["prev_sweep_xz"] = sweep_xz
			var trolley := Vector3(sweep_xz.x, float((_crane["origin"] as Vector3).y), sweep_xz.z)
			var bridge_pos := Vector3(sweep_xz.x, CRANE_BRIDGE_HEIGHT_M, sweep_xz.z)
			_crane["trolley_pos"] = trolley
			_crane["bridge_pos"] = bridge_pos
			(_crane["bridge_mesh"] as MeshInstance3D).position = bridge_pos
			(_crane["hull_body"] as StaticBody3D).position = Vector3(sweep_xz.x, 7.5 + sin(frac * PI) * 2.5, sweep_xz.z)
			if rig != null:
				rig.step(delta, _to_world_dir(move_vel_local))
			_update_crane_hoist_rigging()

			_crane["tag_cooldown"] = float(_crane["tag_cooldown"]) - delta
			if float(_crane["tag_cooldown"]) <= 0.0:
				_crane["tag_cooldown"] = 0.4
				var intensity := 1.5 if bool(_crane["supercharged_this_cycle"]) else 1.0
				_publish_tag(EnvTags.TAG_MAGNETIC, Vector3(sweep_xz.x, 1.0, sweep_xz.z), CRANE_MAGNET_RADIUS_M, "em_crane:" + String(_crane["id"]), intensity, 0.55, facts)

			var pull_mult := 1.4 if bool(_crane["supercharged_this_cycle"]) else 1.0
			for actor in actors:
				if actor is Dictionary and bool((actor as Dictionary).get("magnetic_pullable", false)):
					var apos_world: Vector3 = actor["position"]
					var apos_local := _to_local_point(apos_world)
					var to_beam := Vector3(sweep_xz.x - apos_local.x, 0.0, sweep_xz.z - apos_local.z)
					var d := to_beam.length()
					if d > 0.25 and d <= CRANE_MAGNET_RADIUS_M:
						var step_local := to_beam.normalized() * minf(d, CRANE_PULL_SPEED_MPS * pull_mult * delta)
						actor["position"] = apos_world + _to_world_dir(step_local)

			if float(_crane["timer"]) <= 0.0:
				_crane["state"] = "relocate_drop"
				_crane["timer"] = CRANE_DROP_S
		"relocate_drop":
			if rig != null:
				rig.step(delta, Vector3.ZERO)
			_update_crane_hoist_rigging()
			_crane["timer"] = float(_crane["timer"]) - delta
			var ball_dist := Vector2(ball_local.x - to_p.x, ball_local.z - to_p.z).length()
			if float(_crane["timer"]) <= 0.0 and ball_dist >= BALL_CLEAR_HOLD_M:
				var hb: StaticBody3D = _crane["hull_body"]
				var hs: CollisionShape3D = _crane["hull_shape"]
				hb.position = Vector3(to_p.x, to_p.y + CARGO_HULL_SIZE.y * 0.5, to_p.z)
				hb.collision_layer = 1 << (WORLD_LAYER - 1)
				hs.disabled = false
				_crane["hull_origin"] = to_p
				(_crane["telegraph_mesh"] as MeshInstance3D).visible = false
				(_crane["bridge_mesh"] as MeshInstance3D).visible = false
				(_crane["hoist_root"] as Node3D).visible = false
				_crane["bridge_open"] = false
				_crane["slot_index"] = next_idx
				_crane["relocations"] = int(_crane["relocations"]) + 1
				_crane["state"] = "idle"
				_crane["timer"] = CRANE_IDLE_S
				_on_cargo_touchdown(1.10)
				var world_hull_pos := _to_world_point(hb.position)
				cover_relocated.emit(String(slots[cur_idx]["id"]), String(slots[next_idx]["id"]), world_hull_pos)
				facts.append({
					"kind": "harpoon_bridge_closed",
					"setpiece_id": _crane["id"],
				})
				facts.append({
					"kind": "cover_relocated",
					"setpiece_id": _crane["id"],
					"from_slot": slots[cur_idx]["id"],
					"to_slot": slots[next_idx]["id"],
					"position": world_hull_pos,
				})



func _build_furnace(id: String, origin_local: Vector3) -> void:
	var root := Node3D.new()
	root.name = "SlagFurnace_" + id
	add_child(root)

	var tele := MeshInstance3D.new()
	tele.name = "SlagHazardRing"
	tele.mesh = SetpieceCraft.get_hazard_disc_pad(SLAG_BASIN_RADIUS_M, 0.08)
	SetpieceCraft.bind_surface_materials(tele)
	tele.position = Vector3(origin_local.x, origin_local.y + 0.08, origin_local.z)
	tele.visible = false
	root.add_child(tele)

	var pool := MeshInstance3D.new()
	pool.name = "MoltenSlagPool"
	pool.mesh = SetpieceCraft.get_molten_slag_pool_mesh(SLAG_BASIN_RADIUS_M, 0.25)
	SetpieceCraft.bind_surface_materials(pool)
	pool.position = Vector3(origin_local.x, origin_local.y + 0.12, origin_local.z)
	pool.visible = false
	root.add_child(pool)

	_furnace = {
		"id": id,
		"origin": origin_local,
		"root": root,
		"telegraph_mesh": tele,
		"pool_mesh": pool,
		"state": "dormant",
		"timer": SLAG_DORMANT_S,
		"tag_cooldown": 0.0,
		"berms": [],
		"cycles_completed": 0,
		"berms_shattered": 0,
		"quenched_this_cycle": false,
	}


func _enter_furnace_telegraph() -> void:
	_clear_slag_berms()
	_furnace["state"] = "telegraph"
	_furnace["timer"] = SLAG_TELEGRAPH_S
	_furnace["quenched_this_cycle"] = false
	(_furnace["telegraph_mesh"] as MeshInstance3D).visible = true
	(_furnace["pool_mesh"] as MeshInstance3D).visible = false


func _enter_furnace_cooling(berm_tier: int, facts: Array[Dictionary]) -> void:
	_furnace["state"] = "cooling_berms"
	_furnace["timer"] = SLAG_BERM_LIFE_S
	(_furnace["telegraph_mesh"] as MeshInstance3D).visible = false
	(_furnace["pool_mesh"] as MeshInstance3D).visible = false
	_spawn_slag_berms(berm_tier, facts)


func _spawn_slag_berms(tier: int, facts: Array[Dictionary]) -> void:
	_clear_slag_berms()
	var origin: Vector3 = _furnace["origin"]
	var root: Node3D = _furnace["root"]
	var cycle_idx: int = int(_furnace["cycles_completed"])
	var angle_offset := _berm_phase_offset + float(cycle_idx) * (PI / 3.0)
	for i in SLAG_BERM_COUNT:
		var ang := angle_offset + TAU * float(i) / float(SLAG_BERM_COUNT)
		var pos := Vector3(
			origin.x + cos(ang) * SLAG_BERM_RING_R,
			origin.y + SLAG_BERM_SIZE.y * 0.5,
			origin.z + sin(ang) * SLAG_BERM_RING_R
		)
		var body := StaticBody3D.new()
		body.name = "SlagBerm_%d_%d" % [cycle_idx, i]
		body.collision_layer = 1 << (WORLD_LAYER - 1)
		body.collision_mask = 0
		body.set_meta(ChunkSockets.META_COVER_KIND, "hard")
		body.set_meta("heft_tier", tier)
		body.position = pos
		body.rotation = Vector3(0.0, -ang + PI * 0.5, 0.0)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = SLAG_BERM_SIZE
		cs.shape = bs
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.name = "SlagBermMesh"
		mi.mesh = SetpieceCraft.get_slag_berm_mesh(SLAG_BERM_SIZE, tier <= 1)
		SetpieceCraft.bind_surface_materials(mi)
		body.add_child(mi)
		root.add_child(body)
		var berm := {
			"id": body.name,
			"tier": tier,
			"origin": pos,
			"body": body,
			"shape": cs,
			"mesh": mi,
			"intact": true,
		}
		(_furnace["berms"] as Array).append(berm)
		facts.append({
			"kind": "slag_berm_formed",
			"berm_id": berm["id"],
			"tier": tier,
			"position": _to_world_point(pos),
		})
	slag_berms_changed.emit(SLAG_BERM_COUNT)


func _clear_slag_berms() -> void:
	if _furnace.is_empty():
		return
	var berms: Array = _furnace.get("berms", [])
	for berm in berms:
		var body: StaticBody3D = berm.get("body")
		var cs: CollisionShape3D = berm.get("shape")
		if body != null and is_instance_valid(body):
			body.collision_layer = 0
			body.collision_mask = 0
			body.visible = false
		if cs != null and is_instance_valid(cs):
			cs.disabled = true
		if body != null and is_instance_valid(body) and not _exiting:
			if body.get_parent() != null:
				body.get_parent().remove_child(body)
			body.queue_free()
	berms.clear()
	slag_berms_changed.emit(0)


func _shatter_slag_berm(berm: Dictionary, by: String, facts: Array[Dictionary]) -> void:
	if not bool(berm["intact"]):
		return
	berm["intact"] = false
	var body: StaticBody3D = berm["body"]
	var cs: CollisionShape3D = berm["shape"]
	var mi: MeshInstance3D = berm["mesh"]
	if body != null and is_instance_valid(body):
		body.collision_layer = 0
		body.collision_mask = 0
	if cs != null and is_instance_valid(cs):
		cs.disabled = true
	if mi != null and is_instance_valid(mi):
		mi.visible = false
	_furnace["berms_shattered"] = int(_furnace["berms_shattered"]) + 1
	var intact_left := 0
	for b in _furnace["berms"]:
		if bool(b["intact"]):
			intact_left += 1
	slag_berms_changed.emit(intact_left)
	facts.append({
		"kind": "slag_berm_shattered",
		"berm_id": berm["id"],
		"tier": int(berm["tier"]),
		"by": by,
		"position": _to_world_point(berm["origin"] as Vector3),
		"scrap_reward": int(Destructibles.LOOT.get(int(berm["tier"]), [2, 1])[0]),
	})


func _step_furnace(
		delta: float,
		ball_local: Vector3,
		ball_world: Vector3,
		planar_speed: float,
		fast_enough: bool,
		heft_class: int,
		facts: Array[Dictionary]
) -> void:
	var origin: Vector3 = _furnace["origin"]
	match String(_furnace["state"]):
		"dormant":
			_furnace["timer"] = float(_furnace["timer"]) - delta
			if float(_furnace["timer"]) <= 0.0:
				_enter_furnace_telegraph()
				facts.append({
					"kind": "setpiece_telegraph",
					"setpiece_id": _furnace["id"],
					"lead_s": SLAG_TELEGRAPH_S,
					"origin": _to_world_point(origin),
				})
		"telegraph":
			_furnace["timer"] = float(_furnace["timer"]) - delta
			if float(_furnace["timer"]) <= 0.0:
				_furnace["state"] = "molten_pour"
				_furnace["timer"] = SLAG_MOLTEN_S
				_furnace["tag_cooldown"] = 0.0
				(_furnace["telegraph_mesh"] as MeshInstance3D).visible = false
				(_furnace["pool_mesh"] as MeshInstance3D).visible = true
		"molten_pour":
			_furnace["timer"] = float(_furnace["timer"]) - delta
			_furnace["tag_cooldown"] = float(_furnace["tag_cooldown"]) - delta
			if float(_furnace["tag_cooldown"]) <= 0.0:
				_furnace["tag_cooldown"] = 0.5
				_publish_tag(EnvTags.TAG_SLAG_COATED, origin, SLAG_BASIN_RADIUS_M, "slag_furnace:" + String(_furnace["id"]), 1.0, 0.7, facts)
				_publish_tag(EnvTags.TAG_BURNING, origin, SLAG_BASIN_RADIUS_M, "slag_furnace:" + String(_furnace["id"]), 1.0, 0.7, facts)
			var horiz := Vector2(ball_local.x - origin.x, ball_local.z - origin.z).length()
			if horiz <= SLAG_BASIN_RADIUS_M and ball_local.y <= origin.y + 1.8 and not fast_enough:
				facts.append({
					"kind": "slag_stall_burn",
					"setpiece_id": _furnace["id"],
					"damage": SLAG_STALL_DAMAGE_PER_S * delta,
					"position": ball_world,
				})
			if float(_furnace["timer"]) <= 0.0:
				var next_tier := 2 if int(_furnace["cycles_completed"]) % 2 == 0 else 3
				_enter_furnace_cooling(next_tier, facts)
		"cooling_berms":
			_furnace["timer"] = float(_furnace["timer"]) - delta
			var berm_reach := Destructibles.WALL_REACH + SLAG_BERM_SIZE.x * 0.5
			for berm in _furnace["berms"]:
				if not bool(berm["intact"]):
					continue
				var bpos: Vector3 = berm["origin"]
				var dist := ball_local.distance_to(bpos)
				var btier := int(berm["tier"])
				var speed_bar := Destructibles.WALL_SPEED if btier <= 1 else cruise_speed * Destructibles.RAM_MIN_PER_CRUISE
				if dist <= berm_reach and heft_class >= btier and planar_speed >= speed_bar:
					_shatter_slag_berm(berm, "ram", facts)
			if float(_furnace["timer"]) <= 0.0:
				_clear_slag_berms()
				_furnace["cycles_completed"] = int(_furnace["cycles_completed"]) + 1
				_furnace["state"] = "dormant"
				_furnace["timer"] = SLAG_DORMANT_S
				facts.append({
					"kind": "slag_cycle_cleared",
					"setpiece_id": _furnace["id"],
					"cycles_completed": _furnace["cycles_completed"],
				})



func _build_compactor(id: String, origin_local: Vector3) -> void:
	var root := Node3D.new()
	root.name = "CompactorVent_" + id
	add_child(root)

	var ram := StaticBody3D.new()
	ram.name = "CompactorRamGate"
	ram.collision_layer = 1 << (WORLD_LAYER - 1)
	ram.collision_mask = 0
	ram.set_meta(ChunkSockets.META_COVER_KIND, "hard")
	ram.position = Vector3(origin_local.x, origin_local.y + 2.0, origin_local.z)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(COMPACTOR_HALF_WIDTH_M * 2.0, 4.0, 1.8)
	cs.shape = bs
	ram.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "CompactorRamMesh"
	mi.mesh = SetpieceCraft.get_compactor_ram_mesh(bs.size)
	SetpieceCraft.bind_surface_materials(mi)
	ram.add_child(mi)
	root.add_child(ram)

	var tele := MeshInstance3D.new()
	tele.name = "CompactorHazardZone"
	tele.mesh = SetpieceCraft.build_hazard_strip_pad(COMPACTOR_HALF_WIDTH_M * 2.0, COMPACTOR_HALF_LENGTH_M * 2.0, 0.05)
	SetpieceCraft.bind_surface_materials(tele)
	tele.position = Vector3(origin_local.x, origin_local.y + 0.1, origin_local.z)
	tele.visible = false
	root.add_child(tele)

	_compactor = {
		"id": id,
		"origin": origin_local,
		"root": root,
		"ram_body": ram,
		"ram_shape": cs,
		"ram_mesh": mi,
		"telegraph_mesh": tele,
		"state": "sealed",
		"timer": COMPACTOR_SEALED_S,
		"crushed_this_snap": false,
		"stalled_crushes": 0,
		"fast_boosts": 0,
	}


func _enter_compactor_open_warn() -> void:
	_compactor["state"] = "telegraph_open"
	_compactor["timer"] = COMPACTOR_OPEN_WARN_S


func _step_compactor(
		delta: float,
		ball_local: Vector3,
		vel_local: Vector3,
		fast_enough: bool,
		actors: Array,
		facts: Array[Dictionary]
) -> void:
	var origin: Vector3 = _compactor["origin"]
	var ram: StaticBody3D = _compactor["ram_body"]
	var cs: CollisionShape3D = _compactor["ram_shape"]
	var mi: MeshInstance3D = _compactor["ram_mesh"]
	var tele: MeshInstance3D = _compactor["telegraph_mesh"]

	match String(_compactor["state"]):
		"sealed":
			_compactor["timer"] = float(_compactor["timer"]) - delta
			if ram.collision_layer == 0 and not _inside_compactor(ball_local, origin):
				ram.collision_layer = 1 << (WORLD_LAYER - 1)
				cs.disabled = false
				mi.visible = true
			if float(_compactor["timer"]) <= 0.0:
				_enter_compactor_open_warn()
		"telegraph_open":
			_compactor["timer"] = float(_compactor["timer"]) - delta
			if float(_compactor["timer"]) <= 0.0:
				_compactor["state"] = "high_speed_open"
				_compactor["timer"] = COMPACTOR_OPEN_S
				ram.collision_layer = 0
				cs.disabled = true
				mi.visible = false
				tele.visible = false
				facts.append({
					"kind": "compactor_lane_opened",
					"setpiece_id": _compactor["id"],
					"origin": _to_world_point(origin),
				})
		"high_speed_open":
			_compactor["timer"] = float(_compactor["timer"]) - delta
			if _inside_compactor(ball_local, origin) and fast_enough:
				var flat_local := Vector3(vel_local.x, 0.0, vel_local.z).normalized()
				_compactor["fast_boosts"] = int(_compactor["fast_boosts"]) + 1
				facts.append({
					"kind": "ball_momentum_boost",
					"setpiece_id": _compactor["id"],
					"accel": _to_world_dir(flat_local * COMPACTOR_BOOST_ACCEL),
				})
			if float(_compactor["timer"]) <= 0.0:
				_compactor["state"] = "telegraph_close"
				_compactor["timer"] = COMPACTOR_CLOSE_WARN_S
				_compactor["crushed_this_snap"] = false
				tele.visible = true
				facts.append({
					"kind": "setpiece_telegraph",
					"setpiece_id": _compactor["id"],
					"lead_s": COMPACTOR_CLOSE_WARN_S,
					"origin": _to_world_point(origin),
				})
		"telegraph_close":
			_compactor["timer"] = float(_compactor["timer"]) - delta
			if float(_compactor["timer"]) <= 0.0:
				_compactor["state"] = "crush_snap"
				_compactor["timer"] = COMPACTOR_CRUSH_S
				tele.visible = false
				if not _inside_compactor(ball_local, origin):
					ram.collision_layer = 1 << (WORLD_LAYER - 1)
					cs.disabled = false
					mi.visible = true
		"crush_snap":
			_compactor["timer"] = float(_compactor["timer"]) - delta
			if not bool(_compactor["crushed_this_snap"]):
				_compactor["crushed_this_snap"] = true
				for actor in actors:
					if actor is Dictionary and String((actor as Dictionary).get("kind", "")) == "enemy":
						var apos_local := _to_local_point(actor["position"] as Vector3)
						var avel: Vector3 = actor.get("velocity", Vector3.ZERO)
						if _inside_compactor(apos_local, origin) and Vector2(avel.x, avel.z).length() < 4.0:
							actor["hp"] = maxf(0.0, float(actor.get("hp", 100.0)) - COMPACTOR_STALL_ENEMY_DMG)
							_compactor["stalled_crushes"] = int(_compactor["stalled_crushes"]) + 1
							facts.append({
								"kind": "compactor_crush_punish",
								"setpiece_id": _compactor["id"],
								"target_id": actor.get("id", ""),
								"damage": COMPACTOR_STALL_ENEMY_DMG,
							})
				if _inside_compactor(ball_local, origin):
					if not fast_enough:
						facts.append({
							"kind": "compactor_crush_punish",
							"setpiece_id": _compactor["id"],
							"target_id": "ball",
							"damage": COMPACTOR_STALL_BALL_DMG,
						})
					else:
						var eject_local := Vector3(vel_local.x, 0.0, vel_local.z).normalized()
						facts.append({
							"kind": "ball_momentum_boost",
							"setpiece_id": _compactor["id"],
							"accel": _to_world_dir(eject_local * (COMPACTOR_BOOST_ACCEL * 1.5)),
						})
			elif ram.collision_layer == 0 and not _inside_compactor(ball_local, origin):
				ram.collision_layer = 1 << (WORLD_LAYER - 1)
				cs.disabled = false
				mi.visible = true
			if float(_compactor["timer"]) <= 0.0:
				if not _inside_compactor(ball_local, origin):
					ram.collision_layer = 1 << (WORLD_LAYER - 1)
					cs.disabled = false
					mi.visible = true
				_compactor["state"] = "sealed"
				_compactor["timer"] = COMPACTOR_SEALED_S


static func _inside_compactor(point_local: Vector3, origin_local: Vector3) -> bool:
	return absf(point_local.x - origin_local.x) <= COMPACTOR_HALF_WIDTH_M \
		and absf(point_local.z - origin_local.z) <= COMPACTOR_HALF_LENGTH_M \
		and point_local.y <= origin_local.y + 4.5



func _publish_tag(
		tag: StringName,
		origin_local: Vector3,
		radius_m: float,
		source_id: String,
		intensity: float,
		ttl_s: float,
		facts: Array[Dictionary]
) -> void:
	var world_origin := _to_world_point(origin_local)
	var payload := EnvTags.make_payload(tag, world_origin, radius_m, source_id, intensity, ttl_s, EnvTags.BOUNDS_SETPIECE)
	_upsert_active_tag(payload)
	env_tag_emitted.emit(payload)
	facts.append({
		"kind": "env_tag_emitted",
		"payload": payload,
	})


func _upsert_active_tag(payload: Dictionary) -> void:
	var tag: StringName = payload["tag"]
	var src := String(payload["source_id"])
	for existing in _active_tags:
		if existing["tag"] == tag and String(existing["source_id"]) == src:
			existing["origin"] = payload["origin"]
			existing["radius_m"] = payload["radius_m"]
			existing["intensity"] = payload["intensity"]
			existing["ttl_s"] = maxf(float(existing["ttl_s"]), float(payload["ttl_s"]))
			return
	if _active_tags.size() >= MAX_ACTIVE_TAGS:
		_active_tags.pop_front()
	_active_tags.append(payload.duplicate())


func _expire_tags(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for t in _active_tags:
		t["ttl_s"] = float(t["ttl_s"]) - delta
		if float(t["ttl_s"]) > 0.0:
			kept.append(t)
	_active_tags = kept
