extends SceneTree

# tools/look_subjects.gd and tools/look_harness.gd, headless: the subject rows are sound and
# stand on alpha stages, the frame metrics call a black frame and a flat sky frame dead and a
# textured mid-grey frame live, the blind-pair coin is fixed per subject and camera, the pair
# writer follows it, and the camera and silhouette helpers do what their headers say.
const Subjects := preload("res://tools/look_subjects.gd")
const Harness := preload("res://tools/look_harness.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const T := preload("res://tests/support/t.gd")
const TMP := "user://look_harness_test"

var _t := T.new("look_harness_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var problems := Subjects.problems(AlphaDefs.COUNT)
	_t.check("every subject row is well formed and stands on an alpha stage", problems.is_empty(), "; ".join(problems))
	_t.check("the w7 subjects and the probe ports are all rows", Subjects.SUBJECTS.size() >= 53, "%d rows" % Subjects.SUBJECTS.size())
	for n in Subjects.SUBJECTS:
		var stage := int(Subjects.SUBJECTS[n]["stage"])
		if stage >= 1 and stage <= AlphaDefs.COUNT and int(AlphaDefs.of(stage)["stage"]) != stage:
			_t.check("%s stage %d is alpha_defs row %d" % [n, stage, stage], false)
	var groups := {}
	for g in Subjects.GROUPS:
		_t.check("group %s listed once" % g, not groups.has(g))
		groups[g] = true
		_t.check("group %s stages at least one subject" % g, not Subjects.in_group(g).is_empty())
	for n in ["arb_bowl", "arm_crown", "arw_pit", "cv2_camp_bay", "ttl_stage_ball", "ttl_stage_spil9"]:
		_t.check("re-aimed row %s says why" % n, Subjects.SUBJECTS[n].has("reaim"))

	var black := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	black.fill(Color(0.02, 0.02, 0.02))
	var mb := Harness.frame_metrics(black)
	_t.check("a black frame is dead", Harness.is_dead(mb, Subjects.DEAD), str(mb))
	_t.near("a black frame is all near-black", mb["black"], 1.0)
	var sky := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	sky.fill(Color8(134, 161, 183))
	var ms := Harness.frame_metrics(sky)
	_t.check("a flat sky frame is dead", Harness.is_dead(ms, Subjects.DEAD), str(ms))
	_t.eq("the flat colour is the sky", ms["sky_rgb"], [134, 161, 183])
	var grey := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	for y in range(0, 1080, 2):
		for x in range(0, 1920, 2):
			var v := 118 + (x * 7 + y * 13) % 20
			grey.fill_rect(Rect2i(x, y, 2, 2), Color8(v, v, v))
	var mg := Harness.frame_metrics(grey)
	_t.check("a textured mid-grey frame is live", not Harness.is_dead(mg, Subjects.DEAD), str(mg))
	_t.near("mid-grey luminance", mg["luma"], 0.5, 0.05)

	var heads := 0
	var cams := 0
	for n in Subjects.SUBJECTS:
		for shot in Subjects.SUBJECTS[n]["cameras"]:
			var c := Subjects.coin(n, shot[0])
			_t.check("coin %s/%s is the same twice" % [n, shot[0]], c == Subjects.coin(n, shot[0]))
			heads += 1 if c else 0
			cams += 1
	_t.check("the coin is not one-sided over the table", heads > cams / 4 and heads < cams * 3 / 4, "%d of %d" % [heads, cams])
	_t.eq("coin pinned: arb_bowl/overview", Subjects.coin("arb_bowl", "overview"), ("arb_bowl/overview".sha256_buffer()[0] & 1) == 1)

	DirAccess.make_dir_recursive_absolute(TMP + "/base/gpd_bet")
	DirAccess.make_dir_recursive_absolute(TMP + "/head/gpd_bet")
	var small := Image.create(4, 4, false, Image.FORMAT_RGB8)
	for row in Subjects.SUBJECTS["gpd_bet"]["cameras"]:
		small.fill(Color.RED)
		small.save_png(TMP + "/base/gpd_bet/" + row[0] + ".png")
		small.fill(Color.BLUE)
		small.save_png(TMP + "/head/gpd_bet/" + row[0] + ".png")
	DirAccess.make_dir_recursive_absolute(TMP + "/base/gpd_altar")
	DirAccess.make_dir_recursive_absolute(TMP + "/head/gpd_altar")
	for row in Subjects.SUBJECTS["gpd_altar"]["cameras"]:
		small.save_png(TMP + "/base/gpd_altar/" + row[0] + ".png")
		small.save_png(TMP + "/head/gpd_altar/" + row[0] + ".png")
	for side in [["base", "gpd_bet", "card one"], ["head", "gpd_bet", "card one"], ["base", "gpd_altar", "card zero"], ["head", "gpd_altar", "card one"]]:
		var f := FileAccess.open(TMP + "/%s/%s/frames.json" % [side[0], side[1]], FileAccess.WRITE)
		f.store_string(JSON.stringify({"adapter": side[2]}))
		f.close()
	var made := Harness.write_pairs(["gpd_bet", "gpd_altar"], ProjectSettings.globalize_path(TMP + "/base"), ProjectSettings.globalize_path(TMP + "/head"), ProjectSettings.globalize_path(TMP + "/pairs"))
	_t.eq("one pair per gpd_bet camera and none across two adapters", made, (Subjects.SUBJECTS["gpd_bet"]["cameras"] as Array).size())
	_t.check("a pair across two adapters is refused in key.json", not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TMP + "/pairs/gpd_altar__front")))
	var key: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TMP + "/pairs/key.json"))
	for row in Subjects.SUBJECTS["gpd_bet"]["cameras"]:
		var id: String = "gpd_bet__" + row[0]
		var a := Image.load_from_file(ProjectSettings.globalize_path(TMP + "/pairs/" + id + "/a.png"))
		var a_is_base: bool = a.get_pixel(1, 1).r > 0.5
		_t.check("pair %s side a follows the coin" % id, a_is_base == Subjects.coin("gpd_bet", row[0]))
		_t.eq("key.json names side a of %s" % id, key["pairs"][id]["a"], "base" if a_is_base else "head")
	_t.check("key.json names the adapter refusal", String(key["pairs"]["gpd_altar__front"]).begins_with("adapter_mismatch"))

	var turned := {"miniboss": {"point": Vector3(10, 0, 0), "basis": Basis(Vector3.UP, PI / 2.0), "radius": 1.0}}
	var v := Subjects.resolve("pmb_miniboss_stalk", Subjects.SUBJECTS["pmb_miniboss_stalk"]["cameras"][0], turned)
	_t.check("a basis row turns the eye with its anchor", (v["eye"] as Vector3).is_equal_approx(Vector3(10 - 17, 3, 0)), str(v["eye"]))
	_t.check("the target stays on the anchor", (v["target"] as Vector3).is_equal_approx(Vector3(10, 0, 0)))
	var bay := {"bay": {"point": Vector3(0, 5, 0), "basis": Basis.IDENTITY, "radius": 20.0}}
	var vb := Subjects.resolve("cv2_camp_bay", Subjects.SUBJECTS["cv2_camp_bay"]["cameras"][0], bay)
	_t.check("a scale row multiplies by the anchor radius", (vb["eye"] as Vector3).is_equal_approx(Vector3(14, 14, -14)), str(vb["eye"]))

	var holder := Node3D.new()
	root.add_child(holder)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2, 4, 2)
	box.mesh = bm
	box.position = Vector3(0, 2, 0)
	holder.add_child(box)
	var bounds := Harness.subject_bounds(holder)
	_t.check("subject bounds are the mesh's world box", bounds.size.is_equal_approx(Vector3(2, 4, 2)) and bounds.position.is_equal_approx(Vector3(-1, 0, -1)), str(bounds))
	_t.near("a subject faces an eye on its forward (-Z)", Harness.facing(holder, Vector3(0, 1, -10)), 0.0, 0.01)
	_t.near("a subject turns its back on an eye behind it", Harness.facing(holder, Vector3(0, 1, 10)), 180.0, 0.01)
	holder.free()
	quit(_t.verdict())
