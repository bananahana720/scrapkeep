extends SceneTree

const Card := preload("res://src/ui/class_preview.gd")
const Classes := preload("res://src/core/class_def.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var passed := true
    for pilot in ["pylon_engineer","runner_gunner","tarn"]:
        var card := Card.new(Classes.by_id(pilot))
        root.add_child(card)
        card._pose(0.3)
        var views := {}
        for part in ["BayPin","BayYardWall","BayPost"]:
            var count := 0
            for view in card.find_children("*","MeshInstance3D",true,false):
                if view.name == part and view.mesh is ArrayMesh:
                    count += 1
            views[part] = count
        var missing := card.find_children("MissingYardPiece","MeshInstance3D",true,false)
        var right: bool = (views.BayYardWall == 1 and views.BayPost == 1) if pilot == "pylon_engineer" else views.BayPin == 3
        passed = passed and right and missing.is_empty()
        print("YARD ",JSON.stringify({"pilot":pilot,"models":views,"fallbacks":missing.size()}))
        card.free()
    quit(0 if passed else 1)
