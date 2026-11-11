extends RefCounted

const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Roster := preload("res://src/combat/roster.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")

# Pack pressure E, silt boils (pack_pressure.gd; idle while hazard.boil_by_stage reads 0). The ball stirs the
# Spillway's silt: while a fight is on (an enemy within FIGHT_RADIUS) and the ball has stalled, the silt boils
# up where it is heading. Stalled (wave 37 unit D5, ruling cu call 3; hazard.boil_stall_by_stage 1) means every
# spot the ball has been in the last LOOP_WINDOW seconds lies within STALL_SPREAD metres of their centre: it
# stopped, it crawled, or it held a tight orbit. A ball that keeps covering ground, a wide curve round a pack
# included, never boils. With that dial at 0 the test is the one the boils shipped with: at least LOOP_PATH
# metres rolled in the window, ending under LOOP_NET from where it started (a loop, the rut test), which
# also boiled a wide kite and never a ball that stood still. A low rumble sounds and a ring is committed
# on the ball's predicted roll WARN seconds ahead; the ring fills for WARN seconds, then erupts: a ball
# inside takes DAMAGE times the dial (then the stage mob dial, x1.5 on the dam, ChallengeDials MOBS_DAMAGE_W1) and a kick up, and every enemy inside is tossed and takes ENEMY_DAMAGE
# (bait a crew into it). After a boil the silt rests REST plus a seeded 0 to JITTER seconds. Seeded per run
# and stage, so a seed replays the same boils for the same rolling.
#
# The silt prices standing your ground against a roaming pack, not the loops the game asks for: nothing boils inside the ring of an engaged,
# standing Warden (the fight holds the ball there), and an activity's own crew (an event pack, a camp
# brute, a relay's minibosses) is no fight while it stays within SITE_LEASH of its site. Only roaming packs,
# or a crew dragged off its site, start a boil, and only while the stage is in play before its exit: the
# gates and the launch are a course to run, so the silt lies still from the Warden's break. The rules hold for
# a ring already rumbling too: the moment one turns true (the Warden breaks, or the ball enters an engaged
# Warden's ring) the pending ring is quelled, its ring, marker and rumble cut, and it never erupts.

const FIGHT_RADIUS := 30.0
const LOOP_WINDOW := 10.0
const LOOP_PATH := 60.0
const LOOP_NET := 36.0
# The stall test's reach: wider than the 14 m ring (and its 3 m band) a ball orbits a pack on, so that orbit
# still boils; a kite ring of 20 m or more is free.
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
# Beyond the Warden's ring radius the ball is out of its fight; past this from its site a crew is roaming.
const RING_MARGIN := 10.0
const SITE_LEASH := 40.0
# Flow states the silt boils in (flow.gd NAMES): roaming and the Warden's ring, never the exit run.
const BOIL_STATES := ["stage", "beacon"]

signal rumbled(at: Vector3, seconds_until: float)
signal erupted(at: Vector3, hit_ball: bool, enemies: int)
signal quelled(at: Vector3)

var boils := 0
var ball_hits := 0
var enemy_tosses := 0
var quells := 0
# Set by combat: lands a hit on the pilot as every other hazard does (combat._on_player_hit).
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


# Combat calls this on every stage entry (retries included) and, with counts, on a run start: the seed is
# the run's and the stage's, so an attempt replays the same boils for the same rolling.
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


# Stage play only: the boss arena never boils.
func step(delta: float, enemies: Array) -> void:
	var k := strength()
	if k <= 0.0 or not _ctx.flow.in_stage():
		if _ring != null:
			_quell()
		return
	var ball: Vector3 = _ctx.player.ball_position()
	# Exempt (the exit run, an engaged Warden's ring): a pending ring is quelled, and the loop read waits
	# for the exemption to end, so leaving a long one cannot arm a ring on its first tick.
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
		# A ring freed under it (a fight cleared) is a boil that never erupts.
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


# Whether the ball's last LOOP_WINDOW seconds stir the silt: the stall test where the stage's dial is on, the
# loop test where it is off. Neither reads before the window is full.
func _stirring() -> bool:
	if _samples.size() < int(LOOP_WINDOW / SAMPLE_S) + 1:
		return false
	if ChallengeDials.by_stage_or("hazard.boil_stall_by_stage", int(_ctx.run.stage), 0.0) > 0.0:
		return _stalled()
	return _looping()


# Every sample of the window lies within STALL_SPREAD of the samples' centre.
func _stalled() -> bool:
	var centre := Vector3.ZERO
	for at in _samples:
		centre += _flat(at)
	centre /= float(_samples.size())
	for at in _samples:
		if (_flat(at) - centre).length() > STALL_SPREAD:
			return false
	return true


func _looping() -> bool:
	var path := 0.0
	for i in range(1, _samples.size()):
		path += _flat(_samples[i] - _samples[i - 1]).length()
	return path >= LOOP_PATH and _flat(_samples[-1] - _samples[0]).length() < LOOP_NET


# The exit run (gates, launch) and an engaged, standing Warden's ring: no boil arms there, and none pending erupts.
func _exempt(ball: Vector3) -> bool:
	return not _ctx.flow.state_name() in BOIL_STATES or _in_warden_ring(ball)


func _in_warden_ring(ball: Vector3) -> bool:
	var flow = _ctx.flow
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
		if _set_piece(enemy) or _flat(enemy.global_position - ball).length() > FIGHT_RADIUS:
			continue
		if crews == null:
			crews = _activity_crews()
		if crews.has(enemy) and _flat(enemy.global_position - crews[enemy]).length() <= SITE_LEASH:
			continue
		return true
	return false


# Every enemy an activity site holds (its pack, its brute and its minibosses), to its site's position.
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
		if _set_piece(enemy) or not is_instance_valid(_ring):
			continue
		if not _ring.contains(enemy.global_position - Vector3.UP * float(enemy.get("half_height"))):
			continue
		tossed += 1
		if enemy.has_method("knock"):
			enemy.knock(Vector3.UP, ENEMY_TOSS)
		if enemy.has_method("take_damage"):
			# Tagged as the wear trail tags its sparks, so the kill's source says the silt did it.
			enemy.set("last_damage_source", "silt_boil")
			enemy.take_damage(ENEMY_DAMAGE)
	enemy_tosses += tossed
	erupted.emit(at, hit, tossed)
	_drop_ring()
	_rest = REST + _rng.randf() * JITTER


# A pending ring the stage exempted: no eruption, no damage, and the silt rests as after a boil.
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


# Wardens, vaults and boss pieces are set pieces: they neither start a boil nor take one.
static func _set_piece(enemy) -> bool:
	var kind := String(enemy.get("kind"))
	return kind in ["warden", "vault"] or Roster.is_boss_piece(kind)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
