extends SceneTree

const T := preload("res://tests/support/t.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Juice := preload("res://src/presentation/juice.gd")
const HitStopBudget := preload("res://src/core/hit_stop_budget.gd")
const ComicPage := preload("res://src/ui/comic_page.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const DefenceBars := preload("res://tests/support/defence_bars.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

const MIN_COLOR_LAW_DE := 35.0
const HAZARD_CLEAR_DE := 25.0
const KIND_LOW := 300.0
const KIND_HIGH := 330.0

var _t := T.new("borderlands_look_test")


class StubCamera extends Node3D:
	const PROFILES := ChaseCamera.PROFILES
	var profiles := []
	var punches: Array = []
	var kicks: Array = []
	var shakes: Array = []

	func active_profiles() -> Array:
		return profiles

	func punch_fov(amount: float, time: float) -> void:
		punches.append([amount, time])

	func kick(direction: Vector3, amount: float) -> void:
		kicks.append([direction, amount])

	func shake(amount: float, time := 0.4) -> void:
		shakes.append([amount, time])


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InkOutline.reset_for_tests()
	WorldLook.reset_for_tests()
	_ink_boss_and_fade()
	_world23_contrast()
	_comic_page_punch()
	_juice_impact_zoom()
	InkOutline.reset_for_tests()
	WorldLook.reset_for_tests()
	quit(_t.verdict())


func _cube(slot := "paint") -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().surface_get_arrays(0))
	mesh.surface_set_name(0, slot)
	return mesh


func _body() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.RUST
	return mat


func _ink_boss_and_fade() -> void:
	_t.check("boss role registered in ROLES, WIDTH_PX, WIDTH_CAP, and FADE_RANGE",
		"boss" in InkOutline.ROLES and InkOutline.WIDTH_PX.has("boss")
		and InkOutline.WIDTH_CAP.has("boss") and InkOutline.FADE_RANGE.has("boss"))
	_t.check("ink weights ascend pilot < enemy < warden < boss",
		InkOutline.WIDTH_PX.pilot < InkOutline.WIDTH_PX.enemy
		and InkOutline.WIDTH_PX.enemy < InkOutline.WIDTH_PX.warden
		and InkOutline.WIDTH_PX.warden < InkOutline.WIDTH_PX.boss)
	_t.check("ink metre caps ascend pilot < enemy < warden < boss",
		InkOutline.WIDTH_CAP.pilot < InkOutline.WIDTH_CAP.enemy
		and InkOutline.WIDTH_CAP.enemy < InkOutline.WIDTH_CAP.warden
		and InkOutline.WIDTH_CAP.warden < InkOutline.WIDTH_CAP.boss)
	_t.check("role_for routes Brindle, Waking, and Mind to boss role",
		InkOutline.role_for("brindle") == "boss" and InkOutline.role_for("waking") == "boss"
		and InkOutline.role_for("mind") == "boss" and InkOutline.role_for("boss") == "boss"
		and InkOutline.role_for("warden") == "warden" and InkOutline.role_for("pilot") == "pilot"
		and InkOutline.role_for("chaser") == "enemy")
	var boss_ink := InkOutline.ink("boss")
	_t.check("boss ink shader binds boss width, cap, and extended fade",
		is_equal_approx(float(boss_ink.get_shader_parameter("width_px")), InkOutline.WIDTH_PX.boss)
		and is_equal_approx(float(boss_ink.get_shader_parameter("width_cap")), InkOutline.WIDTH_CAP.boss)
		and float(boss_ink.get_shader_parameter("fade_to")) > 150.0)
	_t.check("boss contour stays readable at close brawl range and 150 m then fades out",
		InkOutline.width_at("boss", 8.0, 0.01) > InkOutline.width_at("warden", 8.0, 0.01)
		and InkOutline.width_at("boss", 150.0, 0.01) > 0.0
		and InkOutline.width_at("boss", 185.0, 0.01) == 0.0)
	_t.check("pilot and enemy silhouettes remain readable out to long range",
		InkOutline.width_at("pilot", 120.0, 0.01) > 0.0 and InkOutline.width_at("enemy", 120.0, 0.01) > 0.0)
	_t.check("hazard rims and weak points are never occluded by ink outlines",
		not InkOutline.drawable(_cube("hazard_rim"), 0, _body())
		and not InkOutline.drawable(_cube("weak_point_hatch"), 0, _body())
		and not InkOutline.drawable(_cube("paint"), 0, PaletteMaterials.hazard_stripe()))
	var boss_view := MeshInstance3D.new()
	boss_view.mesh = _cube("paint")
	boss_view.material_override = _body()
	var lined := InkOutline.apply(boss_view, "boss")
	_t.check("apply with boss role attaches boss ink pass cleanly",
		lined == 1 and boss_view.material_override.next_pass == InkOutline.ink("boss"))
	boss_view.free()


func _colours_in(value, out: Array) -> Array:
	if value is Color:
		out.append(value)
	elif value is Dictionary:
		for key in value:
			_colours_in(value[key], out)
	return out


func _in_kindness(c: Color) -> bool:
	return c.s > 0.2 and c.h * 360.0 >= KIND_LOW and c.h * 360.0 <= KIND_HIGH


func _world23_contrast() -> void:
	var dig: Dictionary = WorldLook.ROWS[2]
	var waking: Dictionary = WorldLook.ARENAS.waking
	var highdraft: Dictionary = WorldLook.ROWS[3]
	var mind: Dictionary = WorldLook.ARENAS.mind
	var pit: Dictionary = WorldLook.stage_look(3, 2, "park_pit")
	_t.check("World 2 Dig separates warm subterranean amber from cool slate shadow",
		(dig.ambient as Color).b > (dig.ambient as Color).r
		and (dig.sun_color as Color).r > (dig.sun_color as Color).b
		and float(dig.saturation) >= 1.2 and float(dig.lamps.energy) >= 5.0
		and DefenceBars.cie76(dig.sun_color, dig.ambient) >= MIN_COLOR_LAW_DE)
	_t.check("World 2 park pit lifts saturation with crisp cool sky fill",
		pit.sky == "hdri" and float(pit.saturation) >= 1.2 and (pit.fill_color as Color).b > (pit.fill_color as Color).r)
	_t.check("Waking arena separates warm amber floor pools against cool slate shadow while keeping 0.16 ambient",
		is_equal_approx(float(waking.energy), 0.16)
		and (waking.ambient as Color).b > (waking.ambient as Color).r
		and waking.floor_accent == Palette.AMBER
		and DefenceBars.cie76(waking.floor_accent, waking.ambient) >= MIN_COLOR_LAW_DE
		and DefenceBars.cie76(waking.floor_accent, waking.fog.color) >= MIN_COLOR_LAW_DE)
	_t.check("World 3 Highdraft sharpens golden-hour saturation and warm-key vs cool-fill contrast",
		float(highdraft.saturation) >= 1.2 and float(highdraft.air.volumetric_fog_anisotropy) > 0.6
		and DefenceBars.cie76(highdraft.sun_color, highdraft.fill_color) >= MIN_COLOR_LAW_DE)
	_t.check("Mind arena pairs dusk violet sky, amber key, and uranium seam accent with crisp saturation",
		float(mind.saturation) >= 1.2 and mind.ambient == Color("9097bd")
		and mind.seam_accent == Palette.ANCIENT
		and (mind.grade.top as Color).b > (mind.grade.top as Color).r
		and (mind.grade.horizon as Color).r > (mind.grade.horizon as Color).b
		and DefenceBars.cie76(mind.seam_accent, mind.grade.top) >= MIN_COLOR_LAW_DE
		and DefenceBars.cie76(mind.sun_color, mind.grade.top) >= MIN_COLOR_LAW_DE)
	var bad_law := []
	for pair in [["dig", dig], ["waking", waking], ["highdraft", highdraft], ["mind", mind]]:
		for c: Color in _colours_in(pair[1], []):
			var solid := Color(c, 1.0)
			if DefenceBars.cie76(solid, Palette.HAZARD) < HAZARD_CLEAR_DE:
				bad_law.append("%s near HAZARD %s" % [pair[0], c.to_html(false)])
			if _in_kindness(solid):
				bad_law.append("%s in Kindness purple %s" % [pair[0], c.to_html(false)])
	_t.eq("World 2 and 3 lighting stays clear of HAZARD and Kindness purple", bad_law, [])
	var src := FileAccess.get_file_as_string("res://src/presentation/world_look.gd")
	_t.check("NightShift Forward+ Light3D lifetime guard comment and go_dark remain intact",
		src.contains("# Light3D freed with a stage crashes Godot 4.7.2 Forward+ on the next boss entry.")
		and src.contains("lights.go_dark()"))


func _comic_page_punch() -> void:
	_t.check("LOSS_CARDS expanded with zero exclamation marks and clean voice",
		ComicPage.LOSS_CARDS.size() >= 6
		and ComicPage.LOSS_CARDS.all(func(line: String) -> bool:
			return line != "" and not line.contains("!") and not line.contains("...") and not line.contains(":")))
	_t.check("WIN_STAMPS provide crisp win punctuation without HIRED, PAID, or exclamation marks",
		ComicPage.WIN_STAMPS.size() >= 3
		and ComicPage.WIN_STAMPS.all(func(s: String) -> bool:
			return s != "" and s != "PAID" and s != "HIRED" and not s.contains("!") and s.split(" ").size() <= 3))
	_t.check("win_stamp appears only on won runs and is deterministic",
		ComicPage.win_stamp({"run_id": "win-7", "won": true}) != ""
		and ComicPage.win_stamp({"run_id": "win-7", "won": true}) == ComicPage.win_stamp({"run_id": "win-7", "won": true})
		and ComicPage.win_stamp({"run_id": "loss-7", "won": false}) == "")
	var poly := ComicPage.burst_polygon(Vector2(100.0, 100.0), 40.0, 0)
	_t.eq("burst_polygon emits alternating spikes and valleys", poly.size(), ComicPage.BURST_POINTS * 2)
	_t.check("caption and win stamp inks hold at least 4.5:1 contrast",
		UiTokens.contrast(ComicPage.INK_COLOR, Palette.LEDGER_CREAM) >= 4.5
		and UiTokens.contrast(ComicPage.INK_COLOR, Palette.AMBER) >= 4.5
		and UiTokens.contrast(Palette.LEDGER_CREAM, ComicPage.INK_COLOR) >= 4.5)
	var cp := ComicPage.new()
	cp.size = Vector2(540.0, 720.0)
	root.add_child(cp)
	cp.show_page({"run_id": "win-9", "won": true, "pilot_name": "Sable", "world": 2, "world_name": "The Dig",
		"title": "THE DIG SHIFT", "panels": [
			{"kind": "opening", "caption": "Dropped into the shaft.", "sfx": "KRAK", "size": "wide", "world": 2},
			{"kind": "finale", "caption": "Core cracked on the bell.", "sfx": "THOOM", "size": "wide", "world": 2},
		]})
	var stamp_box := ComicPage.win_stamp_rect(Rect2(0.0, 0.0, 480.0, 220.0), ComicPage.win_stamp(cp.page), 540.0 / 720.0)
	_t.check("win stamp rect fits cleanly inside finale panel",
		Rect2(0.0, 0.0, 480.0, 220.0).encloses(stamp_box))
	cp.free()


func _juice_impact_zoom() -> void:
	var juice := Juice.new()
	var cam := StubCamera.new()
	juice.camera = cam
	root.add_child(cam)
	root.add_child(juice)
	var zoom := juice.impact_zoom("heavy")
	_t.check("2-frame impact zoom punches FOV in cleanly within cap and duration",
		zoom < 0.0 and absf(zoom) <= Juice.IMPACT_ZOOM_CAP and cam.punches.size() == 1
		and is_equal_approx(float(cam.punches[0][0]), zoom)
		and is_equal_approx(float(cam.punches[0][1]), Juice.IMPACT_ZOOM_S)
		and Juice.IMPACT_ZOOM_FRAMES == 2)
	_t.eq("unknown impact zoom fact sends no punch", juice.impact_zoom("unlisted_fact"), 0.0)
	cam.profiles = ["locked"]
	_t.check("normal profile effective_shake_cap stays within 1.2 and SHAKE_CAP",
		juice.effective_shake_cap() <= 1.2 and is_equal_approx(juice.effective_shake_cap(), Juice.SHAKE_CAP))
	cam.profiles = ["boss"]
	_t.check("boss/warden profile effective_shake_cap stays within 0.6 and SHAKE_CAP",
		juice.effective_shake_cap() <= 0.6 and is_equal_approx(juice.effective_shake_cap(), Juice.SHAKE_CAP))
	juice.request_shake(1.8, 0.2, "probe")
	_t.check("request_shake clamps strictly inside effective_shake_cap",
		cam.shakes.size() == 1 and float(cam.shakes[0][0]) <= 0.6 and float(cam.shakes[0][0]) <= Juice.SHAKE_CAP)
	juice.hit_stops.reset()
	juice._on_harpoon_bit(null, Vector3.ZERO)
	juice.hit_stops.reset()
	juice._on_weak_point("hatch_0")
	_t.check("harpoon bite and boss weak point trigger crisp 2-frame zoom punches within hitstop clamp",
		cam.punches.size() == 3 and float(cam.punches[1][0]) < 0.0 and float(cam.punches[2][0]) < 0.0
		and is_equal_approx(float(cam.punches[1][1]), Juice.IMPACT_ZOOM_S)
		and is_equal_approx(float(cam.punches[2][1]), Juice.IMPACT_ZOOM_S)
		and juice.hit_stops.entries.all(func(row: Array) -> bool: return float(row[1]) * 1000.0 <= HitStopBudget.SPINE_CAP_MS + 0.001))
	juice.free()
	cam.free()
