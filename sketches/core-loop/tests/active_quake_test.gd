extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Quake := preload("res://src/combat/actives/quake_knock.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# Quake Knock (Waking-made, relic; design page "Makers and Actives", 17 Oct 2026). A real Game
# with the first pilot and --actives on. Covers: the row is a relic with a 0.5 s wind-up and its
# own launch sound; a press spends the charge and commits one amber ring at the ball that fills
# over the wind-up while nothing is hurt; the ring hits when the wind-up ends, striking only the
# machines its committed geometry contains (a machine just outside it is untouched: damage lands
# only inside the warning shown); the kinetic blow shatters an ice slab inside the ring and leaves
# one well outside it; weapon damage mods, punch and banked overflow scale it, including overflow
# banked during the wind-up; Chain Arc jumps only between machines inside the ring; Cross Split adds an aftershock ring that is
# shown before it lands and reaches a machine the first ring missed; a Jam mid wind-up drops the
# ring and refunds the charge. Evidence limit: rules in a headless run, not the feel.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const ID := "quake_knock"

var _t := T.new("active_quake_test")
var _game
var _player
var _combat
var _rack
var _kind
var _source := Intent.Scripted.new()
var _fired: Array = []
var _struck: Array = []
var _water_at := Vector3.INF
var _water_y := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _ground(dx: float, dz := 0.0) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, 1.0)


func _enemy(at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", at)
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	enemy.max_hp = 9999.0
	enemy.hp = 9999.0
	return enemy


func _water(point: Vector3) -> Dictionary:
	if Vector2(point.x - _water_at.x, point.z - _water_at.z).length() <= 2.5:
		return {"surface_y": _water_y}
	return {}


func _press() -> void:
	_source.press = {"active_pressed": true}
	await physics_frame
	await physics_frame


# The knock throws machines out of the ring: put the ball and the two inside machines back.
func _regroup(inner: Node3D, edge: Node3D) -> void:
	_player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.2)
	var ball: Vector3 = _player.ball_position()
	inner.global_position = Vector3(ball.x + 3.0, _ground(3.0, 2.0).y, ball.z + 2.0)
	edge.global_position = Vector3(ball.x - 5.5, _ground(-5.5, 0.0).y, ball.z)
	for e in [inner, edge]:
		if "velocity" in e:
			e.velocity = Vector3.ZERO
	await _sim(0.05)


func _rings() -> Array:
	return root.get_tree().get_nodes_in_group("telegraph").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_game.tuning.set_option("actives", "on")
	await _sim(0.4)
	_rack = _combat.get("actives")
	var row: Dictionary = ActiveDefs.row(ID)
	_t.check("01 the row is a Waking-made relic with a 0.5 s wind-up",
		row.get("rarity") == "relic" and row.get("maker") == "waking" and is_equal_approx(float(row.get("windup", 0.0)), 0.5), str(row))
	_t.check("02 its launch has a bank sound with a trim row", SfxBank.has_recipe("active_" + ID) and SfxBank.TRIM_DB.has("active_" + ID))
	if _rack == null or row.is_empty():
		quit(_t.verdict())
		return
	_t.check("03 the rack racks it", _rack.rack(ID) and _rack.active_id == ID)
	_kind = _rack._kinds[ID]
	var ev = _game.events
	ev.active_fired.connect(func(id: String, _at: Vector3, count: int): _fired.append([id, count]))
	ev.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
		if kind == Quake.KIND:
			_struck.append(enemy))

	# --- The press: a committed ring fills over the wind-up -----------------------------
	_player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.2)
	var ball: Vector3 = _player.ball_position()
	var inner := _enemy(_ground(3.0, 2.0))
	var edge := _enemy(_ground(-5.5, 0.0))
	var outside := _enemy(_ground(0.0, 9.0))
	var shock := _enemy(_ground(8.5, 0.0))
	await _sim(0.05)
	var cap := int(row["max_charges"])
	var before := _rings().size()
	await _press()
	_t.check("04 the press spends the charge and fires nothing yet", _rack.charges == cap - 1 and _fired.is_empty() and _rack.winding > 0.0,
		"charges %d fired %s winding %.2f" % [_rack.charges, _fired, _rack.winding])
	_t.eq("05 one ring is committed", _rings().size(), before + 1)
	var ring: Node3D = _kind.pending[0]["ring"] if not _kind.pending.is_empty() else null
	_t.check("06 the ring is the player's own (amber, not a threat), at the ball, sized to the row",
		ring != null and not ring.is_hostile() and Vector2(ring.center.x - ball.x, ring.center.z - ball.z).length() < 1.0
			and is_equal_approx(ring.radius, Quake.RADIUS), "ring %s" % [ring])
	await _sim(0.25)
	_t.check("07 halfway through the wind-up the ring is filling and nothing is hurt",
		ring.progress > 0.2 and ring.progress < 0.9 and _struck.is_empty(), "progress %.2f struck %d" % [ring.progress, _struck.size()])
	var ring_at: Vector3 = ring.center
	var contained := [inner, edge, outside].map(func(e): return ring.contains(e.global_position))
	await _sim(0.35)
	_t.eq("08 it fires once when the wind-up ends, one ring", _fired, [[ID, 1]])
	_t.check("09 the machines inside the ring are struck", inner in _struck and edge in _struck and inner.hp < 9999.0,
		"struck %d inner hp %.1f" % [_struck.size(), inner.hp])
	_t.check("10 a machine outside the ring is untouched", not outside in _struck and outside.hp >= 9999.0 and not shock in _struck,
		"outside hp %.1f, contained %s" % [outside.hp, contained])
	_t.check("11 every struck machine sat inside the warning shown", contained[0] and contained[1] and not contained[2], str(contained))
	await _sim(0.4)
	_t.check("12 the ring clears after it hits", _kind.pending.is_empty() and _kind.spent.is_empty() and _rings().size() == before,
		"pending %d spent %d rings %d" % [_kind.pending.size(), _kind.spent.size(), _rings().size()])

	# --- The kinetic blow shatters ice inside the ring ----------------------------------
	var build = _game.ctx.build
	var slab_spot := _ground(-3.0, -3.0)
	_water_at = slab_spot
	_water_y = slab_spot.y + 0.2
	build.register_material("water", _water)
	var made: Dictionary = build.apply_element("frost", Vector3(slab_spot.x, _water_y + 0.5, slab_spot.z), "test")
	_water_at = Vector3.INF
	var slabs_before: int = build.field.slab_count()
	_t.check("13 a frost slab stands inside the ring", made.get("behaviour", "") == "create_surface" and slabs_before >= 1, str(made))
	var far_spot := _ground(10.0, 10.0)
	_water_at = far_spot
	_water_y = far_spot.y + 0.2
	var far: Dictionary = build.apply_element("frost", Vector3(far_spot.x, _water_y + 0.5, far_spot.z), "test")
	_water_at = Vector3.INF
	await _regroup(inner, edge)
	_rack.charges = 1
	var inner_hp: float = inner.hp
	await _press()
	_rack.bonus = 3
	await _sim(0.6)
	_t.check("14 the knock shatters the slab inside the ring", not build.field.slabs().any(func(sl): return Vector2(sl["at"].x - slab_spot.x, sl["at"].z - slab_spot.z).length() < 1.0),
		"slabs %d -> %d" % [slabs_before, build.field.slab_count()])
	_t.check("14b a slab well outside the ring survives", far.get("behaviour", "") == "create_surface"
		and build.field.slabs().any(func(sl): return Vector2(sl["at"].x - far_spot.x, sl["at"].z - far_spot.z).length() < 1.0), str(far))
	_t.near("14c overflow banked during the wind-up still hits harder", inner_hp - inner.hp, _kind.damage(3), 0.5)

	# --- A strong build hits harder -----------------------------------------------------
	var base: float = _kind.damage()
	_game.tuning.set_mod("weapon_damage", 2.0)
	_t.near("15 weapon damage mods scale the knock", _kind.damage(), base * 2.0, 0.01)
	_game.tuning.clear_mods()
	_t.check("16 banked overflow widens the ring and hits harder",
		_kind.radius_for(2) > Quake.RADIUS and _kind.damage(2) > base, "radius %.2f damage %.1f" % [_kind.radius_for(2), _kind.damage(2)])
	var punched := false
	if build.has_method("punch_bonus"):
		_game.run.add_part("focus_lens", "test")
		await _sim(0.05)
		punched = build.punch_bonus() > 0.0 and _kind.damage() > base
	_t.check("17 punch adds to the knock", punched, "punch %.1f damage %.1f base %.1f" % [build.punch_bonus(), _kind.damage(), base])

	# --- Chain Arc: hits jump between machines inside the same ring -------------------
	_game.run.add_part("chain_arc", "test")
	await _sim(0.05)
	await _regroup(inner, edge)
	_struck.clear()
	_rack.charges = 1
	await _press()
	await _sim(0.6)
	_t.check("17b Chain Arc adds jumps, all onto machines inside the ring",
		_struck.size() > 2 and _struck.all(func(e): return e == inner or e == edge), "struck %d" % _struck.size())
	await _sim(0.3)

	# --- Cross Split: an aftershock ring, shown before it lands -------------------------
	_game.run.add_part("cross_split", "test")
	await _sim(0.05)
	_t.check("18 the build carries Cross Split", build.pattern_level("cross_split") >= 1)
	_fired.clear()
	_struck.clear()
	_player.reset_to(ring_at + Vector3.UP)
	await _sim(0.2)
	_rack.charges = 1
	await _press()
	await _sim(0.55)
	_t.check("19 the fire reports the extra ring", not _fired.is_empty() and _fired[0][1] == 1 + build.pattern_level("cross_split"), str(_fired))
	var after: Array = _kind.pending.filter(func(e): return not e["rack"])
	_t.check("20 the aftershock is shown, wider, and has not landed yet",
		not after.is_empty() and after[0]["ring"].radius > Quake.RADIUS and not shock in _struck,
		"aftershocks %d struck shock %s" % [after.size(), shock in _struck])
	await _sim(0.5)
	_t.check("21 the aftershock reaches the machine the first ring missed", shock in _struck, "struck %d" % _struck.size())

	# --- Jam mid wind-up -----------------------------------------------------------------
	await _sim(0.4)
	_fired.clear()
	_rack.charges = 1
	await _press()
	_rack.lock(0.5)
	await _sim(0.7)
	_t.check("22 a Jam mid wind-up drops the ring and refunds the charge",
		_fired.is_empty() and _rack.charges == 1 and _kind.pending.is_empty() and _rings().size() == before,
		"fired %s charges %d pending %d" % [_fired, _rack.charges, _kind.pending.size()])
	quit(_t.verdict())
