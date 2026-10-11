extends SceneTree

# Rule: the committed bake of park_test.json is fresh, a fresh bake reproduces it byte for byte,
# a one-row table edit turns the freshness check red until a rebake turns it green, `hole` rows
# mark exactly the 2 m cells under their footprint, and the stamps land where PARK.md 2.2 and
# section 3 put them: additive on the y 0 base plain, a `ramp` falling by its height from its
# start to its end along its yaw (park/stages/1-park_dam.md section 2). K-UNITS KB3.

const T := preload("res://tests/support/t.gd")

const PARK := "res://src/world/park/park_test.json"
const BAKED := "res://assets/park/park_test"
const SCRATCH := "user://park_bake_fresh_test"
const FILES := ["ground.bin", "apron.bin", "holes.bin", "under.bin", "surface.bin", "bake.json"]
const SIDE := 801
const CELLS := 800

var t := T.new("park_bake_fresh_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tool_path := "res://tools/park_bake.gd"
	var stamps_path := "res://src/world/park/park_stamps.gd"
	if not t.check("bake tool and stamps exist", ResourceLoader.exists(tool_path) and ResourceLoader.exists(stamps_path)):
		quit(t.verdict())
		return
	var bake: GDScript = load(tool_path)
	var stamps: GDScript = load(stamps_path)
	DirAccess.make_dir_recursive_absolute(SCRATCH)

	var stale: Array = bake.freshness(PARK, BAKED)
	t.check("committed bake is fresh", stale.is_empty(), str(stale))

	# Two bakes give identical bytes: a fresh bake here matches the committed (CLI) bake.
	var again: Dictionary = bake.bake(PARK, SCRATCH + "/again")
	t.check("fresh bake succeeds", again["ok"], str(again["errors"]))
	for name in FILES:
		var a := FileAccess.get_file_as_bytes(BAKED + "/" + name)
		var b := FileAccess.get_file_as_bytes(SCRATCH + "/again/" + name)
		t.check("rebake is byte-identical: " + name, not a.is_empty() and a == b, "%d vs %d bytes" % [a.size(), b.size()])

	_stamps(bake, stamps)
	_holes(bake, BAKED, 1)
	_edit(bake)
	quit(t.verdict())


# One-row edit: the tube stops cutting a hole. The committed bake goes stale on the park hash;
# a rebake of the edited file is fresh and has no hole cells left.
func _edit(bake: GDScript) -> void:
	var text := FileAccess.get_file_as_string(PARK)
	var edited := text.replace('"recipe": "lava_tube_run", "stamp": "", "hole": true',
		'"recipe": "lava_tube_run", "stamp": "", "hole": false')
	t.check("the edit changes one row", edited != text)
	var park_path := SCRATCH + "/park_test.json"
	var f := FileAccess.open(park_path, FileAccess.WRITE)
	f.store_string(edited)
	f.close()
	var stale: Array = bake.freshness(park_path, BAKED)
	t.check("one-row edit without a rebake is stale", not stale.is_empty() and str(stale).contains("park_sha256"), str(stale))
	var rebake: Dictionary = bake.bake(park_path, SCRATCH + "/edited")
	t.check("edited park rebakes", rebake["ok"], str(rebake["errors"]))
	var fresh: Array = bake.freshness(park_path, SCRATCH + "/edited")
	t.check("after the rebake it is fresh", fresh.is_empty(), str(fresh))
	_holes(bake, SCRATCH + "/edited", 0)


# The tube row (at [100, 300], size [200, 30, 16], yaw -10, hole true) marks every 2 m cell whose
# centre lies in its footprint, counted here with this test's own geometry.
func _holes(bake: GDScript, dir: String, tube_holes: int) -> void:
	var holes := FileAccess.get_file_as_bytes(dir + "/holes.bin")
	if not t.eq("holes.bin is one byte per 2 m cell (%s)" % dir, holes.size(), CELLS * CELLS):
		return
	var a := deg_to_rad(-10.0)
	var along := Vector2(sin(a), cos(a))
	var across := Vector2(cos(a), -sin(a))
	var want := 0
	var marked := 0
	var outside_marked := 0
	for j in CELLS:
		for i in CELLS:
			var rel := Vector2(-800.0 + 2.0 * i + 1.0, -800.0 + 2.0 * j + 1.0) - Vector2(100.0, 300.0)
			var inside := absf(rel.dot(along)) <= 100.0 and absf(rel.dot(across)) <= 8.0
			var hole := holes[j * CELLS + i] == 1
			if inside:
				want += 1
				if hole:
					marked += 1
			elif hole:
				outside_marked += 1
	t.check("the footprint holds cells", want > 700, "%d cells" % want)
	t.eq("hole cells under the tube (%s)" % dir, marked, want * tube_holes)
	t.eq("no hole cell outside a hole row (%s)" % dir, outside_marked, 0)
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/bake.json"))
	t.eq("bake.json counts the hole cells (%s)" % dir, int(info["cells"]["holes"]), want * tube_holes)
	t.eq("under.bin has one float per hole cell (%s)" % dir, FileAccess.get_file_as_bytes(dir + "/under.bin").size(), 4 * want * tube_holes)


func _stamps(bake: GDScript, stamps: GDScript) -> void:
	var raw := FileAccess.open_compressed(BAKED + "/ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if not t.check("ground.bin opens as zstd", raw != null):
		return
	var bytes := raw.get_buffer(SIDE * SIDE * 4 + 16)
	raw.close()
	if not t.eq("ground.bin is 801 by 801 float32", bytes.size(), SIDE * SIDE * 4):
		return
	var h := bytes.to_float32_array()
	var at := func(x: float, z: float) -> float:
		return h[int((z + 800.0) / 2.0) * SIDE + int((x + 800.0) / 2.0)]
	# The plain row raises the whole square by 40 (plateau); nothing else touches (600, -600).
	t.near("plateau plain at (600, -600)", at.call(600.0, -600.0), 40.0, 0.001)
	# The lip ramp at [0, -100], length 20 along yaw 0, height 4: start z -110 is +4, end z -90 is +0.
	t.near("ramp near its start (0, -108)", at.call(0.0, -108.0), 40.0 + 4.0 * 0.9, 0.001)
	t.near("ramp near its end (0, -92)", at.call(0.0, -92.0), 40.0 + 4.0 * 0.1, 0.001)
	t.check("ramp falls from start to end", at.call(0.0, -104.0) > at.call(0.0, -96.0))
	# The run_wash wash cuts 12 m below the plain at its centre line.
	t.near("wash floor at the centre (-200, -300)", at.call(-200.0, -300.0), 28.0, 0.001)
	# The pool bowl is 8 deep at its centre, which also sits on the apron row's +2 plateau
	# (yaw 90: 40 m along x, 300 m across z, so z 380 to 680).
	t.near("bowl bottom at (0, 450)", at.call(0.0, 450.0), 34.0, 0.001)
	# Every landform has a surface slot.
	var missing := []
	for landform in preload("res://src/world/park/park_schema.gd").LANDFORMS:
		if stamps.surface_slot(landform) < 0:
			missing.append(landform)
	t.check("every landform has a surface slot", missing.is_empty(), str(missing))
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAKED + "/bake.json"))
	t.eq("bake.json names the map", info.get("map"), "park_test")
	t.eq("apron is the 1 m ring outside the play square", int(info["cells"]["apron"]), 2048 * 2048 - 1601 * 1601)
