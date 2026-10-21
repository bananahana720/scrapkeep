extends SceneTree

const Director := preload("res://src/world/director.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

# The pilot's nemesis lean (w17, ENEMY-PRIORITY.md section 4 lever 2b): from world 2 an authored
# pack holding a kind that presses the pilot's nemesis axis weighs Nemesis.PACK_WEIGHT against
# 1.0, in the interval draw and the credit draw alike. World one, an unknown class and an empty
# build keep the uniform pick, call for call. And in a real game step the director's build is
# the run's class (world.gd _step_director reads combat's build_read()).
#
# Tolerance: 24000 draws over 4 packs, two leaning; each pack's count has a standard deviation
# near 1.2% of itself, so the ratio of the leaning to the plain packs' share (target 1.5) has a
# standard error near 0.03. The band 1.35 to 1.65 is five of those.

const DRAWS := 24000
const PILOT := "tarn"  # nemesis axis: range
# lobber and winch_drone press range; chaser and plated_brute do not.
const TABLE := [
	{"id": "a", "kinds": ["lobber", "lobber"]},
	{"id": "b", "kinds": ["chaser", "chaser"]},
	{"id": "c", "kinds": ["winch_drone"]},
	{"id": "d", "kinds": ["plated_brute"]},
]
const LEAN := ["a", "c"]

var _t := T.new("director_nemesis_test")
var _game


func _initialize() -> void:
	_pure()
	_game = preload("res://src/game.gd").new()
	_game.test_mode = true
	root.add_child(_game)
	_wiring()


func _director(world: int, build: Dictionary, mode := "interval") -> Object:
	var d = Director.new(5)
	d.world = world
	d.authored = TABLE
	d.build = build
	d.set("mode", mode)
	d.threat = 1.0
	return d


func _draw(d: Object, credit: bool) -> String:
	d._last_pack_id = ""
	return String((d._draw_credit() if credit else d._draw_authored())["id"])


func _sequence(world: int, build: Dictionary, credit: bool, n := 300) -> Array:
	var d := _director(world, build, "credit" if credit else "interval")
	var out: Array = []
	for i in n:
		out.append(_draw(d, credit))
	return out


func _counts(world: int, build: Dictionary, credit: bool) -> Dictionary:
	var d := _director(world, build, "credit" if credit else "interval")
	var counts := {"a": 0, "b": 0, "c": 0, "d": 0}
	for i in DRAWS:
		counts[_draw(d, credit)] += 1
	return counts


# Share of draws a leaning pack gets over a plain pack's, from tilted counts relative to the
# same table's untilted counts (cancels the credit draw's own card weights).
func _ratio(tilted: Dictionary, plain: Dictionary) -> float:
	var lean := 0.0
	var rest := 0.0
	for id in tilted:
		var r := float(tilted[id]) / maxf(1.0, float(plain[id]))
		if id in LEAN:
			lean += r / LEAN.size()
		else:
			rest += r / (tilted.size() - LEAN.size())
	return lean / rest


func _pure() -> void:
	_t.check("table holds the pilot's nemesis kinds",
		Nemesis.pack_presses(PILOT, ["lobber"]) and Nemesis.pack_presses(PILOT, ["winch_drone"])
		and not Nemesis.pack_presses(PILOT, ["chaser"]) and not Nemesis.pack_presses(PILOT, ["plated_brute"]))
	var build := {"class": PILOT}
	for credit in [false, true]:
		var label := "credit" if credit else "interval"
		var plain := _counts(2, {}, credit)
		var tilted := _counts(2, build, credit)
		var ratio := _ratio(tilted, plain)
		_t.check("world 2 %s leans 1.5x per nemesis pack" % label, ratio > 1.35 and ratio < 1.65, "ratio %.3f; plain %s tilted %s" % [ratio, plain, tilted])
		_t.eq("world 1 %s identical to empty build" % label, _sequence(1, build, credit), _sequence(1, {}, credit))
		_t.eq("unknown class %s identical to empty build" % label, _sequence(2, {"class": "nobody"}, credit), _sequence(2, {}, credit))
		_t.eq("empty class %s identical to empty build" % label, _sequence(2, {"class": "", "habits": {}}, credit), _sequence(2, {}, credit))
	# A real pilot whose axes press nothing in the table keeps the uniform pick too.
	var quiet := {"class": "runner_gunner"}  # spread: no kind in TABLE
	_t.eq("pilot with no matching pack identical to empty build", _sequence(2, quiet, false), _sequence(2, {}, false))
	_t.eq("pilot with no matching pack identical in credit", _sequence(2, quiet, true), _sequence(2, {}, true))
	# The lean actually changes the world-2 draw (not a no-op).
	_t.check("world 2 tilted sequence differs", _sequence(2, build, false) != _sequence(2, {}, false))
	# Every real pilot id is in the table.
	var ids: Array = []
	for def in ClassDef.all():
		ids.append(String(def.id))
	_t.check("every ClassDef id has nemesis axes", ids.all(func(id): return not Nemesis.of(id).is_empty()), str(ids))


func _wiring() -> void:
	while _game.flow == null:
		await physics_frame
	_game.flow.press_start()
	_game.flow.choose_class(1)
	var frames := 0
	var want := ""
	while frames < 600:
		frames += 1
		await physics_frame
		if _game.run != null and _game.run.class_def != null:
			want = String(_game.run.class_def.id)
			if String(_game.world.director.build.get("class", "")) == want:
				break
	_t.check("director.build class is the run's ClassDef id after stepping", want != "" and String(_game.world.director.build.get("class", "")) == want,
		"want %s got %s after %d frames" % [want, _game.world.director.build.get("class", ""), frames])
	_game.free()
	quit(_t.verdict())
