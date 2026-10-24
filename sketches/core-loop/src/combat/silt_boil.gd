extends RefCounted

const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Roster := preload("res://src/combat/roster.gd")

# Pack pressure E, silt boils (pack_pressure.gd; idle while hazard.boil_by_stage reads 0). The ball stirs the
# Spillway's silt: while a fight is on (an enemy within FIGHT_RADIUS) and the ball has rolled at least
# LOOP_PATH metres in the last LOOP_WINDOW seconds but ended under LOOP_NET from where it started (a loop, the
# rut test), the silt boils up where its loop is carrying it. A low rumble sounds and a ring is committed
# on the ball's predicted roll WARN seconds ahead; the ring fills for WARN seconds, then erupts: a ball
# inside takes DAMAGE times the dial and a kick up, and every enemy inside is tossed and takes ENEMY_DAMAGE
# (bait a crew into it). After a boil the silt rests REST plus a seeded 0 to JITTER seconds. Seeded per run
# and stage, so a seed replays the same boils for the same rolling.

const FIGHT_RADIUS := 30.0
const LOOP_WINDOW := 10.0
const LOOP_PATH := 60.0
const LOOP_NET := 36.0
const SAMPLE_S := 0.5
const WARN := 1.2
const RADIUS := 4.5
const DAMAGE := 10.0
const KICK := 9.0
const ENEMY_DAMAGE := 25.0
const ENEMY_TOSS := 14.0
const REST := 4.0
const JITTER := 2.0

signal rumbled(at: Vector3, seconds_until: float)
signal erupted(at: Vector3, hit_ball: bool, enemies: int)

var boils := 0
var ball_hits := 0
var enemy_tosses := 0
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
	_drop_ring()
	if counts:
		boils = 0
		ball_hits = 0
		enemy_tosses = 0


# Stage play only: the boss arena never boils.
func step(delta: float, enemies: Array) -> void:
	var k := strength()
	if k <= 0.0 or not _ctx.flow.in_stage():
		return
	var ball: Vector3 = _ctx.player.ball_position()
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
			return
		_ring_age += delta
		_ring.set_progress(_ring_age / WARN)
		if _ring_age >= WARN:
			_erupt(k, enemies)
		return
	_rest -= delta
	if _rest > 0.0 or not _looping() or not _fighting(ball, enemies):
		return
	var at := PackPressure.predict(_ctx.player, WARN)
	_ring = Telegraph.ring(_ctx.root, _terrain, Threat.Type.INSTANT, at, RADIUS)
	_ring_age = 0.0
	boils += 1
	rumbled.emit(at, WARN)


func _looping() -> bool:
	if _samples.size() < int(LOOP_WINDOW / SAMPLE_S) + 1:
		return false
	var path := 0.0
	for i in range(1, _samples.size()):
		path += _flat(_samples[i] - _samples[i - 1]).length()
	return path >= LOOP_PATH and _flat(_samples[-1] - _samples[0]).length() < LOOP_NET


func _fighting(ball: Vector3, enemies: Array) -> bool:
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if _set_piece(enemy):
			continue
		if _flat(enemy.global_position - ball).length() <= FIGHT_RADIUS:
			return true
	return false


func _erupt(k: float, enemies: Array) -> void:
	var at: Vector3 = _ring.center if is_instance_valid(_ring) else Vector3.ZERO
	var hit: bool = is_instance_valid(_ring) and _ring.contains(_ctx.player.ball_position())
	if hit:
		ball_hits += 1
		if deal.is_valid():
			deal.call(DAMAGE * k, Vector3.UP * KICK)
	var tossed := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
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
