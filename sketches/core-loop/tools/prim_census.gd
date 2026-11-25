extends RefCounted


const PIN_PATH := "res://tools/prim_census_pin.tsv"
const KINDS := ["code", "stand-in", "stand-in-live"]

var rows: Array[Dictionary] = []
var _seen := {}


func scan(root: Node, tick: int, stage: int, station := false) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if geo.layers == 0 or not geo.is_visible_in_tree():
			continue
		var mesh := _mesh_of(geo)
		if not mesh is PrimitiveMesh:
			continue
		if station and not _visible_in_screen(geo):
			continue
		var origin: Node = root.get_tree().root if station else root
		var path := String(origin.get_path_to(geo))
		var row := {"owner": owner_of(geo), "mesh": mesh.get_class(), "shape": shape_of(path)}
		row["key"] = "%s|%s|%s" % [row.owner, row.mesh, row.shape]
		if _seen.has(row.key):
			continue
		_seen[row.key] = true
		row.merge({"path": path, "tick": tick, "stage": stage, "size": mesh.get_aabb().size * geo.global_transform.basis.get_scale()})
		found.append(row)
		rows.append(row)
	return found


static func owner_of(node: Node) -> String:
	var at := node
	while at != null:
		var script := at.get_script() as Script
		if script != null and script.resource_path != "":
			return script.resource_path.get_file()
		at = at.get_parent()
	return "none"


static func shape_of(path: String) -> String:
	var names := path.split("/", false)
	var out: PackedStringArray = []
	for name in names.slice(maxi(0, names.size() - 3)):
		if name.begins_with("@"):
			out.append(name.get_slice("@", 1))
			continue
		var kept := ""
		for ch in name:
			if not ch.is_valid_int():
				kept += ch
		out.append(kept)
	return "/".join(out)


static func load_pin(path := PIN_PATH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var text := FileAccess.get_file_as_string(path)
	var line_no := 0
	for line in text.split("\n"):
		line_no += 1
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var cells := line.split("\t")
		if cells.size() != 6 or not cells[3] in KINDS or (cells[3] != "code" and cells[4] == "-") or cells[5].strip_edges() == "":
			out.append({"line": line_no, "error": "want owner, mesh, shape, kind (code, stand-in or stand-in-live), row (a BACKLOG row for a stand-in), why: %s" % line})
			continue
		out.append({"owner": cells[0], "mesh": cells[1], "shape": cells[2], "kind": cells[3], "row": cells[4], "why": cells[5], "line": line_no})
	return out


static func pin_for(row: Dictionary, pin: Array[Dictionary]) -> Dictionary:
	for p in pin:
		if p.has("error"):
			continue
		if (p.owner == "*" or p.owner == row.owner) and (p.mesh == "*" or p.mesh == row.mesh) and String(row.shape).match(p.shape):
			return p
	return {}


static func judge(census: Array[Dictionary], pin: Array[Dictionary]) -> Dictionary:
	var out := {"unlisted": [], "stand_ins": [], "stale": [], "errors": pin.filter(func(p): return p.has("error"))}
	var used := {}
	for row in census:
		var p := pin_for(row, pin)
		if p.is_empty():
			out.unlisted.append(row)
			continue
		used[p.line] = true
		if p.kind != "code":
			var hit := row.duplicate()
			hit.merge({"row": p.row, "why": p.why})
			out.stand_ins.append(hit)
	for p in pin:
		if not p.has("error") and p.kind == "stand-in" and not used.has(p.line):
			out.stale.append(p)
	return out


static func describe(row: Dictionary) -> String:
	return "%s (tick %d, stage %d, %s)" % [row.key, row.get("tick", 0), row.get("stage", 0), row.get("path", "")]


static func _mesh_of(geo: GeometryInstance3D) -> Mesh:
	if geo is MeshInstance3D:
		return (geo as MeshInstance3D).mesh
	if geo is MultiMeshInstance3D and (geo as MultiMeshInstance3D).multimesh != null:
		return (geo as MultiMeshInstance3D).multimesh.mesh
	return null

static func _visible_in_screen(node: Node) -> bool:
	var at := node.get_parent()
	while at != null:
		if at is CanvasItem and not at.is_visible_in_tree():
			return false
		if at is CanvasLayer and not at.visible:
			return false
		at = at.get_parent()
	return true
