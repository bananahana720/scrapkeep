extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

const OWNER_OUT := 0.4
const OWNER_HALF := 0.2
const CHEVRON_AHEAD_GAP := 0.3
const BRACKET_HALF_BASE := 0.14
const BRACKET_HALF_PER_M := 0.015
const KEYLINE_EXTRA := 0.08

static var test_pad_scale := 1.0
static var test_skip_hazard_merge := false


static func reset_for_tests() -> void:
	test_pad_scale = 1.0
	test_skip_hazard_merge = false

const GROW := Threat.UNDERLAY

const CHEVRON_PAD := Threat.WAVE_EDGE + CHEVRON_AHEAD_GAP + Threat.CHEVRON_DEPTH + Threat.CHEVRON_LINE + GROW
const LANE_PAD := maxf(Threat.RAIL + GROW, OWNER_OUT + OWNER_HALF + GROW)


const Y_ALLOWANCE := Threat.UNDERLAY

static func mesh_box(node: Node) -> AABB:
	var merged := [AABB(), false]
	_merge(node, merged)
	return merged[0] if merged[1] else AABB()


static func _merge(node: Node, merged: Array) -> void:
	for child in node.get_children():
		if child is Node3D and not child.visible:
			continue
		if child is VisualInstance3D:
			var box: AABB = child.get_aabb()
			if box.size != Vector3.ZERO:
				var world: AABB = child.global_transform * box
				merged[0] = world.merge(merged[0]) if merged[1] else world
				merged[1] = true
		_merge(child, merged)


static func box(d: Dictionary, meshes: AABB) -> AABB:
	if meshes.size == Vector3.ZERO:
		return AABB()
	var c: Vector3 = d["centre"]
	var span := [Vector2(INF, INF), Vector2(-INF, -INF)]
	if d["form"] == "lane":
		var heading: Vector3 = d["dir"]
		var side := Vector3.UP.cross(heading).normalized()
		var half: float = d["half_width"]
		for along in [-float(d["back"]), float(d["length"])]:
			for lateral in [-half, half]:
				var p: Vector3 = c + heading * (along as float) + side * (lateral as float)
				_grow(span, p.x, p.z)
		_pad(span, LANE_PAD)
	elif int(d["type"]) == Threat.Type.PROJECTILE:
		var r: float = d["r_out"]
		var reach_out := maxf(r + _rim_pad(d), Threat.BRACKET_OPEN * r + BRACKET_HALF_BASE + r * BRACKET_HALF_PER_M + GROW)
		_grow(span, c.x - reach_out, c.z - reach_out)
		_grow(span, c.x + reach_out, c.z + reach_out)
	else:
		_sector_span(d, span)
		var pad := _rim_pad(d)
		if int(d["type"]) == Threat.Type.WAVE or int(d["type"]) == Threat.Type.LANE:
			pad = maxf(pad, CHEVRON_PAD)
		_pad(span, pad)
	var lo: Vector2 = span[0]
	var hi: Vector2 = span[1]
	var reach: float = d["reach"]
	var wave := int(d["type"]) == Threat.Type.WAVE
	var up := (reach + Threat.BAND_TOP + GROW) if wave else 0.0
	var y_min := meshes.position.y + (minf(0.0, reach - Threat.BAND_TOP - GROW) if wave else 0.0) - Y_ALLOWANCE
	var y_max := meshes.end.y + up + Y_ALLOWANCE
	var out := AABB(Vector3(lo.x, y_min, lo.y), Vector3(hi.x - lo.x, y_max - y_min, hi.y - lo.y))
	if d.has("launch"):
		out = out.merge(_flight_box(d, c))
	return out


static func _flight_box(d: Dictionary, c: Vector3) -> AABB:
	var launch: Vector3 = d["launch"]
	var bump: float = d["bump"]
	var pad := Threat.DOT_SIZE + KEYLINE_EXTRA
	var lo := Vector3(minf(launch.x, c.x), minf(launch.y, c.y) + minf(0.0, bump * 0.25), minf(launch.z, c.z)) - Vector3.ONE * pad
	var hi := Vector3(maxf(launch.x, c.x), maxf(launch.y, c.y) + maxf(0.0, bump * 0.25), maxf(launch.z, c.z)) + Vector3.ONE * pad
	return AABB(lo, hi - lo)


static func _rim_pad(d: Dictionary) -> float:
	return maxf(maxf(GROW, OWNER_OUT + OWNER_HALF + GROW), Threat.edge_width(d) * 0.5 + GROW)


static func _sector_span(d: Dictionary, span: Array) -> void:
	var c: Vector3 = d["centre"]
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	if Threat.is_full(d):
		_grow(span, c.x - r_out, c.z - r_out)
		_grow(span, c.x + r_out, c.z + r_out)
		return
	for a in [a0, a1]:
		for r in [r_in, r_out]:
			_grow(span, c.x + cos(a) * r, c.z + sin(a) * r)
	var low := minf(a0, a1)
	var high := maxf(a0, a1)
	var k := int(ceil(low / (PI * 0.5)))
	while k * PI * 0.5 <= high:
		var axis := k * PI * 0.5
		_grow(span, c.x + cos(axis) * r_out, c.z + sin(axis) * r_out)
		k += 1


static func _grow(span: Array, x: float, z: float) -> void:
	span[0] = (span[0] as Vector2).min(Vector2(x, z))
	span[1] = (span[1] as Vector2).max(Vector2(x, z))


static func _pad(span: Array, by: float) -> void:
	by *= test_pad_scale
	span[0] = (span[0] as Vector2) - Vector2(by, by)
	span[1] = (span[1] as Vector2) + Vector2(by, by)
