extends SceneTree

const Game := preload("res://src/game.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const Interactables := preload("res://src/world/interactables.gd")
const EventDirector := preload("res://src/world/event_director.gd")

# Zone 1-1 joins the Weir's halfpipe, relay mesa and causeway to the Spillway's
# existing fall line. Sample actual built ground, not just feature declarations:
# lips stay inside x [-74, -50], z [-140, -82] and within 25 m of the line;
# the relay remains an optional site with a downhill return; the causeway is a
# raised, continuous 14 m-wide span. Authored approach joins have at most 1 m of
# height change per horizontal metre (45 degrees), excluding transverse pipe
# walls and the pre-existing shelf risers. The existing route test independently
# checks the full physics sightline, bowl banking and pillar-count contract.
# Evidence limit: geometry and reader integration, not Andrew's hands or feel.

const MAX_JOIN_SLOPE := 1.0
var _game
var _wait := 0
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	if _wait < 3:
		return false
	var terrain = _game.ctx.terrain
	terrain.use(1)
	var map = terrain.map()
	_report("same map readers", map.get_script() == Spillway and _game.ctx.stages.of(1)["map"] == "spillway",
		"stage 1 resolves the rebuilt map under spillway")
	_check_pieces(terrain, map)
	_check_route(terrain, map)
	_check_joins(terrain)
	print("spillway_zone_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _check_pieces(terrain, map) -> void:
	var envelope := Rect2(-74.0, -140.0, 24.0, 58.0)
	var bounds_ok: bool = Spillway.PIPE_X - Spillway.PIPE_DEPTH >= envelope.position.x \
		and Spillway.PIPE_X + Spillway.PIPE_DEPTH <= envelope.end.x \
		and Spillway.PIPE_Z.x - Spillway.PIPE_DEPTH >= envelope.position.y \
		and Spillway.PIPE_Z.y <= envelope.end.y
	var off := 0.0
	for p in [envelope.position, envelope.end, Vector2(envelope.position.x, envelope.end.y), Vector2(envelope.end.x, envelope.position.y)]:
		off = maxf(off, map.off_line(p))
	var floor_h: float = terrain.height(-62.0, -118.0)
	var lip_h: float = minf(terrain.height(-74.0, -118.0), terrain.height(-50.0, -118.0))
	_report("halfpipe lips within fall line", bounds_ok and off <= 25.0 and lip_h - floor_h >= 6.0,
		"x [-74,-50], z [-140,-82], %.2f m off line; floor %.2f, lip %.2f" % [off, floor_h, lip_h])
	_report("halfpipe concrete", map.material_at(-62.0, -118.0) == "concrete", "the carved pump channel presents concrete")
	var relay: Dictionary = map.sites.get("hold_the_relay", {})
	var mesa_h: float = terrain.height(10.0, -84.0)
	_report("relay mesa carries its site", relay.get("ring") == Vector2(10.0, -84.0) \
		and relay.get("relay") == relay.get("ring") and mesa_h >= 39.0,
		"relay at (10,-84), built top %.2f m; 18 m top and 40 m foot radii" % mesa_h)
	var director := EventDirector.new(77, _game.ctx.stages.of(1), map, 16.0, terrain.height)
	var relay_offer := false
	for offer in director.offers:
		if offer["id"] == "hold_the_relay":
			var ring: Vector2 = offer["model"].ring
			relay_offer = ring == Vector2(10.0, -84.0) and absf(offer["model"]._relay_y - mesa_h) <= 0.05
	_report("relay event reader", relay_offer, "the unchanged stage-1 table offers the relay on its built mesa through unique_events")
	var span_ok := true
	var worst := 0.0
	for z in range(-100, -59, 2):
		var expected: float = Spillway._bypass_deck(float(z)) + 6.0
		for x in [-100.0, -94.0, -88.0]:
			worst = maxf(worst, absf(terrain.height(x, float(z)) - expected))
			span_ok = span_ok and map.material_at(x, float(z)) == "concrete"
	_report("causeway raised span", span_ok and worst <= 0.05,
		"14 m flat width, z [-100,-60], deck 6 m above bypass profile; error %.3f m" % worst)
	_report("old Spillway content", map.spawn == Vector2(-62.0, -160.0) and map.beacon == Vector2(-46.0, -12.0) \
		and map.vault == Vector2(-5.0, -130.0) and map.sites.has("scrap_stampede") \
		and map.unique_events.has("scrap_stampede") and map.basin["centre"] == Vector2(0.0, 110.0) \
		and Spillway.CHUTES.size() == 4 and Interactables.PLACEMENTS["spillway"].size() == 3,
		"spawn, beacon, vault, stampede, basin, four chutes and three device placements remain")


func _check_route(terrain, map) -> void:
	var a: Vector2 = map.spawn
	var b: Vector2 = map.beacon
	var high: float = terrain.height(a.x, a.y)
	var low: float = terrain.height(b.x, b.y)
	var sight_ok := true
	for i in 149:
		var t := float(i) / 148.0
		var p := a.lerp(b, t)
		var sight_h := lerpf(high + 16.0, low + 18.0, t)
		sight_ok = sight_ok and terrain.height(p.x, p.y) < sight_h
	var scrap_off := 0.0
	for line in map.scrap_lines:
		for p in line:
			scrap_off = maxf(scrap_off, map.off_line(p))
	_report("spawn-to-beacon contract", high > low and sight_ok and scrap_off <= 25.0 and not map.scrap_lines.is_empty(),
		"spawn %.2f > beacon %.2f; clear ground sightline; scrap %.2f m off line" % [high, low, scrap_off])
	for id in map.sites.keys() + ["vault"]:
		var site: Vector2 = map.vault if id == "vault" else map.sites[id]["ring"]
		var back := _return_to_line(terrain, map, site)
		_report("optional %s downhill return" % id, map.off_line(site) >= 40.0 and back["ok"], back["detail"])
	var banked := 0
	for r in [32.0, 36.0, 40.0, 44.0]:
		for i in 36:
			var dir := Vector2.from_angle(i * TAU / 36.0)
			var inner: Vector2 = b + dir * (r - 2.0)
			var outer: Vector2 = b + dir * (r + 2.0)
			if (terrain.height(outer.x, outer.y) - terrain.height(inner.x, inner.y)) / 4.0 >= tan(deg_to_rad(20.0)):
				banked += 1
	_report("beacon bank", banked >= 72, "%d/144 ring samples bank at least 20 degrees; half required" % banked)


func _return_to_line(terrain, map, site: Vector2) -> Dictionary:
	var h0: float = terrain.height(site.x, site.y)
	var a: Vector2 = map.spawn
	var b: Vector2 = map.beacon
	var s := clampf((site - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	var target := Vector2.INF
	while s <= 1.0:
		var p := a.lerp(b, s)
		if terrain.height(p.x, p.y) < h0 - 3.0:
			target = p
			break
		s += 2.0 / (b - a).length()
	if target == Vector2.INF:
		return {"ok": false, "detail": "no return at least 3 m downhill"}
	var climb := 0.0
	var steps := maxi(1, ceili(site.distance_to(target)))
	for i in steps + 1:
		var p := site.lerp(target, float(i) / steps)
		climb = maxf(climb, terrain.height(p.x, p.y) - h0)
	return {"ok": climb <= 1.5, "detail": "%.2f m off line; return to %s climbs %.2f m of 1.5 allowed" % [map.off_line(site), target, climb]}


func _check_joins(terrain) -> void:
	var paths := {
		"drop deck to pipe head": [Vector2(-62.0, -148.0), Vector2(-62.0, -118.0)],
		"pipe tail to west chute": [Vector2(-62.0, -118.0), Vector2(-62.0, -78.0)],
		"causeway entry": [Vector2(-94.0, -146.0), Vector2(-94.0, -100.0)],
		"causeway across riser": [Vector2(-94.0, -100.0), Vector2(-94.0, -60.0)],
		"causeway exit to beacon bowl": [Vector2(-94.0, -60.0), Vector2(-70.0, -12.0)],
		"relay shoulder to pipe entrance": [Vector2(10.0, -84.0), Vector2(-50.0, -140.0)],
	}
	for label in paths:
		var a: Vector2 = paths[label][0]
		var b: Vector2 = paths[label][1]
		var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
		var spacing := a.distance_to(b) / steps
		var prior: float = terrain.height(a.x, a.y)
		var worst := 0.0
		for i in range(1, steps + 1):
			var p := a.lerp(b, float(i) / steps)
			var h: float = terrain.height(p.x, p.y)
			worst = maxf(worst, absf(h - prior) / spacing)
			prior = h
		_report(label + " continuous", worst <= MAX_JOIN_SLOPE,
			"%s to %s; worst rise/run %.3f, limit %.1f (45 degrees), every 0.5 m" % [a, b, worst, MAX_JOIN_SLOPE])
