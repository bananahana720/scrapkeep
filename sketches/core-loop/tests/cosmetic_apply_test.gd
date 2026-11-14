extends SceneTree

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Profile := preload("res://src/core/profile.gd")
const Game := preload("res://src/game.gd")

# An equipped paint colours the pilot's shell and nothing else (A-series cosmetics, P4).
#   - an owned paint multiplies the lifted paint slot on Pod and Core; class_accent, class_color()
#     and the ball's heft stay put;
#   - an empty, unknown, other-pilot, unowned or non-paint id gives no tint and one warning each;
#   - Tarn's own starter paint applies to Tarn and is refused on another pilot;
#   - a paint equipped on a live shell repaints at the next fit;
#   - a ClassPreview with paint_id tints only its shell's paint slot;
#   - the paint shows: on every pilot's Core lattice, Cobalt and each starter paint pull the
#     colour the paint surfaces render at least SHOWN_PULL of the way to the tint (PAINT-TRACE
#     card B). A multiply over the dark lattice only darkens it, so it fails this.

const LIFT := 1.2
# Share of the sRGB distance from the unpainted Core to the lifted tint that the paint must close (start).
const SHOWN_PULL := 0.5
const SABLE := "pylon_engineer"

var _failures := 0
var _game
var _ticks := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _ticks < 6:
		return false
	_check_applied()
	_check_refusals()
	_check_repaint()
	_check_preview()
	_check_shown()
	print("cosmetic_apply_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


static func slot_albedos(node: Node, slot: String, out: Array = []) -> Array:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) == slot:
				var mat := mi.get_surface_override_material(i)
				if mat is StandardMaterial3D:
					out.append(mat.albedo_color)
				elif mat is ShaderMaterial:
					# The cutaway look's window material keeps an unpainted surface's colour as "tint".
					var painted = mat.get_shader_parameter("paint_tint")
					out.append(painted if painted != null else mat.get_shader_parameter("tint"))
	for c in node.get_children():
		slot_albedos(c, slot, out)
	return out


static func all_equal(colors: Array, want: Color) -> bool:
	if colors.is_empty():
		return false
	for c in colors:
		if not (c as Color).is_equal_approx(want):
			return false
	return true


# A Core with no paint surface passes; whatever paint surface it has must wear the tint.
static func none_or_equal(colors: Array, want: Color) -> bool:
	return colors.is_empty() or all_equal(colors, want)


func _profile() -> Profile:
	var p := Profile.new("%s/cosmetic_apply.json" % _game.storage_dir)
	p.load_profile()
	return p


func _lifted(tint: Color) -> Color:
	return Color(LIFT * tint.r, LIFT * tint.g, LIFT * tint.b)


func _check_applied() -> void:
	var hook = _game.presentation.hero_assets
	var player = _game.player
	var rec: Dictionary = hook.shell_of(player)
	var id: String = rec["class"]
	var plain := Color(LIFT, LIFT, LIFT)
	var heft_before: float = player.heft()
	var mass_before: float = _game.run.mass
	var color_before: Color = player.class_color()
	var accent_before := slot_albedos(rec["pod"], "class_accent")
	var profile := _profile()
	var paint_id := "paint_sable_violet"
	profile.unlock_cosmetic(paint_id)
	profile.equip(id, "paint", paint_id)
	hook.profile = profile
	hook._process(0.016)
	rec = hook.shell_of(player)
	var tint: Color = Cosmetics.row(paint_id)["tint"]
	_report("P4-1 pod", all_equal(slot_albedos(rec["pod"], "paint"), _lifted(tint)), "Pod paint slot wears the tint")
	_report("P4-1 core", none_or_equal(slot_albedos(rec["core"], "paint"), _lifted(tint)), "Core paint slot wears the tint")
	var accent_after := slot_albedos(rec["pod"], "class_accent")
	_report("P4-1 accent", accent_after == accent_before and player.class_color().is_equal_approx(color_before),
		"class_accent and class_color() unchanged")
	_report("P4-1 heft", is_equal_approx(player.heft(), heft_before) and is_equal_approx(_game.run.mass, mass_before),
		"heft and mass unchanged")
	_report("P4-1 plain", not plain.is_equal_approx(_lifted(tint)), "the tint differs from the unpainted lift")
	# An unpainted shell keeps the plain lift.
	hook.profile = null
	profile.equip(id, "paint", "")
	hook._process(0.016)
	_report("P4-1 none", all_equal(slot_albedos(hook.shell_of(player)["pod"], "paint"), plain), "no paint means today's colour")
	hook.profile = profile


func _check_refusals() -> void:
	var hook := HeroAssets.new()
	var profile := _profile()
	hook.profile = profile
	var cases := {
		"": "empty",
		"paint_nope": "unknown",
		"paint_rivet_forge": "other pilot",
		"paint_sable_violet": "not owned",
	}
	for id in cases:
		var got = hook.paint_tint(SABLE, id)
		_report("P4-2 " + cases[id], got == null and hook._warned.has("paint:" + id), "no tint and a warning for '%s'" % id)
	_report("P4-2 starter", hook.paint_tint(SABLE, "paint_sable_lagoon") != null, "a starter needs no unlock")
	_report("P4-2 any", hook.paint_tint(SABLE, "paint_any_salt") != null, "an any-pilot row applies")
	var tarn_tint = hook.paint_tint("tarn", "paint_tarn_ash")
	_report("P4-2 tarn starter", tarn_tint != null and tarn_tint == Color("5e5a54"), "Tarn's starter applies with its own tint, got %s" % [tarn_tint])
	_report("P4-2 tarn paint stays Tarn's", hook.paint_tint(SABLE, "paint_tarn_ash") == null, "Sable cannot wear Tarn's paint")
	var before: int = hook._warned.size()
	hook.paint_tint(SABLE, "paint_nope")
	_report("P4-2 once", hook._warned.size() == before, "one warning per id")
	hook.free()


func _check_repaint() -> void:
	var hook = _game.presentation.hero_assets
	var player = _game.player
	var id: String = hook.shell_of(player)["class"]
	var profile = hook.profile
	profile.equip(id, "paint", "paint_any_night")
	hook._process(0.016)
	var locked := slot_albedos(hook.shell_of(player)["pod"], "paint")
	profile.unlock_cosmetic("paint_any_night")
	hook._process(0.016)
	var unlocked := slot_albedos(hook.shell_of(player)["pod"], "paint")
	_report("P4-3 unlock", all_equal(locked, Color(LIFT, LIFT, LIFT)) and all_equal(unlocked, _lifted(Cosmetics.row("paint_any_night")["tint"])),
		"an equipped paint shows at the next fit once it is unlocked")
	profile.equip(id, "paint", "paint_any_night")
	hook._process(0.016)
	var first := slot_albedos(hook.shell_of(player)["pod"], "paint")
	profile.equip(id, "paint", "paint_any_salt")
	hook._process(0.016)
	var second := slot_albedos(hook.shell_of(player)["pod"], "paint")
	_report("P4-3 repaint", all_equal(first, _lifted(Cosmetics.row("paint_any_night")["tint"]))
		and all_equal(second, _lifted(Cosmetics.row("paint_any_salt")["tint"])),
		"a different paint repaints the live shell at the next fit")


func _check_preview() -> void:
	for def in ClassDef.all():
		var preview := ClassPreview.new(def)
		root.add_child(preview)
		var paint_before := slot_albedos(preview._pod, "paint")
		var accent_before := slot_albedos(preview._pod, "class_accent")
		var pilot_before := slot_albedos(preview._pod, "pilot")
		preview.paint_id = "paint_any_night"
		var tint: Color = Cosmetics.row("paint_any_night")["tint"]
		_report("P4-4 " + def.id, all_equal(slot_albedos(preview._pod, "paint"), _lifted(tint))
			and none_or_equal(slot_albedos(preview._core, "paint"), _lifted(tint))
			and slot_albedos(preview._pod, "class_accent") == accent_before
			and slot_albedos(preview._pod, "pilot") == pilot_before
			and not paint_before.is_empty(),
			"preview tints only the paint slot")
		preview.free()


# The colour a paint surface renders for one vertex colour, before the plate texture and light,
# in linear RGB: vertex x albedo for the plain material, the lerp toward the tint for a painted one.
static func shown(mat: Material, vertex: Color) -> Color:
	if mat is ShaderMaterial:
		var lift: Color = (mat.get_shader_parameter("lift") as Color).srgb_to_linear()
		var tint: Color = (mat.get_shader_parameter("paint_tint") as Color).srgb_to_linear()
		var take: float = mat.get_shader_parameter("paint_take")
		return Color(vertex.r * lift.r, vertex.g * lift.g, vertex.b * lift.b).lerp(tint, take)
	var albedo: Color = (mat as StandardMaterial3D).albedo_color.srgb_to_linear()
	return Color(vertex.r * albedo.r, vertex.g * albedo.g, vertex.b * albedo.b)


# Mean shown colour, in sRGB, over the paint surfaces of the meshes under part that would draw.
static func mean_shown(part: Node) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	var stack: Array[Node] = [part]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D and not (node as Node3D).visible:
			continue
		stack.append_array(node.get_children())
		if not node is MeshInstance3D:
			continue
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) != "paint":
				continue
			var colors = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			if colors == null:
				continue
			var mat := mi.get_surface_override_material(i)
			for c in colors:
				var s := shown(mat, c)
				sum += Vector3(s.r, s.g, s.b)
				n += 1
	if n == 0:
		return Color.BLACK
	sum /= n
	return Color(sum.x, sum.y, sum.z).linear_to_srgb()


static func distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _shown_core(hook, pilot: String, tints: Dictionary) -> Color:
	var ball := Node3D.new()
	var rec: Dictionary = hook.fit_shell_into(ball, pilot, "", 1, tints)
	var got := mean_shown(rec["core"]) if not rec.is_empty() else Color.BLACK
	ball.free()
	return got


func _check_shown() -> void:
	var hook := HeroAssets.new()
	for def in ClassDef.all():
		var plain := _shown_core(hook, def.id, {"class": def.color})
		var paints := ["paint_any_cobalt"]
		for id in Cosmetics.for_slot("paint", def.id):
			if Cosmetics.row(id).get("starter", false):
				paints.append(id)
		for id in paints:
			var tint: Color = Cosmetics.row(id)["tint"]
			var painted := _shown_core(hook, def.id, {"class": def.color, "paint": tint})
			# Both colours sit before the plate texture, so the full paint is the lifted tint.
			var full := _lifted(tint)
			var gap := distance(plain, full)
			var pull := (gap - distance(painted, full)) / maxf(gap, 0.001)
			_report("B shown %s %s" % [def.id, id], pull >= SHOWN_PULL,
				"Core renders %s unpainted, %s with %s: pulled %.2f of the way, needs %.2f" % [plain.to_html(false), painted.to_html(false), tint.to_html(false), pull, SHOWN_PULL])
	hook.free()
