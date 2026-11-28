extends RefCounted

const Rules := preload("res://src/boss/boss_rules.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")

var slag_turn := 0
var next_lobber := 0.0
var lobbers: Array = []
var drones: Array = []
var reprise := {}


func reset() -> void:
	for lobber in lobbers:
		if is_instance_valid(lobber):
			lobber.set_physics_process(false)
			lobber.queue_free()
	lobbers.clear()
	drones.clear()
	reprise = {}
	slag_turn = 0
	next_lobber = 0.0


func cancel_hazards() -> void:
	reprise = {}
	for d in drones:
		if is_instance_valid(d["marker"]):
			d["marker"].queue_free()
	drones.clear()


func enter_phase(clock: float) -> void:
	next_lobber = clock + 3.0
	slag_turn = 0


func pending_drones() -> Array:
	return drones.map(func(d): return d["at"])


func step(boss, delta: float) -> void:
	var here: Vector3 = boss.ship.global_position
	var to_centre := Vector3(boss.arena.global_position.x - here.x, 0.0, boss.arena.global_position.z - here.z)
	var parked := to_centre.length() <= 0.2
	if not parked:
		var move := minf(to_centre.length(), Rules.CIRCLE_SPEED * delta)
		var at := here + to_centre.normalized() * move
		boss.ship.move_to(Vector3(at.x, boss.arena.ground(at), at.z), boss.ship.heading)
	if boss.reeling() and not boss.was_reeling_now() and boss.reel_plant_mode() != "stop":
		if reprise.is_empty() or not bool(reprise.get("cued", false)):
			reprise = {}
			boss.set_next_attack(minf(boss.next_attack_at(), boss.clock + Rules.REEL_SLAG_PERIOD))
	step_reprise(boss)
	if boss.clock >= boss.next_attack_at() and not boss.in_transition() and not (boss.reeling() and boss.reel_plant_mode() == "stop"):
		var ball: Vector3 = boss.ctx.player.ball_position()
		if boss.reeling():
			var slot := pick_slag_slot(boss, ball, slag_turn)
			commit_slag(boss, slot, false, Rules.REEL_SLAG_LIVE)
			slag_turn += 1
			boss.clear_combo()
			boss.set_next_attack(boss.clock + Rules.REEL_SLAG_PERIOD)
		else:
			var slot := slag_turn % 3
			var lead_live := Rules.REEL_SLAG_LIVE if slot == 2 else Rules.SLAG_LIVE
			var slag_warn := commit_slag(boss, slot, false, lead_live)
			slag_turn += 1
			var gap := ChallengeDials.period("brindle", Rules.SLAG_GAP, 2)
			if boss.follow_ups() > 0:
				var at: float = float(boss.clock) + slag_warn + lead_live
				var reprise_slot := slag_turn % 3
				var reprise_live := Rules.REEL_SLAG_LIVE if reprise_slot == 2 else Rules.SLAG_LIVE
				reprise = {"at": at, "cue_at": at - FightPhases.CUE_LEAD, "cued": false, "turn": reprise_slot}
				boss.clear_combo()
				boss.set_next_attack(at + FightPhases.CUED_WARN + reprise_live + gap)
			else:
				boss.set_next_attack(boss.clock + boss.paced_cadence(slag_warn + lead_live + gap))
	if parked and boss.clock >= next_lobber and not boss.in_transition() and not (boss.reeling() and boss.reel_plant_mode() == "stop"):
		next_lobber = boss.clock + (Rules.LOBBER_PERIOD * Rules.REEL_PERIOD_MULT if boss.reeling() else Rules.LOBBER_PERIOD)
		launch_lobber(boss)


func ball_slag_slot(boss, ball: Vector3) -> int:
	var r: float = boss.arena.radius_of(ball)
	if r < boss.Arena.RING_A.x:
		return 2
	if r < (boss.Arena.RING_A.y + boss.Arena.RING_B.x) * 0.5:
		return 0
	return 1


func pick_slag_slot(boss, ball: Vector3, turn: int) -> int:
	if turn == 0:
		return 0
	var slot := ball_slag_slot(boss, ball)
	for offset in 3:
		var cand := (slot + offset) % 3
		var id := slag_id(cand)
		var busy := false
		for h in boss.hazards:
			if is_instance_valid(h) and not h.is_done() and h.attack_id == id:
				busy = true
				break
		if not busy:
			return cand
	return slot


func slag_band(boss, turn: int) -> Vector2:
	match turn % 3:
		0:
			return boss.Arena.RING_A
		1:
			return boss.Arena.RING_B
		_:
			return Rules.FURNACE_CLOSE_BAND


func slag_id(turn: int) -> String:
	match turn % 3:
		0:
			return "slag_ring_a"
		1:
			return "slag_ring_b"
		_:
			return "slag_ring_inner"


func commit_slag(boss, turn: int, cued: bool, live_override := -1.0) -> float:
	var band := slag_band(boss, turn)
	var id := slag_id(turn)
	var h = boss.new_hazard()
	var slag_warn := FightPhases.CUED_WARN if cued else ChallengeDials.tell("brindle", Rules.SLAG_WARN, boss.Hazard.MIN_WARN)
	var live := live_override if live_override > 0.0 else Rules.SLAG_LIVE
	if cued:
		h.warn_floor = FightPhases.CUED_WARN
		h.cued = true
	h.commit_annulus(id, boss.Hazard.Threat.Type.INSTANT, boss.arena.global_position, band, Rules.SLAG_REACH, slag_warn, live)
	h.excluded = func(point: Vector3) -> bool: return boss.arena.is_quenched(point, boss.clock)
	boss.add_hazard(h)
	boss.note_commit()
	boss.ship.cue("slag_warn", turn)
	boss.publish_event("boss_attack_telegraphed", [id, h.warn_seconds])
	return h.warn_seconds


func step_reprise(boss) -> void:
	if reprise.is_empty():
		return
	if boss.reeling() and not reprise["cued"]:
		reprise = {}
		return
	if not reprise["cued"] and boss.clock >= reprise["cue_at"]:
		reprise["cued"] = true
		var reprise_turn := int(reprise["turn"])
		boss.cue_phase_name("slag_ring_a" if reprise_turn % 3 == 0 else ("slag_ring_b" if reprise_turn % 3 == 1 else "slag_ring_inner"))
		boss.show_reprise_preview(reprise_turn)
	if boss.clock >= reprise["at"]:
		var turn: int = reprise["turn"]
		reprise = {}
		boss.clear_reprise_preview()
		commit_slag(boss, turn, true, Rules.REEL_SLAG_LIVE if boss.reeling() or turn % 3 == 2 else -1.0)
		if boss.reeling() and boss.reel_plant_mode() != "stop":
			boss.set_next_attack(minf(boss.next_attack_at(), boss.clock + Rules.REEL_SLAG_PERIOD))


func launch_lobber(boss) -> void:
	if boss.ctx.calm or boss.ctx.spawner == null or not boss.ctx.spawner.has_method("spawn_enemy"):
		return
	lobbers = lobbers.filter(func(l): return is_instance_valid(l) and not (l.has_method("is_dead") and l.is_dead()))
	if lobbers.size() + drones.size() >= Rules.LOBBER_CAP:
		return
	var ball_side: float = boss.ship.to_local(boss.ctx.player.ball_position()).x
	var side := -1.0 if ball_side >= 0.0 else 1.0
	var at: Vector3 = boss.ship.to_global(Vector3(side * Rules.DRONE_SIDE, 0.0, 0.0))
	at = Vector3(at.x, boss.arena.ground(at), at.z)
	var marker = boss.Hazard.new()
	marker.ground = boss.arena.ground
	marker.color = Palette.SAND
	marker.commit_annulus("drone_pad", boss.Hazard.Threat.Type.INSTANT, at, Vector2(0.0, 2.5), 0.0, Rules.DRONE_WARN, Rules.DRONE_WAIT)
	boss.arena.add_child(marker)
	drones.append({"at": at, "marker": marker})
	boss.ship.cue("drone_deploy", drones.size() + Engine.get_physics_frames())


func step_drones(boss, delta: float) -> void:
	var kept: Array = []
	var ball: Vector3 = boss.ctx.player.ball_position()
	for d in drones:
		var marker = d["marker"]
		marker.step(delta)
		var at: Vector3 = d["at"]
		var ready: bool = marker.age >= Rules.DRONE_WARN
		var clear: bool = ball.distance_to(at + Vector3.UP) >= Rules.DRONE_CLEAR
		if ready and clear and boss.state == boss.FIGHT and not boss.in_transition():
			drop_drone(boss, at)
		elif marker.age < Rules.DRONE_WARN + Rules.DRONE_WAIT and boss.state == boss.FIGHT:
			kept.append(d)
			continue
		marker.queue_free()
	drones = kept


func drop_drone(boss, at: Vector3) -> void:
	var lobber = boss.ctx.spawner.spawn_enemy("lobber", at + Vector3.UP)
	if not lobber is Node3D:
		return
	if "terrain" in lobber:
		lobber.terrain = boss.arena.ground_query()
	lobbers.append(lobber)


func slag_hit(boss, h, ball: Vector3, skim := false) -> void:
	if not skim:
		boss.reel_sear(ball, "brindle_slag")
	var dmg := ChallengeDials.damage("brindle", Rules.SLAG_DAMAGE, boss.phase) * (Rules.SKIM_SLAG_MULT if skim else 1.0)
	boss.ctx.run.damage(dmg, "brindle_slag")
	if not boss.ctx.flow.in_play():
		return
	boss.set_hazard_grace(h.get_instance_id(), boss.clock + Rules.SLAG_GRACE)
	if boss.ctx.calm:
		return
	var r: float = boss.arena.radius_of(ball)
	var out := Vector3(ball.x - boss.arena.global_position.x, 0.0, ball.z - boss.arena.global_position.z).normalized()
	var toward := out if h.attack_id == "slag_ring_inner" or r >= (h.r_in + h.r_out) * 0.5 else -out
	var across: Vector3 = Vector3.UP.cross(out)
	var way := toward
	for candidate in [toward, -toward, across, -across]:
		if clear_arc(boss, ball, candidate * Rules.SLAG_BOUNCE_OUT + Vector3.UP * Rules.SLAG_BOUNCE_UP):
			way = candidate
			break
	var v: Vector3 = boss.ctx.player.state.velocity
	var up := maxf(0.0, Rules.SLAG_BOUNCE_UP - v.y)
	boss.shove_ball("brindle_slag", Vector3.UP * up + way * Rules.SLAG_BOUNCE_OUT)


func clear_arc(boss, from: Vector3, launch: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = boss.arena.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS * 0.95
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 4
	query.exclude = [boss.ctx.player.body().get_rid()]
	var g: float = boss.ctx.tuning.f("gravity")
	var at := from
	for k in range(1, 16):
		var t := k * 0.08
		var next := from + Vector3(launch.x, 0.0, launch.z) * t + Vector3.UP * (launch.y * t - 0.5 * g * t * t)
		var lands: bool = t > 0.3 and next.y <= boss.arena.ground(next) + Tuning.RADIUS
		if lands:
			next.y = boss.arena.ground(next) + Tuning.RADIUS + 0.1
		query.transform = Transform3D(Basis.IDENTITY, at)
		query.motion = next - at
		if space.cast_motion(query)[1] < 1.0:
			return false
		if lands:
			return true
		at = next
	return true


func on_crust(boss, h, ball: Vector3) -> bool:
	var r: float = boss.arena.radius_of(ball)
	return r >= h.r_in and r <= h.r_out and ball.y - boss.arena.ground(ball) <= h.reach and boss.arena.is_quenched(ball, boss.clock)
