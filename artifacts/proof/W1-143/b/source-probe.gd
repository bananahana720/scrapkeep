extends "res://tests/prim_census_test.gd"

func _station(area: String, where: Node, ready: bool) -> void:
    super._station(area, where, ready)
    if not ready:
        return
    if area == "menu/ending":
        _ending_sources(where)
    elif area == "menu/title":
        var flood = where.get_node("Flood")
        print("ORIGIN ", JSON.stringify({"station":area, "kind":"flood", "has_cycle":flood.cycle != null, "basin":flood.basin,"visible":flood.is_visible_in_tree()}))
    elif area.begins_with("event/"):
        var seen := {}
        for n in where.find_children("*","MeshInstance3D",true,false):
            if n.mesh is QuadMesh and n.is_visible_in_tree() and String(n.name).begins_with("@") and PrimCensus.owner_of(n) == "site_markers.gd":
                var material := n.material_override as ShaderMaterial
                var kind := str(n.get_meta("kind",""))
                if not seen.has(kind):
                    seen[kind] = true
                    print("ORIGIN ", JSON.stringify({"station":area,"kind":"anonymous plume","site":kind,"shader":material.shader.resource_path if material != null and material.shader != null else ""}))

func _ending_sources(ending: Node) -> void:
    var game = ending.game
    var stage = game.ctx.terrain.geometry_root(2)
    var sources := {}
    var pin := PrimCensus.load_pin()
    for n in stage.find_children("*","MeshInstance3D",true,false):
        if not n.mesh is PrimitiveMesh:
            continue
        var id:int=n.mesh.get_instance_id()
        if not sources.has(id):
            sources[id] = []
        sources[id].append(n)
    var unique := {}
    for n in ending.find_children("*","MeshInstance3D",true,false):
        if not n.mesh is PrimitiveMesh or not n.is_visible_in_tree():
            continue
        var copied:=PrimCensus.shape_of(str(root.get_path_to(n)))
        var k:String=n.mesh.get_class()+"|"+copied
        if unique.has(k):
            continue
        unique[k] = true
        for orig in sources.get(n.mesh.get_instance_id(),[]):
            if orig.material_override != n.material_override or orig.transform != n.transform:
                continue
            var source: String = str(root.get_path_to(orig))
            var owner:=PrimCensus.owner_of(orig)
            var shape:=PrimCensus.shape_of(source)
            var policy:= PrimCensus.pin_for({"owner":owner,"mesh":n.mesh.get_class(),"shape":shape},pin)
            print("ORIGIN ", JSON.stringify({"station":"menu/ending","kind":"snapshot","mesh":n.mesh.get_class(),"copy_shape":copied,"source_path":source,"owner":owner,"shape":shape,"pin":policy.get("why",""),"size":str(n.mesh.get_aabb().size)}))
            break
