extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const T := preload("res://tests/support/t.gd")

# Every active obeys Reduce flashes (#94; the sitting watch list's line on actives). A source
# scan of src/combat/actives (subfolders too) fails on any combat.effects arc, ring, spark or beam
# call, or chain colour handed to combat.chain_hit, whose colour skips ActiveFx.peak, and on any other
# use of effects (an alias, a call by name), so a new active that ignores the setting fails here.
# combat.effects draws every mark at its colour's alpha. Then a real Game fires all six actives
# with the setting off and on and reads the alpha effects draws each mark at (effects.brightest,
# the same functions _process draws with): off, every active draws above INFO_SHARE; on,
# nothing any active draws is brighter than INFO_SHARE of full. Evidence limit: drawn vertex alpha in a headless run, not a rendered
# capture or the feel at Andrew's screen.

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


# Draws in one script whose colour skips ActiveFx.peak: "file:line". A draw call's colour is its
# last argument (the beam's is the one before its life), read to the call's closing bracket, so a
# call wrapped over lines is read whole; a chain colour is the "color" key of a bolt dictionary.
static func _unguarded(path: String) -> Array:
	var out := []
	var text := FileAccess.get_file_as_string(path)
	var line_of := func(at: int) -> String: return "%s:%d" % [path.get_file(), text.substr(0, at).count("\n") + 1]
	var uses := RegEx.create_from_string("effects\\b")
	var draw := RegEx.create_from_string("^effects\\.(arc|ring|spark|beam)\\(")
	for m in uses.search_all(text):
		var start := m.get_start()
		var d := draw.search(text.substr(start, 24))
		if d == null:
			# Anything but a direct draw call: an alias, a call by name, a stored handle.
			out.append(line_of.call(start) + " (not a direct draw)")
			continue
		var args := _args(text, start + d.get_end() - 1)
		var colour: String = args[args.size() - 2] if d.get_string(1) == "beam" and args.size() >= 2 else args[args.size() - 1]
		if not colour.strip_edges().begins_with("ActiveFx.peak("):
			out.append(line_of.call(start))
	for m in RegEx.create_from_string("\"color\"\\s*:\\s*([^,}]+)").search_all(text):
		if not m.get_string(1).strip_edges().begins_with("ActiveFx.peak("):
			out.append(line_of.call(m.get_start()) + " (chain colour)")
	return out


# The top-level arguments of the call whose "(" sits at `open`.
static func _args(text: String, open: int) -> Array:
	var args := []
	var depth := 0
	var from := open + 1
	for i in range(open, text.length()):
		var c := text[i]
		if c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
			if depth == 0:
				args.append(text.substr(from, i - from))
				return args
		elif c == "," and depth == 1:
			args.append(text.substr(from, i - from))
			from = i + 1
	return args


static func _scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + sub + "/"))
	return out


# The brightest alpha combat.effects draws at now.
func _peak_alpha() -> float:
	return _combat.effects.brightest()


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
	for path in _scripts(DIR):
		if path.get_file() != "active_fx.gd":
			scripts += 1
			unguarded.append_array(_unguarded(path))
	_t.eq("01 every mark an active draws goes through ActiveFx.peak", unguarded, [])
	var probe := "res://tests/fixtures/active_flashes_probe.txt"
	_t.check("01b the scan catches a bare colour, a wrapped call, an alias and a chain colour",
		_unguarded(probe).size() == 4, str(_unguarded(probe)))
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
	_t.check("04b effects draws a mark at its colour's alpha",
		is_equal_approx(_combat.effects.spark_alpha({"color": Color(amber, 0.5)}), 0.45)
		and is_equal_approx(_combat.effects.ring_alpha({"color": Color(amber, 0.5), "life": _combat.effects.RING_LIFE}), 0.35))
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
			bright.append("%s %.2f of %.2f" % [id, dimmed[id], full[id]])
	_t.check("05 off: every active draws a mark brighter than the information share (%d of %d)" % [drew.size(), ActiveDefs.ROWS.size()],
		drew.size() == ActiveDefs.ROWS.size(), "full %s" % [full])
	_t.eq("06 on: no active draws anything above the information share of full", bright, [])
	quit(_t.verdict())
