extends RefCounted


const ICON_DIR := "res://assets/icons/"
const SIZE := 64

const IDS := {
	"cls_sable": "ring_dot", "cls_rivet": "double_chevron", "cls_kest": "star",
	"ab_sable_weapon": "bolt", "ab_sable_move": "hook", "ab_sable_special": "rings", "ab_sable_smash": "smash",
	"ab_sable_vault": "launch", "ab_sable_mount": "turret",
	"ab_rivet_weapon": "barrel", "ab_rivet_move": "double_chevron", "ab_rivet_special": "burst_ring", "ab_rivet_smash": "arrow",
	"ab_kest_weapon": "target", "ab_kest_move": "disc_ring", "ab_kest_special": "lane", "ab_kest_smash": "smash",
	"ab_kest_glide": "wing", "ab_kest_cloak": "wave",
	"key_lmb": "mouse_left", "key_rmb": "mouse_right", "key_f": "square", "key_ctrl": "square", "key_space": "square",
	"key_shift": "square", "key_e": "square", "key_q": "square", "key_r": "square", "key_tab": "square",
	"cat_damage": "triangle", "cat_mobility": "double_chevron", "cat_defense": "shield", "cat_utility": "cross",
	"cat_charge": "pips_3", "cat_transform": "wave",
	"el_frost": "burst", "el_arc": "bolt", "el_kinetic": "disc",
	"trg_on_hit": "target", "trg_on_kill": "cross", "trg_on_smash": "smash", "trg_on_rebound": "chevron",
	"trg_on_vault": "launch", "trg_on_charge_release": "ring", "trg_on_cloak_break": "wave", "trg_on_land": "bar",
	"trg_on_speed_tier_up": "chevron_right", "trg_on_pickup": "hoop", "trg_on_damage_taken": "triangle", "trg_timed": "clock",
	"thr_instant": "disc_ring", "thr_wave": "rings", "thr_projectile": "target", "thr_lane": "lane",
	"obj_beacon": "beacon", "obj_warden": "clamp", "obj_gate": "arch", "obj_fabricator": "hoop", "obj_vault": "vault",
	"obj_event": "wave",
	"res_scrap": "cog", "res_heft": "weight", "res_health": "plus", "res_core": "core", "res_timer": "clock",
	"res_difficulty": "bar",
	"fac_fleet": "tag", "fac_reactor": "weight", "fac_swarm": "triangle", "fac_mind": "ring_dot",
}
const PREFIX_FALLBACK := {"ab_": "ring_dot", "cls_": "diamond", "key_": "square", "cat_": "diamond", "el_": "disc",
	"trg_": "square", "thr_": "triangle", "obj_": "square", "res_": "disc", "fac_": "diamond"}
const REEL := "ab_sable_reel"
const EXTRA := {"ab_sable_reel": "reel", "res_mass": "heap", "ab_tarn_weapon": "chevron", "ab_tarn_move": "hook",
	"cls_tarn": "cross", "cls_tally": "square", "cls_cannon": "lane",
	"ab_tarn_special": "clamp", "ab_tarn_smash": "smash",
	"ab_tally_weapon": "tag", "ab_tally_move": "cog", "ab_tally_special": "reel", "ab_tally_smash": "smash",
	"ab_tally_gather": "target", "ab_tally_link": "bolt", "ab_tally_balance": "burst_ring",
	"ab_cannon_weapon": "lane", "ab_cannon_move": "arrow", "ab_cannon_special": "shield", "ab_cannon_smash": "rings",
	"ab_sable_line": "launch", "ab_sable_ult": "turret",
	"ab_rivet_line": "chevron_right", "ab_rivet_ult": "target",
	"ab_kest_line": "ab_kest_line", "ab_kest_ult": "ab_kest_ult",
	"ab_tarn_line": "hook", "ab_tarn_ult": "cross",
	"ab_tally_line": "hook", "ab_tally_ult": "square",
	"ab_cannon_line": "lane",
	"ab_cannon_ult": "burst_ring",
	"cmp_primer_coil": "bolt", "cmp_primer_mesh": "rings", "cmp_ram_prow": "double_chevron",
	"cmp_ram_spring": "disc_ring", "cmp_escape_vent": "launch", "cmp_escape_rail": "arrow",
	"cmp_cog_scoop": "cog", "cmp_cartridge_caddy": "hoop",
	"el_heat": "burst_ring",
	"cons_scrap_dice": "diamond", "cons_duplicator_spool": "rings", "cons_overload_fuse": "bolt",
	"cons_pocket_belt": "pips_2",
	"act_slag_mortar": "burst", "act_magnet_sling": "hook",
	"obj_scrapper": "cog", "obj_press": "weight", "obj_part_press": "weight",
	"obj_tri_terminal": "pips_3", "res_scrap_ingot": "weight",
	"part_orbital_flywheel": "rings", "rel_alt_loadout": "tag",
	"lic_spillway_works": "tag", "lic_fleet_surplus": "tag", "lic_redjaw": "tag",
	"lic_highdraft_roosts": "tag", "lic_waking": "tag", "lic_mind_glass": "tag", "lic_moss": "tag",
	"cls_patch": "wave", "ab_patch_weapon": "wave", "ab_patch_move": "hook",
	"ab_patch_special": "rings", "ab_patch_smash": "smash", "ab_patch_line": "lane", "ab_patch_ult": "burst_ring",
	"radio_take": "knob",
}

const SHAPES := {"ring": "ring", "diamond": "diamond", "square": "square", "chevron": "chevron", "arrow": "arrow",
	"burst": "burst", "bar": "bar", "star": "star", "cross": "cross", "wave": "wave", "core": "core", "lane": "lane", "none": "disc"}

static var _cache := {}


static var _from_file := {}


static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var loaded := _load_svg(id)
	_from_file[id] = loaded != null
	var tex: Texture2D = loaded if loaded != null else _raster(glyph_of(id))
	_cache[id] = tex
	return tex


static func tint(id: String, color: Color) -> Color:
	texture(id)
	return Color(1.0, 1.0, 1.0, color.a) if _from_file.get(id, false) else color


static func shape(name: String) -> Texture2D:
	var key := "shape:" + name
	if not _cache.has(key):
		_cache[key] = _raster(SHAPES.get(name, "disc"))
	return _cache[key]


static func _static_init() -> void:
	assert(IDS.size() == 70, "Icons.IDS must keep the 70 canonical ids")


static func has(id: String) -> bool:
	return IDS.has(id)


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id in IDS:
		out.append(id)
	return out


static func glyph_of(id: String) -> String:
	if IDS.has(id):
		return IDS[id]
	if EXTRA.has(id):
		return EXTRA[id]
	for prefix in PREFIX_FALLBACK:
		if id.begins_with(prefix):
			return PREFIX_FALLBACK[prefix]
	return "square"


static func from_file(id: String) -> bool:
	texture(id)
	return _from_file.get(id, false)


static func class_icon_id(class_id: String) -> String:
	return "cls_" + {"pylon_engineer": "sable", "runner_gunner": "rivet", "demolitions_caster": "kest",
		"remembered_cannon": "cannon", "line_splicer": "patch"}.get(class_id, class_id)


static func _load_svg(id: String) -> Texture2D:
	var path := ICON_DIR + id + ".svg"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_svg_from_buffer(FileAccess.get_file_as_bytes(path), 1.0) == OK:
			return ImageTexture.create_from_image(image)
	return null


static func _raster(glyph: String) -> ImageTexture:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var p := Vector2((x + 0.5 - half) / half, -(y + 0.5 - half) / half)
			var d := distance(glyph, p)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(0.5 - d * half, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func distance(glyph: String, p: Vector2) -> float:
	match glyph:
		"ring":
			return _ring(p, Vector2.ZERO, 0.6, 0.14)
		"disc":
			return p.length() - 0.6
		"ring_dot":
			return minf(_ring(p, Vector2.ZERO, 0.65, 0.12), p.length() - 0.22)
		"disc_ring":
			return minf(p.length() - 0.4, _ring(p, Vector2.ZERO, 0.75, 0.08))
		"rings":
			return minf(_ring(p, Vector2.ZERO, 0.35, 0.1), _ring(p, Vector2.ZERO, 0.75, 0.1))
		"diamond":
			return (absf(p.x) + absf(p.y)) - 0.8
		"square":
			return _box(p, Vector2.ZERO, Vector2(0.62, 0.62))
		"chevron":
			return _chevron(p)
		"chevron_right":
			return _chevron(Vector2(p.y, -p.x))
		"double_chevron":
			var q := Vector2(p.y, -p.x)
			return minf(_chevron(q + Vector2(0.0, 0.3)), _chevron(q - Vector2(0.0, 0.3)))
		"arrow":
			return minf(_seg(p, Vector2(-0.8, 0.0), Vector2(0.5, 0.0), 0.14), _chevron(Vector2(p.y, -(p.x - 0.35))))
		"burst":
			var best := 99.0
			for i in 3:
				var angle := PI * i / 3.0
				best = minf(best, _seg(p, Vector2(cos(angle), sin(angle)) * -0.85, Vector2(cos(angle), sin(angle)) * 0.85, 0.1))
			return best
		"burst_ring":
			return minf(distance("burst", p * 1.6), _ring(p, Vector2.ZERO, 0.8, 0.08))
		"bar":
			return _box(p, Vector2.ZERO, Vector2(0.8, 0.18))
		"star":
			var angle := atan2(p.y, p.x) - PI * 0.5
			var r := 0.5 + 0.32 * cos(5.0 * angle)
			return (p.length() - r) * 0.8
		"cross":
			return minf(_seg(p, Vector2(-0.6, -0.6), Vector2(0.6, 0.6), 0.14), _seg(p, Vector2(-0.6, 0.6), Vector2(0.6, -0.6), 0.14))
		"wave":
			var band := absf(p.y - 0.28 * sin(p.x * PI * 1.5)) - 0.16
			return maxf(band, absf(p.x) - 0.85)
		"core":
			return minf((absf(p.x) + absf(p.y)) - 0.42, _ring(p, Vector2.ZERO, 0.75, 0.09))
		"knob":
			return minf(minf(_ring(p, Vector2.ZERO, 0.75, 0.09), p.length() - 0.16), _seg(p, Vector2.ZERO, Vector2(0.44, 0.62), 0.09))
		"plus":
			return minf(_box(p, Vector2.ZERO, Vector2(0.7, 0.22)), _box(p, Vector2.ZERO, Vector2(0.22, 0.7)))
		"arch":
			var posts := minf(_box(p, Vector2(-0.55, -0.2), Vector2(0.14, 0.6)), _box(p, Vector2(0.55, -0.2), Vector2(0.14, 0.6)))
			return minf(posts, _box(p, Vector2(0.0, 0.5), Vector2(0.72, 0.14)))
		"clock":
			var hands := minf(_seg(p, Vector2.ZERO, Vector2(0.0, 0.45), 0.08), _seg(p, Vector2.ZERO, Vector2(0.32, 0.0), 0.08))
			return minf(_ring(p, Vector2.ZERO, 0.72, 0.1), hands)
		"hook":
			var shaft := _seg(p, Vector2(0.3, 0.8), Vector2(0.3, -0.2), 0.12)
			var cup := maxf(_ring(p, Vector2(0.0, -0.2), 0.3, 0.12), p.y + 0.2)
			return minf(shaft, cup)
		"triangle":
			var q := Vector2(absf(p.x), p.y + 0.3)
			return maxf(q.x * 0.87 + q.y * 0.5 - 0.55, -q.y - 0.15)
		"bolt":
			var a := _seg(p, Vector2(0.3, 0.8), Vector2(-0.2, 0.05), 0.12)
			var b := _seg(p, Vector2(-0.2, 0.05), Vector2(0.2, -0.05), 0.12)
			return minf(minf(a, b), _seg(p, Vector2(0.2, -0.05), Vector2(-0.3, -0.8), 0.12))
		"barrel":
			return minf(_box(p, Vector2(0.15, 0.1), Vector2(0.65, 0.16)), _box(p, Vector2(-0.35, -0.25), Vector2(0.14, 0.35)))
		"turret":
			return minf(_box(p, Vector2(0.0, -0.3), Vector2(0.12, 0.55)), p.distance_to(Vector2(0.0, 0.35)) - 0.3)
		"wing":
			return minf(_seg(p, Vector2(-0.85, -0.1), Vector2(0.0, 0.3), 0.1), _seg(p, Vector2(0.0, 0.3), Vector2(0.85, -0.1), 0.1))
		"reel":
			return minf(_ring(p, Vector2(-0.1, 0.2), 0.45, 0.12), _seg(p, Vector2(0.35, 0.2), Vector2(0.35, -0.8), 0.1))
		"smash":
			var shaft := _seg(p, Vector2(0.0, 0.8), Vector2(0.0, -0.2), 0.13)
			var head := _chevron(Vector2(p.x, -(p.y + 0.15)))
			return minf(minf(shaft, head), _box(p, Vector2(0.0, -0.78), Vector2(0.8, 0.09)))
		"launch":
			var q := p.rotated(-PI * 0.25)
			return distance("arrow", q)
		"clamp":
			return minf(_ring(p, Vector2.ZERO, 0.7, 0.12), distance("cross", p * 1.5))
		"beacon":
			return minf(_ring(p, Vector2.ZERO, 0.72, 0.1), p.length() - 0.3)
		"vault":
			return minf(_box_ring(p, Vector2(0.55, 0.55), 0.1), p.length() - 0.2)
		"hoop":
			return minf(_ring(p, Vector2.ZERO, 0.75, 0.1), (absf(p.x) + absf(p.y)) - 0.35)
		"weight":
			return minf(_ring(p, Vector2(0.0, 0.42), 0.25, 0.09), _box(p, Vector2(0.0, -0.25), Vector2(0.62, 0.42)))
		"heap":
			var base := minf(p.distance_to(Vector2(-0.32, -0.3)), p.distance_to(Vector2(0.32, -0.3)))
			return minf(base, p.distance_to(Vector2(0.0, 0.24))) - 0.29
		"cog":
			var angle := atan2(p.y, p.x)
			var r := 0.55 + 0.14 * clampf(cos(8.0 * angle) * 4.0, -1.0, 1.0)
			return maxf(p.length() - r, -(p.length() - 0.2))
		"tag":
			return maxf(_box(p, Vector2(0.1, 0.0), Vector2(0.72, 0.45)), -(p.distance_to(Vector2(-0.35, 0.0)) - 0.13))
		"shield":
			return maxf(_box(p, Vector2(0.0, 0.05), Vector2(0.6, 0.72)), absf(p.x) * 0.8 - p.y * 0.6 - 0.45)
		"target":
			return minf(_ring(p, Vector2(0.2, -0.2), 0.45, 0.08), p.distance_to(Vector2(-0.55, 0.55)) - 0.18)
		"lane":
			return minf(_box(p, Vector2(-0.15, 0.0), Vector2(0.6, 0.2)), _chevron(Vector2(p.y, -(p.x - 0.55))))
		"mouse_left", "mouse_right", "mouse_wheel":
			return _mouse(glyph, p)
		"pips_1", "pips_2", "pips_3":
			var count := int(glyph.right(1))
			var best := 99.0
			for i in count:
				var x := (float(i) - (count - 1) * 0.5) * 0.55
				best = minf(best, (absf(p.x - x) + absf(p.y)) - 0.26)
			return best
	return p.length() - 0.7


static func _ring(p: Vector2, c: Vector2, r: float, w: float) -> float:
	return absf(p.distance_to(c) - r) - w


static func _box(p: Vector2, c: Vector2, half: Vector2) -> float:
	var d := (p - c).abs() - half
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


static func _box_ring(p: Vector2, half: Vector2, w: float) -> float:
	return absf(_box(p, Vector2.ZERO, half)) - w


static func _seg(p: Vector2, a: Vector2, b: Vector2, w: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t) - w


static func _chevron(p: Vector2) -> float:
	return minf(_seg(p, Vector2(-0.6, -0.3), Vector2(0.0, 0.3), 0.14), _seg(p, Vector2(0.0, 0.3), Vector2(0.6, -0.3), 0.14))


static func _mouse(glyph: String, p: Vector2) -> float:
	var body := absf(_box(p, Vector2.ZERO, Vector2(0.42, 0.7)) - 0.1) - 0.07
	var split := _seg(p, Vector2(-0.52, 0.1), Vector2(0.52, 0.1), 0.05)
	var d := minf(body, split)
	match glyph:
		"mouse_left":
			d = minf(d, _box(p, Vector2(-0.24, 0.42), Vector2(0.2, 0.28)))
		"mouse_right":
			d = minf(d, _box(p, Vector2(0.24, 0.42), Vector2(0.2, 0.28)))
		"mouse_wheel":
			d = minf(d, _box(p, Vector2(0.0, 0.42), Vector2(0.07, 0.22)))
	return d
