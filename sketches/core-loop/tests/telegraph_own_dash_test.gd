extends SceneTree

const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# UA-02: the player's own rings (AMBER) tell themselves from a hostile ring by shape alone
# (Andrew, 13 Nov 2026: keep the colours, add shapes). A hostile edge is solid, a harmless bone
# field is a dashed ring, so the player's own edge is dashed at its own, tighter rhythm.
#   - in each of the five looks the own edge has gaps, and its dash period is under the bone ring's;
#   - a hostile edge has no gaps, and the bone ring's period is DASH;
#   - the own fill keeps its alpha (AREA_ALPHA, SHELL_AREA_ALPHA; halved by the edges look).

var _t := T.new("telegraph_own_dash_test")

const SAMPLES := 1440


func _initialize() -> void:
	_run.call_deferred()


func _ring(tone: Color, r := 6.0) -> Dictionary:
	return {"type": Threat.Type.INSTANT, "tone": tone, "centre": Vector3.ZERO, "reach": 3.5, "progress": 0.0, "live": false,
		"form": "radial", "r_in": 0.0, "r_out": r, "a0": 0.0, "a1": TAU}


func _shell(tone: Color) -> Dictionary:
	var d := _ring(tone, 3.0)
	d["type"] = Threat.Type.PROJECTILE
	return d


func _lane(tone: Color) -> Dictionary:
	return {"type": Threat.Type.LANE, "tone": tone, "centre": Vector3.ZERO, "reach": 3.5, "progress": 0.0, "live": false,
		"form": "lane", "dir": Vector3.FORWARD, "back": 0.0, "length": 20.0, "half_width": 3.0}


static func _mark(d: Dictionary, role: String) -> Dictionary:
	for m in Threat.marks(d, false):
		if m["role"] == role:
			return m
	return {}


static func _inside(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var d1 := (p.x - b.x) * (a.z - b.z) - (a.x - b.x) * (p.z - b.z)
	var d2 := (p.x - c.x) * (b.z - c.z) - (b.x - c.x) * (p.z - c.z)
	var d3 := (p.x - a.x) * (c.z - a.z) - (c.x - a.x) * (p.z - a.z)
	return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))


# For each sample point, whether the mark's triangles cover it.
static func _covered(tris: PackedVector3Array, points: Array) -> Array:
	var out := []
	for p in points:
		var hit := false
		for i in range(0, tris.size() - 2, 3):
			if _inside(p, tris[i], tris[i + 1], tris[i + 2]):
				hit = true
				break
		out.append(hit)
	return out


# Dashes counted round a closed ring: covered runs, wrapping.
static func _runs(covered: Array) -> int:
	var n := 0
	for i in covered.size():
		if covered[i] and not covered[(i + covered.size() - 1) % covered.size()]:
			n += 1
	return n


static func _share(covered: Array) -> float:
	var n := 0
	for c in covered:
		if c:
			n += 1
	return float(n) / maxf(1.0, covered.size())


# Points along the ring's outer edge, mid-width.
static func _ring_points(d: Dictionary) -> Array:
	var r: float = float(d["r_out"]) - Threat.outline_width(d) * 0.5
	var out := []
	for i in SAMPLES:
		var a := TAU * (i + 0.5) / SAMPLES
		out.append(Vector3(cos(a), 0.0, sin(a)) * r)
	return out


# Metres of edge per dash round a ring.
func _period(d: Dictionary, role: String) -> float:
	var covered := _covered(_mark(d, role)["tris"], _ring_points(d))
	var runs := _runs(covered)
	if runs == 0:
		return INF
	return TAU * (float(d["r_out"]) - Threat.outline_width(d) * 0.5) / runs


func _run() -> void:
	var bone := _period(_ring(Palette.SAND), "outline")
	_t.check("the bone ring is dashed at DASH (%.2f m)" % bone, absf(bone - Threat.DASH) < 0.4)
	var counted := 0
	for look in Threat.LOOKS:
		Threat.set_look(look)
		counted += 1
		var own := _ring(Palette.AMBER)
		var covered := _covered(_mark(own, "edge")["tris"], _ring_points(own))
		var share := _share(covered)
		_t.check("%s: the player's own ring edge has gaps (covers %.2f)" % [look, share], share > 0.3 and share < 0.8)
		var period := _period(own, "edge")
		_t.check("%s: its dash period (%.2f m) is under the bone ring's (%.2f m)" % [look, period, bone], period < bone * 0.6)
		var hostile := _ring(Palette.HAZARD)
		var solid := _share(_covered(_mark(hostile, "edge")["tris"], _ring_points(hostile)))
		_t.check("%s: a hostile ring edge is not dashed (covers %.2f)" % [look, solid], solid > 0.99)
		var shell := _shell(Palette.AMBER)
		var shell_share := _share(_covered(_mark(shell, "edge")["tris"], _ring_points(shell)))
		_t.check("%s: the player's own shell ring has gaps (covers %.2f)" % [look, shell_share], shell_share > 0.3 and shell_share < 0.8)
		var lane := _lane(Palette.AMBER)
		var rail := []
		for i in 200:
			rail.append(Threat._lane_at(lane, 16.0 * (i + 0.5) / 200.0, 3.0))
		var lane_share := _share(_covered(_mark(lane, "edge")["tris"], rail))
		_t.check("%s: the player's own lane rail has gaps (covers %.2f)" % [look, lane_share], lane_share > 0.3 and lane_share < 0.8)
		var hostile_lane := _lane(Palette.HAZARD)
		var hostile_rail := _share(_covered(_mark(hostile_lane, "edge")["tris"], rail))
		_t.check("%s: a hostile lane rail is solid (covers %.2f)" % [look, hostile_rail], hostile_rail > 0.99)
		var fill := 0.1 * (Threat.EDGES_FILL if look == "edges" else 1.0)
		_t.near("%s: the own ring's fill alpha is unchanged" % look, _mark(own, "area")["tone"].a, fill)
		var shell_fill := Threat.SHELL_AREA_ALPHA * (Threat.EDGES_FILL if look == "edges" else 1.0)
		_t.near("%s: the own shell's fill alpha is unchanged" % look, _mark(shell, "area")["tone"].a, shell_fill)
	_t.eq("all five looks were checked", counted, 5)
	Threat.set_look("tape")
	quit(_t.verdict())
