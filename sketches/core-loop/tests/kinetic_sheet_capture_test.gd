extends SceneTree

# Unit test for tools/kinetic_sheet_capture.gd (W46-ANIM-VFX-FLAIR):
#   1. CLI option parsing & validation (rejects bad category, missing assets, missing out);
#   2. box_of() merges visible child meshes and skips StageFloor;
#   3. image_metrics() + judge_metrics() pass on a crisp changed frame and catch planted failures
#      (blank frame, frozen non-idle frame, near-black crush, floating idle foot, cancelled death);
#   4. stitch_strip() produces an exact (TILE_W * N) x (TILE_H + HEADER_H) RGBA8 sheet with headers.

const T := preload("res://tests/support/t.gd")
const Capture := preload("res://tools/kinetic_sheet_capture.gd")
const Palette := preload("res://src/core/palette.gd")

var _t := T.new("kinetic_sheet_capture_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_cli()
	_test_box_of()
	_test_metrics_and_gates()
	_test_stitch()
	quit(_t.verdict())


func _test_cli() -> void:
	var opts := Capture.parse_args(PackedStringArray([
		"--category=enemy",
		"--assets=plated_brute,swatter",
		"--world=1",
		"--frames=idle,windup,attack,death",
		"--with-vfx=true",
		"--views=front34,side",
		"--reduce-flashes=true",
		"--out=/tmp/kinetic_test",
	]))
	_t.eq("category parsed", opts["category"], "enemy")
	_t.eq("assets parsed", opts["assets"], ["plated_brute", "swatter"])
	_t.eq("world parsed", opts["world"], 1)
	_t.eq("views parsed", opts["views"], ["front34", "side"])
	_t.check("reduce_flashes true", bool(opts["reduce_flashes"]))
	_t.eq("valid options return empty error", Capture.validate_options(opts), "")
	var bad_cat := opts.duplicate(true)
	bad_cat["category"] = "bogus"
	_t.check("bad category rejected", Capture.validate_options(bad_cat) != "")
	var no_out := opts.duplicate(true)
	no_out["out"] = ""
	_t.check("missing out rejected", Capture.validate_options(no_out) != "")
	var no_assets := opts.duplicate(true)
	no_assets["assets"] = []
	_t.check("empty assets rejected", Capture.validate_options(no_assets) != "")


func _test_box_of() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var a := MeshInstance3D.new()
	var ba := BoxMesh.new()
	ba.size = Vector3(2.0, 2.0, 2.0)
	a.mesh = ba
	a.position = Vector3(0.0, 1.0, 0.0)
	holder.add_child(a)
	var fl := MeshInstance3D.new()
	fl.name = "StageFloor"
	var bf := BoxMesh.new()
	bf.size = Vector3(80.0, 0.4, 80.0)
	fl.mesh = bf
	holder.add_child(fl)
	var box := Capture.box_of(holder)
	_t.near("box_of ignores StageFloor width", box.size.x, 2.0, 0.02)
	_t.near("box_of foot starts at y=0", box.position.y, 0.0, 0.02)
	holder.free()


func _test_metrics_and_gates() -> void:
	var w := 120
	var h := 90
	var bg := Image.create(w, h, false, Image.FORMAT_RGBA8)
	bg.fill(Palette.SANDSTONE)
	var idle := bg.duplicate()
	var attack := bg.duplicate()
	var black := bg.duplicate()
	# Paint a solid brass subject block in idle (40x40 = 1600 px)
	for y in range(25, 65):
		for x in range(40, 80):
			idle.set_pixel(x, y, Palette.BRASS)
			attack.set_pixel(x, y, Palette.BRASS)
			black.set_pixel(x, y, Color(0.01, 0.01, 0.01, 1.0))
	# Shift an arm/burst in attack (20x20 = 400 px changed)
	for y in range(15, 35):
		for x in range(75, 95):
			attack.set_pixel(x, y, Palette.HAZARD)

	var m_idle := Capture.image_metrics(idle, bg, idle)
	var v_idle := Capture.judge_metrics("idle", m_idle, 0.0)
	_t.check("healthy idle passes gate", bool(v_idle["pass"]), str(v_idle["reasons"]))

	var m_atk := Capture.image_metrics(attack, bg, idle)
	var v_atk := Capture.judge_metrics("attack", m_atk, 0.0)
	_t.check("healthy attack with motion delta passes gate", bool(v_atk["pass"]), str(v_atk["reasons"]))

	# Planted failures:
	var v_blank := Capture.judge_metrics("idle", Capture.image_metrics(bg, bg, bg), 0.0)
	_t.check("planted blank frame fails drawn_px", not bool(v_blank["pass"]))

	var v_frozen := Capture.judge_metrics("attack", Capture.image_metrics(idle, bg, idle), 0.0)
	_t.check("planted frozen attack fails delta_vs_idle_px", not bool(v_frozen["pass"]))

	var v_black := Capture.judge_metrics("idle", Capture.image_metrics(black, bg, black), 0.0)
	_t.check("planted crushed black frame fails near_black", not bool(v_black["pass"]))

	var v_float := Capture.judge_metrics("idle", m_idle, 1.2)
	_t.check("planted floating foot fails foot_min_y", not bool(v_float["pass"]))

	var v_cancel := Capture.judge_metrics("death", m_atk, 0.0, false)
	_t.check("planted cancelled death clip fails gate", not bool(v_cancel["pass"]))


func _test_stitch() -> void:
	var tiles: Array = []
	for i in 4:
		var im := Image.create(64, 48, false, Image.FORMAT_RGBA8)
		im.fill(Palette.SANDSTONE)
		tiles.append(im)
	var sheet := Capture.stitch_strip(tiles, ["A | IDLE", "A | WARN", "A | LIVE", "A | DEATH"])
	_t.eq("stitched width equals 4 * tile_w", sheet.get_width(), 256)
	_t.eq("stitched height equals tile_h + HEADER_H", sheet.get_height(), 48 + Capture.HEADER_H)
	_t.check("header painted charcoal at top-left", sheet.get_pixel(2, 2).is_equal_approx(Palette.CHARCOAL))
