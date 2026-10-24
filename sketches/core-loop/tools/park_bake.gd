extends SceneTree

# The park bake (design-v3/PARK.md section 3, K-UNITS KB3): reads a park file, applies each
# row's stamp in order (src/world/park/park_stamps.gd), and writes assets/park/<map_id>/:
#
#   ground.bin   801 by 801 heights at 2 m over -800..800, float32, row-major (z, then x), zstd
#   apron.bin    the 1 m heights of the four 1024 m regions (-1024..1023) outside the play square,
#                row-major, skipping every point with |x| and |z| both at most 800, float32, zstd
#   holes.bin    800 by 800 bytes, one per 2 m cell, 1 under a `hole` row's footprint
#   under.bin    float32 per hole cell in holes.bin order: the floor beneath. No recipe has a
#                collision mesh yet (the K-C families), so it is the ground's own height at the
#                cell centre and bake.json counts these as under_fallback
#   surface.bin  800 by 800 bytes, one per 2 m cell: the material slot of the last stamp row whose
#                footprint holds the cell centre (park_stamps.gd SURFACE_SLOTS), sand elsewhere
#   bake.json    schema, map, the park file's sha256, the bake tool's sha256, grid, height range,
#                cell counts and each output file's sha256
#
# Two bakes of one file give identical bytes. freshness() is what park_bake_fresh_test reads.
#
#   godot --headless --path sketches/core-loop --script res://tools/park_bake.gd -- --map=park_test

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")

const BAKE_SCHEMA := "scrapkeep-park-bake/1"
const TOOL_FILES := ["res://tools/park_bake.gd", "res://src/world/park/park_stamps.gd"]
const PARK_DIR := "res://src/world/park"
const OUT_DIR := "res://assets/park"

const HALF := 800.0
const STEP := 2.0
const CELLS := 800
const SIDE := 801
const APRON_HALF := 1024
const APRON_SIDE := 2048
const OUTPUTS := ["ground.bin", "apron.bin", "holes.bin", "under.bin", "surface.bin"]
# A park whose square stands high on a mesa (park_dam's floor is 100 to 150 m at the square's edge, over a 0 m apron)
# gets a rim in its apron instead of a straight 150 m wall: the square's edge height carries out level to a lip whose
# distance (lip_m) wanders along the edge and across it (warp_m), then falls over fall_m as a cliff and talus to the
# apron's own floor (its stamps, faded in over the fall); low dunes (dune_m) break the level shelf, and a few buttes
# stand off the foot of the fall. The apron is drawn, never collided (park_terrain.gd), so no line or post feels it.
# Seeded, so a rebake is byte-identical.
# lip_m and fall_m together stay inside the 224 m between the square and the region's edge, so the floor meets the
# Terrain3D flat background at 0 m.
const APRON_RIMS := {
	"park_dam": {"seed": 1871, "lip_m": [6.0, 100.0], "fall_m": [55.0, 95.0], "warp_m": 34.0, "dune_m": 2.5,
		"buttes": 11, "butte_r_m": [24.0, 48.0], "butte_h_m": [22.0, 70.0]},
}


func _initialize() -> void:
	var map_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	if map_id.is_empty():
		printerr("park_bake: pass --map=<map_id>")
		quit(2)
		return
	var result := bake("%s/%s.json" % [PARK_DIR, map_id], "%s/%s" % [OUT_DIR, map_id])
	if not result["ok"]:
		printerr("park_bake: %s" % "\n".join(result["errors"]))
		quit(1)
		return
	var info: Dictionary = result["info"]
	print("park_bake: %s -> %s/%s heights %.2f..%.2f, %d hole cells" % [map_id, OUT_DIR, map_id,
		float(info["height"]["min"]), float(info["height"]["max"]), int(info["cells"]["holes"])])
	quit(0)


# Bakes park_path into out_dir. Returns {"ok", "errors", "info"} with info the bake.json content.
static func bake(park_path: String, out_dir: String) -> Dictionary:
	var read := ParkSchema.load_park(park_path)
	if not read["errors"].is_empty():
		return {"ok": false, "errors": ["%s fails the park schema: %s" % [park_path, ParkSchema.describe(read["errors"])]], "info": {}}
	var park: Dictionary = read["data"]
	var rows: Array = park["park_rows"]

	var ground := PackedFloat32Array()
	ground.resize(SIDE * SIDE)
	var apron := PackedFloat32Array()
	apron.resize(APRON_SIDE * APRON_SIDE)
	for row in rows:
		if String(row["stamp"]).is_empty():
			continue
		var f := Stamps.frame(row)
		var box := Stamps.bounds(f)
		_stamp_ground(ground, f, box)
		_stamp_apron(apron, f, box)
	if APRON_RIMS.has(String(park["map"])):
		_rim_apron(apron, ground, APRON_RIMS[String(park["map"])])

	var holes := PackedByteArray()
	holes.resize(CELLS * CELLS)
	var surface := PackedByteArray()
	surface.resize(CELLS * CELLS)
	surface.fill(Stamps.SURFACE_DEFAULT)
	for row in rows:
		var f := Stamps.frame(row)
		var box := Stamps.bounds(f)
		var paints := not String(row["stamp"]).is_empty()
		var slot := Stamps.surface_slot(String(row["landform"]))
		if not paints and not bool(row["hole"]):
			continue
		var j0 := maxi(0, ceili((box[1] + HALF) / STEP - 0.5))
		var j1 := mini(CELLS - 1, floori((box[3] + HALF) / STEP - 0.5))
		var i0 := maxi(0, ceili((box[0] + HALF) / STEP - 0.5))
		var i1 := mini(CELLS - 1, floori((box[2] + HALF) / STEP - 0.5))
		for j in range(j0, j1 + 1):
			var z := -HALF + STEP * j + 1.0
			for i in range(i0, i1 + 1):
				var x := -HALF + STEP * i + 1.0
				if paints and slot >= 0 and Stamps.inside(f, x, z):
					surface[j * CELLS + i] = slot
				if row["hole"] and Stamps.inside(f, x, z):
					holes[j * CELLS + i] = 1

	var under := PackedFloat32Array()
	var surface_counts := {}
	for name in Stamps.SURFACE_SLOTS:
		surface_counts[name] = 0
	for j in CELLS:
		for i in CELLS:
			var k := j * CELLS + i
			surface_counts[Stamps.SURFACE_SLOTS[surface[k]]] += 1
			if holes[k] == 1:
				under.append(_cell_centre_height(ground, i, j))

	var ring := PackedFloat32Array()
	var lo := INF
	var hi := -INF
	for j in APRON_SIDE:
		var z := -APRON_HALF + j
		var line := apron.slice(j * APRON_SIDE, (j + 1) * APRON_SIDE)
		if absi(z) > int(HALF):
			ring.append_array(line)
		else:
			ring.append_array(line.slice(0, APRON_HALF - int(HALF)))
			ring.append_array(line.slice(APRON_HALF + int(HALF) + 1))
	for value in ground:
		lo = minf(lo, value)
		hi = maxf(hi, value)
	for value in ring:
		lo = minf(lo, value)
		hi = maxf(hi, value)

	DirAccess.make_dir_recursive_absolute(out_dir)
	var errors := []
	errors.append_array(_write(out_dir + "/ground.bin", ground.to_byte_array(), true))
	errors.append_array(_write(out_dir + "/apron.bin", ring.to_byte_array(), true))
	errors.append_array(_write(out_dir + "/holes.bin", holes, false))
	errors.append_array(_write(out_dir + "/under.bin", under.to_byte_array(), false))
	errors.append_array(_write(out_dir + "/surface.bin", surface, false))
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "info": {}}

	var files := {}
	for name in OUTPUTS:
		files[name] = FileAccess.get_sha256(out_dir + "/" + name)
	var info := {
		"schema": BAKE_SCHEMA,
		"map": String(park["map"]),
		"park_sha256": FileAccess.get_sha256(park_path),
		"tool_sha256": tool_sha256(),
		"grid": {"step_m": STEP, "half_m": HALF, "side": SIDE, "cells": CELLS,
			"apron_step_m": 1.0, "apron_half_m": APRON_HALF, "region_size": 1024,
			"regions": [[-1, -1], [0, -1], [-1, 0], [0, 0]]},
		"height": {"min": lo, "max": hi},
		"cells": {"ground": SIDE * SIDE, "apron": ring.size(), "holes": under.size(),
			"under_fallback": under.size(), "surface": surface_counts},
		"files": files,
	}
	errors = _write(out_dir + "/bake.json", (JSON.stringify(info, "  ", true) + "\n").to_utf8_buffer(), false)
	return {"ok": errors.is_empty(), "errors": errors, "info": info}


# What makes the bake in bake_dir stale for park_path; empty means fresh.
static func freshness(park_path: String, bake_dir: String) -> Array:
	var json_path := bake_dir + "/bake.json"
	if not FileAccess.file_exists(json_path):
		return ["%s missing: run tools/park_bake.gd" % json_path]
	var info = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not info is Dictionary:
		return ["%s does not parse" % json_path]
	var stale := []
	if info.get("schema") != BAKE_SCHEMA:
		stale.append("schema: %s, want %s" % [info.get("schema"), BAKE_SCHEMA])
	var park_sha := FileAccess.get_sha256(park_path)
	if info.get("park_sha256") != park_sha:
		stale.append("park_sha256: bake has %s, %s is %s; rebake" % [info.get("park_sha256"), park_path, park_sha])
	var tool_sha := tool_sha256()
	if info.get("tool_sha256") != tool_sha:
		stale.append("tool_sha256: bake has %s, the tool is %s; rebake" % [info.get("tool_sha256"), tool_sha])
	var files: Dictionary = info.get("files", {})
	for name in OUTPUTS:
		var got := FileAccess.get_sha256(bake_dir + "/" + name)
		if got.is_empty() or files.get(name) != got:
			stale.append("%s: bake.json has %s, the file is %s" % [name, files.get(name), got])
	return stale


# sha256 over the bake tool and the stamps it calls, so a stamp change makes every bake stale.
static func tool_sha256() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in TOOL_FILES:
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


static func _stamp_ground(ground: PackedFloat32Array, f: Dictionary, box: Array) -> void:
	var i0 := maxi(0, ceili((box[0] + HALF) / STEP))
	var i1 := mini(CELLS, floori((box[2] + HALF) / STEP))
	var j0 := maxi(0, ceili((box[1] + HALF) / STEP))
	var j1 := mini(CELLS, floori((box[3] + HALF) / STEP))
	for j in range(j0, j1 + 1):
		var z := -HALF + STEP * j
		for i in range(i0, i1 + 1):
			ground[j * SIDE + i] += Stamps.offset(f, -HALF + STEP * i, z)


# The apron ring only: points inside the play square come from the 2 m grid at load.
static func _stamp_apron(apron: PackedFloat32Array, f: Dictionary, box: Array) -> void:
	var i0 := maxi(0, ceili(box[0] + APRON_HALF))
	var i1 := mini(APRON_SIDE - 1, floori(box[2] + APRON_HALF))
	var j0 := maxi(0, ceili(box[1] + APRON_HALF))
	var j1 := mini(APRON_SIDE - 1, floori(box[3] + APRON_HALF))
	var inner_lo := APRON_HALF - int(HALF)
	var inner_hi := APRON_HALF + int(HALF)
	for j in range(j0, j1 + 1):
		var z := float(j - APRON_HALF)
		var in_band := j >= inner_lo and j <= inner_hi
		for i in range(i0, i1 + 1):
			if in_band and i >= inner_lo and i <= inner_hi:
				continue
			apron[j * APRON_SIDE + i] += Stamps.offset(f, float(i - APRON_HALF), z)


# The ground at a cell's centre on the two triangles terrain.gd's collider and _grid_height use.
static func _cell_centre_height(ground: PackedFloat32Array, i: int, j: int) -> float:
	var b := ground[j * SIDE + i + 1]
	var c := ground[(j + 1) * SIDE + i]
	return (b + c) * 0.5


static func _write(path: String, bytes: PackedByteArray, compressed: bool) -> Array:
	var file: FileAccess
	if compressed:
		file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ["cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())]]
	file.store_buffer(bytes)
	file.close()
	return []


# Shapes the apron ring of a mesa park (APRON_RIMS). A ring point d metres outside the square (to the nearest square
# point, whose ground height e it carries) stands at e out to the lip and falls to the floor over the fall; the
# stamps' own offsets fade in over the fall, since e already holds them at the edge. Lip and fall widths come from
# noise read at the nearest square point, so they wander along the edge; a second noise warps d itself, so bays and
# spurs cut across the lip.
static func _rim_apron(apron: PackedFloat32Array, ground: PackedFloat32Array, rim: Dictionary) -> void:
	var seed := int(rim["seed"])
	var along := _rim_noise(seed, 1.0 / 220.0)
	var wide := _rim_noise(seed + 1, 1.0 / 90.0)
	var warp := _rim_noise(seed + 2, 1.0 / 75.0)
	var dune := _rim_noise(seed + 3, 1.0 / 38.0)
	var lip: Array = rim["lip_m"]
	var fall: Array = rim["fall_m"]
	var warp_m := float(rim["warp_m"])
	var dune_m := float(rim["dune_m"])
	var buttes := _rim_buttes(rim)
	for j in APRON_SIDE:
		var z := float(j - APRON_HALF)
		for i in APRON_SIDE:
			var x := float(i - APRON_HALF)
			if absf(x) <= HALF and absf(z) <= HALF:
				continue
			var cx := clampf(x, -HALF, HALF)
			var cz := clampf(z, -HALF, HALF)
			var e := _edge_height(ground, cx, cz)
			var d := Vector2(x - cx, z - cz).length()
			var bend := smoothstep(0.0, 30.0, d)
			var dw := d + warp_m * warp.get_noise_2d(x, z) * bend
			var l := lerpf(float(lip[0]), float(lip[1]), along.get_noise_2d(cx, cz) * 0.5 + 0.5)
			var w := lerpf(float(fall[0]), float(fall[1]), wide.get_noise_2d(cx, cz) * 0.5 + 0.5)
			var t := clampf((dw - l) / w, 0.0, 1.0)
			# A cliff at the lip easing to a talus foot: steep first (the strata texture), level last.
			var h := e * pow(1.0 - t, 1.7)
			h += dune_m * dune.get_noise_2d(x, z) * bend * (1.0 - t)
			for b: Dictionary in buttes:
				var r := Vector2(x, z).distance_to(b["at"])
				h = maxf(h, float(b["h"]) * (1.0 - smoothstep(float(b["r"]) * 0.55, float(b["r"]), r)))
			# e already holds the stamps at the edge, so a stamp's own apron offset comes in only as the rim falls away.
			var k := j * APRON_SIDE + i
			apron[k] = h + apron[k] * t


static func _rim_noise(seed: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = 3
	return n


# The square's ground at (x, z) on its edge, read bilinearly from the 2 m grid.
static func _edge_height(ground: PackedFloat32Array, x: float, z: float) -> float:
	var fi := clampf((x + HALF) / STEP, 0.0, float(CELLS))
	var fj := clampf((z + HALF) / STEP, 0.0, float(CELLS))
	var i0 := mini(int(fi), CELLS - 1)
	var j0 := mini(int(fj), CELLS - 1)
	var u := fi - i0
	var v := fj - j0
	var a := lerpf(ground[j0 * SIDE + i0], ground[j0 * SIDE + i0 + 1], u)
	var b := lerpf(ground[(j0 + 1) * SIDE + i0], ground[(j0 + 1) * SIDE + i0 + 1], u)
	return lerpf(a, b, v)


# Buttes off the foot of the fall: centres at least 100 m out from the square, each wholly inside the region's edge,
# from the rim's seed; each a rounded mesa, full height over its inner 55 percent.
static func _rim_buttes(rim: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rim["seed"])
	var r_range: Array = rim["butte_r_m"]
	var h_range: Array = rim["butte_h_m"]
	var out := []
	for k in int(rim["buttes"]):
		var r := rng.randf_range(float(r_range[0]), float(r_range[1]))
		var side := rng.randi() % 4
		var run := rng.randf_range(-HALF - 120.0, HALF + 120.0)
		var out_m := rng.randf_range(HALF + 100.0, APRON_HALF - r - 4.0)
		var at := Vector2(run, out_m)
		match side:
			1: at = Vector2(run, -out_m)
			2: at = Vector2(out_m, run)
			3: at = Vector2(-out_m, run)
		out.append({"at": at, "r": r, "h": rng.randf_range(float(h_range[0]), float(h_range[1]))})
	return out
