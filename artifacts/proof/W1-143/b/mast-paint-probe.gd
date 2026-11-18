extends SceneTree

const Flood := preload("res://src/world/flood.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Cycle := preload("res://src/world/flood_cycle.gd")

func _initialize() -> void:
    call_deferred("_measure")

func _measure() -> void:
    var water := Flood.new()
    root.add_child(water)
    water.setup()
    var initially_dry := not water.is_visible_in_tree()
    water.cycle = Cycle.new()
    var foot := Vector3(12.0, 2.0, 30.0)
    water.configure({"plane_size":Vector2(24,32), "plane_centre":Vector2(2,6),
        "centre":Vector2(2,6), "radius":12.0, "depth":4.0}, -5.0, foot)
    water.cycle.phase = Cycle.HIGH
    water.render()
    var mast := water.get_node_or_null("KlaxonMast") as Node3D
    var shape: MeshInstance3D
    if mast is MeshInstance3D:
        shape = mast
    elif mast != null:
        var models := mast.find_children("*","MeshInstance3D",true,false)
        if not models.is_empty():
            shape = models[0]
    var bulb := water.get_node_or_null("KlaxonBulb") as MeshInstance3D
    var plane := water.get_node_or_null("WaterSurface") as MeshInstance3D
    var checks := {
        "hidden_before_configure":initially_dry,
        "model_in_configured_basin":shape != null and shape.mesh is ArrayMesh and shape.is_visible_in_tree(),
        "mast_uses_authored_vertex_paint":shape != null and ParkProps.colour_errors(shape.mesh,"siren mast",shape).is_empty(),
        "mast_at_foot":mast != null and mast.position.is_equal_approx(foot),
        "lamp_at_warning_height":bulb != null and bulb.position.is_equal_approx(foot + Vector3.UP * 17.0),
        "water_matches_simulation":plane != null and is_equal_approx(plane.position.y,water.surface_y()),
    }
    water.configure({},0.0,Vector3.ZERO)
    checks["empty_basin_clears_geometry"] = not water.is_visible_in_tree()
    water.free()
    print("FLOOD_CHECKS ",JSON.stringify(checks))
    quit(1 if false in checks.values() else 0)
