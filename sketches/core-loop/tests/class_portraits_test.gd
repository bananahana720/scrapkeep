extends SceneTree

const T := preload("res://tests/support/t.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const Icons := preload("res://src/core/icons.gd")
const PORTRAITS := {"pylon_engineer": "cls_sable", "runner_gunner": "cls_rivet", "demolitions_caster": "cls_kest",
	"tarn": "cls_tarn", "tally": "cls_tally", "remembered_cannon": "cls_cannon"}
const NEW_GLYPHS := {"cls_tarn": "cross", "cls_tally": "square", "cls_cannon": "lane"}
const SIDE := 28


func _initialize() -> void:
	var t := T.new("class_portraits_test")
	t.eq("canonical registry unchanged", Icons.IDS.size(), 70)
	for id in NEW_GLYPHS:
		t.check("extra " + id, Icons.EXTRA.has(id) and not Icons.IDS.has(id), "later portrait stays outside IDS")
		t.eq("fallback " + id, Icons.glyph_of(id), NEW_GLYPHS[id])
	var hashes := {}
	var classes := ClassDef.all()
	t.eq("six portraits", classes.size(), PORTRAITS.size())
	for def in classes:
		var id := Icons.class_icon_id(def.id)
		t.eq("mapping " + def.id, id, PORTRAITS.get(def.id, ""))
		var path := Icons.ICON_DIR + id + ".svg"
		t.check("file " + id, FileAccess.file_exists(path), path)
		var texture := Icons.texture(id)
		t.check("texture " + id, texture != null and Icons.from_file(id), "SVG loaded, no procedural fallback")
		var card := ClassCard.new(def)
		t.check("card " + id, card._glyph.texture == texture and card._glyph.modulate == Color.WHITE
			and card._glyph.custom_minimum_size.x >= SIDE and card._glyph.custom_minimum_size.y >= SIDE,
			"portrait keeps its colours and minimum 28 px size")
		card.free()
		var image := Image.new()
		var error := image.load_svg_from_buffer(FileAccess.get_file_as_bytes(path), float(SIDE) / Icons.SIZE)
		if t.check("raster " + id, error == OK and image.get_width() == SIDE and image.get_height() == SIDE, "28 px SVG raster"):
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(image.get_data())
			hashes[id] = digest.finish().hex_encode()
	t.eq("six raster hashes", hashes.size(), PORTRAITS.size())
	var ids := hashes.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			t.check("distinct %s / %s" % [ids[i], ids[j]], hashes[ids[i]] != hashes[ids[j]], "28 px pixel SHA-256 differs")
	quit(t.verdict())
