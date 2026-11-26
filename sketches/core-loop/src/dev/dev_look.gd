extends Node

const SafeStore := preload("res://src/core/safe_store.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const PRINT_SHADER := preload("res://src/dev/dev_print.gdshader")
const PAINT_SHADER := preload("res://src/dev/dev_paint.gdshader")

const LOOK_DIR := "user://dev_looks"
const FILTER_LAYER := -60

const ENV := {
	"exposure": {"prop": "tonemap_exposure", "range": [0.2, 3.0, 0.01]},
	"tonemap": {"prop": "tonemap_mode", "range": [0, 4, 1]},
	"white": {"prop": "tonemap_white", "range": [0.5, 12.0, 0.1]},
	"saturation": {"prop": "adjustment_saturation", "range": [0.0, 2.5, 0.01], "needs": "adjustment_enabled"},
	"contrast": {"prop": "adjustment_contrast", "range": [0.3, 2.5, 0.01], "needs": "adjustment_enabled"},
	"brightness": {"prop": "adjustment_brightness", "range": [0.3, 2.0, 0.01], "needs": "adjustment_enabled"},
	"ambient": {"prop": "ambient_light_energy", "range": [0.0, 2.0, 0.01]},
	"fog": {"prop": "fog_density", "range": [0.0, 0.05, 0.0001], "needs": "fog_enabled"},
	"fog_sky": {"prop": "fog_sky_affect", "range": [0.0, 1.0, 0.01]},
	"air": {"prop": "volumetric_fog_density", "range": [0.0, 0.06, 0.0005], "needs": "volumetric_fog_enabled"},
	"glow": {"prop": "glow_intensity", "range": [0.0, 3.0, 0.01], "needs": "glow_enabled"},
	"bloom": {"prop": "glow_bloom", "range": [0.0, 1.0, 0.01], "needs": "glow_enabled"},
	"ssao": {"prop": "ssao_intensity", "range": [0.0, 6.0, 0.05], "needs": "ssao_enabled"},
}
const SUN := {
	"sun": {"prop": "light_energy", "range": [0.0, 4.0, 0.01]},
	"sun_pitch": {"prop": "rotation_degrees:x", "range": [-89.0, -2.0, 0.5]},
	"sun_yaw": {"prop": "rotation_degrees:y", "range": [-180.0, 180.0, 1.0]},
	"shadow": {"prop": "shadow_opacity", "range": [0.0, 1.0, 0.01], "needs": "shadow_enabled"},
	"sun_size": {"prop": "light_angular_distance", "range": [0.0, 8.0, 0.1]},
}
const PAINT := "paint"
const PRINT := "print"
const FILTERS := {
	"cel": {"pass": PAINT, "param": "cel_steps", "range": [0.0, 12.0, 1.0], "rest": 0.0},
	"cel_soft": {"pass": PAINT, "param": "cel_soft", "range": [0.01, 0.45, 0.01], "rest": 0.14},
	"flatten": {"pass": PAINT, "param": "flatten", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"dots": {"pass": PAINT, "param": "dots", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"dot_px": {"pass": PAINT, "param": "dot_px", "range": [2.0, 16.0, 0.5], "rest": 4.5},
	"shadow_cut": {"pass": PAINT, "param": "shadow_cut", "range": [0.1, 0.8, 0.01], "rest": 0.48},
	"hatch": {"pass": PAINT, "param": "hatch", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"hatch_px": {"pass": PAINT, "param": "hatch_px", "range": [3.0, 14.0, 0.5], "rest": 6.0},
	"lines": {"pass": PAINT, "param": "lines", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"line_px": {"pass": PAINT, "param": "line_px", "range": [0.5, 3.0, 0.05], "rest": 1.25},
	"depth_cut": {"pass": PAINT, "param": "depth_cut", "range": [0.01, 1.0, 0.01], "rest": 0.14},
	"normal_cut": {"pass": PAINT, "param": "normal_cut", "range": [0.05, 1.5, 0.01], "rest": 0.5},
	"fade_from": {"pass": PAINT, "param": "fade_from", "range": [10.0, 300.0, 1.0], "rest": 80.0},
	"fade_to": {"pass": PAINT, "param": "fade_to", "range": [20.0, 600.0, 1.0], "rest": 170.0},
	"pixel": {"pass": PRINT, "param": "pixel_size", "range": [1.0, 16.0, 1.0], "rest": 1.0},
	"posterize": {"pass": PRINT, "param": "posterize", "range": [0.0, 16.0, 1.0], "rest": 0.0},
	"dither": {"pass": PRINT, "param": "dither", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"riso": {"pass": PRINT, "param": "riso", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"riso_shift": {"pass": PRINT, "param": "riso_shift", "range": [0.0, 6.0, 0.1], "rest": 1.2},
	"riso_cell": {"pass": PRINT, "param": "riso_cell", "range": [3.0, 16.0, 0.5], "rest": 5.0},
	"centre_guard": {"pass": PRINT, "param": "centre_guard", "range": [0.0, 1.0, 0.01], "rest": 0.65},
	"grade_sat": {"pass": PRINT, "param": "grade_saturation", "range": [0.0, 2.0, 0.01], "rest": 1.0},
	"grade_contrast": {"pass": PRINT, "param": "grade_contrast", "range": [0.5, 2.0, 0.01], "rest": 1.0},
	"warmth": {"pass": PRINT, "param": "temperature", "range": [-1.0, 1.0, 0.01], "rest": 0.0},
	"chroma": {"pass": PRINT, "param": "chroma", "range": [0.0, 6.0, 0.05], "rest": 0.0},
	"tooth": {"pass": PRINT, "param": "tooth", "range": [0.0, 0.25, 0.005], "rest": 0.0},
	"grain": {"pass": PRINT, "param": "grain", "range": [0.0, 0.5, 0.005], "rest": 0.0},
	"scanlines": {"pass": PRINT, "param": "scanlines", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"vignette": {"pass": PRINT, "param": "vignette", "range": [0.0, 1.5, 0.01], "rest": 0.0},
	"speed_lines": {"pass": PRINT, "param": "speed_lines", "range": [0.0, 1.0, 0.01], "rest": 0.0},
	"impact": {"pass": PRINT, "param": "impact", "range": [0.0, 1.0, 0.01], "rest": 0.0},
}
const CHARCOAL := Color("242a28")
const COLOURS := {
	"ink": {"passes": [PAINT, PRINT], "param": "ink", "rest": CHARCOAL},
	"paper": {"passes": [PRINT], "param": "paper", "rest": Color(0.969, 0.945, 0.890)},
	"riso_a": {"passes": [PRINT], "param": "riso_a", "rest": Color(0.937, 0.333, 0.235)},
	"riso_b": {"passes": [PRINT], "param": "riso_b", "rest": Color(0.137, 0.384, 0.62)},
}
const INK_RANGE := [0.0, 4.0, 0.05]
const IMPACT_HOLD_S := 0.07
const IMPACT_FADE_S := 0.12
const SHOCK_FLOOR := 0.35
const PAINT_PRIORITY := -10
const FAR_BOX := 100000.0

const PRESETS := {
	"shipped": {"blurb": "the game as it ships: no overrides"},
	"graphic press": {"blurb": "five soft cel bands, 30-degree dots in the mid shadows, charcoal ink",
		"filter": {"cel": 5.0, "dots": 0.45, "dot_px": 4.5, "shadow_cut": 0.3, "lines": 0.35, "line_px": 1.1, "fade_from": 75.0, "fade_to": 155.0,
			"tooth": 0.03, "vignette": 0.25, "speed_lines": 0.35, "impact": 0.8}},
	"ligne claire": {"blurb": "Moebius: flat sunlit planes, crisp depth and crease lines, no fog",
		"env": {"fog": 0.0, "air": 0.0, "ambient": 0.55, "ssao": 0.4, "saturation": 1.18},
		"sun": {"sun": 1.6},
		"filter": {"flatten": 0.45, "lines": 0.9, "line_px": 1.25, "depth_cut": 0.14, "normal_cut": 0.5, "fade_from": 85.0, "fade_to": 180.0, "warmth": 0.18}},
	"ink hatch": {"blurb": "workshop pen: cel bands with 20/-70 degree hatching in the shadows",
		"filter": {"cel": 4.0, "hatch": 0.85, "hatch_px": 6.0, "shadow_cut": 0.45, "lines": 0.4, "fade_from": 65.0, "fade_to": 140.0, "tooth": 0.04}},
	"riso zine": {"blurb": "tomato and blue inks a pixel out of register, cream stock",
		"filter": {"riso": 0.45, "riso_shift": 1.1, "centre_guard": 0.65, "tooth": 0.07, "lines": 0.3}},
	"pixel spill": {"blurb": "chunky 3D under a crisp 2D HUD",
		"filter": {"pixel": 3.0, "posterize": 7.0, "dither": 0.55, "grade_sat": 1.12, "cel": 4.0}},
	"anime cut": {"blurb": "clean 3D, speed lines at full tilt and inked impact frames on big hits",
		"filter": {"speed_lines": 1.0, "impact": 1.0, "lines": 0.3, "grade_contrast": 1.06}},
	"noir flood": {"blurb": "night water, hard key light, ink-black shadows",
		"env": {"exposure": 0.85, "saturation": 0.25, "contrast": 1.45, "fog": 0.012, "ambient": 0.08},
		"sun": {"sun": 2.4, "sun_pitch": -18.0},
		"filter": {"cel": 3.0, "lines": 0.6, "hatch": 0.5, "vignette": 0.9, "grain": 0.09}},
	"golden spill": {"blurb": "late sun, long shadows, warm haze",
		"env": {"exposure": 1.18, "saturation": 1.22, "fog": 0.0026, "glow": 1.1, "bloom": 0.08},
		"sun": {"sun": 1.9, "sun_pitch": -12.0},
		"filter": {"warmth": 0.4, "vignette": 0.45}},
	"blueprint": {"blurb": "survey sheet: lines only on cyanotype blue",
		"filter": {"lines": 1.0, "depth_cut": 0.08, "normal_cut": 0.35, "flatten": 1.0, "grade_sat": 0.0, "posterize": 3.0},
		"colour": {"ink": Color(0.93, 0.96, 1.0)},
		"tint": Color(0.36, 0.6, 1.0)},
}

var game
var _env_touched := {}
var _sun_touched := {}
var _env_rest := {}
var _sun_rest := {}
var _filter := {}
var _colour := {}
var _ink_scale := 1.0
var _layer: CanvasLayer
var _rect: ColorRect
var _print: ShaderMaterial
var _paint: ShaderMaterial
var _quad: MeshInstance3D
var _sun: DirectionalLight3D
var _gain := Vector3.ONE
var _impact_left := -1.0
var _impact_strength := 0.0
var impact_on_hits := true
var preset_name := "shipped"


func setup(game_ref) -> void:
	game = game_ref
	name = "DevLook"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_print = ShaderMaterial.new()
	_print.shader = PRINT_SHADER
	_layer = CanvasLayer.new()
	_layer.name = "DevPrintLayer"
	_layer.layer = FILTER_LAYER
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.material = _print
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_rect)
	_layer.visible = false
	_paint = ShaderMaterial.new()
	_paint.shader = PAINT_SHADER
	_paint.render_priority = PAINT_PRIORITY
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_quad = MeshInstance3D.new()
	_quad.name = "DevPaintPass"
	_quad.mesh = quad
	_quad.material_override = _paint
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.custom_aabb = AABB(Vector3.ONE * -FAR_BOX, Vector3.ONE * FAR_BOX * 2.0)
	_quad.visible = false
	add_child(_quad)
	_sync_filters()
	if game.player != null:
		game.player.struck.connect(_on_struck)
		game.player.shockwave.connect(_on_shockwave)


func _exit_tree() -> void:
	if game != null and is_instance_valid(game.player):
		if game.player.struck.is_connected(_on_struck):
			game.player.struck.disconnect(_on_struck)
		if game.player.shockwave.is_connected(_on_shockwave):
			game.player.shockwave.disconnect(_on_shockwave)


func _on_struck(_enemy, _kind, force: float) -> void:
	_on_hit(clampf(force / 30.0, SHOCK_FLOOR, 1.0))


func _on_shockwave(_at, strength: float) -> void:
	_on_hit(clampf(strength, SHOCK_FLOOR, 1.0))


func environment() -> Environment:
	if game == null or game.ctx == null or game.ctx.terrain == null:
		return null
	return game.ctx.terrain.environment


func sun() -> DirectionalLight3D:
	if is_instance_valid(_sun) and _sun.is_inside_tree() and _sun.is_visible_in_tree():
		return _sun
	_sun = null
	for light in game.find_children("*", "DirectionalLight3D", false, false) + game.get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if light.name != "SkyFill" and light.is_visible_in_tree():
			_sun = light
			break
	return _sun


func keys() -> Array:
	return ENV.keys() + SUN.keys() + FILTERS.keys() + ["ink_width"]


func range_of(key: String) -> Array:
	for table in [ENV, SUN, FILTERS]:
		if table.has(key):
			return table[key].range
	return INK_RANGE if key == "ink_width" else []


func value(key: String) -> float:
	if FILTERS.has(key):
		return float(_filter.get(key, FILTERS[key].rest))
	if key == "ink_width":
		return _ink_scale
	if ENV.has(key):
		var env := environment()
		return float(_env_touched.get(key, _read(env, ENV[key].prop) if env != null else 0.0))
	if SUN.has(key):
		var light := sun()
		return float(_sun_touched.get(key, _read(light, SUN[key].prop) if light != null else 0.0))
	return 0.0


func touched(key: String) -> bool:
	return _env_touched.has(key) or _sun_touched.has(key) or _filter.has(key) or (key == "ink_width" and _ink_scale != 1.0)


func set_value(key: String, amount: float) -> String:
	var span := range_of(key)
	if span.is_empty():
		return "!no look key '%s'" % key
	amount = clampf(amount, float(span[0]), float(span[1]))
	if FILTERS.has(key):
		if is_equal_approx(amount, float(FILTERS[key].rest)):
			_filter.erase(key)
		else:
			_filter[key] = amount
		_sync_filters()
	elif key == "ink_width":
		_ink_scale = amount
		_sync_ink()
	elif ENV.has(key):
		var env := environment()
		if env == null:
			return "!no world environment yet"
		_remember(_env_rest, env, ENV[key])
		_env_touched[key] = amount
	elif SUN.has(key):
		var light := sun()
		if light == null:
			return "!no sun in this scene"
		_remember(_sun_rest, light, SUN[key])
		_sun_touched[key] = amount
	return "%s %s" % [key, _show(amount)]


func set_colour(key: String, colour: Color) -> String:
	if not COLOURS.has(key):
		return "!no colour '%s' (paper, ink, riso_a, riso_b)" % key
	_colour[key] = colour
	_sync_filters()
	return "%s #%s" % [key, colour.to_html(false)]


func colour(key: String) -> Color:
	return _colour.get(key, COLOURS[key].rest) if COLOURS.has(key) else Color.BLACK


func release(key: String) -> String:
	if _env_touched.has(key):
		_env_touched.erase(key)
		_restore(environment(), _env_rest, ENV[key], _shares_needs(ENV, _env_touched, ENV[key]))
	elif _sun_touched.has(key):
		_sun_touched.erase(key)
		_restore(sun(), _sun_rest, SUN[key], _shares_needs(SUN, _sun_touched, SUN[key]))
	elif _filter.has(key):
		_filter.erase(key)
		_sync_filters()
	elif key == "ink_width":
		_ink_scale = 1.0
		_sync_ink()
	else:
		return "!%s is not overridden" % key
	return "%s back to the game's value" % key


func clear() -> String:
	for key in _env_touched.keys():
		release(key)
	for key in _sun_touched.keys():
		release(key)
	_filter.clear()
	_colour.clear()
	_gain = Vector3.ONE
	_ink_scale = 1.0
	_sync_ink()
	_sync_filters()
	preset_name = "shipped"
	return "look cleared: the game's own lighting is back"


func apply_preset(id: String) -> String:
	if not PRESETS.has(id):
		var matches := PRESETS.keys().filter(func(k: String): return k.begins_with(id))
		if matches.size() != 1:
			return "!no preset '%s' (%s)" % [id, ", ".join(PRESETS.keys())]
		id = matches[0]
	clear()
	var row: Dictionary = PRESETS[id]
	_apply_row(row)
	preset_name = id
	return "%s: %s" % [id, row.blurb]


func snapshot() -> Dictionary:
	var colours := {}
	for key in _colour:
		colours[key] = "#" + _colour[key].to_html(false)
	var env := {}
	for key in _env_touched:
		env[key] = _env_touched[key]
	var light := {}
	for key in _sun_touched:
		light[key] = _sun_touched[key]
	var shot := {"from": preset_name, "env": env, "sun": light, "filter": _filter.duplicate(), "colour": colours, "ink_width": _ink_scale}
	if _gain != Vector3.ONE:
		shot["tint"] = "#" + Color(_gain.x, _gain.y, _gain.z).to_html(false)
	return shot


func bake(id: String) -> String:
	if not id.is_valid_filename() or id.is_empty():
		return "!give the look a plain file name"
	DirAccess.make_dir_recursive_absolute(LOOK_DIR)
	var path := LOOK_DIR.path_join(id + ".json")
	var err := SafeStore.write_atomic(path, JSON.stringify(snapshot(), "\t"))
	if err != OK:
		return "!could not save %s (error %d)" % [path, err]
	return "baked '%s' -> %s" % [id, ProjectSettings.globalize_path(path)]


func baked() -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(LOOK_DIR):
		if file.ends_with(".json"):
			found.append(file.get_basename())
	return found


func load_baked(id: String) -> String:
	var path := LOOK_DIR.path_join(id + ".json")
	if not FileAccess.file_exists(path):
		return "!no baked look '%s'" % id
	var data = SafeStore.parse(FileAccess.get_file_as_string(path), TYPE_DICTIONARY)
	if not data is Dictionary:
		return "!%s is not a look file" % path
	load_snapshot(data)
	preset_name = id
	return "loaded baked look '%s'" % id


func load_snapshot(data: Dictionary) -> void:
	clear()
	var colours := {}
	for key in data.get("colour", {}):
		colours[key] = Color(String(data.colour[key]))
	var row := {"env": data.get("env", {}), "sun": data.get("sun", {}), "filter": data.get("filter", {}), "colour": colours}
	if data.has("tint"):
		row["tint"] = Color(String(data.tint))
	_apply_row(row)
	if data.has("ink_width"):
		set_value("ink_width", float(data.ink_width))
	preset_name = String(data.get("from", "shipped"))


func describe() -> String:
	var parts: Array[String] = []
	for key in keys():
		if touched(key):
			parts.append("%s=%s" % [key, _show(value(key))])
	for key in _colour:
		parts.append("%s=#%s" % [key, _colour[key].to_html(false)])
	return "%s  %s" % [preset_name, " ".join(parts) if not parts.is_empty() else "(no overrides)"]


func filters_live() -> bool:
	return not _filter.is_empty() or not _colour.is_empty()


func _apply_row(row: Dictionary) -> void:
	for key in row.get("env", {}):
		set_value(key, float(row.env[key]))
	for key in row.get("sun", {}):
		set_value(key, float(row.sun[key]))
	for key in row.get("filter", {}):
		set_value(key, float(row.filter[key]))
	for key in row.get("colour", {}):
		set_colour(key, row.colour[key])
	if row.has("tint"):
		var tint: Color = row.tint
		_gain = Vector3(tint.r, tint.g, tint.b)
	else:
		_gain = Vector3.ONE
	_sync_filters()


func _process(delta: float) -> void:
	var env := environment()
	if env != null:
		for key in _env_touched:
			var row: Dictionary = ENV[key]
			if row.has("needs"):
				env.set(row.needs, true)
			_write(env, row.prop, _env_touched[key])
	var light := sun() if not _sun_touched.is_empty() else null
	if light != null:
		for key in _sun_touched:
			var row: Dictionary = SUN[key]
			if row.has("needs"):
				light.set(row.needs, true)
			_write(light, row.prop, _sun_touched[key])
	_step_overlays(delta / maxf(Engine.time_scale, 0.05))


func _step_overlays(real_delta: float) -> void:
	if not _layer.visible:
		return
	var speed_max := float(_filter.get("speed_lines", 0.0))
	if speed_max > 0.0 and game.player != null and game.player.state != null:
		var fraction := SpeedTier.fraction(game.player.state.velocity.length(), game.tuning.f("cruise"))
		_print.set_shader_parameter("speed_lines", speed_max * smoothstep(0.55, 1.0, fraction))
	var impact_max := float(_filter.get("impact", 0.0))
	if impact_max > 0.0:
		var level := 0.0
		if _impact_left > 0.0:
			_impact_left -= real_delta
			var t := _impact_left
			level = 1.0 if t > IMPACT_FADE_S else clampf(t / IMPACT_FADE_S, 0.0, 1.0)
		_print.set_shader_parameter("impact", impact_max * _impact_strength * level)


func pulse_impact(strength := 1.0) -> void:
	_impact_strength = clampf(strength, 0.0, 1.0)
	_impact_left = IMPACT_HOLD_S + IMPACT_FADE_S


func _on_hit(strength: float) -> void:
	if impact_on_hits and _filter.has("impact"):
		pulse_impact(strength)


func _sync_filters() -> void:
	var live := {PAINT: false, PRINT: false}
	for key in FILTERS:
		var row: Dictionary = FILTERS[key]
		_material_for(row.pass).set_shader_parameter(row.param, float(_filter.get(key, row.rest)))
		if _filter.has(key) and not key in ["speed_lines", "impact"]:
			live[row.pass] = true
		elif _filter.has(key):
			live[PRINT] = true
	for key in COLOURS:
		for pass_id in COLOURS[key].passes:
			_material_for(pass_id).set_shader_parameter(COLOURS[key].param, _colour.get(key, COLOURS[key].rest))
	for key in ["speed_lines", "impact"]:
		_print.set_shader_parameter(key, 0.0)
	if _colour.has("paper") or _colour.has("riso_a") or _colour.has("riso_b"):
		live[PRINT] = true
	_print.set_shader_parameter("gain", _gain)
	_quad.visible = live[PAINT]
	_layer.visible = live[PRINT] or _gain != Vector3.ONE


func _material_for(pass_id: String) -> ShaderMaterial:
	return _paint if pass_id == PAINT else _print


func passes_live() -> Dictionary:
	return {PAINT: _quad.visible, PRINT: _layer.visible}


func _sync_ink() -> void:
	for role in InkOutline.ROLES:
		var mat: ShaderMaterial = InkOutline.ink(role)
		if mat != null:
			mat.set_shader_parameter("width_px", float(InkOutline.WIDTH_PX[role]) * _ink_scale)
			mat.set_shader_parameter("width_cap", float(InkOutline.WIDTH_CAP[role]) * maxf(_ink_scale, 1.0))


static func _remember(store: Dictionary, object: Object, row: Dictionary) -> void:
	var key: String = row.prop
	if not store.has(key):
		store[key] = _read(object, key)
	if row.has("needs") and not store.has(row.needs):
		store[row.needs] = object.get(row.needs)


static func _shares_needs(table: Dictionary, still: Dictionary, row: Dictionary) -> bool:
	if not row.has("needs"):
		return false
	for other in still:
		if table[other].get("needs", "") == row.needs:
			return true
	return false


static func _restore(object: Object, store: Dictionary, row: Dictionary, keep_needs := false) -> void:
	if object == null:
		return
	if store.has(row.prop):
		_write(object, row.prop, store[row.prop])
		store.erase(row.prop)
	if not keep_needs and row.has("needs") and store.has(row.needs):
		object.set(row.needs, store[row.needs])
		store.erase(row.needs)


static func _read(object: Object, prop: String) -> float:
	if object == null:
		return 0.0
	if prop.contains(":"):
		var bits := prop.split(":")
		var vec: Vector3 = object.get(bits[0])
		return vec[bits[1]]
	return float(object.get(prop))


static func _write(object: Object, prop: String, amount) -> void:
	if prop.contains(":"):
		var bits := prop.split(":")
		var vec: Vector3 = object.get(bits[0])
		vec[bits[1]] = float(amount)
		object.set(bits[0], vec)
	elif typeof(object.get(prop)) == TYPE_INT:
		object.set(prop, int(amount))
	else:
		object.set(prop, amount)


static func _show(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return str(int(amount))
	return ("%.4f" % amount).rstrip("0")
