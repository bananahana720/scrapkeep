extends SceneTree

const Fx := preload("res://src/presentation/dig_fx.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")


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
	var dust: CPUParticles3D = burst.get_node("Dust")
	var debris: CPUParticles3D = burst.get_node("Debris")
	t.check("dust spans the rim rather than a small puff", dust.scale_amount_min >= 2.5 and dust.scale_amount_max >= 4.0)
	var rise := debris.initial_velocity_min * cos(deg_to_rad(debris.spread)) * 0.18 + debris.gravity.y * 0.18 * 0.18 * 0.5
	t.check("slowest debris clears rim by a metre at capture time", rise >= 1.0, "rise %.3f m" % rise)
	var light := burst.find_child("Underlight", true, false) as OmniLight3D
	t.check("brief below-rim light exposes the broken opening", light != null and light.position.y < 0 and light.light_energy >= 2.0 and light.omni_range >= 8.0)
	fx._process(0.18)
	fx.freeze_rupture(0.18)
	t.check("mid-rupture capture retains underlight", light != null and light.light_energy > 0.5)
	fx._frozen = false
	fx._process(0.4)
	t.check("underlight extinguishes before dust cleanup", light != null and is_zero_approx(light.light_energy))
	fx._process(0.5)
	await process_frame
	t.check("burst and light expire together", not is_instance_valid(burst) and not is_instance_valid(light))
	stage.free()
	quit(t.verdict())
