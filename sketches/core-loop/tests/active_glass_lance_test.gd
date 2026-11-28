extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Lance := preload("res://src/combat/actives/glass_lance.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# The Glass Lance active (Mind-glass, relic; design page "Makers and Actives", 17 Oct 2026). A
# real Game with the first pilot. Covers: its row is a relic that fires on the press; racked, a
# press fires one lance along the aim that pierces every machine in its band once each, the far
# ones included, and none outside the band; its tell is the band drawn on the press; a machine
# that steps into the band behind the shard is not struck; weapon damage mods, punch, Cross
# Split and overflow scale it; Chain Arc jumps from each pierced machine; Jam refuses it; its
# sound has a recipe and a trim row. Evidence limit: rules in a headless run, not the feel.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const ID := "glass_lance"


var _t := T.new("active_glass_lance_test")
var _game
var _player
var _combat
var _rack
var _source := Intent.Scripted.new()
var _fired: Array = []
var _fails: Array = []
var _struck: Array = []


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
	var enemy: Node3D = _combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(at.x, at.z, 1.0))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	enemy.max_hp = 9999.0
	enemy.hp = 9999.0
	return enemy


func _press() -> void:
	_source.press = {"active_pressed": true}
	await physics_frame
	await physics_frame


func _clear_enemies() -> void:
	for enemy in _combat.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	await _sim(0.4)
	_rack = _combat.get("actives")
	_t.check("00 combat carries the active rack", _rack != null)
	if _rack == null:
		quit(_t.verdict())
		return
	var ev = _game.events
	ev.active_fired.connect(func(id: String, _at: Vector3, count: int): _fired.append([id, count]))
	ev.verb_failed.connect(func(verb: String, reason: String, _at: Vector3):
		if verb == "active":
			_fails.append(reason))
	ev.enemy_struck.connect(func(enemy_node: Node3D, kind: String, _force: float):
		if kind == Lance.KIND:
			_struck.append(enemy_node))

	# --- The row ---------------------------------------------------------------------------
	var row := ActiveDefs.row(ID)
	_t.check("01 the Glass Lance is a Mind-glass relic that fires on the press",
		row.get("maker") == "mind_glass" and row.get("rarity") == "relic" and float(row.get("windup", -1.0)) == 0.0, str(row))

	# --- Racked, a press pierces the line ----------------------------------------------------
	_game.tuning.set_option("actives", "on")
	await _sim(0.1)
	_t.check("02 the rack takes the lance", _rack.rack(ID) and _rack.active_id == ID and _rack.charges == int(row["max_charges"]))
	var record: Dictionary = _rack.slot_record()
	_t.check("03 its bar chip is a valid slot on F", AbilitySlots.valid_slot(record) and record["id"] == "active_" + ID, str(record))

	_player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.2)
	var ball: Vector3 = _player.ball_position()
	var aim: Vector3 = _game.ctx.aim_forward()
	aim.y = 0.0
	aim = aim.normalized()
	var side := aim.cross(Vector3.UP).normalized()
	var in_line := [_enemy(ball + aim * 6.0), _enemy(ball + aim * 14.0 + side * 0.5), _enemy(ball + aim * 30.0)]
	var off_line := [_enemy(ball + aim * 10.0 + side * 5.0), _enemy(ball - aim * 6.0)]
	await physics_frame
	var lance = _rack._kinds[ID]
	var beams_before: int = _combat.effects._beams.size()
	await _press()
	_t.eq("04 the press fires one lance", _fired, [[ID, 1]])
	_t.check("05 the tell is the band, drawn on the press", _combat.effects._beams.size() >= beams_before + 3 * int(ceil(Lance.REACH / Lance.SAMPLE)),
		"beams %d -> %d" % [beams_before, _combat.effects._beams.size()])
	# A machine that steps into the band behind the shard after it has passed.
	await _sim(0.15)
	var late := _enemy(ball + aim * 3.0)
	await _sim(0.5)
	var hit_in := in_line.filter(func(e): return e.hp < 9999.0)
	_t.eq("06 every machine in the band is pierced, the far one too", hit_in.size(), in_line.size())
	_t.check("07 each pierced machine is struck once", in_line.all(func(e): return _struck.count(e) == 1), str(in_line.map(func(e): return _struck.count(e))))
	_t.check("08 no machine outside the band is struck", off_line.all(func(e): return e.hp == 9999.0 and not e in _struck))
	_t.check("09 a machine stepping into the band behind the shard is not struck", late.hp == 9999.0)
	_t.check("10 the lance has run its band and left", lance.lances.is_empty())
	_t.near("11 each pierce deals the lance's damage", 9999.0 - in_line[0].hp, lance.damage(), 0.5)

	# --- A strong build makes a stronger lance ---------------------------------------------
	var base: float = lance.damage()
	_game.tuning.set_mod("weapon_damage", 2.0)
	_t.near("12 weapon damage mods scale the lance", lance.damage(), base * 2.0, 0.01)
	_game.tuning.clear_mods()
	_t.eq("13 overflow pieces arrive as extra lances", lance.count_for(2), 3)

	# --- Chain Arc jumps from each pierced machine -----------------------------------------
	await _clear_enemies()
	_game.ctx.run.add_part("chain_arc", "test")
	await physics_frame
	var front := _enemy(ball + aim * 8.0)
	var beside := _enemy(ball + aim * 8.0 + side * 4.0)
	await physics_frame
	_rack.charges = 1
	await _press()
	await _sim(0.5)
	_t.check("14 Chain Arc jumps from a pierced machine to its neighbour", front.hp < 9999.0 and beside.hp < 9999.0,
		"front %.1f beside %.1f" % [9999.0 - front.hp, 9999.0 - beside.hp])

	# --- Cross Split fans more lances --------------------------------------------------------
	var plain: int = lance.count_for(0)
	_game.ctx.run.add_part("cross_split", "test")
	await physics_frame
	_t.eq("15 Cross Split fans one more lance per level", lance.count_for(0), plain + 1)
	_fired.clear()
	_rack.charges = 1
	await _press()
	_t.check("15b the press fires every fanned lance", _fired == [[ID, plain + 1]] and lance.lances.size() == plain + 1, "fired %s" % [_fired])
	await _sim(0.5)

	# --- A pierce that clears the stage drops the rest of the volley -----------------------
	await _clear_enemies()
	var first := _enemy(ball + aim * 6.0)
	var second := _enemy(ball + aim * 20.0)
	await physics_frame
	var clear_once := func(enemy_node: Node3D, kind: String, _force: float):
		if kind == Lance.KIND and enemy_node == first:
			lance.clear()
	ev.enemy_struck.connect(clear_once)
	_rack.charges = 1
	await _press()
	await _sim(0.5)
	ev.enemy_struck.disconnect(clear_once)
	_t.check("15c a clear mid-flight drops every lance and pierces nothing more", lance.lances.is_empty() and second.hp == 9999.0,
		"flying %d second hurt %.1f" % [lance.lances.size(), 9999.0 - second.hp])

	# --- Jam ------------------------------------------------------------------------------
	_rack.charges = 1
	_rack.lock(0.5)
	_fails.clear()
	await _press()
	_t.check("16 a Jam lock refuses the lance and keeps the charge", _fails == ["jammed"] and _rack.charges == 1, "fails %s" % [_fails])

	# --- Its sound -------------------------------------------------------------------------
	_t.check("17 the lance has its own sound with a trim row", SfxBank.has_recipe("active_" + ID) and SfxBank.TRIM_DB.has("active_" + ID))
	var buf: PackedFloat32Array = SfxBank.new()._bake("active_" + ID)
	_t.check("18 the recipe bakes a short, non-silent tone", buf.size() > 0 and buf.size() < 48000 * 2 and _peak(buf) > 0.1, "samples %d peak %.2f" % [buf.size(), _peak(buf)])
	quit(_t.verdict())


func _peak(buf: PackedFloat32Array) -> float:
	var top := 0.0
	for x in buf:
		top = maxf(top, absf(x))
	return top
