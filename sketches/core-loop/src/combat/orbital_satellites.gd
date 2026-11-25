extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Grip := preload("res://src/movement/grip.gd")

const MAX_SATELLITES := 5
const ORBIT_BASE_RADIUS := 3.1
const ORBIT_TIER_RADIUS_STEP := 0.55
const ORBIT_STACK_RADIUS_STEP := 0.22
const ORBIT_BASE_SPEED := 2.4
const ORBIT_TIER_SPEED_STEP := 1.15
const ORBIT_HIT_RADIUS := 0.95
const ORBIT_HIT_COOLDOWN := 0.35
const ORBIT_BASE_DAMAGE := 11.0
const ORBIT_KNOCK := 4.0
const ORBIT_HEIGHT := 0.75

const GYRO_FOUNDRY_RADIUS := 4.0
const GYRO_FOUNDRY_DAMAGE := 14.0
const ORBITAL_FURNACE_MULT := 1.45
const ORBITAL_FURNACE_SLAG_BONUS := 1.5

const MAX_SLAG_ZONES := 6
const SLAG_KILL_CADENCE := 5
const SLAG_DURATION_S := 4.0
const SLAG_TICK_S := 0.40
const SLAG_TICK_DAMAGE := 7.0
const SLAG_SEGMENTS := 28

const PRISM_FAN_REACH := 11.0
const PRISM_FAN_SPAN_DEG := 54.0
const PRISM_RAY_WIDTH := 1.15
const PRISM_DAMAGE_SHARE := 0.55
const ARC_PRISM_UNPLATED_SHARE := 0.75
const ARC_PRISM_JUMP_RANGE := 8.5

const DEBT_COOLDOWN_S := 0.35
const DEBT_REACH_M := 22.0

const BASALT_CONE_REACH := 11.0
const BASALT_CONE_HALF_DEG := 24.0
const BASALT_COOLDOWN_S := 0.75

const STORM_MAX_CHARGES := 8
const STORM_DISCHARGE_RADIUS := 8.5
const STORM_BASE_DAMAGE := 10.0

const WHIPLASH_PULL_FORCE := 8.5
const WHIPLASH_PULL_CAP := 1.4

const BURDEN_PARTS := ["load_dividend", "debt_collector", "cracked_plating", "thin_pickings", "slack_coil"]
const ORBITAL_COLORS: Array[Color] = [Palette.AMBER, Palette.COPPER, Palette.BRASS]
const VISUAL_COLORS: Array[Color] = [Palette.AMBER, Palette.COPPER, Palette.BRASS, Palette.ARC, Palette.STEEL, Palette.VERDIGRIS, Palette.LEDGER]

var ctx
var combat

var _clock := 0.0
var _orbit_angle := 0.0
var _satellite_positions: Array[Vector3] = []
var _satellite_hit_cd := {}
var _satellite_mm: MultiMesh
var _satellite_view: MultiMeshInstance3D

var slag_zones: Array[Dictionary] = []
var _slag_mesh: ImmediateMesh
var _slag_view: MeshInstance3D

var storm_charges := 0
var _kill_counter := 0
var _shot_counter := 0
var _scrap_counter := 0
var _pickup_counter := 0

var _cooldowns := {}
var _enemy_cd := {}
var _tether_cd := {}

var proc_counts := {}
var last_proc := {}


static func orbit_radius_for(tier: int, stacks := 1) -> float:
	var clamped_tier := clampi(tier, SpeedTier.WALK, SpeedTier.BLAZING)
	var extra_stacks := maxi(0, mini(stacks, MAX_SATELLITES) - 1)
	return ORBIT_BASE_RADIUS + float(clamped_tier) * ORBIT_TIER_RADIUS_STEP + float(extra_stacks) * ORBIT_STACK_RADIUS_STEP


static func orbit_speed_for(tier: int) -> float:
	var clamped_tier := clampi(tier, SpeedTier.WALK, SpeedTier.BLAZING)
	return ORBIT_BASE_SPEED + float(clamped_tier) * ORBIT_TIER_SPEED_STEP


static func used_colors() -> Array[Color]:
	return VISUAL_COLORS.duplicate()


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "OrbitalSatellites"
	_build_visuals()
	_connect_events()


func _build_visuals() -> void:
	_satellite_mm = MultiMesh.new()
	_satellite_mm.transform_format = MultiMesh.TRANSFORM_3D
	_satellite_mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.35, 0.72)
	_satellite_mm.mesh = box
	_satellite_mm.instance_count = MAX_SATELLITES
	_satellite_mm.visible_instance_count = 0
	var sat_mat := StandardMaterial3D.new()
	sat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sat_mat.vertex_color_use_as_albedo = true
	sat_mat.vertex_color_is_srgb = true
	sat_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sat_mat.render_priority = 1
	_satellite_view = MultiMeshInstance3D.new()
	_satellite_view.name = "OrbitalSatelliteMesh"
	_satellite_view.multimesh = _satellite_mm
	_satellite_view.material_override = sat_mat
	_satellite_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_satellite_view.top_level = true
	add_child(_satellite_view)

	_slag_mesh = ImmediateMesh.new()
	var slag_mat := StandardMaterial3D.new()
	slag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slag_mat.vertex_color_use_as_albedo = true
	slag_mat.vertex_color_is_srgb = true
	slag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slag_mat.render_priority = 1
	_slag_view = MeshInstance3D.new()
	_slag_view.name = "MoltenSlagMesh"
	_slag_view.mesh = _slag_mesh
	_slag_view.material_override = slag_mat
	_slag_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slag_view.top_level = true
	add_child(_slag_view)


func _connect_events() -> void:
	if ctx == null or ctx.events == null:
		return
	var ev = ctx.events
	if ev.has_signal("run_started"):
		ev.run_started.connect(func(_c: String): reset_attempt())
	if ev.has_signal("stage_entered"):
		ev.stage_entered.connect(func(_s: int, _r: bool): reset_attempt())
	if ev.has_signal("stage_content_cleared"):
		ev.stage_content_cleared.connect(func(_r: String): reset_attempt())
	if ev.has_signal("player_died"):
		ev.player_died.connect(reset_attempt)
	if ev.has_signal("run_ended"):
		ev.run_ended.connect(func(_won: bool): reset_attempt())
	if ev.has_signal("cogs_collected"):
		ev.cogs_collected.connect(_on_cogs_collected)
	if ev.has_signal("scrap_collected"):
		ev.scrap_collected.connect(_on_scrap_collected)
	if ev.has_signal("enemy_killed"):
		ev.enemy_killed.connect(_on_enemy_killed)
	if ev.has_signal("carved"):
		ev.carved.connect(_on_carved)
	if ev.has_signal("world_fact"):
		ev.world_fact.connect(_on_world_fact)
	if ev.has_signal("landed"):
		ev.landed.connect(_on_landed)
	if ev.has_signal("slammed"):
		ev.slammed.connect(_on_slammed)
	if ev.has_signal("player_hit"):
		ev.player_hit.connect(_on_player_hit)
	if ev.has_signal("boosted"):
		ev.boosted.connect(_on_boosted_or_dashed)
	if ev.has_signal("dashed"):
		ev.dashed.connect(_on_boosted_or_dashed)
	if ev.has_signal("jumped"):
		ev.jumped.connect(_on_jumped)
	if ev.has_signal("harpoon_bit"):
		ev.harpoon_bit.connect(_on_harpoon_bit)
	if ev.has_signal("harpoon_smashed"):
		ev.harpoon_smashed.connect(_on_harpoon_smashed)
	if ev.has_signal("enemy_struck"):
		ev.enemy_struck.connect(_on_enemy_struck)


func reset_attempt() -> void:
	_orbit_angle = 0.0
	_satellite_positions.clear()
	_satellite_hit_cd.clear()
	slag_zones.clear()
	storm_charges = 0
	_kill_counter = 0
	_shot_counter = 0
	_scrap_counter = 0
	_pickup_counter = 0
	_cooldowns.clear()
	_enemy_cd.clear()
	_tether_cd.clear()
	if _satellite_mm != null:
		_satellite_mm.visible_instance_count = 0
	if _slag_mesh != null:
		_slag_mesh.clear_surfaces()


func clear_telemetry() -> void:
	proc_counts.clear()
	last_proc.clear()


func proc_count(id: String) -> int:
	return int(proc_counts.get(id, 0))


func satellite_positions() -> Array[Vector3]:
	return _satellite_positions.duplicate()


func satellite_count() -> int:
	return _satellite_positions.size()


func slag_zone_count() -> int:
	return slag_zones.size()


func storm_charge_count() -> int:
	return storm_charges


func _in_play() -> bool:
	if ctx == null or ctx.player == null or ctx.run == null:
		return false
	return ctx.flow == null or ctx.flow.in_play()


func _effects():
	var build = ctx.build if ctx != null else null
	return build.get("effects") if build != null else null


func _part_copies(part_id: String) -> int:
	var fx = _effects()
	if fx != null and fx.has_method("part_copies"):
		return int(fx.part_copies(part_id))
	if ctx == null or ctx.run == null:
		return 0
	var n := 0
	for held_id in ctx.run.parts:
		if String(held_id) == part_id:
			n += 1
	return n


func _has_part(part_id: String) -> bool:
	return _part_copies(part_id) > 0


func _has_micro(part_id: String) -> bool:
	var fx = _effects()
	if fx != null and fx.has_method("has_micro_mutation") and fx.has_micro_mutation(part_id):
		return true
	return ctx != null and ctx.run != null and Parts.has_micro_mutation(ctx.run.parts, part_id)


func _evolution_live(part_id: String) -> bool:
	return ctx != null and ctx.run != null and Synergies.evolved_live(part_id, ctx.run.parts)


func _speed_tier() -> int:
	if ctx != null and ctx.player != null:
		if ctx.player.has_method("planar_velocity") and ctx.player.tuning != null:
			var vel: Vector3 = ctx.player.planar_velocity()
			var cruise: float = float(ctx.player.tuning.f("cruise"))
			if cruise > 0.0:
				return SpeedTier.of(vel.length(), cruise)
		if ctx.player.has_method("speed_tier"):
			return int(ctx.player.speed_tier())
	return SpeedTier.WALK


func _burden_count() -> int:
	if ctx == null or ctx.run == null:
		return 0
	var count := 0
	for held_id in ctx.run.parts:
		if String(held_id) in BURDEN_PARTS:
			count += 1
	return count


func w50_synergy_context(extra := {}) -> Dictionary:
	var c: Dictionary = combat.synergy_context(extra) if combat != null and combat.has_method("synergy_context") else extra.duplicate()
	if not c.has("has_husk"):
		var husks = combat.get("ally_husks") if combat != null else null
		c["has_husk"] = husks != null and husks.has_method("active_count") and int(husks.active_count()) > 0
	return c


func has_w50_cross_synergy(id: String, extra := {}) -> bool:
	if ctx == null or ctx.run == null:
		return false
	var context := w50_synergy_context(extra)
	return Synergies.cross_system_awake(id, ctx.run.parts, Callable(self, "_part_info"), context)


func active_w50_cross_synergies(extra := {}) -> Array:
	if ctx == null or ctx.run == null:
		return []
	var context := w50_synergy_context(extra)
	var out: Array = []
	for id in Synergies.CROSS_SYSTEM_W50:
		if Synergies.cross_system_awake(id, ctx.run.parts, Callable(self, "_part_info"), context):
			out.append(id)
	return out


static func _part_info(part_id: String) -> Dictionary:
	var d: Resource = Parts.def(part_id)
	if d == null:
		return {}
	return {"tags": d.tags, "bits": d.bits}


func _weapon_damage_scale() -> float:
	if ctx != null and ctx.tuning != null:
		return maxf(0.5, float(ctx.tuning.mod("weapon_damage")))
	return 1.0


func _cd_ready(key: String, duration: float) -> bool:
	if float(_cooldowns.get(key, -INF)) > _clock:
		return false
	_cooldowns[key] = _clock + duration
	return true


func _note_proc(id: String, detail := {}) -> void:
	proc_counts[id] = int(proc_counts.get(id, 0)) + 1
	var entry := detail.duplicate()
	entry["id"] = id
	entry["source"] = "item_proc"
	entry["clock"] = _clock
	last_proc = entry


func _deal_proc(enemy: Node3D, damage: float, dir: Vector3, knock: float) -> void:
	if combat == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	var push := dir if dir.length_squared() > 0.0001 else Vector3.FORWARD
	combat.deal_proc_hit(enemy, combat.SYNERGY, maxf(1.0, damage), push.normalized(), knock, "", "item_proc", "proc")


func _live_enemies(override: Array = []) -> Array:
	var raw: Array = override if not override.is_empty() else (get_tree().get_nodes_in_group("enemy") if get_tree() != null else [])
	var out: Array = []
	for enemy in raw:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		out.append(enemy)
	return out


func _nearest_enemy(at: Vector3, reach: float, exclude_ids: Array = []) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for enemy in _live_enemies():
		if enemy.get_instance_id() in exclude_ids:
			continue
		var d := at.distance_to((enemy as Node3D).global_position)
		if d <= best_d:
			best_d = d
			best = enemy
	return best


func _fx_ring(at: Vector3, radius: float, color: Color) -> void:
	if combat != null and combat.effects != null:
		combat.effects.ring(at, radius, color)


func _fx_arc(from: Vector3, to: Vector3, color: Color) -> void:
	if combat != null and combat.effects != null:
		combat.effects.arc(from, to, color)


func _fx_beam(from: Vector3, to: Vector3, color: Color, life := 0.22) -> void:
	if combat != null and combat.effects != null:
		combat.effects.beam(from, to, color, life)


func _fx_shockwave(at: Vector3, radius: float, color: Color) -> void:
	if combat != null and combat.effects != null:
		combat.effects.shockwave(at, radius, color)


func step(delta: float, enemies: Array) -> void:
	_clock += delta
	if not _in_play():
		if _satellite_mm != null:
			_satellite_mm.visible_instance_count = 0
		return
	var live := _live_enemies(enemies)
	_step_orbitals(delta, live)
	_step_slag_zones(delta, live)
	_step_ghost_conductor(live)


func _step_orbitals(delta: float, enemies: Array) -> void:
	var fx = _effects()
	var count := int(fx.orbital_count()) if fx != null and fx.has_method("orbital_count") else mini(MAX_SATELLITES, _part_copies("orbital_flywheel"))
	if count <= 0:
		_satellite_positions.clear()
		if _satellite_mm != null:
			_satellite_mm.visible_instance_count = 0
		return
	var tier := _speed_tier()
	var radius := orbit_radius_for(tier, count)
	var speed := orbit_speed_for(tier)
	_orbit_angle = wrapf(_orbit_angle + speed * delta, 0.0, TAU)
	var centre: Vector3 = ctx.player.ball_position()
	var furnace := has_w50_cross_synergy("orbital_furnace")
	var furnace_row := Synergies.cross_system_row("orbital_furnace") if furnace else {}
	var gyro := _evolution_live("gyro_foundry")
	var dmg := ORBIT_BASE_DAMAGE * _weapon_damage_scale() * (1.0 + 0.20 * float(tier))
	if furnace:
		dmg *= float(furnace_row.get("bonus_damage_mult", ORBITAL_FURNACE_MULT))
	_satellite_positions.clear()
	if _satellite_mm != null:
		_satellite_mm.visible_instance_count = count
	for i in count:
		var a := _orbit_angle + TAU * float(i) / float(count)
		var pos := centre + Vector3(cos(a) * radius, ORBIT_HEIGHT, sin(a) * radius)
		_satellite_positions.append(pos)
		if _satellite_mm != null:
			var rot := Basis(Vector3.UP, -a)
			_satellite_mm.set_instance_transform(i, Transform3D(rot, pos))
			var col: Color = Palette.COPPER if furnace else ORBITAL_COLORS[i % ORBITAL_COLORS.size()]
			_satellite_mm.set_instance_color(i, col)
		for enemy in enemies:
			var e := enemy as Node3D
			var eid := e.get_instance_id()
			if float(_satellite_hit_cd.get(eid, -INF)) > _clock:
				continue
			var hull := float(e.get("radius")) if e.get("radius") != null else 0.9
			var flat := e.global_position - pos
			flat.y = 0.0
			if flat.length() > ORBIT_HIT_RADIUS + hull:
				continue
			_satellite_hit_cd[eid] = _clock + ORBIT_HIT_COOLDOWN
			var tangent := Vector3(-sin(a), 0.0, cos(a))
			_deal_proc(e, dmg, tangent, ORBIT_KNOCK)
			_note_proc("orbital_flywheel", {"tier": tier, "count": count, "radius": radius, "damage": dmg})
			if furnace:
				if combat.has_method("apply_heat"):
					combat.apply_heat(e, pos)
				_fx_ring(pos, 1.8, Palette.COPPER)
				_note_proc("orbital_furnace", {"damage": dmg, "tier": tier})
			if gyro:
				_trigger_gyro_foundry(pos, e, enemies)


func _trigger_gyro_foundry(at: Vector3, primary: Node3D, enemies: Array) -> void:
	_fx_shockwave(at, GYRO_FOUNDRY_RADIUS, Palette.AMBER)
	var quake_dmg := GYRO_FOUNDRY_DAMAGE * _weapon_damage_scale()
	var hits := 0
	for enemy in enemies:
		var e := enemy as Node3D
		if e == primary or (e.has_method("is_dead") and e.is_dead()):
			continue
		if e.global_position.distance_to(at) <= GYRO_FOUNDRY_RADIUS:
			_deal_proc(e, quake_dmg, e.global_position - at, 5.5)
			hits += 1
	if ctx != null and ctx.has_method("break_props"):
		ctx.break_props(at, GYRO_FOUNDRY_RADIUS, "gyro_foundry")
	_note_proc("gyro_foundry", {"at": at, "radius": GYRO_FOUNDRY_RADIUS, "hits": hits})


func _spawn_slag_zone(at: Vector3) -> void:
	var fx = _effects()
	var furnace := has_w50_cross_synergy("orbital_furnace")
	var furnace_row := Synergies.cross_system_row("orbital_furnace") if furnace else {}
	var extra := float(furnace_row.get("slag_radius_bonus", ORBITAL_FURNACE_SLAG_BONUS)) if furnace else 0.0
	var radius := float(fx.slag_radius(extra)) if fx != null and fx.has_method("slag_radius") else (3.5 + extra)
	if radius <= 0.0:
		radius = 3.5 + extra
	if slag_zones.size() >= MAX_SLAG_ZONES:
		slag_zones.pop_front()
	slag_zones.append({
		"at": Vector3(at.x, at.y + 0.08, at.z),
		"radius": radius,
		"left": SLAG_DURATION_S,
		"tick": 0.0,
		"tag": "heat",
	})
	_fx_ring(at, radius, Palette.COPPER)
	_note_proc("slag_furnace", {"at": at, "radius": radius, "furnace": furnace})
	_redraw_slag_zones()


func _step_slag_zones(delta: float, enemies: Array) -> void:
	if slag_zones.is_empty():
		return
	var kept: Array[Dictionary] = []
	var tick_dmg := SLAG_TICK_DAMAGE * _weapon_damage_scale()
	for zone in slag_zones:
		zone["left"] = float(zone["left"]) - delta
		if float(zone["left"]) <= 0.0:
			continue
		zone["tick"] = float(zone["tick"]) - delta
		if float(zone["tick"]) <= 0.0:
			zone["tick"] = SLAG_TICK_S
			var centre: Vector3 = zone["at"]
			var radius: float = float(zone["radius"])
			for enemy in enemies:
				var e := enemy as Node3D
				var flat := e.global_position - centre
				flat.y = 0.0
				if flat.length() <= radius:
					_deal_proc(e, tick_dmg, flat, 1.5)
					if combat != null and combat.has_method("apply_heat"):
						combat.apply_heat(e, e.global_position)
		kept.append(zone)
	slag_zones = kept
	_redraw_slag_zones()


func _redraw_slag_zones() -> void:
	if _slag_mesh == null:
		return
	_slag_mesh.clear_surfaces()
	if slag_zones.is_empty():
		return
	_slag_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for zone in slag_zones:
		var at: Vector3 = zone["at"]
		var radius: float = float(zone["radius"])
		var alpha := clampf(float(zone["left"]) / SLAG_DURATION_S, 0.25, 0.85)
		var outer := Color(Palette.COPPER.r, Palette.COPPER.g, Palette.COPPER.b, alpha)
		var inner := Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, alpha * 0.8)
		for i in SLAG_SEGMENTS:
			var a0 := TAU * float(i) / float(SLAG_SEGMENTS)
			var a1 := TAU * float(i + 1) / float(SLAG_SEGMENTS)
			_slag_mesh.surface_set_color(outer)
			_slag_mesh.surface_add_vertex(at + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
			_slag_mesh.surface_set_color(outer)
			_slag_mesh.surface_add_vertex(at + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
			var ir := radius * 0.62
			_slag_mesh.surface_set_color(inner)
			_slag_mesh.surface_add_vertex(at + Vector3(cos(a0) * ir, 0.02, sin(a0) * ir))
			_slag_mesh.surface_set_color(inner)
			_slag_mesh.surface_add_vertex(at + Vector3(cos(a1) * ir, 0.02, sin(a1) * ir))
	_slag_mesh.surface_end()


func _step_ghost_conductor(enemies: Array) -> void:
	var husks_mgr = combat.get("ally_husks") if combat != null else null
	if husks_mgr == null:
		return
	var husk_list: Array = husks_mgr.get("husks") if husks_mgr.get("husks") is Array else []
	if husk_list.is_empty():
		return
	if not has_w50_cross_synergy("ghost_conductor", {"has_husk": true}):
		return
	var row := Synergies.cross_system_row("ghost_conductor")
	var width := float(row.get("link_width_m", 1.8))
	var cd := float(row.get("tick_cooldown_s", 0.50))
	var max_links := int(row.get("max_links", 4))
	var dmg := float(row.get("damage_base", 18.0)) * _weapon_damage_scale()
	var ball: Vector3 = ctx.player.ball_position()
	var linked := 0
	for husk in husk_list:
		if linked >= max_links:
			break
		if not is_instance_valid(husk):
			continue
		linked += 1
		var hpos: Vector3 = (husk as Node3D).global_position
		for enemy in enemies:
			var e := enemy as Node3D
			var eid := e.get_instance_id()
			if float(_tether_cd.get(eid, -INF)) > _clock:
				continue
			var hull := float(e.get("radius")) if e.get("radius") != null else 0.9
			if combat.in_line(ball, hpos, width, e.global_position, hull):
				_tether_cd[eid] = _clock + cd
				_fx_arc(ball + Vector3.UP * 0.5, hpos + Vector3.UP * 0.5, Palette.AMBER)
				_deal_proc(e, dmg, hpos - ball, 3.0)
				_note_proc("ghost_conductor", {"damage": dmg, "links": linked})


func stamp_bolt(record: Dictionary, p: Resource) -> void:
	if String(record.get("source", "")) != "weapon":
		return
	var fx = _effects()
	if _has_part("boomerang_spool"):
		var bstats: Dictionary = fx.boomerang_stats() if fx != null and fx.has_method("boomerang_stats") else {"pause_s": 0.15, "damage_mult": 1.15, "width_mult": 1.25}
		record["boomerang"] = true
		record["boomerang_pause_s"] = float(bstats.get("pause_s", 0.15))
		record["boomerang_damage_mult"] = float(bstats.get("damage_mult", 1.15))
		record["boomerang_width_mult"] = float(bstats.get("width_mult", 1.25))
		if _evolution_live("whiplash_spool"):
			record["whiplash_pull"] = true
	if has_w50_cross_synergy("railgun_ricochet"):
		var bits := int(record.get("bits", 0))
		var has_bounce := ShotBits.has(bits, ShotBits.bit("bounce")) or int(record.get("extra_bounces", 0)) > 0
		var has_pierce := int(record.get("pierce", 0)) > 0 or ShotBits.has(bits, ShotBits.bit("pierce")) or (p != null and int(p.get("pierce")) > 0)
		if has_bounce or has_pierce:
			var rrow := Synergies.cross_system_row("railgun_ricochet")
			record["railgun_ricochet"] = true
			record["railgun_speed_mult"] = float(rrow.get("speed_mult", 1.40))
			record["railgun_damage_mult"] = float(rrow.get("damage_mult", 1.35))
			record["railgun_max_stacks"] = int(rrow.get("max_stacks", 2))
			if not has_bounce:
				record["extra_bounces"] = maxi(int(record.get("extra_bounces", 0)), 1)
	if _has_micro("gatling_heart"):
		var grow := Parts.micro_mutation("gatling_heart")
		var every := maxi(1, int(grow.get("every_shots", 12)))
		_shot_counter += 1
		if _shot_counter % every == 0:
			_fire_gatling_vent(record, grow)


func _fire_gatling_vent(record: Dictionary, grow: Dictionary) -> void:
	var origin: Vector3 = Vector3(record.get("origin", ctx.player.ball_position()))
	var dir: Vector3 = Vector3(record.get("dir", Vector3.FORWARD)).normalized()
	var dmg := float(grow.get("damage_base", 18.0)) * _weapon_damage_scale()
	var reach := float(grow.get("radius_m", 5.5))
	var knock := float(grow.get("knock", 6.0))
	_fx_beam(origin, origin + dir * reach, Palette.BRASS, 0.16)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		var to_e := e.global_position - origin
		var dist := to_e.length()
		if dist <= reach and (dist < 0.1 or to_e.normalized().dot(dir) >= 0.5):
			_deal_proc(e, dmg, dir, knock)
			hits += 1
	_note_proc("gatling_heart", {"shots": _shot_counter, "hits": hits, "damage": dmg, "radius": reach})


func on_bolt_hit(bolt: Dictionary, enemy: Node3D, point: Vector3, _part := "") -> void:
	if not _in_play() or not is_instance_valid(enemy):
		return
	var src := String(bolt.get("source", ""))
	if bool(bolt.get("boomerang_returned", false)):
		_note_proc("boomerang_return_hit", {"damage": float(bolt.get("damage", 0.0))})
		if bool(bolt.get("whiplash_pull", false)) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			_apply_whiplash_pull(enemy)
		return
	if src != "weapon":
		return
	if _has_part("prism_splitter"):
		_maybe_prism_refract(bolt, enemy, point)
	if _has_micro("horizon_optic"):
		_maybe_horizon_ping(bolt, enemy, point)
	if _has_part("storm_capacitor"):
		_maybe_charge_storm()
	if has_w50_cross_synergy("overclocked_circuit"):
		_maybe_overclocked_circuit(point, enemy)


func _apply_whiplash_pull(enemy: Node3D) -> void:
	var body_heft := Grip.heft_of(enemy)
	var pilot_heft := float(combat.heft()) if combat != null and combat.has_method("heft") else 1.0
	if body_heft > pilot_heft:
		return
	var to_ball: Vector3 = ctx.player.ball_position() - enemy.global_position
	to_ball.y = 0.0
	if to_ball.length_squared() < 0.01:
		return
	var force := WHIPLASH_PULL_FORCE * minf(pilot_heft / maxf(body_heft, 0.01), WHIPLASH_PULL_CAP)
	if enemy.has_method("knock"):
		enemy.knock(to_ball.normalized(), force)
	_fx_arc(enemy.global_position + Vector3.UP * 0.5, ctx.player.ball_position() + Vector3.UP * 0.5, Palette.LEDGER)
	_note_proc("whiplash_spool", {"force": force, "heft": body_heft})


func _is_plated_target(enemy: Node3D) -> bool:
	if combat != null and combat.has_method("plating_of") and float(combat.plating_of(enemy)) > 0.0:
		return true
	var p = enemy.get("plating")
	return p != null and float(p) > 0.0


func _maybe_prism_refract(bolt: Dictionary, enemy: Node3D, point: Vector3) -> void:
	var plated := _is_plated_target(enemy)
	var evolved := _evolution_live("arc_prism")
	if not plated and not evolved:
		return
	var fx = _effects()
	var rays := int(fx.prism_rays()) if fx != null and fx.has_method("prism_rays") else clampi(2 + _part_copies("prism_splitter"), 3, 5)
	if rays < 3:
		rays = 3
	var base_dir := Vector3(bolt.get("dir", Vector3.FORWARD))
	base_dir.y = 0.0
	base_dir = base_dir.normalized() if base_dir.length_squared() > 0.0001 else Vector3.FORWARD
	var dmg := float(bolt.get("damage", 10.0)) * PRISM_DAMAGE_SHARE * (1.0 if plated else ARC_PRISM_UNPLATED_SHARE)
	var struck_id := enemy.get_instance_id()
	var hit_ids := [struck_id]
	var enemies := _live_enemies()
	var span := deg_to_rad(PRISM_FAN_SPAN_DEG)
	var total_hits := 0
	for i in rays:
		var frac := (float(i) / float(maxi(1, rays - 1))) * 2.0 - 1.0
		var rdir := base_dir.rotated(Vector3.UP, frac * span * 0.5).normalized()
		var tip := point + rdir * PRISM_FAN_REACH
		_fx_beam(point, tip, Palette.AMBER if i % 2 == 0 else Palette.COPPER, 0.22)
		for cand in enemies:
			var ce := cand as Node3D
			var cid := ce.get_instance_id()
			if cid in hit_ids:
				continue
			var hull := float(ce.get("radius")) if ce.get("radius") != null else 0.9
			if combat.in_line(point, tip, PRISM_RAY_WIDTH, ce.global_position, hull):
				hit_ids.append(cid)
				_deal_proc(ce, dmg, rdir, 3.0)
				total_hits += 1
				if evolved:
					var jump := _nearest_enemy(ce.global_position, ARC_PRISM_JUMP_RANGE, hit_ids)
					if jump != null:
						hit_ids.append(jump.get_instance_id())
						_fx_arc(ce.global_position + Vector3.UP * 0.5, jump.global_position + Vector3.UP * 0.5, Palette.ARC)
						_deal_proc(jump, dmg * 0.65, jump.global_position - ce.global_position, 2.0)
						_note_proc("arc_prism", {"rays": rays, "plated": plated, "jump_damage": dmg * 0.65})
	_note_proc("prism_splitter", {"rays": rays, "hits": total_hits, "plated": plated, "evolved": evolved})


func _maybe_horizon_ping(bolt: Dictionary, enemy: Node3D, point: Vector3) -> void:
	var hrow := Parts.micro_mutation("horizon_optic")
	var min_range := float(hrow.get("min_range_m", 22.0))
	var origin: Vector3 = Vector3(bolt.get("fired_from", bolt.get("origin", point)))
	var dist := maxf(origin.distance_to(point), float(bolt.get("travelled", 0.0)))
	if dist < min_range:
		return
	var eid := enemy.get_instance_id()
	var key := "horizon_" + str(eid)
	if float(_enemy_cd.get(key, -INF)) > _clock:
		return
	_enemy_cd[key] = _clock + float(hrow.get("cooldown_s", 0.60))
	var bonus := float(bolt.get("damage", 10.0)) * float(hrow.get("bonus_share", 0.20))
	_fx_beam(origin, point, Palette.ARC, 0.16)
	_deal_proc(enemy, bonus, Vector3(bolt.get("dir", Vector3.FORWARD)), 2.5)
	_note_proc("horizon_optic", {"dist": dist, "damage": bonus})


func _maybe_charge_storm() -> void:
	var airborne := ctx.player.state != null and not bool(ctx.player.state.grounded)
	var gliding := ctx.player.kit != null and bool(ctx.player.kit.gliding)
	if not airborne and not gliding:
		return
	storm_charges = mini(STORM_MAX_CHARGES, storm_charges + 1)
	_note_proc("storm_capacitor_charge", {"charges": storm_charges, "gliding": gliding})


func _maybe_overclocked_circuit(at: Vector3, primary: Node3D) -> void:
	var row := Synergies.cross_system_row("overclocked_circuit")
	var tier := _speed_tier()
	if tier < int(row.get("min_tier", SpeedTier.FAST)):
		return
	if not _cd_ready("overclocked_circuit", float(row.get("cooldown_s", 0.45))):
		return
	var radius := float(row.get("radius_m", 9.0))
	var dmg := float(row.get("damage_base", 20.0)) * _weapon_damage_scale()
	_fx_ring(at, radius, Palette.ARC)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		if e == primary:
			continue
		if e.global_position.distance_to(at) <= radius:
			_fx_arc(at + Vector3.UP * 0.5, e.global_position + Vector3.UP * 0.5, Palette.ARC)
			_deal_proc(e, dmg, e.global_position - at, 3.0)
			hits += 1
	_note_proc("overclocked_circuit", {"tier": tier, "radius": radius, "hits": hits, "damage": dmg})


func on_bolt_bounce(bolt: Dictionary, at: Vector3) -> void:
	if bool(bolt.get("railgun_boosted_last", false)):
		var dir := Vector3(bolt.get("dir", Vector3.FORWARD)).normalized()
		_fx_beam(at, at + dir * 5.0, Palette.LEDGER, 0.20)
		_note_proc("railgun_ricochet", {
			"boosts": int(bolt.get("railgun_boosts", 0)),
			"speed": float(bolt.get("speed", 0.0)),
			"damage": float(bolt.get("damage", 0.0)),
		})


func strike_mult(_enemy: Node3D, _kind: String, cls: String) -> float:
	if cls == "item_proc" or ctx == null or ctx.run == null:
		return 1.0
	var mult := 1.0
	if _has_part("patch_tether"):
		var held_consumable: bool = ctx.run.has_method("has_consumable") and bool(ctx.run.has_consumable())
		var fx = _effects()
		var bonus := float(fx.pocket_aura_bonus(held_consumable)) if fx != null and fx.has_method("pocket_aura_bonus") else (0.18 if held_consumable else 0.0)
		if bonus > 0.0:
			mult *= 1.0 + bonus
	if has_w50_cross_synergy("heavy_dividend"):
		var row := Synergies.cross_system_row("heavy_dividend")
		var per := float(row.get("per_burden", 0.12))
		var cap := float(row.get("cap_bonus", 0.60))
		var burdens := maxi(1, _burden_count())
		mult *= 1.0 + minf(cap, float(burdens) * per)
	return mult


func _on_cogs_collected(amount: int, _total: int) -> void:
	if amount <= 0 or not _in_play():
		return
	if _has_part("debt_collector") and _cd_ready("debt_collector", DEBT_COOLDOWN_S):
		var ball: Vector3 = ctx.player.ball_position()
		var target := _nearest_enemy(ball, DEBT_REACH_M)
		if target != null:
			var fx = _effects()
			var dmg := float(fx.coin_shot_damage()) if fx != null and fx.has_method("coin_shot_damage") else 14.0
			dmg *= _weapon_damage_scale()
			_fx_beam(ball + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5, Palette.BRASS, 0.20)
			_deal_proc(target, dmg, target.global_position - ball, 3.5)
			_note_proc("debt_collector", {"damage": dmg})
	_tick_scrap_magnetron()


func _on_scrap_collected(amount: int, _at: Vector3, _total: int) -> void:
	if amount <= 0 or not _in_play():
		return
	if _has_micro("magnet_spool"):
		var mrow := Parts.micro_mutation("magnet_spool")
		var every := maxi(1, int(mrow.get("every_scrap", 5)))
		_scrap_counter += 1
		if _scrap_counter % every == 0:
			var ball: Vector3 = ctx.player.ball_position()
			var target := _nearest_enemy(ball, float(mrow.get("reach_m", 10.0)))
			if target != null:
				var dmg := float(mrow.get("damage_base", 12.0)) * _weapon_damage_scale()
				_fx_arc(ball + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5, Palette.VERDIGRIS)
				_deal_proc(target, dmg, target.global_position - ball, 2.5)
				_note_proc("magnet_spool", {"count": _scrap_counter, "damage": dmg})
	_tick_scrap_magnetron()


func _tick_scrap_magnetron() -> void:
	if not has_w50_cross_synergy("scrap_magnetron"):
		return
	var row := Synergies.cross_system_row("scrap_magnetron")
	var every := int(row.get("pickup_threshold", 4))
	_pickup_counter += 1
	if _pickup_counter % maxi(1, every) != 0:
		return
	if not _cd_ready("scrap_magnetron", float(row.get("cooldown_s", 0.50))):
		return
	var ball: Vector3 = ctx.player.ball_position()
	var radius := float(row.get("radius_m", 8.0))
	var dmg := float(row.get("damage_base", 22.0)) * _weapon_damage_scale()
	_fx_ring(ball, radius, Palette.ARC)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		if e.global_position.distance_to(ball) <= radius:
			_fx_arc(ball + Vector3.UP * 0.5, e.global_position + Vector3.UP * 0.5, Palette.ARC)
			_deal_proc(e, dmg, e.global_position - ball, 3.5)
			hits += 1
	_note_proc("scrap_magnetron", {"pickups": _pickup_counter, "hits": hits, "damage": dmg, "radius": radius})


func _on_enemy_killed(_kind: String, at: Vector3, _scrap_value: int) -> void:
	if not _in_play() or not _has_part("slag_furnace"):
		return
	_kill_counter += 1
	if _kill_counter % SLAG_KILL_CADENCE == 0:
		_spawn_slag_zone(at)


func _on_carved(at: Vector3, seconds: float, _speed: float) -> void:
	if not _in_play():
		return
	if _has_micro("grip_tread") and seconds >= 0.35:
		var grow := Parts.micro_mutation("grip_tread")
		if _cd_ready("grip_tread", float(grow.get("cooldown_s", 0.60))):
			var radius := float(grow.get("radius_m", 2.8))
			var dmg := float(grow.get("damage_base", 12.0)) * _weapon_damage_scale()
			var knock := float(grow.get("knock", 5.0))
			_fx_ring(at, radius, Palette.COPPER)
			var hits := 0
			for enemy in _live_enemies():
				var e := enemy as Node3D
				if e.global_position.distance_to(at) <= radius:
					_deal_proc(e, dmg, e.global_position - at, knock)
					hits += 1
			_note_proc("grip_tread", {"seconds": seconds, "hits": hits, "damage": dmg, "radius": radius})
	if _has_part("basalt_ram"):
		_fire_basalt_cone(at, "carve")


func _on_world_fact(kind: String, at: Vector3) -> void:
	if not _in_play() or kind != "piece_shattered":
		return
	if _has_part("basalt_ram"):
		_fire_basalt_cone(at, "breach")


func _fire_basalt_cone(at: Vector3, trigger_kind: String) -> void:
	if not _cd_ready("basalt_ram", BASALT_COOLDOWN_S):
		return
	var fx = _effects()
	var dmg := float(fx.basalt_cone_damage()) if fx != null and fx.has_method("basalt_cone_damage") else 18.0
	dmg *= _weapon_damage_scale()
	var vel: Vector3 = ctx.player.planar_velocity() if ctx.player.has_method("planar_velocity") else Vector3.ZERO
	vel.y = 0.0
	var dir: Vector3 = vel.normalized() if vel.length_squared() > 0.05 else Vector3(ctx.aim_forward())
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	var cos_half := cos(deg_to_rad(BASALT_CONE_HALF_DEG))
	for side in [-1.0, 0.0, 1.0]:
		var edge: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(BASALT_CONE_HALF_DEG) * float(side))
		_fx_beam(at + Vector3.UP * 0.4, at + Vector3.UP * 0.4 + edge * BASALT_CONE_REACH, Palette.COPPER, 0.24)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		var flat := e.global_position - at
		flat.y = 0.0
		var dist := flat.length()
		if dist <= BASALT_CONE_REACH and (dist < 0.1 or flat.normalized().dot(dir) >= cos_half):
			_deal_proc(e, dmg, dir, 6.5)
			hits += 1
	_note_proc("basalt_ram", {"trigger": trigger_kind, "hits": hits, "damage": dmg})


func _on_landed(impact: float) -> void:
	if impact <= 0.0 or not _in_play():
		return
	_release_storm_capacitor(ctx.player.ball_position(), "land")


func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05 or not _in_play():
		return
	_release_storm_capacitor(at, "slam")


func _release_storm_capacitor(at: Vector3, trigger_kind: String) -> void:
	if storm_charges <= 0 or not _has_part("storm_capacitor"):
		return
	var spent := storm_charges
	storm_charges = 0
	var fx = _effects()
	var mult := float(fx.storm_static_mult()) if fx != null and fx.has_method("storm_static_mult") else 1.25
	var dmg := STORM_BASE_DAMAGE * float(spent) * mult * _weapon_damage_scale()
	_fx_shockwave(at, STORM_DISCHARGE_RADIUS, Palette.ARC)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		if e.global_position.distance_to(at) <= STORM_DISCHARGE_RADIUS:
			_fx_arc(at + Vector3.UP * 0.6, e.global_position + Vector3.UP * 0.6, Palette.ARC)
			_deal_proc(e, dmg, e.global_position - at, 5.5)
			hits += 1
	_note_proc("storm_capacitor", {"trigger": trigger_kind, "charges": spent, "hits": hits, "damage": dmg})


func _on_player_hit(amount: float, _source: String) -> void:
	if amount <= 0.0 or not _in_play() or not _has_micro("rivet_plating"):
		return
	var row := Parts.micro_mutation("rivet_plating")
	if not _cd_ready("rivet_plating", float(row.get("cooldown_s", 1.0))):
		return
	var ball: Vector3 = ctx.player.ball_position()
	var radius := float(row.get("radius_m", 4.5))
	var dmg := float(row.get("damage_base", 14.0)) * _weapon_damage_scale()
	var knock := float(row.get("knock", 7.0))
	_fx_ring(ball, radius, Palette.STEEL)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		if e.global_position.distance_to(ball) <= radius:
			_deal_proc(e, dmg, e.global_position - ball, knock)
			hits += 1
	_note_proc("rivet_plating", {"hits": hits, "damage": dmg, "radius": radius})


func _on_boosted_or_dashed(direction: Vector3) -> void:
	if not _in_play() or not _has_micro("vent_baffle"):
		return
	var row := Parts.micro_mutation("vent_baffle")
	if not _cd_ready("vent_baffle", float(row.get("cooldown_s", 0.50))):
		return
	var ball: Vector3 = ctx.player.ball_position()
	var back := -direction
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 0.01 else Vector3.BACK
	var vent_at := ball + back * 2.0
	var radius := float(row.get("radius_m", 5.0))
	var dmg := float(row.get("damage_base", 12.0)) * _weapon_damage_scale()
	var knock := float(row.get("knock", 9.0))
	_fx_ring(vent_at, radius, Palette.COPPER)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		if e.global_position.distance_to(vent_at) <= radius:
			_deal_proc(e, dmg, back, knock)
			hits += 1
	_note_proc("vent_baffle", {"hits": hits, "damage": dmg, "radius": radius})


func _on_jumped(air: bool) -> void:
	if air or not _in_play() or not _has_micro("spring_shims"):
		return
	var row := Parts.micro_mutation("spring_shims")
	if not _cd_ready("spring_shims", float(row.get("cooldown_s", 0.50))):
		return
	var ball: Vector3 = ctx.player.ball_position()
	var radius := float(row.get("radius_m", 4.0))
	var dmg := float(row.get("damage_base", 10.0)) * _weapon_damage_scale()
	var knock := float(row.get("knock", 6.0))
	_fx_ring(ball, radius, Palette.AMBER)
	var hits := 0
	for enemy in _live_enemies():
		var e := enemy as Node3D
		if e.global_position.distance_to(ball) <= radius:
			_deal_proc(e, dmg, e.global_position - ball, knock)
			hits += 1
	_note_proc("spring_shims", {"hits": hits, "damage": dmg, "radius": radius})


func _on_harpoon_bit(enemy: Node3D, at: Vector3) -> void:
	if not _in_play() or not _has_micro("live_line"):
		return
	var row := Parts.micro_mutation("live_line")
	if not _cd_ready("live_line", float(row.get("cooldown_s", 0.50))):
		return
	var exclude := [enemy.get_instance_id()] if is_instance_valid(enemy) else []
	var other := _nearest_enemy(at, float(row.get("reach_m", 7.0)), exclude)
	if other == null:
		return
	var dmg := float(row.get("damage_base", 16.0)) * _weapon_damage_scale()
	_fx_arc(at + Vector3.UP * 0.5, other.global_position + Vector3.UP * 0.5, Palette.ARC)
	_deal_proc(other, dmg, other.global_position - at, 3.0)
	_note_proc("live_line", {"damage": dmg})


func _on_harpoon_smashed(_enemy: Node3D, at: Vector3, _speed: float) -> void:
	if not _in_play() or not _has_micro("winch_pawl"):
		return
	var row := Parts.micro_mutation("winch_pawl")
	if not _cd_ready("winch_pawl", float(row.get("cooldown_s", 0.45))):
		return
	var radius := float(row.get("radius_m", 4.5))
	var dmg := float(row.get("damage_base", 16.0)) * _weapon_damage_scale()
	var knock := float(row.get("knock", 7.0))
	_fx_ring(at, radius, Palette.AMBER)
	var hits := 0
	for e in _live_enemies():
		var en := e as Node3D
		if en.global_position.distance_to(at) <= radius:
			_deal_proc(en, dmg, en.global_position - at, knock)
			hits += 1
	_note_proc("winch_pawl", {"hits": hits, "damage": dmg, "radius": radius})


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if kind != "ram" or not _in_play() or not _has_micro("ram_plow"):
		return
	var row := Parts.micro_mutation("ram_plow")
	if _speed_tier() < int(row.get("min_tier", SpeedTier.FAST)) or not is_instance_valid(enemy):
		return
	if not _cd_ready("ram_plow", float(row.get("cooldown_s", 0.40))):
		return
	var at := enemy.global_position
	var radius := float(row.get("radius_m", 4.5))
	var dmg := float(row.get("damage_base", 20.0)) * _weapon_damage_scale()
	var knock := float(row.get("knock", 9.0))
	_fx_ring(at, radius, Palette.COPPER)
	var hits := 0
	for cand in _live_enemies():
		var ce := cand as Node3D
		if ce == enemy:
			continue
		if ce.global_position.distance_to(at) <= radius:
			_deal_proc(ce, dmg, ce.global_position - at, knock)
			hits += 1
	_note_proc("ram_plow", {"hits": hits, "damage": dmg, "radius": radius})
