extends "res://src/combat/enemy.gd"

const SPECIAL_CUES := "res://src/combat/special_cues.gd"
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

signal special_tell(moment: String)
signal wiped(crew: Array)
signal synced(members: Array)
signal overtime_started(ally: Node3D)
signal overtime_interrupted(shattered: Array)
signal overtime_primed(ally: Node3D)

const SpecialRig := preload("res://src/presentation/special_rig.gd")
const MODEL := "res://assets/models/world_one/enemy_foreman.glb"
const HP := 120.0
const SCRAP := 6
const WIPE_EVERY := 5.0
const BEAT := 60.0 / 129.0
const HORN_LEAD := BEAT
const CLOCK_OUT := 1.5
const CLAIM_RADIUS := 30.0
const OVERTIME_HP_SHARE := 0.5
const OVERTIME_WARN := 0.90
const OVERTIME_COOLDOWN := 6.0
const OVERTIME_RING_RADIUS := 4.5
const OVERTIME_RING_REACH := 3.0
const OVERTIME_BLAST_DAMAGE := 8.0
const OVERTIME_BLAST_SHOVE := 10.0
const OVERTIME_INTERRUPT_KNOCK := 6.0
const OVERTIME_INTERRUPT_DAMAGE := 15.0
const FORMATION_RADIUS := 6.5
const FORMATION_SLOT_RADIUS := 3.8
const FORMATION_ARC := PI * 0.65
const SYNC_REACH := CLAIM_RADIUS
const SYNC_BEAT_MARGIN := 0.85
const BODY_SIZE := Vector3(2.4, 5.6, 2.4)
const BODY_CENTER := Vector3(0.0, 0.8, 0.0)
const TETHER_FALLBACK := Vector3(0.0, 4.2, 0.0)

var crew: Array = []
var wipes := 0
var horns := 0
var syncs := 0
var overtime_whistles := 0
var overtime_interrupts := 0
var overtime_completes := 0
var overtime_shattered := 0

var _claimed := false
var _clock := 0.0
var _horned := false
var _overtime_active := false
var _overtime_t := 0.0
var _overtime_cd := 0.0
var _overtime_ally: Node3D
var _overtime_damage := 0.0
var _overtime_second_blast := false
var _signal_material: StandardMaterial3D
var _hand: Node3D
var _tether_mesh: ImmediateMesh
var _tethers: MeshInstance3D
var _tether_material: StandardMaterial3D
var _sync_ring: MeshInstance3D
var _reels: Array = []
static var _shared: Array = []
static var _sockets: Dictionary = {}
static var _asset_warned := false
static var _sync_ring_mesh: ArrayMesh
static var _sync_ring_material: StandardMaterial3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "foreman"
	_set_health(HP * threat)
	plating = 0.0
	scrap_value = SCRAP
	weight = 3.0
	radius = BODY_SIZE.x * 0.5
	half_height = 2.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	shape.shape = box
	shape.position = BODY_CENTER
	add_child(shape)
	_base_color = Color.WHITE
	_material = Palette.solid(_base_color)
	_material.vertex_color_use_as_albedo = true
	_build_body()
	_build_tethers()


func _build_body() -> void:
	var parts := _parts()
	if parts.is_empty():
		_fallback_body()
		return
	_signal_material = Palette.solid(Palette.BRASS, 0.0)
	_signal_material.vertex_color_use_as_albedo = true
	var model := SpecialRig.seat(self, _visual_parent(), MODEL, "foreman")
	for part in parts:
		var mi: MeshInstance3D = model.find_child(part.name, true, false) as MeshInstance3D if model != null else null
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			_visual_parent().add_child(mi)
		match String(part.name):
			"ForemanBody", "ForemanHand":
				mi.material_override = _material
			"ForemanSignal":
				mi.material_override = _signal_material
		if part.name == "ForemanHand" and model == null:
			_hand = mi
	for socket in ["tether_a", "tether_b", "tether_c", "tether_d"]:
		if _sockets.has(socket):
			_reels.append(_sockets[socket])


func _fallback_body() -> void:
	var pivot := _visual_parent()
	_base_color = Palette.RUST
	_material.vertex_color_use_as_albedo = false
	_material.albedo_color = _base_color
	for item in [[Vector3(2.2, 3.4, 2.2), Palette.RUST, Vector3(0.0, -0.3, 0.0)],
			[Vector3(0.3, 2.6, 0.3), Palette.CHARCOAL, Vector3(0.0, 2.7, 0.0)]]:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = item[0]
		mi.mesh = mesh
		mi.material_override = _material if item[1] == Palette.RUST else Palette.solid(item[1])
		mi.position = item[2]
		pivot.add_child(mi)
	var horn := MeshInstance3D.new()
	var bell := CylinderMesh.new()
	bell.top_radius = 0.15
	bell.bottom_radius = 0.6
	bell.height = 1.0
	horn.mesh = bell
	_signal_material = Palette.solid(Palette.BRASS, 0.0)
	horn.material_override = _signal_material
	horn.position = Vector3(0.0, 4.4, -0.4)
	horn.rotation.x = PI * 0.5
	pivot.add_child(horn)


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var packed := load(MODEL) as PackedScene if ResourceLoader.exists(MODEL) else null
	if packed == null:
		_asset_warning()
		return []
	var scene := packed.instantiate() as Node3D
	var parts: Array = []
	for part in ["ForemanBody", "ForemanHand", "ForemanSignal"]:
		var mi := scene.find_child(part, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			scene.free()
			_asset_warning()
			return []
		parts.append({"name": part, "mesh": mi.mesh.duplicate(), "xform": _in_scene(mi, scene)})
	for socket in ["HornMouth", "ClockFace", "tether_a", "tether_b", "tether_c", "tether_d", "SteamValve"]:
		var node := scene.find_child(socket, true, false) as Node3D
		if node != null:
			_sockets[socket] = _in_scene(node, scene).origin
	scene.free()
	_shared = parts
	return _shared


static func _in_scene(node: Node3D, scene: Node3D) -> Transform3D:
	var xform := node.transform
	var ancestor := node.get_parent()
	while ancestor != scene and ancestor is Node3D:
		xform = (ancestor as Node3D).transform * xform
		ancestor = ancestor.get_parent()
	return xform


static func _asset_warning() -> void:
	if not _asset_warned:
		_asset_warned = true
		push_warning("foreman: missing or malformed model; using fallback body")


static func _ring_mesh() -> ArrayMesh:
	if _sync_ring_mesh != null:
		return _sync_ring_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := FORMATION_SLOT_RADIUS - 0.14
	var outer := FORMATION_SLOT_RADIUS + 0.14
	var segments := 48
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var i0 := Vector3(cos(a0) * inner, 0.0, sin(a0) * inner)
		var o0 := Vector3(cos(a0) * outer, 0.0, sin(a0) * outer)
		var i1 := Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)
		var o1 := Vector3(cos(a1) * outer, 0.0, sin(a1) * outer)
		for p in [i0, o0, o1, i0, o1, i1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	_sync_ring_mesh = st.commit()
	return _sync_ring_mesh


static func _ring_material() -> StandardMaterial3D:
	if _sync_ring_material == null:
		_sync_ring_material = Palette.unshaded(Palette.BRASS)
	return _sync_ring_material


func _build_tethers() -> void:
	_tether_mesh = ImmediateMesh.new()
	_tethers = MeshInstance3D.new()
	_tethers.name = "ForemanTethers"
	_tethers.mesh = _tether_mesh
	_tethers.top_level = true
	_tethers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tether_material = Palette.solid(Palette.CABLE, 0.0, false)
	_tether_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tethers.material_override = _tether_material
	add_child(_tethers)
	_sync_ring = MeshInstance3D.new()
	_sync_ring.name = "ForemanSyncRing"
	_sync_ring.mesh = _ring_mesh()
	_sync_ring.material_override = _ring_material()
	_sync_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sync_ring.position = Vector3(0.0, -half_height + 0.15, 0.0)
	_sync_ring.visible = false
	add_child(_sync_ring)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_move(delta, Vector3.ZERO)
	if not _claimed:
		_claimed = true
		_claim()
	_tick_hand(delta)
	if not _in_play() or target == null:
		_draw_tethers()
		return
	_face(_flat_to_ball())
	_overtime_cd = maxf(0.0, _overtime_cd - delta)
	if standing_crew().is_empty():
		if _overtime_active:
			_cancel_overtime()
		if not _in_pack() and Engine.get_physics_frames() % Engine.physics_ticks_per_second == 0:
			_claim()
		_clock = 0.0
		_horned = false
		_show_signal(0.0)
		_draw_tethers()
		return
	if _overtime_active:
		if _knocked_speed() >= OVERTIME_INTERRUPT_KNOCK or _overtime_damage >= OVERTIME_INTERRUPT_DAMAGE:
			_interrupt_overtime()
		else:
			_overtime_t += delta
			var u := clampf(_overtime_t / OVERTIME_WARN, 0.0, 1.0)
			var tele := telegraph()
			if tele != null:
				tele.set_progress(u)
			if not _overtime_second_blast and _overtime_t >= OVERTIME_WARN * 0.5:
				_overtime_second_blast = true
				_steam_blast_fx()
			_show_overtime_signal(u)
			if _overtime_t >= OVERTIME_WARN:
				_complete_overtime()
		_draw_tethers()
		return
	if _overtime_cd <= 0.0 and not _horned:
		var injured := _injured_ally()
		if injured != null:
			if AttackBudget.ask(self):
				_start_overtime(injured)
				_draw_tethers()
				return
		else:
			AttackBudget.withdraw(self)
	_clock += delta
	if not _horned and _clock >= WIPE_EVERY - HORN_LEAD:
		_horned = true
		_horn()
	_show_signal(clampf((_clock - (WIPE_EVERY - HORN_LEAD)) / HORN_LEAD, 0.0, 1.0) if _horned else 0.0)
	if _clock >= WIPE_EVERY:
		_clock = 0.0
		_horned = false
		_wipe()
	_draw_tethers()


func _injured_ally() -> Node3D:
	var best: Node3D = null
	var best_share := OVERTIME_HP_SHARE
	for member in standing_crew():
		var m_max := float(member.get("max_hp"))
		var m_hp := float(member.get("hp"))
		if m_max <= 0.0:
			continue
		var share := m_hp / m_max
		if share < best_share:
			best_share = share
			best = member as Node3D
	return best


func _steam_blast_fx() -> void:
	if world_root == null or not is_inside_tree():
		return
	var valve: Vector3 = to_global(_sockets.get("SteamValve", Vector3(0.0, 3.6, 0.0)))
	var mouth: Vector3 = to_global(_sockets.get("HornMouth", Vector3(0.0, 5.2, -0.4)))
	FxLibrary.burst(world_root, "steam_puff", valve, 10)
	FxLibrary.burst(world_root, "brass_spark", mouth, 8)


func _start_overtime(ally: Node3D) -> void:
	_overtime_active = true
	_overtime_t = 0.0
	_overtime_ally = ally
	_overtime_damage = 0.0
	_overtime_second_blast = false
	overtime_whistles += 1
	var tele := _commit_ring(Threat.Type.INSTANT, global_position, OVERTIME_RING_RADIUS, OVERTIME_RING_REACH, Palette.HAZARD)
	tele.warn_seconds = OVERTIME_WARN
	_steam_blast_fx()
	if ResourceLoader.exists(SPECIAL_CUES):
		load(SPECIAL_CUES).tell(self)
	else:
		special_tell.emit("tell")
	overtime_started.emit(ally)


func _complete_overtime() -> void:
	var tele := telegraph()
	var ally := _overtime_ally
	_overtime_active = false
	_overtime_cd = OVERTIME_COOLDOWN
	_overtime_ally = null
	_overtime_damage = 0.0
	overtime_completes += 1
	if tele != null and target != null and tele.contains(_ball()):
		var out := _ball() - global_position
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.1 else -global_basis.z
		hit_player.emit(OVERTIME_BLAST_DAMAGE, dir * OVERTIME_BLAST_SHOVE + Vector3.UP * 3.0)
	_clear_telegraph()
	AttackBudget.release(self)
	_show_signal(0.0)
	if not is_instance_valid(ally) or ally.is_dead():
		ally = _injured_ally()
	if ally != null and is_instance_valid(ally) and not ally.is_dead():
		if ally.has_meta(AttackBudget.CLOCKED_OUT_META):
			ally.remove_meta(AttackBudget.CLOCKED_OUT_META)
		if ally.has_method("prime_attack"):
			ally.prime_attack()
		else:
			if "_rest" in ally:
				ally._rest = 0.0
			if "recover_left" in ally:
				ally.recover_left = 0.0
			if "stun_left" in ally:
				ally.stun_left = 0.0
		ally.set_meta("overtime_boosted", true)
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "brass_spark", ally.global_position + Vector3.UP * 0.8, 12)
		overtime_primed.emit(ally)


func _interrupt_overtime() -> void:
	if not _overtime_active:
		return
	_overtime_active = false
	_overtime_cd = OVERTIME_COOLDOWN
	_overtime_ally = null
	_overtime_damage = 0.0
	_clock = 0.0
	_horned = false
	overtime_interrupts += 1
	_clear_telegraph()
	AttackBudget.release(self)
	_show_signal(0.0)
	var combat = _combat()
	var shattered: Array = []
	for member in standing_crew():
		var had_plate := false
		if member.has_method("strip_plate") and member.strip_plate():
			had_plate = true
		if float(member.get("plating")) > 0.0:
			had_plate = true
			member.set("plating", 0.0)
			if combat != null:
				combat.wipe_shred(member)
		if member.has_method("set_tint"):
			member.set_tint("")
		if member.has_method("flash"):
			member.flash()
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "plate_chunks", member.global_position + Vector3.UP * 0.8, 10)
			FxLibrary.burst(world_root, "brass_spark", member.global_position + Vector3.UP * 0.8, 8)
		shattered.append(member)
		if had_plate:
			overtime_shattered += 1
	overtime_interrupted.emit(shattered)


func _cancel_overtime() -> void:
	_overtime_active = false
	_overtime_ally = null
	_overtime_damage = 0.0
	_clear_telegraph()
	AttackBudget.release(self)
	AttackBudget.withdraw(self)


func _show_overtime_signal(progress: float) -> void:
	var beat := absf(sin(progress * TAU))
	if _signal_material != null:
		_signal_material.emission_enabled = true
		_signal_material.emission = Palette.HAZARD
		_signal_material.emission_energy_multiplier = FlashGuard.spike(0.8, 3.2 * (0.4 + 0.6 * beat))
	if _tether_material != null:
		_tether_material.albedo_color = Palette.HAZARD
	if _sync_ring != null:
		_sync_ring.visible = not _dead
		if _sync_ring.visible:
			var pulse := 1.0 + 0.09 * beat
			_sync_ring.scale = Vector3(pulse, 1.0, pulse)


func take_damage(amount: float) -> float:
	if _overtime_active and amount > 0.0 and not _dead:
		_overtime_damage += amount
		if hp - amount <= 0.0 or _overtime_damage >= OVERTIME_INTERRUPT_DAMAGE:
			_interrupt_overtime()
	return super(amount)


func _claim() -> void:
	var pack := int(get_meta(AttackBudget.PACK_META, -1))
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or other in crew or not _crewable(other):
			continue
		if pack >= 0:
			if int(other.get_meta(AttackBudget.PACK_META, -1)) == pack:
				_hire(other)
		elif other.global_position.distance_to(global_position) <= CLAIM_RADIUS and not other.has_meta("foreman"):
			_hire(other)


func _crewable(other: Node) -> bool:
	if not is_instance_valid(other) or not other.has_method("is_dead") or other.is_dead():
		return false
	return String(other.get("kind")) not in ["foreman", "warden", "vault", "miniboss", "rogue_crane", "rogue_skip", "rogue_tender"]


func _hire(other: Node3D) -> void:
	crew.append(other)
	other.set_meta("foreman", get_instance_id())


func standing_crew() -> Array:
	var kept: Array = []
	for member in crew:
		if is_instance_valid(member) and not member.is_dead():
			kept.append(member)
	crew = kept
	return crew


func _horn() -> void:
	horns += 1
	if ResourceLoader.exists(SPECIAL_CUES):
		load(SPECIAL_CUES).tell(self)
	else:
		special_tell.emit("tell")
	_snap_formation()


func prime_horn(lead_margin := 0.1) -> void:
	_clock = maxf(0.0, WIPE_EVERY - HORN_LEAD - lead_margin)
	_horned = false


func _snap_formation() -> void:
	if not _in_pack():
		_claim()
	var chasers: Array = []
	for member in standing_crew():
		if String(member.get("kind")) != "chaser" or not member.can_rally():
			continue
		var flat := Vector2(member.global_position.x - global_position.x, member.global_position.z - global_position.z).length()
		if flat <= SYNC_REACH:
			chasers.append(member)
	if chasers.is_empty():
		return
	var forward := _flat_to_ball()
	forward = forward.normalized() if forward.length_squared() > 0.01 else -global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var right := Vector3(-forward.z, 0.0, forward.x)
	chasers.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var da := a.global_position - global_position
		var db := b.global_position - global_position
		return atan2(da.dot(right), da.dot(forward)) < atan2(db.dot(right), db.dot(forward)))
	var count := chasers.size()
	var duration := HORN_LEAD * SYNC_BEAT_MARGIN
	var joined: Array = []
	for i in count:
		var angle := 0.0 if count == 1 else lerpf(-FORMATION_ARC * 0.5, FORMATION_ARC * 0.5, float(i) / float(count - 1))
		var dir := forward.rotated(Vector3.UP, angle)
		var slot := global_position + dir * FORMATION_SLOT_RADIUS
		var chaser: Node3D = chasers[i]
		if chaser.rally_to(slot, duration):
			chaser.react("flinch", slot - chaser.global_position, false, false)
			joined.append(chaser)
	if joined.is_empty():
		return
	syncs += 1
	synced.emit(joined)
	var events = _events()
	if events != null:
		events.world_fact.emit("quick_sync", global_position)


func _wipe() -> void:
	wipes += 1
	if not _in_pack():
		_claim()
	var combat = _combat()
	var members := standing_crew()
	if combat != null:
		for member in members:
			combat.wipe_shred(member)
	wiped.emit(members)


func _in_pack() -> bool:
	return int(get_meta(AttackBudget.PACK_META, -1)) >= 0


func _combat():
	var fleet = spec.get("fleet")
	return fleet.combat if fleet != null and is_instance_valid(fleet) else null


func _events():
	var fleet = spec.get("fleet")
	var fleet_ctx = fleet.get("ctx") if fleet != null and is_instance_valid(fleet) else null
	var ev = fleet_ctx.get("events") if fleet_ctx != null else null
	return ev if ev != null and is_instance_valid(ev) else null


func _show_signal(level: float) -> void:
	if _signal_material != null:
		_signal_material.emission_enabled = level > 0.0
		_signal_material.emission = Palette.AMBER
		_signal_material.emission_energy_multiplier = FlashGuard.spike(0.0, 3.0 * level)
	if _tether_material != null:
		_tether_material.albedo_color = Palette.BRASS if level > 0.0 else Palette.CABLE
	if _sync_ring != null:
		_sync_ring.visible = level > 0.0 and not _dead
		if _sync_ring.visible:
			var pulse := 1.0 + 0.06 * sin(level * PI)
			_sync_ring.scale = Vector3(pulse, 1.0, pulse)


func _tick_hand(_delta: float) -> void:
	if _hand == null:
		return
	var beats := floorf(float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second / BEAT)
	_hand.rotation.z = fposmod(beats, 12.0) * TAU / 12.0


func _face(to_ball: Vector3) -> void:
	if to_ball.length() > 0.5:
		rotation.y = atan2(-to_ball.x, -to_ball.z)


func _draw_tethers() -> void:
	if _tether_mesh == null:
		return
	_tether_mesh.clear_surfaces()
	var members := standing_crew()
	if members.is_empty() or _dead:
		return
	_tether_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in members.size():
		var reel: Vector3 = _reels[i % _reels.size()] if not _reels.is_empty() else TETHER_FALLBACK
		_tether_mesh.surface_add_vertex(to_global(reel))
		_tether_mesh.surface_add_vertex(members[i].global_position + Vector3.UP * 0.5)
	_tether_mesh.surface_end()


func _die() -> void:
	if _overtime_active:
		_interrupt_overtime()
	AttackBudget.release(self)
	AttackBudget.withdraw(self)
	var members := standing_crew()
	if not members.is_empty():
		var fleet = spec.get("fleet")
		if fleet != null and is_instance_valid(fleet):
			fleet.discover("shift_over", global_position)
		var events = _events()
		if events != null:
			events.world_fact.emit("shift_over", global_position)
	for member in members:
		AttackBudget.clock_out(member, CLOCK_OUT)
		member.cancel_rally()
		member.remove_meta("foreman")
	crew.clear()
	if _tether_mesh != null:
		_tether_mesh.clear_surfaces()
	if _tethers != null:
		_tethers.visible = false
	if _sync_ring != null:
		_sync_ring.visible = false
	super._die()


func _exit_tree() -> void:
	if _overtime_active:
		_cancel_overtime()
	else:
		AttackBudget.release(self)
		AttackBudget.withdraw(self)
	for member in crew:
		if is_instance_valid(member) and int(member.get_meta("foreman", 0)) == get_instance_id():
			member.cancel_rally()
			member.remove_meta("foreman")
	super._exit_tree()
