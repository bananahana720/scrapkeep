extends SceneTree

const Game := preload("res://src/game.gd")
const Director := preload("res://src/world/director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

# Codex review w18 (level #1): with enemy homes ahead, a pack member whose kind has no home on
# the park was stripped, and crossed_wires (every member homeless) never arrived, so the flume's
# authored arrivals stalled until the ball left the window. On the real flume, with homes in the
# window, each of the homeless packs queues every member in one arrival, inside a live window
# home's footprint, and the pack after it is drawn.

const HOMELESS := ["crossed_wires", "weir_strung", "shift_crew", "flap_line"]

var _game
var _graph
var _ticks := 0
var _phase := 0
var _failures := 0
var _ball := Vector2.ZERO
var _sites := {}
var _pack_index := 0
var _made := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	_graph = Graph.read("res://assets/park/park_flume/graph.bin")


func _check(label: String, ok: bool, detail := "") -> void:
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _at(row: Dictionary) -> Vector2:
	return Vector2(float(row.at[0]), float(row.at[1]))


func _row(id: String) -> Dictionary:
	for row in ParkDefs.PACKS_FLUME:
		if row.id == id:
			return row.duplicate(true)
	return {}


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _ticks == 0:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	_ticks += 1
	if _ticks < 20:
		return false
	if _phase == 0:
		_game.flow.enter_stage(2, Vector3.ZERO, false)
		var map = _game.ctx.terrain.map()
		_check("real Game uses park_flume", map is ParkMap and map.title == "park_flume", str(map.title))
		for site in map.park.park_rows:
			_sites[site.id] = site
		var chaser_home := {}
		for home in map.park.home_rows:
			if home.enemy == "chaser" and not home.dormant:
				chaser_home = home
		_ball = _window_ball(_sites[chaser_home.site])
		_check("flume window fixture", _ball != Vector2.INF, str(_ball))
		_game.player.body().freeze = true
		_phase = 1
		_start_pack()
		return false
	_place_ball()
	var d = _game.world.director
	if d.arrivals.is_empty():
		d._timer = 0.0
		if _ticks < 80:
			return false
	var id: String = HOMELESS[_pack_index]
	var want: Array = _row(id).kinds
	var got := []
	var housed := true
	for a in d.arrivals:
		if a.pack != d.arrivals[0].pack:
			continue
		got.append(Director.KIND_NAMES[a.kind])
		housed = housed and _in_window_home(a.at)
	got.sort()
	want = want.duplicate()
	want.sort()
	_check("%s queues every member with homes in the window" % id, got == want, "%s vs %s" % [got, want])
	_check("%s arrives inside a live window home" % id, housed and not d.arrivals.is_empty())
	_check("%s arrival is counted and the next pack drawn" % id,
		d._arrivals_made == _made + 1 and not d.packs.is_empty() and d.packs[0].id == id,
		"made %d packs %s" % [d._arrivals_made, d.packs])
	_pack_index += 1
	if _pack_index < HOMELESS.size():
		_start_pack()
		return false
	_game.queue_free()
	print("director_homeless_test: PASS" if _failures == 0 else "director_homeless_test: FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
	return true


func _start_pack() -> void:
	var d = _game.world.director
	_place_ball()
	d.stage_time = 90.0
	d.arrivals.clear()
	d.packs.clear()
	d._arrivals_made = 0
	d.elite_arrival = 99
	d._last_pack_id = ""
	d._next_pack = _row(HOMELESS[_pack_index])
	d._timer = 0.0
	_made = d._arrivals_made
	_ticks = 20


func _place_ball() -> void:
	var body = _game.player.body()
	body.global_position = _game.ctx.terrain.drop_point(_ball.x, _ball.y, 2.4)
	_game.player.state.velocity = Vector3.ZERO


func _window_ball(site: Dictionary) -> Vector2:
	var home_d: float = _graph.d_landmark(_at(site))
	for n in _graph.px.size():
		var p := Vector2(_graph.px[n], _graph.pz[n])
		var ahead: float = _graph.d_landmark_node(n) - home_d
		if ahead >= 120.0 and ahead <= 180.0 and p.distance_to(_at(site)) < 200.0:
			return p
	return Vector2.INF


func _in_window_home(at: Vector2) -> bool:
	for home in _game.ctx.terrain.map().park.home_rows:
		if home.dormant:
			continue
		var site: Dictionary = _sites[home.site]
		var ahead: float = _graph.d_landmark(_ball) - _graph.d_landmark(at)
		if ParkMap.footprint_contains(site, at) and ahead >= Director.HOME_WINDOW.x and ahead <= Director.HOME_WINDOW.y:
			return true
	return false
