extends SceneTree

# SG1 arc mark (comps/W13-INTEGRATION-3.md unit SG1; comps/gunfire/elements-and-fusion.md,
# shock +10% for 5 s, a start value). An arc strike marks its target for ARC_MARK_SECONDS; while
# the mark holds, every strike through the damage door deals 1 + ARC_MARK_FRACTION, applied once
# in the door's caps stage. Proves on the real strike() path, against frozen dummies:
# 1. the fraction and window are declared once on combat, and the arc row lives in the one
#    _exposed table (no second exposure table);
# 2. the marking arc hit deals base damage (its own mark never raises it), and a later arc hit
#    on the marked dummy rises;
# 3. contact, projectile, area and companion (primer coil consume) each rise by the same declared
#    fraction while marked and return to base on expiry;
# 4. the wear trail bypasses the door, so a marked dummy takes the trail's base damage;
# 5. every frame of the window, the drawn ArcMark ring is present exactly while the row is live,
#    its radius is the row's committed radius (the dummy's hull) and the strike multiplier reads
#    the same row; it is gone in the frame the row expires;
# 6. no extra hit: each strike call makes one door pass and one enemy_struck, and the window
#    frames make none;
# 7. the plate exposure keeps its numbers and reach: a plate-exposed dummy takes BRACE_MULT from
#    a contact and base damage from a projectile or an area.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const T := preload("res://tests/support/t.gd")

const BIG := 1.0e9
const TOL := 1.0e-4
const EXPECTED_CHECKS := 34
# [label, kind, force, source] as each source's real caller hands it to strike().
const PROBES := [
	["contact", "ram", 20.0, ""],
	["projectile", "runner", 10.0, "weapon"],
	["area", "sticky", 10.0, "weapon"],
]

var _t := T.new("arc_mark_test")
var _game
var _ticks := 0
var _spawned: Array = []
var _struck_seen := 0
var _combat
var _fraction := 0.0
var _seconds := 0.0
# The window walk: the dummy under watch and what each frame saw.
var _watched: Node3D = null
var _frames := 0
var _live_frames := 0
var _mismatch: Array = []
var _passes_at_watch := 0
var _struck_at_watch := 0
var _clock_at_watch := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_setup()
		return false
	if _ticks < 12:
		return false
	if _ticks == 12:
		_combat = _game.ctx.spawner
		var consts: Dictionary = _combat.get_script().get_script_constant_map()
		_fraction = float(consts.get("ARC_MARK_FRACTION", 0.0))
		_seconds = float(consts.get("ARC_MARK_SECONDS", 0.0))
		_t.check("the fraction is declared once on combat", _fraction > 0.0 and _fraction < 1.0,
			"ARC_MARK_FRACTION %s" % [consts.get("ARC_MARK_FRACTION")])
		_t.check("the window is declared once on combat", _seconds > 0.0, "ARC_MARK_SECONDS %s" % [consts.get("ARC_MARK_SECONDS")])
		if not _combat.has_method("_arc_key") or _fraction <= 0.0 or _seconds <= 0.0:
			_t.eq("every check ran", _t.checks + 1, EXPECTED_CHECKS)
			quit(_t.verdict())
			return true
		_run_instant_checks()
		_start_watch()
		return false
	return _watch_frame()


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var anchor := Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_game.player.reset_to(anchor)
	_game.player.body().global_position = anchor
	ctx.run.companion = {}
	ctx.events.enemy_struck.connect(func(_e, _k, _f): _struck_seen += 1)


func _row(enemy: Node3D) -> Dictionary:
	return _combat._exposed.get(_combat._arc_key(enemy.get_instance_id()), {})


func _mult() -> float:
	return 1.0 + _fraction


func _dealt(enemy: Node3D, kind: String, force: float, source: String) -> float:
	var hp: float = enemy.hp
	_combat.strike(enemy, kind, force, "", source)
	return hp - float(enemy.hp)


func _mark(enemy: Node3D) -> float:
	return _dealt(enemy, "arc", 5.0, "")


func _run_instant_checks() -> void:
	var door = _combat.door
	door.trace_on = true
	door.traces.clear()
	var struck_before := _struck_seen
	var calls := 0

	# 1 and 2: the marking hit, and the row it leaves in the one table.
	var plain := _dummy(Vector3(9.0, 0.0, 0.0))
	var marked := _dummy(Vector3(-9.0, 0.0, 0.0))
	# An arc hit marks what it strikes, so its base is read on a dummy of its own.
	var arc_base := _dealt(_dummy(Vector3(0.0, 0.0, -12.0)), "arc", 5.0, "")
	var arc_first := _mark(marked)
	calls += 2
	_t.near("the marking arc hit deals base damage", arc_first, arc_base)
	var row := _row(marked)
	_t.check("the arc mark is its own entry kind in the one _exposed table",
		not row.is_empty() and row.get("kind", "") == "arc" and int(row.get("id", 0)) == marked.get_instance_id()
			and not _combat._exposed.has(marked.get_instance_id()),
		"row %s" % [row])
	_t.near("the mark lasts the declared window", float(row.get("until", 0.0)) - _combat._clock, _seconds)
	var arc_again := _mark(marked)
	calls += 1
	_t.near("a later arc hit on the marked dummy rises by the fraction", arc_again, arc_base * _mult(), TOL * arc_base)
	_t.check("the plain dummy carries no mark", _row(plain).is_empty(), "%s" % [_row(plain)])

	# 3: every source rises by the same fraction while marked.
	for probe in PROBES:
		var base := _dealt(plain, probe[1], probe[2], probe[3])
		var up := _dealt(marked, probe[1], probe[2], probe[3])
		calls += 2
		_t.check("%s rises by the declared fraction while marked" % probe[0], base > 0.0 and absf(up - base * _mult()) <= TOL * base,
			"base %.4f marked %.4f ratio %.4f" % [base, up, up / base if base > 0.0 else 0.0])
	var c_base := _companion_hit(plain)
	var c_up := _companion_hit(marked)
	calls += 4
	_t.check("companion (primer coil consume) rises by the declared fraction while marked",
		c_base > 0.0 and absf(c_up - c_base * _mult()) <= TOL * c_base,
		"base %.4f marked %.4f ratio %.4f" % [c_base, c_up, c_up / c_base if c_base > 0.0 else 0.0])
	_t.check("the coil and the mark multiply once each (no double mark)",
		absf(c_up - _dealt_ram_plain() * Companion.PRIMER_COIL_MULT * _mult()) <= TOL * c_up, "marked consume %.4f" % c_up)
	calls += 1

	# 4: the wear trail bypasses the door, so the mark does not apply to it (by design).
	var deal: Callable = _combat.wear_trail.deal
	var hp_before: float = marked.hp
	var removed: float = deal.call(marked, _combat.wear_trail.DAMAGE) if deal.is_valid() else 0.0
	_t.near("the wear trail is not raised by the mark (it bypasses the door)", hp_before - float(marked.hp), _combat.wear_trail.DAMAGE)
	_t.near("the trail reports its base damage on a marked dummy", removed, _combat.wear_trail.DAMAGE)

	# 7: the plate exposure keeps its numbers and its reach.
	var plated := _dummy(Vector3(0.0, 0.0, 9.0))
	_combat.cannon_expose(plated, 99.0, "ram")
	var ram_base := _dealt(plain, "ram", 20.0, "")
	var ram_plate := _dealt(plated, "ram", 20.0, "")
	var shot_base := _dealt(plain, "runner", 10.0, "weapon")
	var shot_plate := _dealt(plated, "runner", 10.0, "weapon")
	var area_base := _dealt(plain, "sticky", 10.0, "weapon")
	var area_plate := _dealt(plated, "sticky", 10.0, "weapon")
	calls += 6
	_t.near("a plate-exposed dummy takes BRACE_MULT from a contact", ram_plate, ram_base * MindAttacks.BRACE_MULT, TOL * ram_base)
	_t.near("a plate-exposed dummy takes base damage from a projectile", shot_plate, shot_base, TOL * shot_base)
	_t.near("a plate-exposed dummy takes base damage from an area", area_plate, area_base, TOL * area_base)
	_t.check("the plate row keeps its key and carries no arc kind", _combat._exposed.has(plated.get_instance_id())
			and String(_combat._exposed[plated.get_instance_id()].get("kind", "plate")) != "arc", "%s" % [_combat._exposed.get(plated.get_instance_id())])
	_mark(plated)
	var both := _dealt(plated, "ram", 20.0, "")
	calls += 2
	_t.near("plate and arc on one dummy multiply as two rows", both, ram_base * MindAttacks.BRACE_MULT * _mult(), TOL * ram_base)
	_t.check("plate and arc rows coexist on one dummy", _combat._exposed.has(plated.get_instance_id()) and not _row(plated).is_empty(),
		"plate %s arc %s" % [_combat._exposed.has(plated.get_instance_id()), not _row(plated).is_empty()])

	# 6: one door pass and one enemy_struck per strike call.
	door.trace_on = false
	_t.eq("one door pass per strike call", door.traces.size(), calls)
	_t.eq("one enemy_struck per strike call", _struck_seen - struck_before, calls)
	_t.eq("declared door order unchanged", door.ORDER, ["armour", "caps", "crit", "announce", "plates", "health", "execute", "events"])


# Prime with a weapon hit, then consume with a contact; returns the consume hit's damage.
func _companion_hit(enemy: Node3D) -> float:
	var c := Companion.new()
	for id in ["primer_coil", "escape_vent"]:
		c.acquire(id)
	c.assemble(["primer_coil", "escape_vent"])
	_game.ctx.run.companion = c.to_dict()
	_combat.strike(enemy, "runner", 1.0, "", "weapon")
	var dealt := _dealt(enemy, "ram", 20.0, "")
	_game.ctx.run.companion = {}
	return dealt


func _dealt_ram_plain() -> float:
	return _dealt(_dummy(Vector3(0.0, 0.0, -9.0)), "ram", 20.0, "")


func _start_watch() -> void:
	_watched = _dummy(Vector3(6.0, 0.0, 6.0))
	_mark(_watched)
	_clock_at_watch = _combat._clock
	_combat.door.trace_on = true
	_combat.door.traces.clear()
	_passes_at_watch = 0
	_struck_at_watch = _struck_seen


# 5: called once per physics frame until the row has expired, then the closing checks.
func _watch_frame() -> bool:
	var row := _row(_watched)
	var live: bool = not row.is_empty() and float(row["until"]) > _combat._clock
	var mark: Node3D = _watched.get_node_or_null("ArcMark")
	var drawn: bool = mark != null and mark.is_visible_in_tree() and not mark.is_queued_for_deletion()
	var mult: float = _combat._strike_mult(_watched, "runner", "weapon")
	var radius_ok := true
	if drawn and live:
		var r: float = float(row.get("radius", -1.0))
		var gs: Vector3 = mark.global_basis.get_scale()
		var flat := Vector2(mark.global_position.x - _watched.global_position.x, mark.global_position.z - _watched.global_position.z)
		radius_ok = is_equal_approx(r, _combat.hull_radius(_watched)) and absf(gs.x - r) < TOL and absf(gs.z - r) < TOL and flat.length() < TOL
	if drawn != live or not radius_ok or absf(mult - (_mult() if live else 1.0)) > TOL:
		if _mismatch.size() < 5:
			_mismatch.append("frame %d live %s drawn %s radius_ok %s mult %.4f" % [_frames, live, drawn, radius_ok, mult])
	_frames += 1
	_live_frames += 1 if live else 0
	if live and _frames < 2000:
		return false
	# One more frame after expiry so a late free would show.
	if _frames < _live_frames + 2:
		return false
	_finish()
	return true


func _finish() -> void:
	var door = _combat.door
	door.trace_on = false
	_t.check("the clock ran through the window", _combat._clock - _clock_at_watch >= _seconds,
		"%.3f s of %.3f" % [_combat._clock - _clock_at_watch, _seconds])
	_t.check("the drawn ring equals the committed row in every frame", _mismatch.is_empty() and _live_frames > 0,
		"%d live frames of %d; %s" % [_live_frames, _frames, _mismatch])
	_t.check("the ring is gone after the window", _watched.get_node_or_null("ArcMark") == null
			or _watched.get_node("ArcMark").is_queued_for_deletion(), "")
	_t.check("the row is gone after the window", _row(_watched).is_empty(), "%s" % [_row(_watched)])
	_t.eq("the window frames make no door pass", door.traces.size(), 0)
	_t.eq("the window frames publish no enemy_struck", _struck_seen - _struck_at_watch, 0)
	var plain := _dummy(Vector3(-6.0, 0.0, -6.0))
	for probe in PROBES:
		var base := _dealt(plain, probe[1], probe[2], probe[3])
		var after := _dealt(_watched, probe[1], probe[2], probe[3])
		_t.near("%s returns to base on expiry" % probe[0], after, base, TOL * base)
	var c_base := _companion_hit(plain)
	var c_after := _companion_hit(_watched)
	_t.near("companion returns to base on expiry", c_after, c_base, TOL * c_base)
	_clear()
	_t.eq("every check ran", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


# A frozen, unplated chaser with a bottomless pool, away from the ball so nothing touches it.
func _dummy(offset: Vector3) -> Node3D:
	var spot: Vector3 = _game.player.ball_position() + offset
	var e: Node3D = _combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(e)
	e.hp = BIG
	e.max_hp = BIG
	e.plating = 0.0
	e.set_physics_process(false)
	e.set_process(false)
	return e


func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.queue_free()
	_spawned.clear()
