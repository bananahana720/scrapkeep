extends SceneTree

const T := preload("res://tests/support/t.gd")
const TierMark := preload("res://src/build/tier_mark.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")
const Accretion := preload("res://src/build/accretion.gd")
const ShopTile := preload("res://src/ui/shop_tile.gd")
const Palette := preload("res://src/core/palette.gd")

# W1-26: an item tier reads by shape as well as colour (VISUAL-LANGUAGE sections 2 and 5).
# Each rung has its own TierMark shape; a pedestal gem is the rung's upright mark, a ball part
# piece stands on the rung's foot (none for common), and the shop's four frames differ by
# shape (lines, corner marks, dashing), never by colour or line width alone.

var _t := T.new("tier_mark_test")


func _initialize() -> void:
	_check_shapes()
	_check_marks()
	_check_feet()
	_check_pieces()
	_check_frames()
	quit(_t.verdict())


func _check_shapes() -> void:
	var shapes := {}
	for id in ItemGen.RARITIES:
		shapes[TierMark.shape_of(id)] = id
	_t.check("four rungs, four shapes", shapes.size() == ItemGen.RARITIES.size(), str(shapes))
	_t.eq("an old id wears the rung it folds into", TierMark.shape_of("rare_plus"), TierMark.shape_of("relic"))
	_t.eq("an unknown id reads as common", TierMark.shape_of("nope"), TierMark.shape_of("common"))


# A mark's silhouette as its mesh kinds, mesh count and bounds, rounded to a centimetre.
func _signature(node: Node3D) -> String:
	var kinds := PackedStringArray()
	var box := AABB()
	var first := true
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		kinds.append(m.mesh.get_class())
		var b := m.transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	kinds.sort()
	return "%s %s" % [",".join(kinds), (box.size * 100.0).round()]


func _mints(node: Node3D) -> int:
	var n := 0
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if m.material_override is StandardMaterial3D and m.material_override.albedo_color == Palette.ARC:
			n += 1
	return n


func _check_marks() -> void:
	var sigs := {}
	var mat := Palette.solid(Palette.SAND)
	for id in ItemGen.RARITIES:
		var mark := TierMark.mark(id, mat)
		sigs[_signature(mark)] = id
		mark.free()
	_t.check("each rung's upright mark has its own silhouette", sigs.size() == ItemGen.RARITIES.size(), str(sigs))
	var relic := TierMark.mark("relic", mat)
	_t.check("the relic mark has a mint heart", _mints(relic) == 1)
	relic.free()
	var crown := TierMark.mark("evolved", mat)
	var points := crown.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.mesh is CylinderMesh).size()
	_t.eq("the evolved crown stands its points", points, TierMark.CROWN_POINTS)
	crown.free()


func _check_feet() -> void:
	var mat := Palette.solid(Palette.SAND)
	_t.check("a common piece has no foot", TierMark.foot("common", mat) == null)
	var sigs := {}
	for id in ["rare", "relic", "evolved"]:
		var foot := TierMark.foot(id, mat)
		sigs[_signature(foot)] = id
		foot.free()
	_t.check("rare, relic and evolved feet differ in shape", sigs.size() == 3, str(sigs))


# One part per rung, built as the ball draws it: the foot under it names the rung's shape.
func _check_pieces() -> void:
	var by_rarity := {}
	for id in Parts.rows():
		var r := Parts.rarity_of(id)
		if not by_rarity.has(r) and Parts.def(id) != null:
			by_rarity[r] = id
	for id in Parts.EVOLVED:
		if not by_rarity.has("evolved") and Parts.def(id) != null:
			by_rarity["evolved"] = id
	var acc := Accretion.new()
	var bad := []
	for r in ItemGen.RARITIES:
		if not by_rarity.has(r):
			bad.append("no %s part" % r)
			continue
		var piece: Node3D = acc._piece(by_rarity[r])
		var feet := piece.find_children("Foot_*", "Node3D", false, false)
		var want := "" if r == "common" else "Foot_" + TierMark.shape_of(r)
		var got := "" if feet.is_empty() else String(feet[0].name)
		if got != want:
			bad.append("%s %s: %s, want %s" % [r, by_rarity[r], got, want])
		piece.free()
	acc.free()
	_t.check("each ball piece stands on its rung's foot", bad.is_empty(), "%s; bad %s" % [by_rarity, bad])


# The shape keys only: two frames that match on these differ by colour or width alone.
func _check_frames() -> void:
	var shapes := {}
	for id in ItemGen.RARITIES:
		var f: Dictionary = ShopTile.RARITY[id]
		shapes["%s %s %s" % [f["double"], f["notches"], f["dashed"]]] = id
	_t.check("the four shop frames differ by shape", shapes.size() == ItemGen.RARITIES.size(), str(shapes))
