extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const Meanings := preload("res://src/core/colour_meanings.gd")
const Palette := preload("res://src/core/palette.gd")
const ShopTile := preload("res://src/ui/shop_tile.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

const FLOOR := 20.0
const SIGHTS := {
	"normal": [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	"protan": [Vector3(0.152286, 1.052583, -0.204868), Vector3(0.114503, 0.786281, 0.099216), Vector3(-0.003882, -0.048116, 1.051998)],
	"deutan": [Vector3(0.367322, 0.860646, -0.227968), Vector3(0.280085, 0.672501, 0.047413), Vector3(-0.011820, 0.042940, 0.968881)],
	"tritan": [Vector3(1.255528, -0.076749, -0.178779), Vector3(-0.078411, 0.930809, 0.147602), Vector3(0.004733, 0.691367, 0.303900)],
}
const CLOSE := {
	"AMBER|BRASS": {"carrier": "a relic reward's frame is doubled with bolt heads (shop_tile.gd RARITY) and its gate topper is a prism where a boss fact never is (reward_gates.gd); Brindle's ground warnings carry brass rim ticks (hazard.gd, threat_grammar.gd); Brindle's caller plate uses fleet hand frame and fac_fleet icon in brass (caller_tile.gd); all checked below. An event toast in either colour relies on its words", "finding": ""},
	"AMBER|HAZARD": {"carrier": "a relic reward is a doubled bolt-headed frame or a prism topper, the cost strike on a shop tile is one diagonal line, and the pilot's danger mark is a diamond with a bang; relic is never drawn as a ground fill; on the ground the player's own ring has a dashed edge every OWN_DASH metres in every look where a hostile ring's edge is solid", "finding": ""},
	"BRASS|HAZARD": {"carrier": "Brindle's ground warning is a danger-toned warning plus brass rim ticks in every look (threat_grammar.gd, checked below); Brindle's caller plate is brass on a fleet hand frame with fac_fleet icon and no caller uses HAZARD (caller_tile.gd, checked below); boss_attack_telegraphed and attack_cued use chevron where danger events event_announced and event_started use wave (event_kinds.gd, checked below); a boss's body and badge are brass solids where danger is a ground fill", "finding": "UF-03: hostile floor telegraph default look stays clear rather than striped; the tape cover measure is done (27 Nov, Mac Metal: same marks, alphas and cover as clear) and the flip waits on Painter.warm_keys() in threat_grammar.gd listing the striped unclassed mark, which threat_grammar_test fails without under tape"},
	"ANCIENT|ARC": {"carrier": "ancient seams carry a pattern cue (material_slots.gd, the pattern field)", "finding": ""},
}
const SHARED := {
	"ARC": {"carrier": "the common reward is a flat slab gate topper (reward_gates.gd, checked below), and on a screen its frame is the one single-line frame on a tile and steel, not mint (shop_tile.gd RARITY, checked below); live is drawn on an enemy part, the rogue's weak point and the miniboss's core, or a key, never in a frame or on a gate", "finding": ""},
}

var _t := T.new("colour_cvd_test")


func _initialize() -> void:
	var palette: Dictionary = (Palette as GDScript).get_script_constant_map()
	var facts := {}
	for table in [Meanings.MEANINGS, Meanings.REWARD_RUNGS]:
		for fact in table:
			facts[fact] = table[fact]
	var colours := {}
	for fact in facts:
		colours[facts[fact]] = true
	_t.check("the meanings name seven or more colours", colours.size() >= 7, str(colours.size()))
	_t.eq("every close pair and shared colour has a row, and every row is still needed", faults(facts, palette, CLOSE, SHARED), [])
	var fake := {"A": Color("9dff3c"), "B": Color("a5f548"), "C": Color("0000ff")}
	var planted := faults({"one": "A", "two": "B", "three": "A", "four": "C"}, fake, {"A|C": {"carrier": "", "finding": ""}}, {})
	_t.eq("planted: the judge names four faults", planted.size(), 4)
	for want in ["A|B is close", "A carries one and three", "the CLOSE row A|C no longer", "the row A|C names neither"]:
		_t.check("planted: one fault reads \"%s\"" % want, planted.any(func(line: String) -> bool: return line.begins_with(want)))
	_t.check("planted: red and blue are not close", closest(Color("ff0000"), Color("0000ff"))["de"] >= FLOOR)
	_t.eq("every reward rung has a frame", frame_faults(Meanings.REWARD_RUNGS.keys(), ShopTile.RARITY), [])
	_t.check("the common reward is the one single-line frame", _single_lines(ShopTile.RARITY) == ["common"], str(_single_lines(ShopTile.RARITY)))
	var common_de: float = closest(ShopTile.RARITY["common"]["color"], Palette.ARC)["de"]
	_t.check("the common frame on a screen is told from mint, which is press now, by every eye", common_de >= FLOOR, "%.1f" % common_de)
	_t.check("no reward frame on a screen is mint", ShopTile.RARITY.values().all(func(row): return row["color"] != Palette.ARC))
	var sable_worst := INF
	var sable_nearest := ""
	for cname in colours:
		var hit: Dictionary = closest(ClassDef.SABLE_SCREEN, palette[cname])
		if float(hit["de"]) < sable_worst:
			sable_worst = float(hit["de"])
			sable_nearest = "%s (%s)" % [cname, hit["sight"]]
	_t.check("Sable's screen accent is told from every meaning colour by every eye", sable_worst >= FLOOR,
		"%.1f vs %s" % [sable_worst, sable_nearest])
	_t.eq("the relic reward's frame carries bolt heads", ShopTile.RARITY["relic"]["notches"], "bolt")
	var boss_hazard := _hazard(Palette.BRASS)
	var plain_hazard := _hazard(Palette.HAZARD)
	_t.check("a brass-owned hazard draws brass rim ticks on a danger-toned warning", _owner_mark(boss_hazard.descriptor()).get("tone") == Color(Palette.BRASS, 1.0) and boss_hazard.descriptor()["tone"] == Palette.HAZARD)
	_t.check("a plain danger hazard draws no rim ticks", _owner_mark(plain_hazard.descriptor()).is_empty())
	boss_hazard.free()
	plain_hazard.free()
	var brindle_caller: Dictionary = CallerTile.CALLERS.get("brindle", {})
	_t.check("Brindle's caller plate is brass on a fleet frame with fac_fleet icon",
		brindle_caller.get("color") == Palette.BRASS and String(brindle_caller.get("hands", "")) == "fleet" and String(brindle_caller.get("icon", "")) == "fac_fleet",
		str(brindle_caller))
	var hazard_callers := CallerTile.CALLERS.keys().filter(func(id): return CallerTile.CALLERS[id].get("color") == Palette.HAZARD)
	_t.eq("no caller tile uses danger HAZARD colour", hazard_callers, [])
	_t.check("boss cue rows differ in shape from hazard event rows",
		String(EventKinds.ROWS["boss_attack_telegraphed"]["shape"]) != String(EventKinds.ROWS["event_announced"]["shape"])
		and String(EventKinds.ROWS["attack_cued"]["shape"]) != String(EventKinds.ROWS["event_started"]["shape"]),
		"boss=%s/%s event=%s/%s" % [EventKinds.ROWS["boss_attack_telegraphed"]["shape"], EventKinds.ROWS["attack_cued"]["shape"],
			EventKinds.ROWS["event_announced"]["shape"], EventKinds.ROWS["event_started"]["shape"]])
	var ring := {"type": Threat.Type.INSTANT, "centre": Vector3.ZERO, "reach": 3.5, "progress": 0.0, "live": false,
		"form": "radial", "r_in": 0.0, "r_out": 6.0, "a0": 0.0, "a1": TAU}
	var own_area := _edge_area(ring.merged({"tone": Palette.AMBER}))
	var hostile_area := _edge_area(ring.merged({"tone": Palette.HAZARD}))
	_t.check("the player's own ring edge is dashed where a hostile ring's is solid (%.2f against %.2f m2)" % [own_area, hostile_area],
		hostile_area > 0.0 and own_area > 0.0 and own_area < hostile_area * 0.8)
	var shapes := {}
	for rung in ["common", "rare", "relic"]:
		var topper: MeshInstance3D = RewardGates._topper(rung, null)
		shapes[rung] = topper.mesh.get_class()
		topper.free()
	_t.eq("the gate topper is a slab for common and a prism for rare and relic", shapes, {"common": "BoxMesh", "rare": "PrismMesh", "relic": "PrismMesh"})
	var twins := {"a": {"color": Color.RED, "width": 2.0, "double": false, "notches": "", "dashed": false},
		"b": {"color": Color.BLUE, "width": 2.0, "double": false, "notches": "", "dashed": false}}
	_t.eq("planted: two frames that differ only by colour are named", frame_faults(["a", "b", "c"], twins), ["a and b differ by colour alone", "c has no frame"])
	quit(_t.verdict())


func _hazard(colour: Color) -> Node3D:
	var h: Node3D = Hazard.new()
	h.ground = func(_p: Vector3) -> float: return 0.0
	h.color = colour
	h.commit_annulus("cvd_test", Threat.Type.INSTANT, Vector3(60.0, 0.0, -90.0), Vector2(8.0, 14.0), 1.8, 2.5, 6.0)
	return h


func _owner_mark(d: Dictionary) -> Dictionary:
	for m in Threat.all_marks(d):
		if m["role"] == "owner":
			return m
	return {}


static func faults(facts: Dictionary, palette: Dictionary, close_rows: Dictionary, shared_rows: Dictionary) -> Array:
	var out := []
	var uses := {}
	for fact in facts:
		uses[facts[fact]] = uses.get(facts[fact], []) + [fact]
	var names := uses.keys()
	names.sort()
	var close := {}
	for i in names.size():
		for j in range(i + 1, names.size()):
			var worst := closest(palette[names[i]], palette[names[j]])
			if worst["de"] < FLOOR:
				close["%s|%s" % [names[i], names[j]]] = worst
	for key in close:
		if not close_rows.has(key):
			out.append("%s is close (%s %.1f) and has no CLOSE row" % [key, close[key]["sight"], close[key]["de"]])
	for name in names:
		if uses[name].size() > 1 and not shared_rows.has(name):
			out.append("%s carries %s and has no SHARED row" % [name, " and ".join(uses[name])])
	for key in close_rows:
		if not close.has(key):
			out.append("the CLOSE row %s no longer names a close pair: delete it" % key)
	for key in shared_rows:
		if uses.get(key, []).size() < 2:
			out.append("the SHARED row %s no longer names a colour with two facts: delete it" % key)
	for rows in [close_rows, shared_rows]:
		for key in rows:
			if rows[key]["carrier"] == "" and rows[key]["finding"] == "":
				out.append("the row %s names neither a carrier nor a finding" % key)
	return out


static func frame_faults(rungs: Array, frames: Dictionary) -> Array:
	var out := []
	var have := []
	for rung in rungs:
		if frames.has(rung):
			have.append(rung)
	for i in have.size():
		for j in range(i + 1, have.size()):
			if _shape(frames[have[i]]) == _shape(frames[have[j]]):
				out.append("%s and %s differ by colour alone" % [have[i], have[j]])
	for rung in rungs:
		if not frames.has(rung):
			out.append("%s has no frame" % rung)
	return out


static func _shape(frame: Dictionary) -> Array:
	return [frame["width"], frame["double"], frame["notches"], frame["dashed"]]


static func _single_lines(frames: Dictionary) -> Array:
	var out := []
	for rung in frames:
		if not frames[rung]["double"]:
			out.append(rung)
	return out


static func closest(a: Color, b: Color) -> Dictionary:
	var out := {"sight": "", "de": INF}
	for sight in SIGHTS:
		var de := _lab(_see(a, SIGHTS[sight])).distance_to(_lab(_see(b, SIGHTS[sight])))
		if de < out["de"]:
			out = {"sight": sight, "de": de}
	return out


static func _see(c: Color, m: Array) -> Vector3:
	var l := c.srgb_to_linear()
	var v := Vector3(l.r, l.g, l.b)
	return Vector3(clampf(m[0].dot(v), 0.0, 1.0), clampf(m[1].dot(v), 0.0, 1.0), clampf(m[2].dot(v), 0.0, 1.0))


static func _lab(v: Vector3) -> Vector3:
	var x := _f((0.4124 * v.x + 0.3576 * v.y + 0.1805 * v.z) / 0.95047)
	var y := _f(0.2126 * v.x + 0.7152 * v.y + 0.0722 * v.z)
	var z := _f((0.0193 * v.x + 0.1192 * v.y + 0.9505 * v.z) / 1.08883)
	return Vector3(116.0 * y - 16.0, 500.0 * (x - y), 200.0 * (y - z))


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


func _edge_area(d: Dictionary) -> float:
	var area := 0.0
	for m in Threat.marks(d, false):
		if m["role"] == "edge":
			var tris: PackedVector3Array = m["tris"]
			for i in range(0, tris.size() - 2, 3):
				area += absf((tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i]).y) * 0.5
	return area
