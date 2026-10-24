extends SceneTree
# The dam's mesa rim (tools/park_bake.gd APRON_RIMS; 4080 park stills, acb55972: the square's 100 to 150 m edge stood
# as one straight wall over a flat 0 m apron). Read from the committed bake:
# (a) one metre outside the square the apron meets the square's edge height (no wall);
# (b) the lip wanders: where the rim first falls below half its edge height, sampled every 20 m round the square,
#     spreads over at least LIP_SPREAD_M (standard deviation), so the edge is no straight line;
# (c) the apron is back near the 0 m floor at the region's edge, where Terrain3D's flat background takes over;
# (d) a park without a rim row bakes its apron byte for byte as before (the flume's, pinned at stage acb55972).
# Evidence limit: bake data only; the look is in the stills.

const T := preload("res://tests/support/t.gd")
const Bake := preload("res://tools/park_bake.gd")

const HALF := 800
const APRON_HALF := 1024
const APRON_SIDE := 2048
const SIDE := 801
const SEAM_M := 3.0
const LIP_SPREAD_M := 12.0
const FLOOR_M := 12.0
const FLUME_APRON_SHA := "fc34a864773de34858a3716431eb549959aa5e1b46c170b46fdc3849f745b94a"

var _t := T.new("park_apron_rim_test")


func _initialize() -> void:
	call_deferred("_run")


func _read(path: String, n: int) -> PackedFloat32Array:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var out := f.get_buffer(n * 4).to_float32_array()
	f.close()
	return out


# The full 2048 x 2048 apron (inside the square left at 0) from the ring the bake writes.
func _apron(map: String) -> PackedFloat32Array:
	var ring := _read("res://assets/park/%s/apron.bin" % map, APRON_SIDE * APRON_SIDE - (HALF * 2 + 1) * (HALF * 2 + 1))
	var full := PackedFloat32Array()
	full.resize(APRON_SIDE * APRON_SIDE)
	var k := 0
	for j in APRON_SIDE:
		for i in APRON_SIDE:
			if absi(i - APRON_HALF) <= HALF and absi(j - APRON_HALF) <= HALF:
				continue
			full[j * APRON_SIDE + i] = ring[k]
			k += 1
	return full


func _at(apron: PackedFloat32Array, x: int, z: int) -> float:
	return apron[(z + APRON_HALF) * APRON_SIDE + x + APRON_HALF]


func _run() -> void:
	_t.check("the dam has a rim row", Bake.APRON_RIMS.has("park_dam"))
	var apron := _apron("park_dam")
	var ground := _read("res://assets/park/park_dam/ground.bin", SIDE * SIDE)
	var seam := 0.0
	var lips := []
	var outer := 0.0
	for s in range(-HALF, HALF + 1, 20):
		# Each side: the square's edge point, the outward step, and the apron points along the outward line.
		for side in 4:
			var edge := Vector2i(s, -HALF) if side == 0 else (Vector2i(s, HALF) if side == 1 else (Vector2i(-HALF, s) if side == 2 else Vector2i(HALF, s)))
			var step := Vector2i(0, -1) if side == 0 else (Vector2i(0, 1) if side == 1 else (Vector2i(-1, 0) if side == 2 else Vector2i(1, 0)))
			var e := ground[((edge.y + HALF) / 2) * SIDE + (edge.x + HALF) / 2]
			var first := edge + step
			seam = maxf(seam, absf(_at(apron, first.x, first.y) - e))
			var lip := APRON_HALF - HALF
			for d in range(1, APRON_HALF - HALF):
				var p := edge + step * d
				if _at(apron, p.x, p.y) < e * 0.5:
					lip = d
					break
			lips.append(float(lip))
			var last := edge + step * (APRON_HALF - HALF - 1)
			outer = maxf(outer, _at(apron, last.x, last.y))
	var mean := 0.0
	for l: float in lips:
		mean += l
	mean /= lips.size()
	var spread := 0.0
	for l: float in lips:
		spread += (l - mean) * (l - mean)
	spread = sqrt(spread / lips.size())
	_t.check("(a) the apron meets the square's edge within %.0f m" % SEAM_M, seam <= SEAM_M, "worst %.2f m" % seam)
	_t.check("(b) the lip wanders round the square (spread at least %.0f m)" % LIP_SPREAD_M, spread >= LIP_SPREAD_M, "mean %.1f m, spread %.1f m over %d samples" % [mean, spread, lips.size()])
	_t.check("(c) the apron is near the floor at the region's edge", outer <= FLOOR_M, "highest %.1f m" % outer)
	print("park_apron_rim_test: seam %.2f m, lip mean %.1f m spread %.1f m, outer %.1f m" % [seam, mean, spread, outer])
	var flume := FileAccess.get_sha256("res://assets/park/park_flume/apron.bin")
	_t.check("(d) the flume has no rim row and bakes its apron as before the rim", not Bake.APRON_RIMS.has("park_flume") and flume == FLUME_APRON_SHA, flume)
	quit(_t.verdict())
