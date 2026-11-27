extends RefCounted

const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Roster := preload("res://src/combat/roster.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")

const FIGHT_RADIUS := 30.0
const LOOP_WINDOW := 10.0
const LOOP_PATH := 60.0
const LOOP_NET := 36.0
const STALL_SPREAD := 18.0
const SAMPLE_S := 0.5
const WARN := 1.2
const RADIUS := 4.5
const DAMAGE := 10.0
const KICK := 9.0
const ENEMY_DAMAGE := 25.0
const ENEMY_TOSS := 14.0
const REST := 4.0
const JITTER := 2.0
const RING_MARGIN := 10.0
const SITE_LEASH := 40.0
const BOIL_STATES := ["stage", "beacon"]

signal rumbled(at: Vector3, seconds_until: float)
signal erupted(at: Vector3, hit_ball: bool, enemies: int)
signal quelled(at: Vector3)

var boils := 0
var ball_hits := 0
var enemy_tosses := 0
var quells := 0
var deal: Callable

var _ctx
var _terrain
var _rng := RandomNumberGenerator.new()
var _samples: Array = []
var _sample_clock := 0.0
var _rest := 0.0
var _ring: Node3D = null
var _ring_age := 0.0


func setup(ctx, terrain_ref = null) -> void:
	_ctx = ctx
	_terrain = terrain_ref


func strength() -> float:
	if _ctx == null or _ctx.run == null:
		return 0.0
	return ChallengeDials.by_stage_or("hazard.boil_by_stage", int(_ctx.run.stage), 0.0)


func reset(counts := false) -> void:
	_rng.seed = hash([int(_ctx.run.run_seed), int(_ctx.run.stage), "silt_boil"])
	_samples.clear()
	_sample_clock = 0.0
	_rest = REST
	if _ring != null:
		quelled.emit(_ring.center if is_instance_valid(_ring) else Vector3.ZERO)
	_drop_ring()
	if counts:
		boils = 0
		ball_hits = 0
		enemy_tosses = 0
		quells = 0


func step(delta: float, enemies: Array) -> void:
	var k := strength()
	if k <= 0.0 or not _ctx.flow.in_stage():
		if _ring != null:
			_quell()
		return
	var ball: Vector3 = _ctx.player.ball_position()
	if _exempt(ball):
		if _ring != null:
			_quell()
		_samples.clear()
		_sample_clock = 0.0
		return
	_sample_clock += delta
	if _sample_clock >= SAMPLE_S:
		_sample_clock = 0.0
		_samples.append(ball)
		while _samples.size() > int(LOOP_WINDOW / SAMPLE_S) + 1:
			_samples.pop_front()
	if _ring != null:
		if not is_instance_valid(_ring):
			_drop_ring()
			_rest = REST
			quelled.emit(Vector3.ZERO)
			return
		_ring_age += delta
		_ring.set_progress(_ring_age / WARN)
		if _ring_age >= WARN:
			_erupt(k, enemies)
		return
	_rest -= delta
	if _rest > 0.0 or not _stirring() or not _fighting(ball, enemies):
		return
	var at := PackPressure.predict(_ctx.player, WARN)
	_ring = Telegraph.ring(_ctx.root, _terrain, Threat.Type.INSTANT, at, RADIUS)
	_ring_age = 0.0
	boils += 1
	rumbled.emit(at, WARN)


func _stirring() -> bool:
	if _samples.size() < int(LOOP_WINDOW / SAMPLE_S) + 1:
		return false
	if ChallengeDials.by_stage_or("hazard.boil_stall_by_stage", int(_ctx.run.stage), 0.0) > 0.0:
		return _stalled()
	return _looping()


func _stalled() -> bool:
	return stalled(_samples)


static func stalled(samples: Array) -> bool:
	if samples.size() < int(LOOP_WINDOW / SAMPLE_S) + 1:
		return false
	var centre := Vector3.ZERO
	for at in samples:
		centre += _flat(at)
	centre /= float(samples.size())
	for at in samples:
		if (_flat(at) - centre).length() > STALL_SPREAD:
			return false
	return true


func _looping() -> bool:
	var path := 0.0
	for i in range(1, _samples.size()):
		path += _flat(_samples[i] - _samples[i - 1]).length()
	return path >= LOOP_PATH and _flat(_samples[-1] - _samples[0]).length() < LOOP_NET


func _exempt(ball: Vector3) -> bool:
	return _ctx.get("calm") == true or exempt(_ctx.flow, ball)


static func exempt(flow, ball: Vector3) -> bool:
	return not flow.state_name() in BOIL_STATES or _in_warden_ring(flow, ball)


static func _in_warden_ring(flow, ball: Vector3) -> bool:
	if not flow.engaged():
		return false
	var beacon = flow.get("beacon")
	var warden = flow.get("warden")
	if beacon == null or warden == null or not is_instance_valid(warden):
		return false
	return _flat(beacon.global_position - ball).length() <= float(beacon.radius) + RING_MARGIN


func _fighting(ball: Vector3, enemies: Array) -> bool:
	var crews = null
	for enemy in enemies:
		if DamageDoor.dead(enemy):
			continue
		if set_piece(enemy) or _flat(enemy.global_position - ball).length() > FIGHT_RADIUS:
			continue
		if crews == null:
			crews = _activity_crews()
		if crews.has(enemy) and _flat(enemy.global_position - crews[enemy]).length() <= SITE_LEASH:
			continue
		return true
	return false


func _activity_crews() -> Dictionary:
	var out := {}
	var world = _ctx.root.get_node_or_null("World") if _ctx.root != null else null
	var activities = world.get("activities") if world != null else null
	if activities == null:
		return out
	for site in activities.sites:
		if not is_instance_valid(site):
			continue
		for enemy in site.pack + site.minibosses + [site.brute]:
			if enemy != null and is_instance_valid(enemy):
				out[enemy] = site.global_position
	return out


func _erupt(k: float, enemies: Array) -> void:
	var at: Vector3 = _ring.center if is_instance_valid(_ring) else Vector3.ZERO
	var hit: bool = is_instance_valid(_ring) and _ring.contains(_ctx.player.ball_position())
	if hit:
		ball_hits += 1
		if deal.is_valid():
			deal.call(DAMAGE * k, Vector3.UP * KICK)
	var tossed := 0
	for enemy in enemies:
		if DamageDoor.dead(enemy):
			continue
		if set_piece(enemy) or not is_instance_valid(_ring):
			continue
		if not _ring.contains(enemy.global_position - Vector3.UP * float(enemy.get("half_height"))):
			continue
		tossed += 1
		if enemy.has_method("knock"):
			enemy.knock(Vector3.UP, ENEMY_TOSS)
		if enemy.has_method("take_damage"):
			enemy.set("last_damage_source", "silt_boil")
			enemy.take_damage(ENEMY_DAMAGE)
	enemy_tosses += tossed
	erupted.emit(at, hit, tossed)
	_drop_ring()
	_rest = REST + _rng.randf() * JITTER


func _quell() -> void:
	var at: Vector3 = _ring.center if is_instance_valid(_ring) else Vector3.ZERO
	_drop_ring()
	_rest = REST
	quells += 1
	quelled.emit(at)


func _drop_ring() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	_ring_age = 0.0


static func set_piece(enemy) -> bool:
	var kind := String(enemy.get("kind"))
	return kind in ["warden", "vault"] or Roster.is_boss_piece(kind)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
