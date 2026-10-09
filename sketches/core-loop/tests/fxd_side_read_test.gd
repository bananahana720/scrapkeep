# 2026-10-09 VX-FX: GPUParticles3D casts (base class settings on the process material); the Underlight is retired (SEEDS:88 no rim glow), the check now pins no light and a sandstone puff.
extends SceneTree

const Fx := preload("res://src/presentation/dig_fx.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Palette := preload("res://src/core/palette.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("fxd_side_read_test")
	Preset.apply("high")
	var stage := Node3D.new()
	root.add_child(stage)
	var fx := Fx.new()
	stage.add_child(fx)
	fx.prepare(stage, null)
	fx.set_process(false)
	var cover := Node3D.new()
	stage.add_child(cover)
	cover.set_meta("home", Vector3.ZERO)
	var skin := Node3D.new()
	skin.name = "BreachSkin"
	cover.add_child(skin)
	for i in 3:
		var wedge := MeshInstance3D.new()
		wedge.mesh = BoxMesh.new()
		wedge.material_override = fx.lamp_material("steel", null)
		wedge.position = Vector3(cos(i * TAU / 3.0), 0, sin(i * TAU / 3.0))
		wedge.set_meta("wedge", true)
		skin.add_child(wedge)
	fx._rupture("probe", cover, Vector3.ZERO)
	var burst: Node3D = fx.bursts[0].node
	var dust: GPUParticles3D = burst.get_node("Dust")
	var debris: GPUParticles3D = burst.get_node("Debris")
	var dust_pm := dust.process_material as ParticleProcessMaterial
	var debris_pm := debris.process_material as ParticleProcessMaterial
	t.check("dust spans the rim rather than a small puff", dust_pm.scale_min >= 2.5 and dust_pm.scale_max >= 4.0)
	var rise := debris_pm.initial_velocity_min * cos(deg_to_rad(debris_pm.spread)) * 0.18 + debris_pm.gravity.y * 0.18 * 0.18 * 0.5
	t.check("slowest debris clears rim by a metre at capture time", rise >= 1.0, "rise %.3f m" % rise)
	t.check("no light and no glow puff in the burst: the puff is sandstone", burst.find_children("*", "Light3D", true, false).is_empty()
		and burst.get_node_or_null("Glow") == null and FxLibrary.colour("dig_dust", "breach_opened") == Palette.SANDSTONE)
	fx._process(0.18)
	fx.freeze_rupture(0.18)
	t.check("mid-rupture capture freezes the particle clocks", burst.get_children().all(func(p): return p.speed_scale == 0))
	fx._frozen = false
	fx._process(0.4)
	fx._process(0.5)
	await process_frame
	t.check("burst expires with the rupture", not is_instance_valid(burst))
	stage.free()
	quit(t.verdict())
