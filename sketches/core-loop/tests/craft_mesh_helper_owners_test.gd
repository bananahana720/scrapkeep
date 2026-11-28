extends SceneTree


const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")
const SCULPTOR := "res://src/presentation/craft/hero_kitbash_sculptor.gd"

var _t := T.new("craft_mesh_helper_owners_test")


func _initialize() -> void:
	var uv_defs := []
	var mask_defs := []
	var bolt_defs := []
	var scripts := SourceScan.sources(_t, ["res://src"])
	for path in scripts:
		var text: String = scripts[path]
		if text.contains("func _uv_for(") or text.contains("func planar_uv("):
			uv_defs.append(path)
		if not SourceScan.search(_t, text, "func _?vc\\(").is_empty():
			mask_defs.append(path)
		if not SourceScan.search(_t, text, "func _?bolt_ring\\(").is_empty():
			bolt_defs.append(path)
	_t.check("HeroKitbashSculptor.planar_uv is the one planar UV projection", uv_defs == [SCULPTOR], str(uv_defs))
	_t.check("CraftLookdev.encode_mask is the one vertex-mask encoder", mask_defs.is_empty(), str(mask_defs))
	_t.check("HeroKitbashSculptor.bolt_ring is the one bolt ring", bolt_defs == [SCULPTOR], str(bolt_defs))
	quit(_t.verdict())

