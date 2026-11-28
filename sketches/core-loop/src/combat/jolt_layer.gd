extends "res://src/combat/counter.gd"

const AreaField := preload("res://src/combat/area_field.gd")
const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

const FIELD := "static_jam"
const HP := 45.0
const WET_SPREAD := 1.5
const LAY_AHEAD := 12.0

const PRIMARY_WARN := 1.0
const PRIMARY_LIVE := 3.7
const RIM_INNER_RATIO := 0.72
const RIM_OUTER_MARGIN := 3.0
const RIM_SKIRT_S := 0.90
const WHIP_WARN := 0.70
const WHIP_LIVE := 0.75
const WHIP_LENGTH := 16.0
const WHIP_WIDTH := 2.4
const WHIP_REACH := 3.0
const WHIP_WAVE_REACH := 2.4
const WHIP_DAMAGE := 10.0
const WHIP_SHOVE := 6.0
const WHIP_JAM_S := 0.6
const SPECIAL_REFUND_SHARE := 0.30
const BOOST_GRACE_S := 0.65

var field = null
var jolts := 0
var slipped := 0
var recalls := 0
var cable_whips := 0
var short_outs := 0
var whip_jolts := 0

var _presence: AudioStreamPlayer3D
var _told := -1
var _spool: MeshInstance3D
var _coil: MeshInstance3D
var _mat_start_hp := 0.0
var _rim_time := 0.0
var _whip_primed := false
var _whipping := false
var _whip_dir := Vector3.FORWARD
var _whip_origin := Vector3.ZERO
var _whip_pos := Vector3.ZERO
var _whip_hit := false
var _whip_reversed := false
var _whip_spark_t := 0.0
var _boost_grace := 0.0
static var _shared: Array = []


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	if _reaction_bus != null:
		if not _reaction_bus.boosted.is_connected(_on_boost_action):
			_reaction_bus.boosted.connect(_on_boost_action)
		if not _reaction_bus.dashed.is_connected(_on_boost_action):
			_reaction_bus.dashed.connect(_on_boost_action)
		if not _reaction_bus.sprint_started.is_connected(_on_boost_action):
			_reaction_bus.sprint_started.connect(_on_boost_action)
		if not _reaction_bus.blink_used.is_connected(_on_blink_action):
			_reaction_bus.blink_used.connect(_on_blink_action)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 4.0
	attack_range = 22.0


func _build_tool() -> void:
	_presence = FoleyAudio.player("jolt_layer_presence", self)
	if _presence != null:
		_presence.autoplay = true
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.name == "JoltCoil":
				_coil = mi
		return
	_spool = _cylinder(0.55, 0.5, Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.9, -0.25))
	_spool.rotation.z = PI * 0.5
	_coil = _cylinder(0.12, 1.6, Palette.ARC, Vector3(0.0, CREW_HALF + 1.6, -0.25), 1.4)


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_one/enemy_jolt_layer.glb", "jolt_layer")
	return _shared


func _physics_process(delta: float) -> void:
	_boost_grace = maxf(0.0, _boost_grace - delta)
	if _whip_primed and phase == Phase.ROAM and not recovering() and not stunned():
		_rest = minf(_rest, 1.0)
	super._physics_process(delta)


func _on_boost_action(_dir: Vector3) -> void:
	_boost_grace = BOOST_GRACE_S


func _on_blink_action(_from: Vector3, _to: Vector3) -> void:
	_boost_grace = BOOST_GRACE_S


func whip_wave_position() -> Vector3:
	return _whip_pos


func _commit(to_ball: Vector3) -> Node3D:
	if _whip_primed:
		_whip_primed = false
		_whipping = true
		_whip_hit = false
		_whip_reversed = false
		_whip_spark_t = 0.0
		_rim_time = 0.0
		field = null
		_told = -1
		warn_seconds = WHIP_WARN
		live_seconds = WHIP_LIVE
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_whip_dir = flat.normalized() if flat.length() > 0.1 else -global_transform.basis.z
		_whip_origin = global_position
		_whip_pos = global_position
		_facing(_whip_dir)
		_cue("tell")
		_crackle(10, 8)
		return _commit_lane(Threat.Type.LANE, _whip_origin, _whip_dir, WHIP_LENGTH, WHIP_WIDTH, WHIP_REACH)
	_whipping = false
	_whip_hit = false
	_whip_reversed = false
	_rim_time = 0.0
	_mat_start_hp = hp
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	var at := _ahead(warn_seconds, LAY_AHEAD)
	field = AreaField.new(FIELD, at, self)
	if _on_water(at):
		field.spread = WET_SPREAD
	var ring: Node3D = _commit_ring(Threat.Type.INSTANT, at, field.radius(), 4.0)
	if ring != null:
		ring.lands_on_live = false
	return ring


func _go_live() -> void:
	if _whipping:
		cable_whips += 1
		_whip_pos = _whip_origin
		_crackle(12, 10)


func _live(delta: float) -> bool:
	if _whipping:
		return _live_whip(delta)
	var tele := telegraph()
	if tele == null or field == null:
		return false
	var player = _player()
	if player != null and hp >= _mat_start_hp - 0.1 and player.speed_tier() < SpeedTier.FAST:
		var ball := _real_ball()
		var dist := Vector2(ball.x - field.centre.x, ball.z - field.centre.z).length()
		var r: float = field.radius()
		if dist >= r * RIM_INNER_RATIO and dist <= r + RIM_OUTER_MARGIN and absf(ball.y - field.centre.y) <= 4.0:
			_rim_time += delta
			if _rim_time >= RIM_SKIRT_S:
				_whip_primed = true
		else:
			_rim_time = maxf(0.0, _rim_time - delta * 2.0)
	else:
		_rim_time = maxf(0.0, _rim_time - delta * 2.0)
	var pulsed: bool = field.step(delta)
	tele.set_progress(field.lead_fraction())
	if field.pulses != _told and field.until_pulse() <= FoleyAudio.JOLT_TELL_LEAD:
		_told = field.pulses
		_cue("tell")
		_crackle(8, 6)
	if not pulsed:
		return true
	tele.land()
	_crackle(12, 10)
	if player == null:
		return true
	match String(field.pulse_player(player, _real_ball())):
		"landed":
			jolts += 1
			flash()
			_cue("jam")
			_recall_q()
		"speed", "air", "line":
			slipped += 1
			if fleet != null:
				fleet.discover("mat_slip", _real_ball())
	return true


func _live_whip(delta: float) -> bool:
	if _whip_reversed or _dead:
		return false
	var tele := telegraph()
	if tele == null:
		return false
	var u := clampf(_t / WHIP_LIVE, 0.0, 1.0)
	var along := u * WHIP_LENGTH
	var flat_at := _whip_origin + _whip_dir * along
	var gy: float = Telegraph.ground_under(terrain, flat_at) if terrain != null else _whip_origin.y
	_whip_pos = Vector3(flat_at.x, gy + 0.5, flat_at.z)
	tele.run_body(along, WHIP_WAVE_REACH)
	_whip_spark_t += delta
	if _whip_spark_t >= 0.08 and world_root != null and is_inside_tree():
		_whip_spark_t = 0.0
		FxLibrary.burst(world_root, "arc_fizz", _whip_pos, 4)
		FxLibrary.burst(world_root, "brass_spark", _whip_pos, 3)
	var player = _player()
	if player != null:
		var ball := _real_ball()
		var dist_wave := Vector2(ball.x - _whip_pos.x, ball.z - _whip_pos.z).length()
		var dy := absf(ball.y - _whip_pos.y)
		if dist_wave <= WHIP_WAVE_REACH and dy <= WHIP_REACH:
			var boosting: bool = _boost_grace > 0.0 or player.kit.sprinting or player.speed_tier() >= SpeedTier.BLAZING
			if boosting:
				_reverse_surge(player)
				return false
			if not _whip_hit and player.state.on_floor():
				_whip_hit = true
				whip_jolts += 1
				if player.crowd_control("cable_whip", Vector3.ZERO, true):
					player.abilities.jam(WHIP_JAM_S)
				_recall_q()
				hit_player.emit(WHIP_DAMAGE, _whip_dir * WHIP_SHOVE)
				flash()
				_cue("jam")
	return _t < WHIP_LIVE


func _reverse_surge(player) -> void:
	if _whip_reversed or _dead:
		return
	_whip_reversed = true
	short_outs += 1
	if player != null and player.abilities != null:
		var cd: float = player.abilities.cooldown_of(AbilityState.SPECIAL)
		if cd > 0.0:
			player.abilities.refund(AbilityState.SPECIAL, cd * SPECIAL_REFUND_SHARE)
		if player.abilities.jammed():
			player.abilities.jam_left = 0.0
	_crackle(16, 14)
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "phase_ring", global_position + Vector3.UP * 1.2, 20, Palette.ARC)
	take_damage(hp)


func _on_water(at: Vector3) -> bool:
	return terrain != null and terrain.has_method("on_water") and terrain.on_water(at)


func _recall_q() -> void:
	var combat = fleet.combat if fleet != null else null
	var ult = combat.ultimate if combat != null else null
	if ult != null and ult.winding_up():
		ult.recall()
		recalls += 1
		_cue("fizzle")


func _on_end() -> void:
	field = null
	_told = -1
	_whipping = false
	_whip_hit = false
	_whip_reversed = false
	_rim_time = 0.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE


func _die() -> void:
	FoleyAudio.one_shot("jolt_layer_break", get_parent(), global_position)
	super._die()


func _cue(part: String) -> void:
	if is_inside_tree():
		FoleyAudio.one_shot("jolt_layer_" + part, get_parent(), global_position)


func _crackle(arcs: int, sparks: int) -> void:
	if world_root == null or not is_inside_tree():
		return
	var at := _coil.global_position if is_instance_valid(_coil) else global_position + Vector3(0.0, 2.2, -0.25)
	FxLibrary.burst(world_root, "arc_fizz", at, arcs)
	FxLibrary.burst(world_root, "brass_spark", at, sparks)


func _pose() -> void:
	if _coil != null:
		var lead: float = field.lead_fraction() if field != null else (_warn_progress() if _whipping and phase == Phase.WARN else (1.0 if _whipping and phase == Phase.LIVE else 0.0))
		_coil.scale = Vector3.ONE * (1.0 + 0.35 * clampf(lead, 0.0, 1.0))
		var spin := 0.28 + 0.32 * lead if phase == Phase.LIVE else (0.24 if _whipping and phase == Phase.WARN else (0.14 if phase == Phase.WARN else 0.03))
		_coil.rotation.y = wrapf(_coil.rotation.y + spin * Comfort.motion_scale(), -PI, PI)
	if _spool != null:
		var spool_spin := 0.55 if _whipping and phase != Phase.ROAM else (0.25 if phase == Phase.LIVE else 0.02)
		_spool.rotation.x += spool_spin * Comfort.motion_scale()


func _exit_tree() -> void:
	if is_instance_valid(_reaction_bus):
		if _reaction_bus.boosted.is_connected(_on_boost_action):
			_reaction_bus.boosted.disconnect(_on_boost_action)
		if _reaction_bus.dashed.is_connected(_on_boost_action):
			_reaction_bus.dashed.disconnect(_on_boost_action)
		if _reaction_bus.sprint_started.is_connected(_on_boost_action):
			_reaction_bus.sprint_started.disconnect(_on_boost_action)
		if _reaction_bus.blink_used.is_connected(_on_blink_action):
			_reaction_bus.blink_used.disconnect(_on_blink_action)
	super._exit_tree()
