extends Node3D

const EndingSequence := preload("res://src/ui/ending_sequence.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# The victory lap (Andrew's design answer Q16, 2026-10-17 22:12Z: "60 s free roll", over a closing camera shot).
# After the Mind falls and the crew's fly-over plays (ending_sequence.gd), the ball drops over the rim of Meteor Crater,
# the crater_ending bowl, with the run's whole build still on it. Nothing in the bowl can hurt it and nothing ends the
# lap but the clock: no enemies, no hazards, no fail state (flow ignores a death in the lap). The bowl is a 60 m deep
# half-pipe and the floor's middle is the old vent, which throws the ball up harder the faster it comes in; its light
# column is the eye line from the rim. The lap counts what a strong build does there (top speed, best air, laps of the
# wall) and answers each new record with a drawn word and a flare over the rim (principle 5, overpowered pays). The
# narrator opens, the crew log keeps its dry notes, the swing's crash lands ten seconds out, the last three seconds
# count down, and the stats ride into the credits, which roll over this same bowl.
#
# The bowl's geometry is EndingSequence.CRATER_ROW placed with its collider, centred on the node. Its shape comes from
# tools/blender/park/crater.py (stamp radius F 235 m, depth 60 m): the floor is a paraboloid to 0.8 F, the rim crest
# stands 12 m up at 0.85 F, and the ejecta apron ends at 1.5 F, where the GLB ends.

signal finished

const SECONDS := 60.0
const F := 235.0
const DEPTH := 60.0
const BOWL_R := 0.8 * F
const CREST_R := 0.85 * F
# Past this radius, or this far under the floor, the ball has left the crater; it comes back over the north rim.
const EDGE_R := 1.42 * F
const FALL_Y := -DEPTH - 30.0
const ENTRY_LIFT := 14.0
# The wall band where travel around the centre counts toward a rim lap.
const WALL_FROM := 0.35 * F
const WALL_TO := 1.0 * F
const AIR_WORD := 1.2
const VENT_R := 16.0
const VENT_ABOVE := 8.0
const VENT_LIFT := 26.0
const VENT_PER_SPEED := 0.45
const VENT_COOL := 1.2
const SPEED_WORDS := [30.0, 45.0, 60.0, 80.0, 100.0, 130.0]
const CRASH_AT := 50.0
const COUNT_FROM := 3
const FLARE_SECONDS := 2.2
const WORD_SECONDS := 1.6
const CAPTION_FIRST := 10.0
const CAPTION_EVERY := 10.0
# TONE-READ: the narrator opens and the narrator winks; the crew log in between stays dry (tone bible, rule 4).
const OPENER := "Meanwhile, at a very old hole."
const CRASH := "This is the sad part."
# The lap's own crew log, after the fly-over read the worlds' lines; the washer is the Highdraft log's, still rolling.
const LOG := [
	"Crew log: crater floor clear. Somebody left the vent on.",
	"Crew log: no machines down here. The hole is older than all of them.",
	"Crew log: the washer from the Highdraft deck is still rolling. Down here now.",
	"Crew log: told the lap does not count. Counting it anyway.",
]
const BANNER := "VICTORY LAP"

var ctx
var crater: Node3D
var clock := 0.0
var top_speed := 0.0
var best_air := 0.0
var rim_laps := 0
var records: Array = []
var captions: Array = []
var rescues := 0
var vent_shots := 0
var _vent_cool := 0.0
var _turned := 0.0
var _bearing := INF
var _air := 0.0
var _speed_word := 0
var _done := false
var _layer: CanvasLayer
var _clock_label: Label
var _caption: Label
var _word: Label
var _count: Label
var _word_left := 0.0
var _flares: Array = []


# Places the bowl and its vent. False when the bowl did not place, so flow can end the run the old way.
func build(ctx_ref) -> bool:
	ctx = ctx_ref
	name = "VictoryLap"
	crater = ParkRecipes.place(EndingSequence.CRATER_ROW, self)
	if crater == null or crater.find_children("Collider", "StaticBody3D", true, false).is_empty():
		return false
	captions = _caption_rows()
	_build_vent()
	return true


# The centre of the bowl's floor plan, at ground level.
func centre() -> Vector3:
	return global_position


# The ball comes in over the north rim heading for the middle, at least at cruise speed: a lap starts rolling.
func begin(carried: Vector3) -> void:
	var cruise: float = ctx.tuning.f("cruise") if ctx.tuning != null else 12.0
	var speed := maxf(Vector2(carried.x, carried.z).length(), cruise)
	_build_overlay()
	_place(speed)
	_show_word(BANNER, Palette.AMBER, 2.4, 64)


func _place(speed: float) -> void:
	var at := entry_point()
	ctx.player.set_frozen(false)
	ctx.player.reset_to(at, Vector3.BACK * speed)
	ctx.player.body().global_position = at
	ctx.camera.snap(Vector3.BACK)


func entry_point() -> Vector3:
	return centre() + Vector3(0.0, DEPTH * 0.2 + ENTRY_LIFT, -CREST_R)


func seconds_left() -> float:
	return maxf(0.0, SECONDS - clock)


# One physics tick. True once the clock has run out.
func step(delta: float) -> bool:
	if _done:
		return true
	clock += delta
	var ball: Vector3 = ctx.player.ball_position()
	var flat := Vector2(ball.x - centre().x, ball.z - centre().z)
	if flat.length() > EDGE_R or ball.y < centre().y + FALL_Y:
		rescues += 1
		_place(maxf(ctx.player.planar_velocity().length(), ctx.tuning.f("cruise") if ctx.tuning != null else 12.0))
		_bearing = INF
		return false
	_vent(ball, flat, delta)
	_count_speed()
	_count_air(delta)
	_count_laps(flat)
	_step_overlay(delta)
	_step_flares(delta)
	if clock >= SECONDS:
		_done = true
		finished.emit()
	return _done


func stats() -> Dictionary:
	return {"top_speed": top_speed, "best_air": best_air, "rim_laps": rim_laps, "vent_shots": vent_shots,
		"records": records.size(), "rescues": rescues}


# Into the vent, the ball leaves straight up at VENT_LIFT plus a share of its rolling speed, keeping that speed.
func _vent(ball: Vector3, flat: Vector2, delta: float) -> void:
	_vent_cool = maxf(0.0, _vent_cool - delta)
	if _vent_cool > 0.0 or flat.length() > VENT_R or ball.y > centre().y - DEPTH + VENT_ABOVE:
		return
	var planar: Vector3 = ctx.player.planar_velocity()
	ctx.player.set_velocity_now(planar + Vector3.UP * (VENT_LIFT + VENT_PER_SPEED * planar.length()))
	_vent_cool = VENT_COOL
	vent_shots += 1
	_air = 0.0
	_show_word("FWOOM", Palette.AMBER, WORD_SECONDS, 56)
	_flare(Palette.AMBER, centre() + Vector3(0.0, -DEPTH + 4.0, 0.0))


func _count_speed() -> void:
	var speed: float = ctx.player.planar_velocity().length()
	top_speed = maxf(top_speed, speed)
	while _speed_word < SPEED_WORDS.size() and speed >= SPEED_WORDS[_speed_word]:
		_speed_word += 1
		if _speed_word > 1:
			_record("%d M/S" % int(SPEED_WORDS[_speed_word - 1]), Palette.ARC)


func _count_air(delta: float) -> void:
	if not ctx.player.state.grounded:
		_air += delta
		return
	if _air >= AIR_WORD and _air > best_air:
		_record("FWOOSH  %.1f S AIR" % _air, Palette.AMBER)
	if _air >= AIR_WORD:
		best_air = maxf(best_air, _air)
	_air = 0.0


func _count_laps(flat: Vector2) -> void:
	var r := flat.length()
	if r < WALL_FROM or r > WALL_TO:
		_bearing = INF
		return
	var bearing := atan2(flat.x, flat.y)
	if _bearing != INF:
		_turned += wrapf(bearing - _bearing, -PI, PI)
	_bearing = bearing
	if absf(_turned) >= TAU * (rim_laps + 1):
		rim_laps += 1
		_record("RIM LAP x%d" % rim_laps, Palette.BRASS)


func _record(word: String, color: Color) -> void:
	records.append({"word": word, "at": clock})
	_show_word(word, color, WORD_SECONDS, 46)
	_flare(color, _over_rim())


# --- The overlay --------------------------------------------------------------------

func _caption_rows() -> Array:
	var rows: Array = [{"at": 0.6, "text": OPENER}]
	for k in LOG.size():
		rows.append({"at": CAPTION_FIRST + CAPTION_EVERY * k, "text": LOG[k]})
	rows.append({"at": CRASH_AT, "text": CRASH})
	return rows


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_word = _label(64, Palette.AMBER, Control.PRESET_CENTER_TOP, 90.0)
	_clock_label = _label(34, Palette.SAND, Control.PRESET_TOP_RIGHT, 24.0)
	_clock_label.offset_left = -220.0
	_clock_label.offset_right = -32.0
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption = _label(26, Palette.SAND, Control.PRESET_BOTTOM_WIDE, -150.0)
	_caption.offset_left = 120.0
	_caption.offset_right = -120.0
	_caption.offset_bottom = -70.0
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count = _label(150, Palette.AMBER, Control.PRESET_CENTER, -110.0)
	_count.visible = false


func _label(size_px: int, color: Color, preset: int, top: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.CHARCOAL)
	label.add_theme_constant_override("outline_size", maxi(6, size_px / 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(label)
	label.set_anchors_and_offsets_preset(preset)
	if preset == Control.PRESET_CENTER_TOP or preset == Control.PRESET_CENTER:
		label.offset_left = -700.0
		label.offset_right = 700.0
	label.offset_top = top
	label.offset_bottom = top + size_px * 1.4
	return label


func _show_word(word: String, color: Color, seconds: float, size_px: int) -> void:
	_word.text = word
	_word.add_theme_color_override("font_color", color)
	_word.add_theme_font_size_override("font_size", size_px)
	_word.modulate.a = 1.0
	_word_left = seconds


func _step_overlay(delta: float) -> void:
	var left := seconds_left()
	_clock_label.text = "LAP  0:%02d" % int(ceilf(left))
	_word_left = maxf(0.0, _word_left - delta)
	_word.modulate.a = clampf(_word_left / 0.4, 0.0, 1.0)
	var line := ""
	for row in captions:
		if clock >= float(row["at"]):
			line = String(row["text"])
	_caption.text = line
	var count := int(ceilf(left))
	_count.visible = left > 0.0 and count <= COUNT_FROM
	if _count.visible:
		_count.text = str(count)
		_count.modulate.a = clampf(fmod(left, 1.0) / 0.3, 0.0, 1.0)


# The rim above the ball's bearing, where a record's flare goes up so it is seen from the floor.
func _over_rim() -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var out := Vector2(ball.x - centre().x, ball.z - centre().z)
	out = out.normalized() if out.length() > 1.0 else Vector2(0.0, 1.0)
	return centre() + Vector3(out.x * CREST_R, DEPTH * 0.2 + 6.0, out.y * CREST_R)


# The vent: a lit ring on the floor's middle under a pale column tall enough to clear the rim.
func _build_vent() -> void:
	var vent := Node3D.new()
	vent.name = "Vent"
	add_child(vent)
	vent.position = Vector3(0.0, -DEPTH + 0.4, 0.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = VENT_R - 2.0
	torus.outer_radius = VENT_R
	ring.mesh = torus
	ring.material_override = _glow(Palette.AMBER, 3.0, 1.0)
	vent.add_child(ring)
	var column := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = VENT_R * 0.7
	cylinder.bottom_radius = VENT_R * 0.9
	cylinder.height = DEPTH * 1.6
	column.mesh = cylinder
	column.material_override = _glow(Palette.AMBER, 1.2, 0.16)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position.y = cylinder.height * 0.5
	vent.add_child(column)


func _glow(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# A flare: a lit ball that climbs and fades.
func _flare(color: Color, at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.4
	sphere.height = 4.8
	mesh.mesh = sphere
	# A flare is a brightness spike, so it reads the reduce-flashes toggle (VISUAL-LANGUAGE.md section 8).
	var material := _glow(color, FlashGuard.spike(1.0, 6.0), 0.99)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.global_position = at
	_flares.append({"node": mesh, "material": material, "left": FLARE_SECONDS})


func _step_flares(delta: float) -> void:
	for flare in _flares.duplicate():
		flare["left"] -= delta
		var node: MeshInstance3D = flare["node"]
		if flare["left"] <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_flares.erase(flare)
			continue
		var p: float = float(flare["left"]) / FLARE_SECONDS
		node.position.y += 18.0 * delta
		node.scale = Vector3.ONE * (1.0 + (1.0 - p) * 2.0)
		flare["material"].albedo_color.a = p
