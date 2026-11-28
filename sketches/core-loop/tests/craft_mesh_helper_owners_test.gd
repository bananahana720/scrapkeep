extends SceneTree


const T := preload("res://tests/support/t.gd")
const SCULPTOR := "res://src/presentation/craft/hero_kitbash_sculptor.gd"

var _t := T.new("craft_mesh_helper_owners_test")


func _initialize() -> void:
	var mask_helper := RegEx.create_from_string("func _?vc\\(")
	var bolt_helper := RegEx.create_from_string("func _?bolt_ring\\(")
	var uv_defs := []
	var mask_defs := []
	var bolt_defs := []
	for path in _scripts("res://src/"):
		var text := FileAccess.get_file_as_string(path)
		if text.contains("func _uv_for(") or text.contains("func planar_uv("):
			uv_defs.append(path)
		if mask_helper.search(text) != null:
			mask_defs.append(path)
		if bolt_helper.search(text) != null:
			bolt_defs.append(path)
	_t.check("HeroKitbashSculptor.planar_uv is the one planar UV projection", uv_defs == [SCULPTOR], str(uv_defs))
	_t.check("CraftLookdev.encode_mask is the one vertex-mask encoder", mask_defs.is_empty(), str(mask_defs))
	_t.check("HeroKitbashSculptor.bolt_ring is the one bolt ring", bolt_defs == [SCULPTOR], str(bolt_defs))
	quit(_t.verdict())


static func _scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + sub + "/"))
	return out
