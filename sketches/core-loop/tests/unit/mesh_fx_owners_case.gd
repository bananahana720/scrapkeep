extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const ImpactFrame := preload("res://src/presentation/impact_frame.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const LandmarkBeam := preload("res://src/presentation/landmark_beam.gd")
const WardenDress := preload("res://src/presentation/warden_dress.gd")
const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")

const WORLD23 := "res://src/presentation/world23_chunk_craft.gd"
const SETPIECE := "res://src/presentation/craft/experimental_setpiece_craft.gd"
const PBR_HELPERS := ["micro_normal_texture", "make_weathered_pbr", "enrich_standard_pbr"]
const SHARED_CRAFT := ["_dup_preset", "_new_canvas", "_add_flat_deck_slab", "_add_beveled_annulus", "_add_clean_louver"]
const PARTICLE_MOVED := ["glow", "box", "ball", "ramp", "fade", "flecks_material", "embers_material", "carve_material",
	"column_material", "boon_material"]
const DENSITY_MOVED := ["_publish_fill_scale", "_fill_scale", "_density_target", "_density_wait", "step", "publish"]
const HERO_ALIASES := ["WARDEN_BASE", "WARDEN_KITS", "WARDEN_MANTLES", "WARDEN_BODIES", "WARDEN_BODY_BLENDS", "WARDEN_BODY_CHARGE",
	"MIND_CHUNK_FINGERS"]
const PLAYER_FX_ALIASES := ["FRAME_FRAMES", "HEAT_COLOR"]
const OUTSIDE_REACH := ["PlayerFx.ImpactFrame", "PlayerFx.PauseGuard", "Vfx.PopGate"]
const SELF := "res://tests/unit/mesh_fx_owners_case.gd"
const WARDEN_MOVED := ["wears_body", "driver_count", "own_clip", "rig_mind_body", "clip_end_pose", "set_bone_pose", "play_body",
	"start_body_clip", "drive_body", "body_pulse", "body_stagger", "body_chunk", "filter_shed", "hold_mind", "track_lens",
	"update_mantle", "rig_warden_jaws", "adapt_warden_tower", "has_warden_chunk_nodes", "move_warden_fragment"]


func _src_files(dir: String, out: Array) -> Array:
	for sub in DirAccess.get_directories_at(dir):
		_src_files(dir.path_join(sub), out)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _declares(path: String, name: String) -> bool:
	var re := RegEx.new()
	re.compile("(?m)^(static )?func %s\\(" % name)
	return re.search(_text(path)) != null


func _names(path: String, name: String) -> bool:
	var re := RegEx.new()
	re.compile("(?m)^(static )?(func|const|var) %s\\b" % name)
	return re.search(_text(path)) != null


func run(t) -> void:
	var files := _src_files("res://src", [])
	var reach := []
	for path in _src_files("res://src", []) + _src_files("res://tests", []) + _src_files("res://tools", []):
		if path == SELF:
			continue
		var text := _text(path)
		for name in OUTSIDE_REACH:
			if text.contains(name):
				reach.append("%s: %s" % [path.get_file(), name])
	t.eq("no script reaches a moved name through its old owner", reach, [])
	var pbr_reach := []
	var cut_reach := []
	var bevel_reach := []
	var bare_tint := []
	for path in files:
		var text := _text(path)
		for line in text.split("\n"):
			for name in PBR_HELPERS:
				if line.contains(name + "(") and not line.contains("func " + name) and not path.ends_with("craft_lookdev.gd") \
						and not (line.contains("craft_lookdev.gd") or line.contains("Lookdev." + name)):
					pbr_reach.append("%s: %s" % [path.get_file(), line.strip_edges()])
		if text.contains("_cut_kit(") or (text.contains("_cutaway_dressed") and not path.ends_with("weapon_rig_fx.gd")):
			cut_reach.append(path.get_file())
		if text.contains("PropMeshes._bevel_box(") or text.contains("PropMeshes._bevel_cyl("):
			bevel_reach.append(path.get_file())
		if text.contains("set_instance_shader_parameter(\"tint\""):
			bare_tint.append(path.get_file())
	t.eq("every PBR helper call goes through craft_lookdev", pbr_reach, [])
	for name in PBR_HELPERS:
		t.check("craft_lookdev owns %s" % name, _declares("res://src/presentation/craft/craft_lookdev.gd", name))
		t.check("world23_chunk_craft no longer declares %s" % name, not _declares(WORLD23, name))
	for path in [WORLD23, SETPIECE]:
		for name in SHARED_CRAFT:
			t.check("%s no longer declares %s" % [path.get_file(), name], not _declares(path, name))
		t.check("%s binds materials through craft_lookdev" % path.get_file(),
			_text(path).contains("Lookdev.bind_surface_materials(mi, get_material)"))
	t.eq("no script reaches the cutaway kit or flag outside WeaponRigFx", cut_reach, [])
	t.check("BallLooks.cut_kit is public", _declares("res://src/presentation/ball_looks.gd", "cut_kit"))
	t.eq("no script calls the private bevel helpers", bevel_reach, [])
	for name in ["bevel_box", "bevel_cyl"]:
		t.check("craft_prop_meshes declares %s" % name, _declares("res://src/presentation/craft_prop_meshes.gd", name))
	t.eq("no script names the tint parameter by a bare string", bare_tint, [])
	t.eq("FxLibrary.TINT is the tint parameter", FxLibrary.TINT, &"tint")
	t.eq("Palette.INK_DEEP holds the deep ink", Palette.INK_DEEP, Color(0.07, 0.07, 0.08))
	t.eq("PlayerFx ink is the palette's deep ink", PlayerFx.INK, Palette.INK_DEEP)
	t.eq("ImpactFrame ink is the palette's deep ink", ImpactFrame.INK, Palette.INK_DEEP)
	t.eq("ImpactFrame shows for three frames", ImpactFrame.FRAMES, 3)
	var player_fx_path := "res://src/presentation/player_fx.gd"
	for name in PLAYER_FX_ALIASES:
		t.check("player_fx.gd keeps no %s alias" % name, not _names(player_fx_path, name))
	for name in PARTICLE_MOVED:
		t.check("player_fx.gd no longer declares %s" % name, not _names(player_fx_path, name) and not _names(player_fx_path, "_" + name))
	for name in DENSITY_MOVED:
		t.check("vfx.gd no longer declares %s" % name, not _names("res://src/presentation/vfx.gd", name))
	for name in ["_bevel_box", "_bevel_cyl"]:
		t.check("craft_prop_meshes.gd no longer declares %s" % name, not _names("res://src/presentation/craft_prop_meshes.gd", name))
	t.check("world23_chunk_craft.gd keeps no bind_surface_materials delegate", not _declares(WORLD23, "bind_surface_materials"))
	var player_fx := _text("res://src/presentation/player_fx.gd")
	var vfx := _text("res://src/presentation/vfx.gd")
	t.check("player_fx.gd holds no nested ImpactFrame or PauseGuard", not player_fx.contains("class ImpactFrame") and not player_fx.contains("class PauseGuard"))
	t.check("vfx.gd holds no nested PopGate", not vfx.contains("class PopGate"))
	var budget := _text("res://src/presentation/fx_budget.gd")
	t.check("fx_budget.gd declares no sparkle or beam limit of its own", not budget.contains("const SPARKLE_MAX") and not budget.contains("const BEAM_LAYERS"))
	t.eq("the sparkle ceiling lives on Vfx", Vfx.SPARKLE_CEILING, Vfx.SPARKLE_POOL * Vfx.SPARKLE_MAX)
	t.eq("the beam layers live on LandmarkBeam", LandmarkBeam.BEAM_LAYERS, 2)
	var hero := "res://src/presentation/hero_assets.gd"
	for name in WARDEN_MOVED:
		t.check("warden_dress owns %s" % name, _declares("res://src/presentation/warden_dress.gd", name))
		t.check("hero_assets no longer declares _%s" % name, not _declares(hero, "_" + name))
	for name in HERO_ALIASES:
		t.check("hero_assets keeps no %s alias" % name, not _names(hero, name))
	t.check("hero_assets reads its Warden tables from warden_dress", _text(hero).contains("WardenDress.BODIES["))
