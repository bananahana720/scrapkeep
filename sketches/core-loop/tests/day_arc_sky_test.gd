extends SceneTree

# One day per run (Andrew's design answer 14, 2026-10-17): the sky follows the stage's time of day,
# dawn in the Spillway to dusk at the Mind, and the Highdraft keeps no fixed morning. Checks the
# grade rows, the shared HDRI sky's grade on stage entry and its release, the fog lean, and the
# Mind's dusk row. Evidence limit: headless values; the look itself is judged from rendered stills
# (tools/day_arc_capture.gd) and frame times on the 4080.

const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

const EXPECTED_CHECKS := 23
var _t := T.new("day_arc_sky_test")


class Terrain extends RefCounted:
	var environment: Environment
	var root := Node3D.new()

	func _init(env: Environment) -> void:
		environment = env

	func geometry_root(_stage: int) -> Node3D:
		return root

	func map_for(_stage: int) -> RefCounted:
		return null


class StageCtx extends RefCounted:
	var terrain
	var stages = StageDefs
	var root = null
	var player = null
	var events = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_rows()
	_entry()
	_mind()
	_t.eq("every check ran", _t.checks, EXPECTED_CHECKS)
	quit(_t.verdict())


func _rows() -> void:
	var energy := {}
	for id in WorldLook.TIME_ORDER:
		var row: Dictionary = WorldLook.TIME_ROWS[id]
		var grade: Dictionary = row.get("grade", {})
		_t.check(id + " has a sky grade and a fog lean", grade.get("top") is Color and grade.get("horizon") is Color
			and grade.get("glow") is Color and grade.get("recolor") is float and grade.get("energy") is float
			and row.get("fog_tint") is Color)
		energy[id] = float(grade.get("energy", 0.0))
	_t.check("noon is at least morning, and dusk is below golden, dawn and morning, with dawn below morning", energy.noon >= energy.morning
		and energy.dusk < energy.golden and energy.dusk < energy.dawn and energy.dawn < energy.morning, str(energy))
	var dusk: Color = WorldLook.TIME_ROWS.dusk.grade.top
	var noon: Color = WorldLook.TIME_ROWS.noon.grade.top
	_t.check("the dusk zenith is darker and bluer than noon's", dusk.get_luminance() < noon.get_luminance() * 0.5 and dusk.b > dusk.r)
	var dawn_glow: Color = WorldLook.TIME_ROWS.dawn.grade.glow
	_t.check("dawn and dusk glow warm", dawn_glow.r > dawn_glow.b and (WorldLook.TIME_ROWS.dusk.grade.glow as Color).r > (WorldLook.TIME_ROWS.dusk.grade.glow as Color).b)
	var values := WorldLook.grade(WorldLook.stage_look(1, 1))
	var r: Vector3 = WorldLook.TIME_ROWS.dawn.sun_rotation
	var toward := Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), 0.0)).z
	_t.check("the glow sits under the day's sun", (values["shader_parameter/sun_dir"] as Vector3).is_equal_approx(toward)
		and toward.y > 0.0)
	_t.eq("a dome look grades no sky", WorldLook.sky_rows(WorldLook.stage_look(StageDefs.first_of(2), 2)), [])
	var high := StageDefs.last_of(3)
	_t.check("the Highdraft's base key is the late day, not a morning", WorldLook.ROWS[3].sun_color == WorldLook.TIME_ROWS.golden.sun_color
		and WorldLook.time_id(high) == "dusk" and WorldLook.time_id(StageDefs.first_of(3)) == "golden")


# Real stage hook: entering a stage grades the shared HDRI sky; moving on regrades it; the grade
# leaves with the stage's look and the sky falls back to the plain panorama defaults.
func _entry() -> void:
	var env := Environment.new()
	var ctx := StageCtx.new()
	ctx.terrain = Terrain.new(env)
	var material := PaletteMaterials.hdri_sky().sky_material as ShaderMaterial
	_t.check("the HDRI sky is the time-of-day shader over the panorama", material != null
		and (material.get_shader_parameter("panorama") as Texture2D).resource_path == PaletteMaterials.HDRI_SKY)
	var plain = material.get_shader_parameter("horizon_tint")
	WorldLook._on_stage_entered(1, false, ctx)
	_t.eq("stage 1 enters the dawn horizon", material.get_shader_parameter("horizon_tint"), WorldLook.TIME_ROWS.dawn.grade.horizon)
	var look := WorldLook.stage_look(1, 1)
	_t.check("stage 1 fog leans toward dawn", env.fog_light_color.is_equal_approx((look.fog.color as Color).lerp(look.fog_tint, 0.5))
		and not env.fog_light_color.is_equal_approx(look.fog.color), str(env.fog_light_color))
	var last := StageDefs.last_of(3)
	WorldLook._on_stage_entered(last, false, ctx)
	_t.eq("the last stage enters the dusk horizon", material.get_shader_parameter("horizon_tint"), WorldLook.TIME_ROWS.dusk.grade.horizon)
	_t.near("the last stage's sky is the dusk energy", material.get_shader_parameter("energy"), WorldLook.TIME_ROWS.dusk.grade.energy)
	GraphicsPreset.clear_lighting(env, "world")
	_t.eq("leaving the look restores the plain panorama", material.get_shader_parameter("horizon_tint"), plain)
	_t.check("the plain panorama is the shader's white default", plain == null or plain == Color.WHITE, str(plain))
	ctx.terrain.root.free()


func _mind() -> void:
	var mind: Dictionary = WorldLook.ARENAS.mind
	var dusk: Dictionary = WorldLook.TIME_ROWS.dusk
	_t.eq("the Mind's crown is on the dusk bearing", mind.sun_rotation.y, dusk.sun_rotation.y)
	_t.check("the Mind's sun is warm and low", (mind.sun_color as Color).r > (mind.sun_color as Color).b and -mind.sun_rotation.x < 20.0)
	_t.check("the Mind keeps its light level for reads", mind.energy >= 0.28 and mind.sun_energy >= 2.0)
	_t.check("the Mind grades its own sky", not WorldLook.grade(mind).is_empty())
