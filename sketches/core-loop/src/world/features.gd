extends RefCounted


static func kicker(x: float, z: float, at: Vector2, dir: Vector2, length: float, width: float, lip: float) -> float:
	var rel := Vector2(x, z) - at
	var u := rel.dot(dir)
	var v := absf(rel.dot(Vector2(-dir.y, dir.x)))
	if u < -length or u > 5.0 or v > width * 0.5 + 4.0:
		return 0.0
	var side := 1.0 - smoothstep(width * 0.5, width * 0.5 + 4.0, v)
	var rise: float
	if u <= 0.0:
		var t := (u + length) / length
		rise = lip * pow(t, 1.6)
	else:
		rise = lip * (1.0 - smoothstep(0.0, 5.0, u))
	return rise * side


static func banked_arc(x: float, z: float, centre: Vector2, radius: float, width: float, bank: float,
		from_deg: float, to_deg: float) -> float:
	var rel := Vector2(x, z) - centre
	var o := rel.length() - radius
	if o < 0.0 or o > width + 10.0:
		return 0.0
	var angle := rad_to_deg(atan2(rel.y, rel.x))
	var span := wrapf(to_deg - from_deg, 0.0, 360.0)
	var into := wrapf(angle - from_deg, 0.0, 360.0)
	if into > span:
		return 0.0
	var ends := smoothstep(0.0, 25.0, into) * smoothstep(0.0, 25.0, span - into)
	var h: float
	if o <= width:
		h = bank * pow(o / width, 2.0)
	else:
		h = bank * (1.0 - smoothstep(width, width + 10.0, o))
	return h * ends


static func halfpipe(x: float, z: float, cx: float, z0: float, z1: float, top: Callable, depth: float,
		fade_out := 0.0) -> float:
	var adx := absf(x - cx)
	var far := z1 if fade_out > 0.0 else z1 + depth
	if adx >= depth or z < z0 - depth or z > far:
		return INF
	var zc := clampf(z, z0, z1)
	var end := z - zc
	var r := sqrt(adx * adx + end * end)
	if r >= depth:
		return INF
	var rise := depth - sqrt(depth * depth - r * r)
	var scale := 1.0
	if fade_out > 0.0:
		scale = 1.0 - smoothstep(z1 - fade_out, z1, zc)
	return float(top.call(zc)) - (depth - rise) * scale


const BOWL_FLAT := 28.0
const BOWL_RIM := 47.0
const BOWL_OUT := 62.0
const BOWL_SLOPE := 0.445


static func bowl_bank(d: float) -> float:
	if d <= BOWL_FLAT:
		return 0.0
	if d <= BOWL_FLAT + 2.0:
		return BOWL_SLOPE * pow(d - BOWL_FLAT, 2.0) / 4.0
	return BOWL_SLOPE * (d - BOWL_FLAT - 1.0)


static func beacon_bowl(x: float, z: float, centre: Vector2, floor_h: float, h: float) -> float:
	var d := Vector2(x, z).distance_to(centre)
	if d >= BOWL_OUT:
		return h
	return lerpf(floor_h + bowl_bank(minf(d, BOWL_RIM)), h, smoothstep(BOWL_RIM, BOWL_OUT, d))


static func mesa(x: float, z: float, centre: Vector2, top_radius: float, foot_radius: float, height: float) -> float:
	var d := Vector2(x, z).distance_to(centre)
	return height * (1.0 - smoothstep(top_radius, foot_radius, d))


static func descent(s: float, s0: float, s1: float, h0: float, h1: float) -> float:
	var t := clampf(inverse_lerp(s0, s1, s), 0.0, 1.0)
	return lerpf(h0, h1, lerpf(t, smoothstep(0.0, 1.0, t), 0.45))


static func rim(x: float, z: float) -> float:
	return 55.0 * smoothstep(162.0, 199.0, maxf(absf(x), absf(z)))


static func ripple(x: float, z: float) -> float:
	return 0.85 * sin(x * 0.055) * cos(z * 0.047) + 0.45 * sin((x + z) * 0.031)
