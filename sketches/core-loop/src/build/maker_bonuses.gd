extends RefCounted

const MakerSets := preload("res://src/build/maker_sets.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Palette := preload("res://src/core/palette.gd")

# What a completed maker set does (maker_sets.gd counts the pieces). Build owns this: refresh()
# recounts the run's parts (relics among them) and racked active, step() runs the timed bonuses, and the bus
# handlers and one damage-door hook run the rest. Every bonus strikes through build.item_hit (a
# synergy strike that never procs an item) or combat's wear-trail bypass, so no bonus feeds
# another in a loop. A set completing is announced once a run on the bus as cause_armed
# ("set_" + bonus), and each firing as cause_fired, so the run log counts them and presentation
# can give them a look of their own.
#
# Bench Teeth lays its teeth along the ball's carve line: BallState.carving once wall grip (#61)
# adds it, and until then the ball's own fast ground roll (the same fallback the Waking's
# carving_now() uses). lay_tooth() is open to any other carve source.

# Full Pressure: the steam ring an active vents.
const STEAM_RADIUS := 7.0
const STEAM_DAMAGE := 8.0
const STEAM_KNOCK := 18.0
# Rounded Up: hits round up to the next multiple of this.
const ROUND_TO := 5.0
# Bench Teeth: a tooth every TOOTH_SPACING metres of fast ground roll, at speed tier
# TOOTH_TIER or above; each lives TOOTH_LIFE seconds and bites a machine within TOOTH_REACH
# once per TOOTH_REBITE seconds.
const TOOTH_SPACING := 2.2
const TOOTH_TIER := 1
const TOOTH_LIFE := 3.0
const TOOTH_REACH := 1.6
const TOOTH_DAMAGE := 10.0
const TOOTH_REBITE := 0.5
const MAX_TEETH := 30
# Tremor: a landing at or above TREMOR_MIN impact ripples TREMOR_RADIUS plus TREMOR_GROWTH per
# point of impact, up to TREMOR_MAX metres; damage scales with the impact over TREMOR_REF.
const TREMOR_MIN := 4.0
const TREMOR_RADIUS := 4.5
const TREMOR_GROWTH := 0.25
const TREMOR_MAX := 9.0
const TREMOR_DAMAGE := 14.0
const TREMOR_REF := 8.0
const TREMOR_KNOCK := 12.0
const TREMOR_GAP := 0.35
# Noticed: a crit's splinter strikes SPLINTER_SHARE of the crit SPLINTER_DELAY later, the same
# machine or the nearest within SPLINTER_REACH; at most SPLINTER_PER_SECOND.
const SPLINTER_DELAY := 0.3
const SPLINTER_SHARE := 0.5
const SPLINTER_REACH := 7.0
const SPLINTER_PER_SECOND := 8.0
const HOOK := "maker_sets"
const MOSS_SOURCES_SKIPPED := ["spare", "evolution"]

var build
var ctx
# maker -> distinct pieces held.
var counted := {}
var live: Array = []
var fires := {}
var _signature := ""
var _announced := {}
var _spare_armed := false
var _teeth: Array = []
var _rolled := 0.0
var _last_ball := Vector3.INF
var _bitten := {}
var _clock := 0.0
var _tremor_ready := 0.0
var _splinters: Array = []
var _splinter_budget := SPLINTER_PER_SECOND
var _tooth_serial := 0


func _init(owner_build) -> void:
	build = owner_build
	ctx = owner_build.ctx


func setup() -> void:
	ctx.events.active_fired.connect(_on_active_fired)
	ctx.events.landed.connect(_on_landed)
	ctx.events.part_gained.connect(_on_part_gained)
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): _on_stage())
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear_flight())
	ctx.events.run_started.connect(func(_class_id: String): reset())
	var door = ctx.spawner.get("door") if ctx.spawner != null else null
	if door != null and door.has_method("hook") and not door.hook("hit", HOOK, _on_door_hit):
		push_error("maker sets: the damage door refused the %s hook; Rounded Up and Noticed are off" % HOOK)


func reset() -> void:
	counted = {}
	live = []
	fires = {}
	_signature = ""
	_announced.clear()
	_spare_armed = false
	_clear_flight()


func has(bonus_id: String) -> bool:
	return bonus_id in live


# Recounts the pieces when the parts or the racked active changed. Cheap when nothing did.
func refresh() -> void:
	var active := _racked_maker()
	# The parts themselves, not their count: a retry or a sale can swap one part for another.
	var signature := "%d|%s" % [ctx.run.parts.hash(), active]
	if signature == _signature:
		return
	_signature = signature
	counted = MakerSets.counts(ctx.run.parts, [active] if active != "" else [])
	var was := live
	live = MakerSets.live_bonuses(counted)
	for bonus_id in live:
		if not bonus_id in was:
			_on_completed(bonus_id)


# The open-frame rule the active rack asks at release: fired in the air, an active fires twice.
func fires_twice() -> bool:
	return has("open_frame") and ctx.player != null and not bool(ctx.player.state.grounded)


func note_fire(bonus_id: String, target: Node3D, at: Vector3) -> void:
	fires[bonus_id] = int(fires.get(bonus_id, 0)) + 1
	ctx.events.cause_fired.emit("set_" + bonus_id, target, at)


func step(delta: float) -> void:
	_clock += delta
	refresh()
	_splinter_budget = minf(SPLINTER_PER_SECOND, _splinter_budget + SPLINTER_PER_SECOND * delta)
	_step_splinters()
	_step_teeth(delta)


func _racked_maker() -> String:
	var rack = ctx.spawner.get("actives") if ctx.spawner != null else null
	if rack == null or not rack.has_method("enabled") or not rack.enabled() or String(rack.active_id) == "":
		return ""
	return String(ActiveDefs.row(String(rack.active_id)).get("maker", ""))


func _on_completed(bonus_id: String) -> void:
	if bonus_id == "packed_a_spare":
		_spare_armed = true
	if _announced.has(bonus_id):
		return
	_announced[bonus_id] = true
	ctx.events.cause_armed.emit("set_" + bonus_id)
	ctx.events.maker_set_completed.emit(MakerSets.maker_of_bonus(bonus_id), bonus_id)
	var fx = _effects()
	if fx != null:
		var ball: Vector3 = ctx.player.ball_position()
		for i in 3:
			fx.ring(ball, 2.5 + 2.0 * i, Palette.BRASS)


func _on_stage() -> void:
	_clear_flight()
	refresh()
	_spare_armed = has("packed_a_spare")


func _clear_flight() -> void:
	_teeth.clear()
	_bitten.clear()
	_splinters.clear()
	_last_ball = Vector3.INF
	_rolled = 0.0


# ---- Full Pressure (Spillway Works) ----

func _on_active_fired(_active_id: String, at: Vector3, _count: int) -> void:
	if not has("full_pressure") or not ctx.flow.in_play():
		return
	var fx = _effects()
	if fx != null:
		fx.ring(at, STEAM_RADIUS, Palette.SAND)
		fx.ring(at, STEAM_RADIUS * 0.6, Palette.SAND)
	for enemy in build.enemies_near(at, STEAM_RADIUS, 32):
		if not is_instance_valid(enemy):
			continue
		var away: Vector3 = enemy.global_position - at
		away.y = 0.0
		if enemy.has_method("knock"):
			enemy.knock(away.normalized() if away.length() > 0.1 else Vector3.FORWARD, STEAM_KNOCK)
		build.item_hit(enemy, STEAM_DAMAGE * ctx.run.heft())
	note_fire("full_pressure", null, at)


# ---- Rounded Up (Fleet Surplus) and Noticed (Mind-glass): one door hook ----

func _on_door_hit(hit: Dictionary) -> void:
	var enemy = hit.get("enemy")
	var result: Dictionary = hit.get("result", {})
	if not is_instance_valid(enemy) or result.is_empty():
		return
	var dealt := float(result.get("dealt", 0.0))
	# A target no player hit hurts (a crew fitter) gets neither bonus. A plate that takes a hit whole is not one:
	# Rounded Up's top-up still lands through it (coordinator ruling, 24 Oct: no nerf in a small lane).
	if dealt <= 0.0 or (enemy.has_method("takes_no_damage") and enemy.takes_no_damage()):
		return
	if has("noticed") and String(hit.get("kind", "")) != "synergy" and _is_crit(enemy, result) \
			and _splinter_budget >= 1.0:
		_splinter_budget -= 1.0
		_splinters.append({"at": _clock + SPLINTER_DELAY, "enemy": weakref(enemy),
			"where": enemy.global_position, "damage": dealt * SPLINTER_SHARE})
	if has("rounded_up") and not bool(hit.get("killed", false)):
		var extra := ceilf(dealt / ROUND_TO - 0.0001) * ROUND_TO - dealt
		if extra > 0.01 and ctx.spawner.has_method("_trail_deal"):
			ctx.spawner._trail_deal(enemy, extra, "rounded_up", "item_proc")
			fires["rounded_up"] = int(fires.get("rounded_up", 0)) + 1


# The crit rule juice.gd and the damage numbers use (DamageNumbers.is_crit): a weak point
# softer than the body plating, or a dealt figure above the punch.
func _is_crit(enemy: Node3D, result: Dictionary) -> bool:
	var dealt := float(result.get("dealt", 0.0))
	var body := float(ctx.spawner.plating_of(enemy)) if ctx.spawner.has_method("plating_of") else -INF
	var weak := String(result.get("part", "")) != "" and float(result.get("plating", 0.0)) < body
	return weak or dealt > float(result.get("punch", dealt)) * 1.01


func _step_splinters() -> void:
	var due := []
	for s in _splinters:
		if float(s["at"]) <= _clock:
			due.append(s)
	for s in due:
		_splinters.erase(s)
		var target: Node3D = s["enemy"].get_ref()
		if not is_instance_valid(target) or (target.has_method("is_dead") and target.is_dead()):
			var near: Array = build.enemies_near(s["where"], SPLINTER_REACH, 1)
			target = near[0] if not near.is_empty() else null
		if target == null:
			continue
		var fx = _effects()
		if fx != null:
			fx.arc(s["where"] + Vector3.UP * 1.5, target.global_position + Vector3.UP * 0.6, Palette.VERDIGRIS)
		# item_hit applies the weapon multiplier; the crit's dealt figure already carries it.
		build.item_hit(target, float(s["damage"]) / maxf(0.01, build.sheet.mod("weapon_damage")))
		note_fire("noticed", target, target.global_position)


# ---- Bench Teeth (Redjaw Workshops) ----

func _step_teeth(delta: float) -> void:
	for tooth in _teeth:
		tooth["life"] -= delta
	_teeth = _teeth.filter(func(tooth): return float(tooth["life"]) > 0.0)
	if _teeth.is_empty():
		_bitten.clear()
	if not has("bench_teeth") or not ctx.flow.in_play():
		_last_ball = Vector3.INF
		return
	var ball: Vector3 = ctx.player.ball_position()
	if _carving() and _last_ball != Vector3.INF:
		_rolled += Vector2(ball.x - _last_ball.x, ball.z - _last_ball.z).length()
		if _rolled >= TOOTH_SPACING:
			_rolled = 0.0
			lay_tooth(ball)
	else:
		_rolled = 0.0
	_last_ball = ball
	for tooth in _teeth:
		for enemy in build.enemies_near(tooth["at"], TOOTH_REACH, 4):
			var key := "%d:%d" % [int(tooth["id"]), enemy.get_instance_id()]
			if float(_bitten.get(key, -INF)) + TOOTH_REBITE > _clock:
				continue
			_bitten[key] = _clock
			build.item_hit(enemy, TOOTH_DAMAGE * ctx.run.heft())
			var fx = _effects()
			if fx != null:
				fx.spark(tooth["at"] + Vector3.UP * 0.4, Palette.RUST)
			note_fire("bench_teeth", enemy, tooth["at"])


func _carving() -> bool:
	var state = ctx.player.state
	if "carving" in state:
		return bool(state.carving)
	return bool(state.grounded) and int(state.tier) >= TOOTH_TIER


func lay_tooth(at: Vector3) -> void:
	_tooth_serial += 1
	_teeth.append({"id": _tooth_serial, "at": at, "life": TOOTH_LIFE})
	if _teeth.size() > MAX_TEETH:
		_teeth.pop_front()
	var fx = _effects()
	if fx != null:
		fx.spark(at + Vector3.UP * 0.2, Palette.RUST)


func teeth() -> Array:
	return _teeth.duplicate(true)


# ---- Tremor (Waking-made) ----

func _on_landed(impact: float) -> void:
	if not has("tremor") or impact < TREMOR_MIN or _clock < _tremor_ready or not ctx.flow.in_play():
		return
	_tremor_ready = _clock + TREMOR_GAP
	var at: Vector3 = ctx.player.ball_position()
	var radius := minf(TREMOR_MAX, TREMOR_RADIUS + TREMOR_GROWTH * impact)
	var fx = _effects()
	if fx != null:
		fx.ring(at, radius, Palette.ANCIENT)
		fx.ring(at, radius * 0.5, Palette.ANCIENT)
	var scale := clampf(impact / TREMOR_REF, 0.75, 2.0)
	for enemy in build.enemies_near(at, radius, 32):
		if not is_instance_valid(enemy):
			continue
		var away: Vector3 = enemy.global_position - at
		away.y = 0.0
		if enemy.has_method("knock"):
			enemy.knock(away.normalized() if away.length() > 0.1 else Vector3.FORWARD, TREMOR_KNOCK)
		build.item_hit(enemy, TREMOR_DAMAGE * scale * ctx.run.heft())
	note_fire("tremor", null, at)


# ---- Packed a Spare (Moss's Spares, 2 pieces) ----

# The piece that completes the set is not its own spare: the set must already have been live
# before this part's recount (a nested part_gained, an evolution grant, may have recounted first).
func _on_part_gained(part_id: String, source: String) -> void:
	var was_live := _live_without(part_id, MakerSets.MOSS)
	refresh()
	if not was_live or not _spare_armed or source in MOSS_SOURCES_SKIPPED or MakerSets.maker_of(part_id) == "":
		return
	_spare_armed = false
	ctx.run.add_part(part_id, "spare")
	note_fire("packed_a_spare", null, ctx.player.ball_position())


# True when maker's set is complete without one copy of part_id: the set held before it came.
func _live_without(part_id: String, maker: String) -> bool:
	var parts: Array = ctx.run.parts.duplicate()
	parts.erase(part_id)
	var active := _racked_maker()
	var counted_before := MakerSets.counts(parts, [active] if active != "" else [])
	return int(counted_before.get(maker, 0)) >= int(MakerSets.SETS[maker]["pieces"])


func _effects():
	return ctx.spawner.get("effects") if ctx.spawner != null else null
