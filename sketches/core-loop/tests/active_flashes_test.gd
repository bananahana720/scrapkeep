extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const T := preload("res://tests/support/t.gd")

# Every active obeys Reduce flashes (#94; the sitting watch list's line on actives). A source
# scan fails on any combat.effects ring, spark or beam call under src/combat/actives that skips
# ActiveFx.peak, so a new active that ignores the setting fails here. Then a real Game fires all
# six actives with the setting off and on: on, no peak any active draws is brighter than
# FlashGuard.INFO_SHARE of full; off, peaks draw at full strength. Evidence limit: drawn alpha in a
# headless run, not a rendered capture or the feel at Andrew's screen.

const DIR := "res://src/combat/actives/"
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const EPS := 0.001

var _t := T.new("active_flashes_test")
var _game
var _combat
var _rack


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


# Calls in one script that draw a peak without ActiveFx.peak: "file:line".
static func _unguarded(path: String) -> Array:
	var out := []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var call := RegEx.create_from_string("effects\\.(ring|spark|beam)\\(")
	for i in lines.size():
		if call.search(lines[i]) != null and not "ActiveFx.peak(" in lines[i]:
			out.append("%s:%d" % [path.get_file(), i + 1])
	return out


# The brightest peak alpha combat.effects holds now.
func _peak_alpha() -> float:
	var best := 0.0
	var fx = _combat.effects
	for list in [fx._rings, fx._sparks, fx._beams]:
		for entry in list:
			best = maxf(best, float((entry["color"] as Color).a))
	return best


# Fires one active at three machines and returns the brightest peak drawn over 2 s.
func _fire(id: String) -> float:
	_combat.effects.clear()
	_game.player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.1)
	var spawned := []
	var forward: Vector3 = _game.ctx.aim_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var side := forward.cross(Vector3.UP).normalized()
	# Along the aim, so the aimed actives (the torch, the lance, the pulse) cross them too.
	for spot in [Vector2(9.0, 0.0), Vector2(12.0, 1.0), Vector2(7.0, -1.0)]:
		var at: Vector3 = forward * spot.x + side * spot.y
		var enemy: Node3D = _combat.spawn_enemy("chaser", _ground(at.x, at.z))
		if "live" in enemy:
			enemy.live = Callable(self, "_never")
		enemy.max_hp = 9999.0
		enemy.hp = 9999.0
		spawned.append(enemy)
	await _sim(0.05)
	_rack.rack(id)
	_rack.press()
	var best := 0.0
	for i in roundi(2.0 * Engine.physics_ticks_per_second):
		await physics_frame
		best = maxf(best, _peak_alpha())
	for enemy in spawned:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await _sim(0.1)
	return best


func _run() -> void:
	# --- The source scan ---------------------------------------------------------------
	var unguarded := []
	var scripts := 0
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".gd") and file != "active_fx.gd":
			scripts += 1
			unguarded.append_array(_unguarded(DIR + file))
	_t.eq("01 every active peak goes through ActiveFx.peak", unguarded, [])
	var outside := []
	for id in ActiveDefs.ROWS:
		var path: String = (ActiveDefs.ROWS[id]["kind"] as GDScript).resource_path
		if not path.begins_with(DIR):
			outside.append(path)
	_t.check("02 every active's script lives where the scan reads", outside.is_empty() and scripts >= ActiveDefs.ROWS.size(), str(outside))

	# --- The helper ----------------------------------------------------------------------
	var amber := Color(0.9, 0.6, 0.2, 1.0)
	FlashGuard.on = false
	_t.eq("03 off: a peak is drawn as given", ActiveFx.peak(amber), amber)
	FlashGuard.on = true
	var dim := ActiveFx.peak(amber)
	_t.check("04 on: a peak keeps its colour and keeps INFO_SHARE of its alpha",
		is_equal_approx(dim.r, amber.r) and is_equal_approx(dim.g, amber.g) and is_equal_approx(dim.a, FlashGuard.INFO_SHARE), str(dim))
	FlashGuard.on = false

	# --- All six actives, off then on ---------------------------------------------------
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_game.tuning.set_option("actives", "on")
	await _sim(0.4)
	_rack = _combat.get("actives")
	var full := {}
	var dimmed := {}
	for id in ActiveDefs.ROWS:
		FlashGuard.on = false
		full[id] = await _fire(id)
		FlashGuard.on = true
		dimmed[id] = await _fire(id)
	FlashGuard.on = false
	var drew := []
	var bright := []
	for id in ActiveDefs.ROWS:
		if float(full[id]) > FlashGuard.INFO_SHARE + EPS:
			drew.append(id)
		if float(dimmed[id]) > FlashGuard.INFO_SHARE + EPS:
			bright.append("%s %.2f" % [id, dimmed[id]])
	_t.check("05 off: the actives draw full-strength peaks (%d of %d)" % [drew.size(), ActiveDefs.ROWS.size()],
		drew.size() == ActiveDefs.ROWS.size(), "full %s" % [full])
	_t.eq("06 on: no active draws a peak above the information share", bright, [])
	quit(_t.verdict())
