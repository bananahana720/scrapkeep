extends SceneTree

# Wave 46 E3-02 (concept sheet 03-arena-stands-camp):
#   - the Slag Bowl has four stands, one to each quarter of the compass (north 270, east 0, south 90, west 180 in the
#     bowl's bearings), the recipe's STANDS (tools/blender/bosses/arena_bowl_yard.py) and the dress's agree row for row,
#     each stand draws geometry in its sector and seats crew, all of it behind the rim wall, and the yard GLB keeps inside
#     its scenery exception (triangles and draws) with the stands in one three-slot part;
#   - the camp's shift board stands where camp_layout.gd says, which agrees with tools/blender/camp/layout.py row for row;
#   - a pilot's camp quip hands the call-in's voice length to the caller plate, so its talking bars run as long as the
#     voice does (a silent call leaves them still);
#   - a rescue cage shows the keeper's scarf only once it is freed, on its front right post, with no collider and no
#     group; a retry keeps it on the freed cage and a new run takes it off again.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const Dress := preload("res://src/presentation/arena_bowl_dress.gd")
const Arena := preload("res://src/boss/arena.gd")
const Layout := preload("res://src/world/camp_layout.gd")
const Site := preload("res://src/world/rescue_site.gd")
const T := preload("res://tests/support/t.gd")

const YARD_GLB := "res://assets/models/bosses/arena_bowl_yard.glb"
const YARD_RECIPE := "res://tools/blender/bosses/arena_bowl_yard.py"
const YARD_ROW := "res://assets/registry.d/arena_bowl_yard.json"
const CAMP_RECIPE := "res://tools/blender/camp/layout.py"
const QUARTERS := [270.0, 0.0, 90.0, 180.0]
const VOICE_S := 3.5

var t := T.new("arena_stands_camp_test")
var game


# The call-in, as the hub sees it for one quip: records the call and answers with a voice length.
class VoiceStub extends RefCounted:
	var seconds := 0.0
	var calls: Array = []

	func call_in(kind: String, speaker: String, text: String) -> float:
		calls.append([kind, speaker, text])
		return seconds


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	while game.flow == null:
		await physics_frame
	await _frames(5)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	_stands_rows()
	_yard_budget()
	_camp_rows()
	await _camp()
	await _bowl()
	await _cage()
	game.free()
	quit(t.verdict())


func _angle_gap(a: float, b: float) -> float:
	return absf(angle_difference(deg_to_rad(a), deg_to_rad(b)))


func _stands_rows() -> void:
	t.eq("four stands", Dress.STANDS.size(), 4)
	for i in mini(Dress.STANDS.size(), QUARTERS.size()):
		var row: Array = Dress.STANDS[i]
		t.check("stand %d faces its own quarter (%.0f)" % [i, QUARTERS[i]], _angle_gap(row[0], QUARTERS[i]) <= deg_to_rad(45.0),
			"centre %.1f" % row[0])
		t.check("stand %d seats tiers that exist" % i, row[2] >= 0 and row[3] >= 1 and row[2] + row[3] <= Dress.TIERS, str(row))
	var source := FileAccess.get_file_as_string(YARD_RECIPE)
	var names := RegEx.create_from_string("NORTH_BLEACHERS, EAST_CRANE_WATCH, SOUTH_SCAFFOLD, WEST_GALLERY = ([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)").search(source)
	var rows := RegEx.create_from_string("\\((NORTH_BLEACHERS|EAST_CRANE_WATCH|SOUTH_SCAFFOLD|WEST_GALLERY), ([0-9.]+), ([0-9]+), ([0-9]+)\\)").search_all(source)
	t.check("the recipe names its four stands", names != null and rows.size() == 4, "%d rows" % rows.size())
	if names == null or rows.size() != 4:
		return
	var centres := {"NORTH_BLEACHERS": names.get_string(1).to_float(), "EAST_CRANE_WATCH": names.get_string(2).to_float(),
		"SOUTH_SCAFFOLD": names.get_string(3).to_float(), "WEST_GALLERY": names.get_string(4).to_float()}
	for i in 4:
		var m: RegExMatch = rows[i]
		var py := [centres[m.get_string(1)], m.get_string(2).to_float(), m.get_string(3).to_int(), m.get_string(4).to_int()]
		var gd: Array = Dress.STANDS[i]
		t.check("the recipe's stand %d is the dress's" % i, is_equal_approx(py[0], gd[0]) and is_equal_approx(py[1], gd[1])
			and py[2] == gd[2] and py[3] == gd[3], "%s vs %s" % [py, gd])


func _yard_budget() -> void:
	var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(YARD_ROW))["assets"][0]
	var cap: Dictionary = row["exception"]
	var scene := (load(YARD_GLB) as PackedScene).instantiate()
	var tris := 0
	var draws := 0
	var stand_slots := 0
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		draws += view.mesh.get_surface_count()
		for s in view.mesh.get_surface_count():
			var arrays := view.mesh.surface_get_arrays(s)
			tris += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		if view.name == "FleetStands":
			stand_slots = view.mesh.get_surface_count()
	t.check("the yard keeps inside its triangle exception", tris > 0 and tris <= int(cap["tris"]), "%d of %d" % [tris, int(cap["tris"])])
	t.check("the yard keeps inside its draw exception", draws > 0 and draws <= int(cap["draws"]), "%d of %d" % [draws, int(cap["draws"])])
	t.eq("the four stands are one three-slot part", stand_slots, 3)
	t.check("the yard GLB carries no collider", scene.find_children("*", "CollisionObject3D", true, false).is_empty())
	scene.free()


# layout.py's DRESSING and camp_layout.gd's agree: the same pieces the same number of times (a run written as a
# comprehension counts once per bearing), and every row the recipe writes out in numbers is the same row in both.
func _camp_rows() -> void:
	var source := FileAccess.get_file_as_string(CAMP_RECIPE)
	var block := source.get_slice("DRESSING = [", 1).get_slice("\n]", 0)
	var py_count := {}
	var literal := RegEx.create_from_string("^\\(\"([a-z_]+)\", ([0-9.]+), ([0-9.]+), (-?[0-9.]+)\\),$")
	var named := RegEx.create_from_string("^\\(\"([a-z_]+)\",")
	var run := RegEx.create_from_string("^\\*\\[\\(\"([a-z_]+)\",.* for b in \\(([0-9., ]+)\\)\\],$")
	var literals := 0
	for raw in block.split("\n", false):
		var line := raw.strip_edges()
		var r := run.search(line)
		var n := named.search(line)
		if r != null:
			py_count[r.get_string(1)] = int(py_count.get(r.get_string(1), 0)) + r.get_string(2).split(",", false).size()
		elif n != null:
			py_count[n.get_string(1)] = int(py_count.get(n.get_string(1), 0)) + 1
		var m := literal.search(line)
		if m != null:
			literals += 1
			var want := [m.get_string(1), m.get_string(2).to_float(), m.get_string(3).to_float(), m.get_string(4).to_float()]
			t.check("camp_layout.gd has layout.py's row %s" % str(want), _has_row(want))
	var gd_count := {}
	for r: Array in Layout.DRESSING:
		gd_count[r[0]] = int(gd_count.get(r[0], 0)) + 1
	t.check("layout.py writes its rows out", literals >= 10, "%d rows in numbers" % literals)
	t.check("both list the same pieces as often", py_count.recursive_equal(gd_count, 1), "%s vs %s" % [py_count, gd_count])
	t.eq("the shift board is one dressing row in both", [int(py_count.get("camp_shift_board", 0)), int(gd_count.get("camp_shift_board", 0))], [1, 1])


func _has_row(want: Array) -> bool:
	for r: Array in Layout.DRESSING:
		if r[0] == want[0] and is_equal_approx(r[1], want[1]) and is_equal_approx(r[2], want[2]) and is_equal_approx(r[3], want[3]):
			return true
	return false


func _camp() -> void:
	var profile = game.ctx.profile
	profile.unlock_pilot("runner_gunner")
	profile.unlock_pilot("tally")
	game._screen_key(KEY_K)
	await _frames(5)
	var hub = game.camp_hub
	t.check("K enters the camp walk", hub.walking and hub.built)
	var board: Node3D = hub.piece("camp_shift_board")
	t.check("the shift board is placed", board != null)
	if board != null:
		var at := Layout.at(194.0, 21.0)
		t.check("the shift board stands at its layout row", Vector2(board.position.x, board.position.z).distance_to(Vector2(at.x, at.z)) < 0.01,
			str(board.position))
		t.check("the shift board is solid, like the benches", not board.find_children("*", "CollisionShape3D", true, false).is_empty())
		var grouped := ([board] + board.find_children("*", "", true, false)).filter(func(n: Node): return not n.get_groups().is_empty())
		t.check("the shift board is in no group", grouped.is_empty(), str(grouped))
	# The voice length reaches the plate: the bars run while the voice does, then stop.
	var real = game.presentation.audio
	var stub := VoiceStub.new()
	stub.seconds = VOICE_S
	game.presentation.audio = stub
	hub._quip_from("runner_gunner")
	game.presentation.audio = real
	t.eq("the quip calls in once, in Rivet's voice", stub.calls.size() == 1 and stub.calls[0][0] == "camp_quip" and stub.calls[0][1] == "rivet"
		and stub.calls[0][2] == hub.quip_words(), true)
	var tile = hub._quip_tile
	t.check("the plate talks as the voice starts", tile.talking())
	tile._process(VOICE_S - 0.5)
	t.check("the plate still talks just before the voice ends", tile.talking())
	tile._process(1.0)
	t.check("the plate stops talking once the voice has", not tile.talking())
	hub._end_quip(true)
	var quiet := VoiceStub.new()
	game.presentation.audio = quiet
	hub._quip_from("tally")
	game.presentation.audio = real
	t.check("a silent call (another caller still talking) leaves the plate still", quiet.calls.size() == 1 and tile.visible and not tile.talking())
	hub._end_quip(true)
	hub.leave_walk()
	await _frames(5)


func _bowl() -> void:
	Harness.start_run(game)
	game.run.set_max_hp(999999.0)
	Harness.enter(game, Vector3(18, 0, 0))
	await _frames(30)
	var yard = game.boss.arena.get_node_or_null("ArenaBowlDress/FleetYard")
	t.check("the bowl has its Fleet yard", yard != null)
	if yard == null:
		return
	var stands := yard.get_node_or_null("FleetStands") as MeshInstance3D
	t.check("the stands are drawn", stands != null)
	if stands == null:
		return
	var per_stand := []
	per_stand.resize(Dress.STANDS.size())
	per_stand.fill(0)
	var nearest := INF
	for s in stands.mesh.get_surface_count():
		for vertex: Vector3 in stands.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = stands.transform * vertex
			nearest = minf(nearest, Vector2(p.x, p.z).length())
			var bearing := rad_to_deg(atan2(p.z, p.x))
			for i in Dress.STANDS.size():
				if _angle_gap(bearing, Dress.STANDS[i][0]) <= deg_to_rad(Dress.STANDS[i][1] + 2.0):
					per_stand[i] += 1
	t.check("every stand stands behind the rim wall", nearest > Arena.BANK_R + Arena.WALL_THICK, "nearest %.2f m" % nearest)
	for i in Dress.STANDS.size():
		t.check("stand %d is built in its sector" % i, per_stand[i] > 200, "%d vertices" % per_stand[i])
	var seated := []
	seated.resize(Dress.STANDS.size())
	seated.fill(0)
	for crowd: Array in yard.seats:
		for row: Dictionary in crowd:
			var at: Vector3 = row.rest.origin
			var bearing := rad_to_deg(atan2(at.z, at.x))
			for i in Dress.STANDS.size():
				if _angle_gap(bearing, Dress.STANDS[i][0]) <= deg_to_rad(Dress.STANDS[i][1]):
					seated[i] += 1
	for i in Dress.STANDS.size():
		t.check("stand %d seats crew" % i, seated[i] > 0, "%d seated" % seated[i])
	t.check("the yard adds no bodies", yard.find_children("*", "CollisionObject3D", true, false).is_empty())


func _scarf_state(cage) -> Node3D:
	return cage.get_node_or_null("KeeperScarf") as Node3D


func _cage() -> void:
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.world.rescue._done.clear()
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await process_frame
	var cage = game.world.rescue.cage("rivet")
	t.check("stage 1 builds Rivet's cage", cage != null)
	if cage == null:
		return
	var scarf := _scarf_state(cage)
	t.check("the cage carries the keeper's scarf", scarf != null)
	if scarf == null:
		return
	t.check("the scarf is hidden while the pilot is caged", not scarf.visible)
	t.check("the scarf is tied to the front right post", scarf.position.is_equal_approx(Site.SCARF_AT), str(scarf.position))
	t.check("the scarf has no collider", scarf.find_children("*", "CollisionObject3D", true, false).is_empty()
		and scarf.find_children("*", "CollisionShape3D", true, false).is_empty())
	var grouped := ([scarf] + scarf.find_children("*", "", true, false)).filter(func(n: Node): return not n.get_groups().is_empty())
	t.check("the scarf is in no group (never a target)", grouped.is_empty(), str(grouped))
	var drawn := scarf.find_children("*", "MeshInstance3D", true, false)
	t.check("the scarf is drawn from its model", not drawn.is_empty() and (drawn[0] as MeshInstance3D).mesh is ArrayMesh)
	var mint := 0
	var orange := 0
	for view: MeshInstance3D in drawn:
		for s in view.mesh.get_surface_count():
			var material := view.get_active_material(s) as BaseMaterial3D
			t.check("the scarf draws its vertex colours", material != null and material.vertex_color_use_as_albedo)
			for c: Color in view.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]:
				var srgb := c.linear_to_srgb()
				var hue := srgb.h * 360.0
				mint += 1 if hue > 120.0 and hue < 200.0 and srgb.s > 0.2 else 0
				orange += 1 if hue >= 10.0 and hue <= 40.0 and srgb.s > 0.4 else 0
	t.check("no mint in the scarf", mint == 0, "%d mint vertices" % mint)
	t.check("the scarf is orange wool", orange > 0, "%d orange vertices" % orange)
	cage.fire()
	cage.tick(Site.BREAK_SECONDS + 0.1)
	t.check("freed, the cage shows the scarf", cage.spent and scarf.visible)
	game.flow.enter_stage(1, Vector3.ZERO, true)
	await process_frame
	var again = game.world.rescue.cage("rivet")
	var kept := _scarf_state(again) if again != null else null
	t.check("a retry keeps the scarf on the freed cage", again != null and again.spent and kept != null and kept.visible)
	game.events.run_started.emit("pylon_engineer")
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await process_frame
	var fresh = game.world.rescue.cage("rivet")
	var gone := _scarf_state(fresh) if fresh != null else null
	t.check("a new run cages the pilot again, scarf hidden", fresh != null and not fresh.spent and gone != null and not gone.visible)
