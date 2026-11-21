extends SceneTree

const T := preload("res://tests/support/t.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Kit := preload("res://src/presentation/destructible_kit.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Palette := preload("res://src/core/palette.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

# Test F (design-v3/HEFT-DESTRUCTIBLES.md sections 4.1, 9 and 10.2), unit C: the look of a heft destructible.
# Proves, with a planted failing control beside every claim:
#   - each tier's mesh carries exactly tier - 1 recessed seam bands (read from the vertices, not the meta),
#     fits its box, stays inside 3000 triangles and is wound to Godot's front face;
#   - the colour law: opaque vertex colour only, never a signal hue, nothing emissive, never alpha;
#   - the four shards are a few triangles each, distinct and opaque;
#   - the four family shatter sounds resolve in the bank, and the module plays the family's own on a break;
#   - the fixture tick stays at or under 0.3 ms and a break frame stays under one 60 Hz frame (16.7 ms);
#   - nothing is allocated at the break (no new resource, material or shader) and nothing outlives the stage.
# Evidence limit: a headless run measures the CPU side of the break only. The GPU frame, and the opaque
# shrink against an alpha-fade shader stall, are measured when the run has a window (NEEDS: gpu otherwise).

const DT := 1.0 / 60.0
const CRUISE := 14.0
const TICK_CAP_MS := 0.3
const FRAME_CAP_MS := 1000.0 / 60.0
const SEAM_MATCH := 0.002
const SIZES := {
	1: Vector3(1.4, 1.2, 1.4), 2: Vector3(2.6, 2.4, 1.0), 3: Vector3(2.6, 3.2, 2.6),
	4: Vector3(3.2, 4.0, 3.0), 5: Vector3(3.6, 5.0, 3.0),
}

var t := T.new("destructibles_look_test")


class FakeAudio extends RefCounted:
	var heard: Array[String] = []

	func play(_kind: String, _db := 0.0, _pitch := 1.0, _bus := "SFX", sound_override := "") -> bool:
		heard.append(sound_override)
		return true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_tier_meshes()
	_shards()
	_colour_law_controls()
	_sounds()
	_module_sounds()
	_build_warmth()
	_tick_cost()
	_break_frame()
	await _leaks()
	await _gpu_frame()
	quit(t.verdict())


# ---- the mesh reads -----------------------------------------------------------------------------

func _arrays(mesh: Mesh) -> Array:
	return mesh.surface_get_arrays(0)


# Seam bands as the vertices show them: the SEAM-coloured vertices sit on two heights a band, so the band
# count is half the distinct heights, and every one is set back from the piece's faces.
func _seams(mesh: Mesh) -> Dictionary:
	var arrays := _arrays(mesh)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var box := mesh.get_aabb()
	var heights := {}
	var shallow := 1000.0
	var foreign := 0
	for i in verts.size():
		if Kit.color_distance(colors[i], Kit.SEAM) <= SEAM_MATCH:
			heights[snappedf(verts[i].y, 0.001)] = true
			shallow = minf(shallow, minf(box.size.x * 0.5 - absf(verts[i].x), box.size.z * 0.5 - absf(verts[i].z)))
	var ys: Array = heights.keys()
	ys.sort()
	return {"bands": ys.size() / 2, "odd": ys.size() % 2 != 0, "recess": shallow if not ys.is_empty() else 0.0,
		"thickness": float(ys[1]) - float(ys[0]) if ys.size() >= 2 else 0.0, "foreign": foreign}


func _seams_read(mesh: Mesh, tier: int) -> bool:
	var seen := _seams(mesh)
	return int(seen["bands"]) == tier - 1 and not bool(seen["odd"]) and (tier == 1 or float(seen["recess"]) >= 0.03)


func _winds_front(mesh: Mesh) -> bool:
	var arrays := _arrays(mesh)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, index.size(), 3):
		var cross := (verts[index[i + 1]] - verts[index[i]]).cross(verts[index[i + 2]] - verts[index[i]])
		if cross.length_squared() < 0.0000001 or cross.dot(normals[index[i]]) >= 0.0:
			return false
	return true


func _within_budget(mesh: Mesh, cap: int) -> bool:
	return mesh.get_surface_count() == 1 and Kit.triangle_count(mesh) <= cap


# "" when the surface passes the colour law, else the first thing wrong with it.
func _law_mesh(mesh: Mesh) -> String:
	var arrays := _arrays(mesh)
	var colors: Variant = arrays[Mesh.ARRAY_COLOR]
	if not colors is PackedColorArray or (colors as PackedColorArray).is_empty():
		return "no vertex colour"
	for c in colors as PackedColorArray:
		if not is_equal_approx(c.a, 1.0):
			return "alpha %.2f" % c.a
		for name in Kit.FORBIDDEN:
			var d := Kit.color_distance(c, Kit.FORBIDDEN[name])
			if d < Kit.MIN_FORBIDDEN_DISTANCE:
				return "%s within %.3f of %s" % [c.to_html(false), d, name]
	return ""


func _law_material(mat: BaseMaterial3D) -> String:
	if mat == null:
		return "no material"
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return "transparent"
	if not is_equal_approx(mat.albedo_color.a, 1.0):
		return "albedo alpha %.2f" % mat.albedo_color.a
	if mat.emission_enabled:
		return "emissive"
	if not mat.vertex_color_use_as_albedo:
		return "vertex colour ignored"
	return ""


func _tier_meshes() -> void:
	var hashes := {}
	for tier in range(1, 6):
		var size: Vector3 = SIZES[tier]
		var mesh := Kit.piece_mesh(tier, size)
		var tag := "tier %d" % tier
		t.check("F: %s builds one surface within %d triangles" % [tag, Kit.TRIANGLE_BUDGET], _within_budget(mesh, Kit.TRIANGLE_BUDGET), "%d tris" % Kit.triangle_count(mesh))
		var box := mesh.get_aabb()
		t.check("F: %s is a solid the size of its box" % tag, box.size.is_equal_approx(size) or (box.size - size).length() <= 0.01, "%s vs %s" % [box.size, size])
		t.check("F: %s sits centred on its origin" % tag, box.get_center().length() <= 0.01, "%s" % box.get_center())
		t.check("F: %s reads %d seam bands from its vertices" % [tag, tier - 1], _seams_read(mesh, tier), str(_seams(mesh)))
		t.eq("F: %s carries the same count as meta" % tag, int(mesh.get_meta("seam_bands", -1)), tier - 1)
		t.eq("F: %s seam count is the kit's tier - 1 rule" % tag, Kit.seam_count(tier), tier - 1)
		t.check("F: %s is wound to Godot's front face" % tag, _winds_front(mesh), "")
		t.eq("F: %s wears the park palette only" % tag, _law_mesh(mesh), "")
		if tier > 1:
			var seen := _seams(mesh)
			t.check("F: %s seam is a recessed band of its own thickness" % tag, absf(float(seen["thickness"]) - float(mesh.get_meta("seam_thickness"))) <= 0.002 and float(seen["recess"]) >= 0.03,
				"thickness %.3f recess %.3f" % [seen["thickness"], seen["recess"]])
		var key := str((_arrays(mesh)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) + ":" + str(hash(_arrays(mesh)[Mesh.ARRAY_VERTEX]))
		t.check("F: %s has a shape of its own" % tag, not hashes.has(key), "")
		hashes[key] = true
	# The heft read grows with the tier: more seams, and a bigger solid than the one below it.
	t.check("F: the seam count climbs one a tier", Kit.seam_count(1) == 0 and Kit.seam_count(5) == 4, "")
	# A small piece still builds a whole one.
	var tiny := Kit.piece_mesh(5, Vector3(0.8, 1.6, 0.8))
	t.check("F: a narrow tier 5 still reads four seams inside its budget", _seams_read(tiny, 5) and _within_budget(tiny, Kit.TRIANGLE_BUDGET), str(_seams(tiny)))

	# Planted controls: each predicate must fail the fault it claims to catch.
	var three := Kit.piece_mesh(3, SIZES[3])
	t.check("F control: a tier 3 mesh read as tier 2 fails the seam count", not _seams_read(three, 2), "")
	t.check("F control: a mesh with a seam read as tier 1 fails", not _seams_read(three, 1), "")
	var sphere := SphereMesh.new()
	sphere.radial_segments = 64
	sphere.rings = 32
	var heavy: Mesh = sphere
	t.check("F control: a %d-triangle mesh fails the 3000 budget" % Kit.triangle_count(heavy), not _within_budget(heavy, Kit.TRIANGLE_BUDGET), "")
	t.check("F control: a mesh with a second surface fails the one-draw budget", not _within_budget(_two_surfaces(), Kit.TRIANGLE_BUDGET), "")
	var flipped := _flipped(three)
	t.check("F control: a mesh wound backwards fails the front-face check", not _winds_front(flipped), "")
	var bare := Kit.piece_mesh(1, SIZES[1])
	t.check("F control: tier 1 wears no seam colour, so a seam always means a break", int(_seams(bare)["bands"]) == 0, "")
	t.check("F control: a size mismatch fails the box check", (Kit.piece_mesh(3, Vector3(2.0, 2.0, 2.0)).get_aabb().size - SIZES[3]).length() > 0.01, "")


func _two_surfaces() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new().get_mesh_arrays()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box)
	return mesh


func _flipped(mesh: Mesh) -> ArrayMesh:
	var arrays := _arrays(mesh).duplicate(true)
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, index.size(), 3):
		var swap := index[i + 1]
		index[i + 1] = index[i + 2]
		index[i + 2] = swap
	arrays[Mesh.ARRAY_INDEX] = index
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


# ---- shards -------------------------------------------------------------------------------------

func _shards() -> void:
	var seen := {}
	for family in Kit.FAMILIES:
		var mesh := Kit.shard_mesh(family)
		var tag := "%s shard" % family
		t.check("F: the %s is one surface under %d triangles" % [tag, Kit.SHARD_TRIANGLE_BUDGET], _within_budget(mesh, Kit.SHARD_TRIANGLE_BUDGET), "%d tris" % Kit.triangle_count(mesh))
		var box := mesh.get_aabb()
		t.check("F: the %s is a solid, not a sliver, and no longer than %.1f m" % [tag, Kit.SHARD_MAX_M],
			box.size.x > 0.02 and box.size.y > 0.02 and box.size.z > 0.02 and maxf(box.size.x, maxf(box.size.y, box.size.z)) <= Kit.SHARD_MAX_M + 0.001, str(box.size))
		t.check("F: the %s is wound to Godot's front face" % tag, _winds_front(mesh), "")
		t.eq("F: the %s wears the park palette only" % tag, _law_mesh(mesh), "")
		var key := str(hash(_arrays(mesh)[Mesh.ARRAY_VERTEX])) + str(hash(_arrays(mesh)[Mesh.ARRAY_COLOR]))
		t.check("F: the %s is distinct from the others" % tag, not seen.has(key), "")
		seen[key] = true
	var puff := Kit.puff_mesh()
	t.check("F: the dust puff is one opaque surface of park sand", _within_budget(puff, Kit.SHARD_TRIANGLE_BUDGET) and _law_mesh(puff) == "", _law_mesh(puff))
	t.check("F: an unknown family falls back to a scrap plate, never to nothing", Kit.triangle_count(Kit.shard_mesh("glass")) > 0, "")


# ---- the colour law -----------------------------------------------------------------------------

func _painted(color: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_color(color)
	for corner in [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 0, 0)]:
		tool.set_normal(Vector3.BACK)
		tool.add_vertex(corner)
	tool.index()
	return tool.commit()


func _colour_law_controls() -> void:
	var mat := Kit.material()
	t.eq("F: the kit's one material is opaque vertex colour with no emission", _law_material(mat), "")
	t.check("F: the material casts the same alpha, mode and glow on every read", mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(mat.albedo_color.a, 1.0) and not mat.emission_enabled and mat.vertex_color_use_as_albedo, "")
	# Planted: an alpha-faded material of every kind must fail the same predicate.
	var faded := Kit.material()
	faded.albedo_color.a = 0.5
	t.check("F control: an albedo alpha of 0.5 fails the law", _law_material(faded) != "", _law_material(faded))
	var alpha := Kit.material()
	alpha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	t.check("F control: TRANSPARENCY_ALPHA fails the law", _law_material(alpha) != "", _law_material(alpha))
	var scissor := Kit.material()
	scissor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	t.check("F control: an alpha-scissor shard fails the law", _law_material(scissor) != "", "")
	var glow := Kit.material()
	glow.emission_enabled = true
	t.check("F control: an emissive surface fails the law", _law_material(glow) != "", _law_material(glow))
	var plain := Kit.material()
	plain.vertex_color_use_as_albedo = false
	t.check("F control: a material that ignores vertex colour fails the law", _law_material(plain) != "", "")
	t.check("F control: no material fails the law", _law_material(null) != "", "")
	# Planted: a vertex painted any forbidden hue fails, and a faded vertex colour fails.
	for name in Kit.FORBIDDEN:
		var why := _law_mesh(_painted(Kit.FORBIDDEN[name]))
		t.check("F control: a vertex painted %s fails the colour law" % name, why != "", why)
	t.check("F control: a faded vertex colour fails the colour law", _law_mesh(_painted(Color(Palette.SAND.r, Palette.SAND.g, Palette.SAND.b, 0.5))) != "", "")
	t.check("F control: a mesh with no vertex colour fails the colour law", _law_mesh(BoxMesh.new()) != "", "")
	# The palette the kit paints with sits clear of every signal hue by the stated margin.
	for color in [Palette.SAND, Palette.SANDSTONE, Palette.RUST, Palette.CHARCOAL, Kit.CONCRETE]:
		for name in Kit.FORBIDDEN:
			t.check("F: %s keeps clear of %s" % [color.to_html(false), name], Kit.color_distance(color, Kit.FORBIDDEN[name]) >= Kit.MIN_FORBIDDEN_DISTANCE,
				"%.3f" % Kit.color_distance(color, Kit.FORBIDDEN[name]))


# ---- sounds -------------------------------------------------------------------------------------

func _sounds() -> void:
	var seen := {}
	for id in Kit.sfx_ids():
		t.check("F: %s resolves in the audio bank" % id, SfxBank.has_recipe(id) and SfxBank.plays_own(id) and SfxBank.TRIM_DB.has(id), "")
		var wav := SfxBank.stream(id)
		var peak := Synth.wav_peak(wav)
		var seconds := wav.data.size() / 2.0 / wav.mix_rate
		t.check("F: %s renders a non-silent clip under 0.6 s" % id, peak >= 0.1 and seconds > 0.1 and seconds < 0.6, "peak %.3f, %.3f s" % [peak, seconds])
		t.check("F: %s is not the fallback blip" % id, SfxBank.samples(id).size() != int(0.12 * SfxBank.RATE), "")
		var key := "%d:%.4f" % [SfxBank.samples(id).size(), peak]
		t.check("F: %s sounds unlike the other families" % id, not seen.has(key), key)
		seen[key] = true
	for tier in range(1, 6):
		t.check("F: tier %d breaks with %s" % [tier, Kit.sfx_id(tier)], Kit.sfx_id(tier) in Kit.sfx_ids(), "")
	t.eq("F: the four families are the four ids", Kit.sfx_ids(), ["destructible_wood", "destructible_scrap", "destructible_masonry", "destructible_steel"])
	t.check("F control: an id with no row does not resolve", not SfxBank.has_recipe("destructible_glass"), "")


func _rows(count: int, tier_of: Callable) -> Array:
	var rows: Array = []
	for i in count:
		var tier: int = tier_of.call(i)
		rows.append({"id": "p%02d" % i, "tier": tier, "at": Vector3(float(i % 5) * 6.0, SIZES[tier].y * 0.5, float(i / 5) * 6.0), "size": SIZES[tier]})
	return rows


func _ctx(extra: Dictionary = {}) -> Dictionary:
	var ctx := {"root": root, "cruise": CRUISE, "run_seed": 7, "run_id": "bot-9", "stage": 1, "refused": func(_at: Vector3) -> void: pass}
	ctx.merge(extra, true)
	return ctx


func _make(rows: Array, extra: Dictionary = {}) -> Node3D:
	var mod: Node3D = Destructibles.new()
	mod.build(rows, _ctx(extra))
	mod.finish_build()
	mod.set_process(false)
	return mod


func _module_sounds() -> void:
	var heard: Array[String] = []
	var mod := _make(_rows(5, func(i: int) -> int: return i + 1), {"sfx": func(id: String, _at: Vector3) -> void: heard.append(id)})
	mod.on_blast(Vector3(12.0, 2.0, 3.0), 60.0, "test", 1, 5)
	var want: Array[String] = ["destructible_wood", "destructible_scrap", "destructible_masonry", "destructible_steel", "destructible_steel"]
	var got := heard.duplicate()
	got.sort()
	want.sort()
	t.eq("F: a break of each tier plays its family's sound", got, want)
	t.eq("F: every piece broke", mod.intact_count(), 0)
	mod.queue_free()

	var audio := FakeAudio.new()
	var wired := _make(_rows(2, func(i: int) -> int: return i + 1), {"presentation": {"audio": audio}})
	wired.on_blast(Vector3(3.0, 2.0, 0.0), 60.0, "test", 1, 5)
	t.check("F: the game's audio plays the family sound when no sfx key is given", audio.heard.size() == 2 and "destructible_wood" in audio.heard and "destructible_scrap" in audio.heard, str(audio.heard))
	wired.queue_free()

	var quiet_heard: Array[String] = []
	var quiet := _make(_rows(3, func(i: int) -> int: return i + 1), {"no_visuals": true, "sfx": func(id: String, _at: Vector3) -> void: quiet_heard.append(id)})
	quiet.on_blast(Vector3(6.0, 2.0, 0.0), 60.0, "test", 1, 5)
	t.check("F: --bot-no-visuals=1 breaks the pieces and plays nothing", quiet.intact_count() == 0 and quiet_heard.is_empty(), str(quiet_heard))
	quiet.queue_free()

	var silent := _make(_rows(2, func(i: int) -> int: return i + 1))
	silent.on_blast(Vector3(3.0, 2.0, 0.0), 60.0, "test", 1, 5)
	t.eq("F control: with no sound wired the break is silent and still breaks", silent.intact_count(), 0)
	silent.queue_free()
	t.check("F control: a break below the tier plays nothing", _silent_under_tier(), "")


func _silent_under_tier() -> bool:
	var heard: Array[String] = []
	var mod := _make(_rows(1, func(_i: int) -> int: return 3), {"sfx": func(id: String, _at: Vector3) -> void: heard.append(id)})
	mod.on_blast(Vector3(0.0, 2.0, 0.0), 60.0, "test", 1, 1)
	var ok: bool = heard.is_empty() and mod.intact_count() == 1
	mod.queue_free()
	return ok


# ---- build: everything warm before the first break ------------------------------------------------

func _build_warmth() -> void:
	var rows := _rows(20, func(i: int) -> int: return (i % 5) + 1)
	var mod := _make(rows)
	var mat: StandardMaterial3D = mod.material()
	t.eq("F: the build leaves the one material opaque", _law_material(mat), "")
	var pieces := 0
	var shared := true
	var one_draw := true
	var meshes := {}
	for child in mod.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Intact_"):
			var node := child as MeshInstance3D
			pieces += 1
			shared = shared and node.material_override == mat
			one_draw = one_draw and node.mesh != null and node.mesh.get_surface_count() == 1
			meshes[node.mesh] = true
	t.eq("F: every intact piece has its mesh before the first break", pieces, 20)
	t.check("F: every piece shares the one material and draws once", shared and one_draw, "")
	t.eq("F: a tier and size share one mesh, so 20 pieces build five meshes", meshes.size(), 5)
	var pool_ok := true
	for node in mod.pool_nodes():
		pool_ok = pool_ok and node.mesh != null and node.material_override == mat
	t.check("F: the shard and puff pool is built, meshed and on the one material", pool_ok and mod.pool_nodes().size() == Destructibles.SHARD_POOL + Destructibles.PUFF_POOL, "%d nodes" % mod.pool_nodes().size())
	var families := {}
	for node in mod.pool_nodes():
		families[node.mesh] = true
	t.check("F: the pool holds a shard mesh and a puff mesh built ahead of any break", families.size() >= 2, "%d meshes" % families.size())
	mod.queue_free()
	# The sliced build reaches the same state.
	var sliced := Destructibles.new()
	sliced.build(rows, _ctx())
	t.check("F: the sliced build has queued its meshes behind the colliders", not sliced.is_built(), "")
	sliced.finish_build()
	t.check("F: the sliced build finishes", sliced.is_built(), "")
	sliced.queue_free()


# ---- cost ---------------------------------------------------------------------------------------

# Mean milliseconds a call takes over `ticks` physics ticks.
func _mean_ms(ticks: int, call: Callable) -> float:
	var total := 0
	for i in ticks:
		var start := Time.get_ticks_usec()
		call.call(i)
		total += Time.get_ticks_usec() - start
	return float(total) / float(ticks) / 1000.0


func _tick_cost() -> void:
	# Twenty intact pieces on the Mac Studio, a ball weaving through them at a speed under every bar, so
	# each tick scans and the cue-bump path runs: the worst a tick costs with nothing breaking.
	var mod := _make(_rows(20, func(i: int) -> int: return (i % 4) + 2))
	var x := -6.0
	var ball_tick := func(i: int) -> void:
		x += 6.0 * DT
		mod.on_ball(Vector3(x, 1.0, 3.0 + sin(float(i) * 0.1) * 2.0), Vector3(6.0, 0.0, 0.0), 1, DT)
	var warm := _mean_ms(30, ball_tick)
	var mean := _mean_ms(200, ball_tick)
	print("F: fixture tick, 20 intact pieces, 200 ticks: mean %.4f ms (warm-up %.4f ms), cap %.1f ms" % [mean, warm, TICK_CAP_MS])
	t.check("F: the fixture tick over 20 intact pieces costs at most %.1f ms (%.4f ms)" % [TICK_CAP_MS, mean], mean <= TICK_CAP_MS, "%.4f ms" % mean)
	t.eq("F: nothing broke on the under-tier tick run", mod.intact_count(), 20)
	var slow := _mean_ms(20, func(_i: int) -> void: OS.delay_usec(700))
	t.check("F control: a 0.7 ms tick fails the cap", slow > TICK_CAP_MS, "%.3f ms" % slow)
	mod.queue_free()


func _frame_ok(ms: float) -> bool:
	return ms < FRAME_CAP_MS


func _break_frame() -> void:
	# Twenty breaks, each the ball arriving at its piece heavy enough and fast enough: the tick that breaks
	# it, then the frame's effect step. Their worst is the CPU side of the break frame.
	var rows := _rows(20, func(i: int) -> int: return (i % 5) + 1)
	var mod := _make(rows)
	var worst := 0.0
	var total := 0.0
	var broke := 0
	for i in 20:
		var id := "p%02d" % i
		var box: AABB = mod.bounds_of(id)
		var at := Vector3(box.position.x - 2.5, 1.0, box.get_center().z)
		mod.on_ball(at - Vector3(0.3, 0.0, 0.0), Vector3(15.0, 0.0, 0.0), 5, DT)
		var start := Time.get_ticks_usec()
		mod.on_ball(at, Vector3(15.0, 0.0, 0.0), 5, DT)
		mod._process(DT)
		var ms := float(Time.get_ticks_usec() - start) / 1000.0
		if mod.state_of(id) == "shattered":
			broke += 1
			worst = maxf(worst, ms)
			total += ms
	var mean := total / maxf(float(broke), 1.0)
	print("F: break frame (CPU: the break tick plus the effect step), %d breaks: mean %.4f ms, worst %.4f ms, Mac Studio 60 Hz frame %.1f ms" % [broke, mean, worst, FRAME_CAP_MS])
	t.eq("F: every ball arrival broke its piece", broke, 20)
	t.check("F: the worst break frame is under one 60 Hz frame (%.4f ms of %.1f ms)" % [worst, FRAME_CAP_MS], _frame_ok(worst), "%.4f ms" % worst)
	t.check("F: the mean break adds at most %.1f ms to a tick (%.4f ms)" % [TICK_CAP_MS, mean], mean <= TICK_CAP_MS, "%.4f ms" % mean)
	t.check("F control: a 20 ms break frame fails the 60 Hz cap", not _frame_ok(20.0), "")
	mod.queue_free()


# ---- nothing is allocated at the break, nothing outlives the stage -------------------------------------

func _nodes_back(base: float) -> bool:
	return Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == base


func _leaks() -> void:
	await process_frame
	var base_nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mod := _make(_rows(20, func(i: int) -> int: return (i % 5) + 1))
	var resources_before: float = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var mat: StandardMaterial3D = mod.material()
	mod.on_blast(Vector3(12.0, 2.0, 12.0), 80.0, "test", 1, 5)
	for i in 120:
		mod._process(DT)
	var resources_after: float = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	t.eq("F: breaking 20 pieces allocates no resource, mesh, material or shader", resources_after, resources_before)
	t.check("F: the one material is the same object after the breaks and still opaque", mod.material() == mat and _law_material(mat) == "", "")
	t.eq("F: every shard is done inside two seconds", mod.live_shards() + mod.live_puffs(), 0)
	var opaque_through := true
	var shrinks := false
	var again := _make(_rows(1, func(_i: int) -> int: return 2))
	again.on_blast(Vector3(0.0, 2.0, 0.0), 60.0, "test", 1, 5)
	for i in 30:
		again._process(DT)
		for node in again.pool_nodes():
			if node.visible:
				shrinks = shrinks or node.scale.x < 1.0
				opaque_through = opaque_through and node.material_override == again.material() and _law_material(again.material()) == "" and node.scale.x >= EnemyMotion.SPECK - 0.0001
	t.check("F: a live shard shrinks toward SPECK on an opaque material and never fades", shrinks and opaque_through, "")
	again.queue_free()
	mod.queue_free()
	await process_frame
	await process_frame
	t.check("F: freeing the stage frees every body, mesh and shard", _nodes_back(base_nodes), "")
	t.eq("F: no orphan node is left", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 0.0)
	# Planted: the same count check sees a leaked node.
	var leaked := Node3D.new()
	root.add_child(leaked)
	t.check("F control: a leaked node fails the node count", not _nodes_back(base_nodes), "")
	leaked.free()


# ---- the GPU frame, when the run has a window -----------------------------------------------------

func _gpu_frame() -> void:
	if DisplayServer.get_name() == "headless":
		t.skip("F: GPU break frame and the alpha-fade stall", "headless run: NEEDS: gpu, measure windowed on the Mac Studio and the 4080")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var camera := Camera3D.new()
	camera.position = Vector3(12.0, 9.0, 22.0)
	root.add_child(camera)
	camera.look_at(Vector3(12.0, 2.0, 6.0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	root.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	ground.position = Vector3(12.0, 0.0, 6.0)
	root.add_child(ground)
	var mod := _make(_rows(20, func(i: int) -> int: return (i % 5) + 1))
	mod.set_process(true)
	for i in 60:
		await process_frame
	var frame_ms: Array[float] = []
	var last := Time.get_ticks_usec()
	mod.on_blast(Vector3(12.0, 2.0, 6.0), 80.0, "test", 1, 5)
	for i in 30:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
	var worst := 0.0
	for ms in frame_ms:
		worst = maxf(worst, ms)
	print("F: windowed break frames on %s: worst %.3f ms over 30 frames after 20 breaks, 60 Hz frame %.1f ms" % [DisplayServer.get_name(), worst, FRAME_CAP_MS])
	t.check("F: the windowed break frame stays inside one 60 Hz frame (%.3f ms)" % worst, _frame_ok(worst), "%.3f ms" % worst)
	mod.queue_free()
	await process_frame
	# Planted alpha-fade variant: the same break on a shard material the renderer has not drawn yet. Printed, not
	# asserted: a shader stall depends on the driver, and the opaque material is what the module ships.
	var stalled := _make(_rows(20, func(i: int) -> int: return (i % 5) + 1))
	var fade := Kit.material()
	fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade.albedo_color.a = 0.5
	for node in stalled.pool_nodes():
		node.material_override = fade
	stalled.set_process(true)
	await process_frame
	var fade_worst := 0.0
	last = Time.get_ticks_usec()
	stalled.on_blast(Vector3(12.0, 2.0, 6.0), 80.0, "test", 1, 5)
	for i in 30:
		await process_frame
		var now := Time.get_ticks_usec()
		fade_worst = maxf(fade_worst, float(now - last) / 1000.0)
		last = now
	print("F: planted alpha-fade shard variant, first break frames: worst %.3f ms against the opaque %.3f ms" % [fade_worst, worst])
	t.check("F control: the alpha-fade variant fails the colour law the opaque shard passes", _law_material(fade) != "" and _law_material(Kit.material()) == "", "")
	stalled.queue_free()
	camera.queue_free()
	light.queue_free()
	ground.queue_free()
	await process_frame
