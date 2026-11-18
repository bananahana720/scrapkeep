extends SceneTree

const Card := preload("res://src/ui/class_preview.gd")
const Classes := preload("res://src/core/class_def.gd")

func _initialize() -> void:
    call_deferred("_measure")

func _measure() -> void:
    var facts := {}
    for pilot in Classes.all():
        var card := Card.new(pilot)
        root.add_child(card)
        var stationary := {}
        var roles := {}
        for i in 121:
            var rest := i == 0
            card._pose(card._rest_phase() if rest else (i-1) / 120.0)
            for child in card._viewport.get_children():
                if not child is MeshInstance3D or not child.mesh is PrimitiveMesh or not child.is_visible_in_tree():
                    continue
                var role = card._props.find_key(child)
                if role == null:
                    if child.mesh is CylinderMesh:
                        role = "turntable floor"
                    elif child.mesh is TorusMesh:
                        role = "turntable rim"
                    elif child.mesh is BoxMesh and pilot.id == "pylon_engineer":
                        role = "wall"
                    else:
                        role = "unidentified"
                var pair := "%s/%s" % [child.mesh.get_class(),role]
                roles[pair] = true
                if rest:
                    stationary[pair] = true
        facts[pilot.id] = {"rest":stationary.keys(),"loop":roles.keys()}
        card.free()
    print("PREVIEW_ROLES ",JSON.stringify(facts))
    quit(0 if facts.size() == 6 else 1)
