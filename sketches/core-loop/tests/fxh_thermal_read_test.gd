extends SceneTree

const Fx := preload("res://src/presentation/highdraft_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("fxh_thermal_read_test")
	var fx := Fx.new()
	root.add_child(fx)
	fx._thermal({"base": Vector3.ZERO, "height": 40.0, "radius": 5.0, "state": "idle"}, Fx._shader("thermal_rise.gdshader"))
	var row: Dictionary = fx.thermals[0]
	var marker: Mesh = row.views[1].multimesh.mesh
	var width: float = maxf(marker.get_aabb().size.x, marker.get_aabb().size.z)
	var pixels := width / 20.0 * 1920.0 / (2.0 * tan(deg_to_rad(60.0) * 0.5))
	t.check("lift arrows span at least 40 pixels from 20 m", pixels >= 40.0, "projected width %.1f px" % pixels)
	t.check("idle lift markers retain solid contrast", row.material.get_shader_parameter("idle_opacity") != null and float(row.material.get_shader_parameter("idle_opacity")) >= 0.7)
	t.check("occupied lift markers remain readable", row.material.get_shader_parameter("occupied_opacity") != null and float(row.material.get_shader_parameter("occupied_opacity")) >= 0.9)
	t.eq("thermal highlight reads existing lift role", row.material.get_shader_parameter("lift_tint"), EventKinds.world_row("thermal_ride").color)
	t.eq("thermal silhouettes use palette verdigris", row.material.get_shader_parameter("edge_tint"), Palette.VERDIGRIS)
	t.check("thermal uses upward chevrons instead of thin lines", marker is ArrayMesh and marker.get_aabb().size.y >= 0.65)
	fx.free()
	quit(t.verdict())
