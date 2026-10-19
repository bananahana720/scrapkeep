extends SceneTree

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# Ambient life colour law (ambient_kinds.gd): lilac means "harmless and alive". (a) every record colour is in the life band
# or a declared accent that is neutral or in band; (b) every built ambient GLB paints only band or neutral colours, at most
# NEUTRAL_SHARE neutral, and carries no emission; (c) no enemy, Warden or boss model paints a saturated colour in the band
# plus a 10 degree margin; (d) every record colour sits at least MIN_GAP CIE76 from the hazard, amber, arc, ancient, brass,
# rust and copper colours that carry a verb or a threat. Colours are vertex colour (linear in the GLB, so converted to sRGB
# the way the other asset tests do) times the material albedo.

const MIN_V := 0.12
const MIN_GAP := 25.0
const ENEMY_MARGIN := 10.0
const ENEMY_CLASSES := ["enemy", "warden_base", "warden_kit"]
const SKIP := ["/companion/", "camp_pet"]
const REGISTRY := "res://assets/registry.json"
const BOSS_DIR := "res://assets/models/bosses/"

var _t := T.new("ambient_palette_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _run() -> void:
	_record()
	_ambient_models()
	_enemy_side()
	_reserved_gap()


# --- (a) the record ---------------------------------------------------------------------------------------------------

func _record() -> void:
	var colours := 0
	for id in AmbientKinds.KINDS:
		var palette: Dictionary = AmbientKinds.KINDS[id].palette
		for name in palette:
			var c: Color = palette[name]
			colours += 1
			if AmbientKinds.ACCENTS.has(name):
				_t.check("%s %s accent is neutral or in band" % [id, name],
					AmbientKinds.is_neutral(c) or AmbientKinds.in_band(c), _describe(c))
			else:
				_t.check("%s %s is in the life band" % [id, name], AmbientKinds.in_band(c), _describe(c))
	_t.check("the record was read", colours > 0, "%d palette colours" % colours)


# --- (b) every built ambient GLB --------------------------------------------------------------------------------------

func _ambient_models() -> void:
	var built := 0
	for id in AmbientKinds.KINDS:
		var path: String = AmbientKinds.KINDS[id].model
		if not ResourceLoader.exists(path):
			continue
		built += 1
		var sample := _sample(path)
		_t.check("%s has painted vertices" % id, sample.total > 0, "%d vertices" % sample.total)
		var outside := 0
		var neutral := 0
		for key in sample.counts:
			var c := _from_key(key)
			if c.s < AmbientKinds.NEUTRAL_SAT:
				neutral += sample.counts[key]
			elif not AmbientKinds.in_band(c):
				outside += sample.counts[key]
				_t.check("%s colour %s is in the life band" % [id, c.to_html(false)], false, _describe(c))
		_t.eq("%s has no vertex colour outside the life band" % id, outside, 0)
		var share: float = float(neutral) / maxf(1.0, float(sample.total))
		_t.check("%s neutral share is within %.0f%%" % [id, AmbientKinds.NEUTRAL_SHARE * 100.0],
			share <= AmbientKinds.NEUTRAL_SHARE, "%.1f%% of %d vertices" % [share * 100.0, sample.total])
		_t.eq("%s has no emissive material" % id, sample.emissive, 0)
	print("ambient models read: %d of %d kinds" % [built, AmbientKinds.KINDS.size()])


# --- (c) the enemy side -----------------------------------------------------------------------------------------------

func _enemy_side() -> void:
	var paths := {}
	var registry = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	_t.check("the registry parses", registry is Dictionary and registry.has("assets"))
	for row in registry["assets"]:
		if ENEMY_CLASSES.has(row["class"]) and String(row["path"]).ends_with(".glb"):
			paths[row["path"]] = true
	for file in DirAccess.get_files_at(BOSS_DIR):
		if file.get_extension() == "glb":
			paths[BOSS_DIR + file] = true
	var lo: float = AmbientKinds.LIFE_HUE.x - ENEMY_MARGIN
	var hi: float = AmbientKinds.LIFE_HUE.y + ENEMY_MARGIN
	var checked := 0
	var colours := 0
	var nearest := 999.0
	var names := paths.keys()
	names.sort()
	for path: String in names:
		var skip := false
		for token: String in SKIP:
			skip = skip or path.contains(token)
		if skip or not ResourceLoader.exists(path):
			continue
		checked += 1
		var sample := _sample(path)
		var bad := []
		for key in sample.counts:
			var c := _from_key(key)
			colours += 1
			if c.s >= AmbientKinds.NEUTRAL_SAT:
				var hue := c.h * 360.0
				if hue >= lo and hue <= hi:
					bad.append(c.to_html(false) + " hue %.0f" % hue)
				else:
					nearest = minf(nearest, minf(absf(hue - lo), absf(hue - hi)))
		_t.check("%s paints nothing saturated in %.0f to %.0f degrees" % [path.get_file(), lo, hi], bad.is_empty(),
			"%d colours%s" % [sample.counts.size(), "" if bad.is_empty() else ", in band: " + ", ".join(bad)])
	_t.check("enemy-side models were read", checked > 20, "%d models, %d distinct colours" % [checked, colours])
	print("enemy side: nearest saturated hue is %.0f degrees outside %.0f to %.0f" % [nearest, lo, hi])


# --- (d) reserved colours ---------------------------------------------------------------------------------------------

func _reserved_gap() -> void:
	var reserved := {"HAZARD": Palette.HAZARD, "AMBER": Palette.AMBER, "ARC": Palette.ARC, "ANCIENT": Palette.ANCIENT,
		"BRASS": Palette.BRASS, "RUST": Palette.RUST, "COPPER": Palette.COPPER}
	var worst := 999.0
	for id in AmbientKinds.KINDS:
		var palette: Dictionary = AmbientKinds.KINDS[id].palette
		for name in palette:
			var c: Color = palette[name]
			var nearest := 999.0
			var which := ""
			for label in reserved:
				var d := _cie76(c, reserved[label])
				if d < nearest:
					nearest = d
					which = label
			worst = minf(worst, nearest)
			_t.check("%s %s is clear of the verb and threat colours" % [id, name], nearest >= MIN_GAP,
				"%s is %.1f from %s (floor %.0f)" % [c.to_html(false), nearest, which, MIN_GAP])
	print("reserved colours: closest record colour is %.1f CIE76" % worst)


# --- sampling ---------------------------------------------------------------------------------------------------------

# Every distinct vertex colour (vertex colour as sRGB times the surface material's albedo, 8 bits a channel) with its
# vertex count, ignoring near-black (v < MIN_V). `emissive` counts materials with emission on.
func _sample(path: String) -> Dictionary:
	var counts := {}
	var total := 0
	var emissive := 0
	var packed := load(path) as PackedScene
	if packed == null:
		return {"counts": counts, "total": 0, "emissive": 0}
	var node := packed.instantiate()
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var albedo := Color.WHITE
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null:
				albedo = mat.albedo_color
				if mat.emission_enabled:
					emissive += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var colours = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				var base := (colours[i] as Color).linear_to_srgb() if colours != null else Color.WHITE
				var c := Color(base.r * albedo.r, base.g * albedo.g, base.b * albedo.b)
				if c.v < MIN_V:
					continue
				total += 1
				var key := c.to_rgba32() >> 8
				counts[key] = counts.get(key, 0) + 1
	node.free()
	return {"counts": counts, "total": total, "emissive": emissive}


static func _from_key(key: int) -> Color:
	return Color.hex((key << 8) | 0xff)


static func _describe(c: Color) -> String:
	return "%s hue %.0f sat %.2f" % [c.to_html(false), c.h * 360.0, c.s]


static func _cie76(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


static func _lab(c: Color) -> Vector3:
	var r := _linear(c.r)
	var g := _linear(c.g)
	var b := _linear(c.b)
	var x := (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
	var y := r * 0.2126729 + g * 0.7151522 + b * 0.0721750
	var z := (b * 0.9503041 + g * 0.1191920 + r * 0.0193339) / 1.08883
	return Vector3(116.0 * _f(y) - 16.0, 500.0 * (_f(x) - _f(y)), 200.0 * (_f(y) - _f(z)))


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
