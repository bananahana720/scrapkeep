extends RefCounted

# Flat distance from a point to a ParkMap.fight_sites() site, 0 inside it: a footprint site ("half", "yaw_deg") is a
# rotated rectangle read as ParkMap.footprint_contains reads it; a ring site ("ring": inner, outer) is the band of
# distance from its "at". Shared by the breathing and rhythm map checks.
static func distance(site: Dictionary, p: Vector2) -> float:
	var at: Vector2 = site["at"]
	if site.has("ring"):
		var ring: Vector2 = site["ring"]
		var d := p.distance_to(at)
		return maxf(0.0, maxf(ring.x - d, d - ring.y))
	var local := (p - at).rotated(deg_to_rad(float(site["yaw_deg"])))
	var half: Vector2 = site["half"]
	return Vector2(maxf(0.0, absf(local.x) - half.x), maxf(0.0, absf(local.y) - half.y)).length()


# Distance to the nearest site, INF for none.
static func nearest(sites: Array, p: Vector2) -> float:
	var best := INF
	for site in sites:
		best = minf(best, distance(site, p))
	return best
