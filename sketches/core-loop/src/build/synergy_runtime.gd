extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Synergies := preload("res://src/build/synergies.gd")

const ROD_REACH := 12.0
const ROD_DAMAGE := 10.0
const ROD_PER_SECOND := 6.0
const TESLA_REACH := 12.0
const TESLA_DAMAGE := 12.0
const TESLA_EVERY := 0.5
const TESLA_TARGETS := 2
const WRECK_RADIUS := 6.0
const SYNERGY_KIND := "synergy"
const SYNERGY_PUNCH := 1.2
const WRECK_FORCE := 18.0
const SHRAPNEL_RADIUS := 6.0
const SHRAPNEL_FORCE := 14.0
const SHRAPNEL_TARGETS := 3
const SHRAPNEL_PER_SECOND := 6.0
const GLACIER_IMPACT := 9.0
const GLACIER_RADIUS := 5.0
const PINWHEEL_RADIUS := 4.5
const PINWHEEL_FORCE := 10.0
const PINWHEEL_EVERY := 0.3
const PINWHEEL_TIER := 2
const PINWHEEL_TARGETS := 4

var rams: Array[Vector3] = []
var kills: Array[Vector3] = []
var _landings: Array[float] = []
var _rod_budget := ROD_PER_SECOND
var _shrapnel_budget := SHRAPNEL_PER_SECOND
var _tesla_clock := 0.0
var _pinwheel_clock := 0.0
var _pinwheel_cut := {}
var _live: Array = []
var _discovered := {}
var _armed := {}
var _fired := {}
var found_map := {}
var woken := {}
var sets_fresh: Array = []


func reset_run() -> void:
	_live = []
	_armed.clear()
	_fired.clear()
	_discovered.clear()
	found_map.clear()
	woken.clear()


func reset_stage() -> void:
	rams.clear()
	kills.clear()
	_landings.clear()
	_pinwheel_cut.clear()
	_rod_budget = ROD_PER_SECOND
	_shrapnel_budget = SHRAPNEL_PER_SECOND


func clear_fired() -> void:
	_fired.clear()


func discovered() -> Array:
	return _discovered.keys()


func found() -> Array:
	return found_map.values()


func is_known(build, synergy_id: String) -> bool:
	var codex = build.codex_ref()
	if codex != null and codex.known(synergy_id):
		return true
	return _discovered.has(synergy_id)


func sync_live(build) -> void:
	for synergy_id in _live:
		if not synergy_id in build.sheet.synergies:
			_fired.erase(synergy_id)
	for synergy_id in build.sheet.synergies:
		if not synergy_id in _live:
			_on_synergy_live(build, synergy_id)
	_live = build.sheet.synergies.duplicate()
	sets_fresh = []
	for trick_id in build.sheet.synergies:
		if Synergies.told_on_wake(trick_id) and not woken.has(trick_id):
			woken[trick_id] = true
			sets_fresh.append(trick_id)
			_discovered[trick_id] = true
			var codex = build.codex_ref()
			if codex != null:
				build.ensure_declared()
				codex.mark_known(trick_id, build.PARTICIPANTS)


func _on_synergy_live(build, synergy_id: String) -> void:
	if _armed.has(synergy_id):
		return
	_armed[synergy_id] = true
	build.ctx.events.cause_armed.emit(synergy_id)


func fire(build, synergy_id: String, body: Node3D, at: Vector3) -> void:
	build.ctx.events.cause_fired.emit(synergy_id, body, at)
	if _fired.has(synergy_id):
		return
	_fired[synergy_id] = true
	_discovered[synergy_id] = true
	var codex = build.codex_ref()
	if codex != null:
		build.ensure_declared()
		codex.mark_discovered(synergy_id, build.ctx.player.ball_position(), build.PARTICIPANTS)


func note_found(build, key: String, text: String) -> void:
	found_map[key] = text
	var codex = build.codex_ref()
	if codex != null:
		codex.mark_found(text, Synergies.CATEGORY, build.PARTICIPANTS)


func refill_budgets(delta: float) -> void:
	_rod_budget = minf(ROD_PER_SECOND, _rod_budget + ROD_PER_SECOND * delta)
	_shrapnel_budget = minf(SHRAPNEL_PER_SECOND, _shrapnel_budget + SHRAPNEL_PER_SECOND * delta)


func on_enemy_killed(build, at: Vector3) -> void:
	if build.has_transformer("shrapnel_bloom") and not build.ctx.run.last_kill_triggerless:
		kills.append(at)


func on_landed(build, impact: float) -> void:
	if build.has_transformer("glacier_hull") and impact >= GLACIER_IMPACT:
		_landings.append(impact)


func on_enemy_struck(build, enemy: Node3D, kind: String) -> void:
	if kind == "ram" and build.has_transformer("wrecking_ball") and is_instance_valid(enemy):
		rams.append(enemy.global_position)


func on_shot_fired(build) -> void:
	if build.has_transformer("storm_lattice"):
		fire(build, "storm_lattice", null, build.ctx.player.ball_position())
	if build.has_transformer("linked_spiral"):
		note_found(build, "trick:linked_spiral", Synergies.ROWS["linked_spiral"]["found"])


func step(build, ball: Vector3, delta: float) -> void:
	for at in rams:
		build.field.flash_ring(at, WRECK_RADIUS, Palette.AMBER)
		var wrecked := false
		for enemy in build.enemies_near(at, WRECK_RADIUS, 99):
			if enemy.global_position.distance_to(at) > 0.5:
				wrecked = true
				_synergy_hit(build, enemy, WRECK_FORCE, "wrecking_ball")
		if not wrecked:
			fire(build, "wrecking_ball", null, at)
	rams.clear()
	for at in kills:
		if _shrapnel_budget < 1.0:
			break
		_shrapnel_budget -= 1.0
		build.field.shard_burst(at)
		var burst_targets: Array = build.enemies_near(at, SHRAPNEL_RADIUS, SHRAPNEL_TARGETS)
		for enemy in burst_targets:
			_synergy_hit(build, enemy, SHRAPNEL_FORCE, "shrapnel_bloom")
		if burst_targets.is_empty():
			fire(build, "shrapnel_bloom", null, at)
	kills.clear()
	for impact in _landings:
		build.field.flash_ring(ball + Vector3.DOWN * 0.8, GLACIER_RADIUS, Palette.ICE)
		var ring_targets: Array = build.enemies_near(ball, GLACIER_RADIUS, 99)
		for enemy in ring_targets:
			_synergy_hit(build, enemy, impact * 1.5, "glacier_hull")
		if ring_targets.is_empty():
			fire(build, "glacier_hull", null, ball)
		build.frost_ring(ball)
	_landings.clear()
	if build.has_transformer("tesla_pylon") and (build.ctx.player.kit.mounted or build.ctx.player.kit.hooked):
		_tesla_clock -= delta
		if _tesla_clock <= 0.0:
			_tesla_clock = TESLA_EVERY
			for enemy in build.enemies_near(ball, TESLA_REACH, TESLA_TARGETS):
				build.field.zap_line(ball, enemy.global_position)
				build.strike_enemy(enemy, "arc", TESLA_DAMAGE * build.sheet.mod("weapon_damage"))
				fire(build, "tesla_pylon", enemy, enemy.global_position)
	else:
		_tesla_clock = 0.0
	for id in _pinwheel_cut.keys():
		_pinwheel_cut[id] -= delta
		if _pinwheel_cut[id] <= 0.0:
			_pinwheel_cut.erase(id)
	if build.has_transformer("pinwheel") and build.ctx.player.speed_tier() >= PINWHEEL_TIER:
		_pinwheel_clock -= delta
		if _pinwheel_clock <= 0.0:
			_pinwheel_clock = PINWHEEL_EVERY
			build.field.flash_ring(ball, PINWHEEL_RADIUS, Palette.AMBER)
		for enemy in build.enemies_near(ball, PINWHEEL_RADIUS, PINWHEEL_TARGETS):
			if not _pinwheel_cut.has(enemy.get_instance_id()):
				_pinwheel_cut[enemy.get_instance_id()] = PINWHEEL_EVERY
				_synergy_hit(build, enemy, PINWHEEL_FORCE, "pinwheel")
	else:
		_pinwheel_clock = 0.0


func lightning_rod(build, ball: Vector3) -> void:
	if _rod_budget < 1.0:
		return
	var targets: Array = build.enemies_near(ball, ROD_REACH, 1)
	if targets.is_empty():
		return
	_rod_budget -= 1.0
	build.field.zap_line(ball, targets[0].global_position)
	build.strike_enemy(targets[0], "arc", ROD_DAMAGE * build.sheet.mod("weapon_damage"))
	fire(build, "lightning_rod", targets[0], targets[0].global_position)


func _synergy_hit(build, enemy: Node3D, force: float, synergy_id: String) -> void:
	build.strike_enemy(enemy, SYNERGY_KIND, force * SYNERGY_PUNCH * build.ctx.run.heft())
	fire(build, synergy_id, enemy, enemy.global_position)
