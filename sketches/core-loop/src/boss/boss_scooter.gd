extends RefCounted

const Rules := preload("res://src/boss/boss_rules.gd")
const Target := preload("res://src/boss/boss_target.gd")
const Palette := preload("res://src/core/palette.gd")

const EJECT_MARK_LIVE := 0.3

var eject := {}
var scooter_anim: AnimationPlayer


func reset() -> void:
	eject = {}
	scooter_anim = null


func clear_mark() -> void:
	var mark = eject_mark()
	if mark != null:
		mark.queue_free()
		eject.erase("mark")


func begin_eject(boss) -> void:
	boss.cancel_hazards()
	boss.spill_break()
	boss.state = boss.EJECT
	boss.phase = boss.CHASE_PHASE
	boss.phase_clock = 0.0
	boss.ship.hull.set_solid(true, true)
	boss.ship.cockpit_open(true)
	boss.ship.show_cranes(false)
	boss.ship.open_caps(false)
	boss.ship.cue("eject")
	boss.scooter = Target.new()
	boss.scooter.setup(boss, "scooter", "scooter", Vector3(2.0, 1.2, 2.8), Vector2(1.6, 1.0))
	boss.arena.add_child(boss.scooter)
	boss.scooter.set_solid(false)
	var body := MeshInstance3D.new()
	var legacy_scooter_seam: bool = boss.Requisition.scooter_path != boss.Requisition.SCOOTER_MODEL and not ResourceLoader.exists(boss.Requisition.scooter_path)
	if legacy_scooter_seam:
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 1.0, 2.8)
		body.mesh = box
		body.material_override = Palette.solid(Palette.BRASS, 0.8)
	else:
		var craft = boss.scooter_craft()
		body.name = "ScooterHullCraft"
		body.mesh = craft.brindle_scooter_hull(Vector3(2.0, 1.0, 2.8))
		body.material_override = craft.craft_shader_material("brindle_scooter_brass", "oxidized_hull_plating", Palette.BRASS, Palette.AMBER, 0.44, 0.68, Palette.AMBER, 0.8)
	boss.scooter.add_child(body)
	scooter_anim = boss.Requisition.dress_scooter(boss.scooter)
	if scooter_anim != null:
		boss.BossModel.hide_primitive(body)
		boss.BossModel.play(scooter_anim, "eject")
	var ball: Vector3 = boss.ctx.player.ball_position()
	var land: float = boss.arena.angle_of(ball) + PI
	var from: Vector3 = boss.ship.to_global(Vector3(0.0, boss.Requisition.DECK + 1.5, 4.8))
	boss.scooter.global_position = from
	eject = {"t": 0.0, "from": from, "angle": land, "landed": false, "dir": 1.0, "slow_until": -1.0}
	commit_eject_mark(boss, land)
	boss.publish_event("boss_phase_changed", [boss.CHASE_PHASE, boss.CHASE_NAME])
	boss.publish_event("boss_attack_telegraphed", ["eject", Rules.EJECT_FLIGHT])


func commit_eject_mark(boss, angle: float) -> void:
	var to: Vector3 = boss.arena.point_at(angle, Rules.SCOOTER_RING, 0.7)
	var h = boss.Hazard.new()
	h.ground = boss.arena.ground
	h.color = Palette.SAND
	h.commit_annulus("eject_landing", boss.Hazard.Threat.Type.INSTANT, Vector3(to.x, boss.arena.ground(to), to.z),
		Vector2(0.0, Rules.SCOOTER_TOUCH), Rules.SCOOTER_TOUCH, Rules.EJECT_FLIGHT, EJECT_MARK_LIVE)
	boss.arena.add_child(h)
	eject["mark"] = h


func eject_mark() -> Node3D:
	var h = eject.get("mark")
	return h if is_instance_valid(h) else null


func step_eject_mark(delta: float) -> void:
	var h = eject_mark()
	if h == null:
		return
	h.step(delta)
	if h.is_done():
		h.queue_free()
		eject.erase("mark")


func step(boss, delta: float) -> void:
	step_eject_mark(delta)
	if not is_instance_valid(boss.scooter):
		return
	if not eject["landed"]:
		eject["t"] += delta
		var f := clampf(eject["t"] / Rules.EJECT_FLIGHT, 0.0, 1.0)
		var to: Vector3 = boss.arena.point_at(eject["angle"], Rules.SCOOTER_RING, 0.7)
		var at: Vector3 = (eject["from"] as Vector3).lerp(to, f) + Vector3.UP * 14.0 * 4.0 * f * (1.0 - f)
		boss.scooter.global_position = at
		if f >= 1.0:
			eject["landed"] = true
			eject["puff_t"] = 0.0
			boss.BossModel.play(scooter_anim, "chase")
			boss.scooter.set_solid(true)
			if is_instance_valid(boss.arena):
				boss.FxLibrary.burst(boss.arena, "slam_dust", to, 14)
				boss.FxLibrary.burst(boss.arena, "brass_spark", to + Vector3.UP * 0.4, 10)
			var ball_angle: float = boss.arena.angle_of(boss.ctx.player.ball_position())
			eject["dir"] = -signf(angle_difference(eject["angle"], ball_angle))
			if eject["dir"] == 0.0:
				eject["dir"] = 1.0
		return
	var speed := scooter_speed(boss.clock)
	eject["angle"] += eject["dir"] * speed / Rules.SCOOTER_RING * delta
	var at: Vector3 = boss.arena.point_at(eject["angle"], Rules.SCOOTER_RING, 0.7)
	var ahead: Vector3 = boss.Arena.tangent(eject["angle"]) * eject["dir"]
	var slowed: bool = boss.clock < float(eject.get("slow_until", -1.0))
	var roll: float = sin(float(boss.clock) * 24.0) * 0.14 * float(boss.EnemyMotion.motion_scale) if slowed else 0.0
	boss.scooter.global_transform = Transform3D(Basis.looking_at(ahead, Vector3.UP) * Basis(Vector3.FORWARD, roll), at)
	eject["puff_t"] = float(eject.get("puff_t", 0.0)) + delta
	if float(eject["puff_t"]) >= 0.22 and is_instance_valid(boss.arena):
		eject["puff_t"] = 0.0
		var tail := at - ahead.normalized() * 1.6 + Vector3.UP * 0.5
		boss.FxLibrary.burst(boss.arena, "steam_puff", tail, 4)


func scooter_speed(clock: float) -> float:
	var speed := Rules.SCOOTER_SPEED
	if clock < eject.get("slow_until", -1.0):
		speed = maxf(Rules.SCOOTER_MIN_SPEED, speed * Rules.SCOOTER_SLOW)
	return speed


func scooter_landed(boss) -> bool:
	return boss.state == boss.EJECT and eject.get("landed", false)


func on_enemy_struck(boss, enemy: Node3D, kind: String) -> void:
	if enemy == null or enemy != boss.scooter or not scooter_landed(boss):
		return
	if kind in Rules.CONTACT_KINDS and boss.ctx.player.ball_position().distance_to(boss.scooter.global_position) <= Rules.SCOOTER_TOUCH:
		boss.defeat_boss("stomp" if kind == "stomp" or boss.from_above_target(boss.scooter) else kind, boss.scooter.global_position, boss.scooter.last_damage_source)
	else:
		eject["slow_until"] = boss.clock + Rules.SCOOTER_SLOW_SECONDS
		if is_instance_valid(boss.arena):
			boss.FxLibrary.burst(boss.arena, "brass_spark", boss.scooter.global_position + Vector3.UP * 0.6, 12)
