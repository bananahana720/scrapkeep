extends SceneTree

# Verifies all W50 3D models, wordless SVG icons, registry entries, Patch 7th pilot assets
# (Ruling dl + Ruling en cutaway-first proportions), and W50AssetHooks / AllyHuskLook presentation
# wiring with zero primitive stand-in regressions.

const W50AssetHooks := preload("res://src/presentation/w50_asset_hooks.gd")
const AllyHuskLook := preload("res://src/presentation/ally_husk_look.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Icons := preload("res://src/ui/icons.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

const NEW_GLBS := [
	# W50 Consumables
	"res://assets/models/consumables/cons_scrap_dice.glb",
	"res://assets/models/consumables/cons_duplicator_spool.glb",
	"res://assets/models/consumables/cons_overload_fuse.glb",
	# W50 Actives
	"res://assets/models/actives/act_magnet_sling_buoy.glb",
	"res://assets/models/actives/act_magnet_sling_pod.glb",
	"res://assets/models/actives/act_slag_mortar_shell.glb",
	"res://assets/models/actives/act_slag_mortar_pod.glb",
	# W50 Stations & Ingot
	"res://assets/models/stations/station_scrapper.glb",
	"res://assets/models/stations/station_part_press.glb",
	"res://assets/models/stations/station_tri_terminal.glb",
	"res://assets/models/stations/prop_scrap_ingot.glb",
	# W50 Orbitals & Relic VFX
	"res://assets/models/vfx/orbital_flywheel_sat.glb",
	"res://assets/models/vfx/relic_halo_orb.glb",
	"res://assets/models/vfx/relic_drill_auger.glb",
	"res://assets/models/vfx/relic_voltaic_halo.glb",
	"res://assets/models/vfx/relic_snare_beacon.glb",
	# Stand-in replacements & Patch 7th pilot
	"res://assets/models/world_one/sable_stake.glb",
	"res://assets/models/ally_husk/ally_husk_wreck.glb",
	"res://assets/models/pilot_patch_anim.glb",
	"res://assets/models/world_one/shell_patch.glb",
	"res://assets/models/world_one/patch_husk_sticker.glb",
]

const NEW_ICONS := [
	"cons_scrap_dice", "cons_duplicator_spool", "cons_overload_fuse", "cons_pocket_belt",
	"act_magnet_sling", "act_slag_mortar",
	"obj_scrapper", "obj_part_press", "obj_tri_terminal", "res_scrap_ingot",
	"part_orbital_flywheel", "rel_alt_loadout",
	"rel_arc_sling", "rel_voltaic_ring", "rel_fan_cylinder", "rel_drill_auger",
	"rel_thermite_dive", "rel_zip_cluster", "rel_wrecking_chain", "rel_tape_loop",
	"rel_siege_mortar", "rel_halo_coil", "rel_slotted_rail", "rel_updraft_snare",
	"lic_spillway_works", "lic_fleet_surplus", "lic_redjaw", "lic_highdraft_roosts",
	"lic_waking", "lic_mind_glass", "lic_moss",
	"cls_patch", "ab_patch_weapon", "ab_patch_move", "ab_patch_special",
	"ab_patch_smash", "ab_patch_line", "ab_patch_ult",
]

var _t := T.new("w50_3d_assets_test")


func _initialize() -> void:
	_check_glbs_and_budgets()
	_check_icons()
	_check_patch_ruling_en_and_six_pilot_invariance()
	_check_presentation_hooks()
	_check_ally_husk_wreck()
	W50AssetHooks._reset()
	quit(_t.verdict())


func _check_glbs_and_budgets() -> void:
	var hazard_hex := Palette.HAZARD.to_html(false).to_lower()
	for path in NEW_GLBS:
		_t.check("GLB exists: " + path, ResourceLoader.exists(path))
		var inst := W50AssetHooks.instantiate_prop(path, "CheckProp", false)
		_t.check("GLB instantiates cleanly: " + path, inst != null)
		if inst == null:
			continue
		var mesh_count := 0
		var tris := 0
		var draws := 0
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			mesh_count += 1
			draws += mi.mesh.get_surface_count()
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				var verts = arr[Mesh.ARRAY_VERTEX]
				if idx is PackedInt32Array and idx.size() > 0:
					tris += idx.size() / 3
				elif verts is PackedVector3Array:
					tris += verts.size() / 3
				var mat := mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					_t.check("no HAZARD albedo on " + path,
						sm.albedo_color.to_html(false).to_lower() != hazard_hex)
					if sm.emission_enabled:
						_t.check("no HAZARD emission on " + path,
							sm.emission.to_html(false).to_lower() != hazard_hex)
		_t.check("non-empty geometry in %s (%dT)" % [path, tris], mesh_count > 0 and tris > 0)
		if path == "res://assets/models/vfx/orbital_flywheel_sat.glb":
			_t.check("orbital_flywheel_sat.glb is strictly 1 draw (%dD)" % draws, draws == 1)
		inst.free()


func _check_icons() -> void:
	for id in NEW_ICONS:
		var tex: Texture2D = Icons.texture(id)
		_t.check("icon loads: " + id, tex != null)
		_t.check("icon from committed SVG: " + id, Icons.from_file(id))
		var svg_path := "res://assets/icons/%s.svg" % id
		var body := FileAccess.get_file_as_string(svg_path)
		_t.check("wordless SVG (no <text>): " + id, not body.contains("<text"))
		_t.check("no HAZARD #ff5a3c in SVG: " + id, not body.to_lower().contains("ff5a3c"))


func _check_patch_ruling_en_and_six_pilot_invariance() -> void:
	_t.check("base 6 pilots pinned", HeroAssets.PILOTS.size() == 6 and HeroAssets.SHELLS.size() == 6)
	_t.check("Patch hidden pilot registered",
		HeroAssets.HIDDEN_PILOTS.has("line_splicer") and HeroAssets.HIDDEN_SHELLS.has("line_splicer"))
	_t.check("HeroAssets.shell_path resolves Patch",
		HeroAssets.shell_path("line_splicer", "", 1, {}) == "res://assets/models/world_one/shell_patch.glb")
	var packed := load("res://assets/models/world_one/shell_patch.glb") as PackedScene
	_t.check("shell_patch.glb loads", packed != null)
	if packed != null:
		var inst := packed.instantiate()
		_t.check("shell_patch has Core", inst.find_child("Core", true, false) != null)
		_t.check("shell_patch has Pod", inst.find_child("Pod", true, false) != null)
		_t.check("shell_patch has WeaponRing", inst.find_child("WeaponRing", true, false) != null)
		_t.check("shell_patch has Dome", inst.find_child("Dome", true, false) != null)
		var max_r := 0.0
		var pod_min_y := INF
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var verts = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				if verts is PackedVector3Array:
					for v in verts:
						max_r = maxf(max_r, Vector2(v.x, v.z).length())
						if String(mi.name) in ["Pod", "WeaponRing"]:
							pod_min_y = minf(pod_min_y, v.y)
		_t.check("shell_patch horizontal reach %.2fm <= 1.75m (Ruling en)" % max_r, max_r <= 1.75)
		_t.check("shell_patch pod/weapon clearance %.2fm >= -0.55m" % pod_min_y, pod_min_y >= -0.55)
		inst.free()


func _check_presentation_hooks() -> void:
	var host := Node3D.new()
	root.add_child(host)

	# 1. ConsumableDrop_scrap_dice dressing swaps in dedicated W50 GLB.
	var drop := Node3D.new()
	drop.name = "ConsumableDrop_scrap_dice"
	var sock := Node3D.new()
	sock.name = "SocketCartridge"
	drop.add_child(sock)
	host.add_child(drop)
	_t.check("dresses W50 scrap_dice drop", W50AssetHooks.dress_consumable_drop(drop))
	_t.check("CartridgeModel mounted in SocketCartridge", sock.has_node("CartridgeModel"))

	# 2. WorldScrapper & WorldPartPress dressing mounts 3D station GLBs.
	var scrapper := Node3D.new()
	scrapper.name = "WorldScrapper"
	host.add_child(scrapper)
	_t.check("dresses WorldScrapper", W50AssetHooks.dress_station(scrapper, "scrapper"))
	_t.check("WorldScrapper gets StationModel", scrapper.has_node("StationModel"))

	var press := Node3D.new()
	press.name = "WorldPartPress"
	host.add_child(press)
	_t.check("dresses WorldPartPress", W50AssetHooks.dress_station(press, "part_press"))
	_t.check("WorldPartPress gets StationModel", press.has_node("StationModel"))

	# 3. OrbitalSatellites MultiMesh BoxMesh -> orbital_flywheel_sat.glb mesh.
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "OrbitalSatelliteMesh"
	var mm := MultiMesh.new()
	mm.mesh = BoxMesh.new()
	mmi.multimesh = mm
	host.add_child(mmi)
	_t.check("dresses OrbitalSatelliteMesh", W50AssetHooks.dress_orbital_multimesh(mmi))
	_t.check("OrbitalSatelliteMesh no longer uses BoxMesh", not (mmi.multimesh.mesh is BoxMesh))

	# 4. DroppedActive PrismMesh -> act_magnet_sling_pod.glb.
	var dropped := Node3D.new()
	dropped.name = "DroppedActive"
	dropped.set_meta("active_id", "magnet_sling")
	var prism := MeshInstance3D.new()
	prism.mesh = PrismMesh.new()
	dropped.add_child(prism)
	host.add_child(dropped)
	_t.check("dresses DroppedActive magnet_sling", W50AssetHooks.dress_dropped_active(dropped))
	_t.check("PrismMesh hidden and ActivePodModel mounted",
		prism.layers == 0 and dropped.has_node("ActivePodModel"))

	# 5. SableStakes/Stake CylinderMesh+TorusMesh -> sable_stake.glb.
	var stakes := Node3D.new()
	stakes.name = "SableStakes"
	var stake := Node3D.new()
	stake.name = "Stake"
	var cyl := MeshInstance3D.new()
	cyl.mesh = CylinderMesh.new()
	var tor := MeshInstance3D.new()
	tor.mesh = TorusMesh.new()
	stake.add_child(cyl)
	stake.add_child(tor)
	stakes.add_child(stake)
	host.add_child(stakes)
	_t.check("dresses SableStakes/Stake", W50AssetHooks.dress_sable_stake(stake))
	_t.check("SableStake stand-in primitives hidden and sable_stake.glb mounted",
		cyl.layers == 0 and tor.layers == 0 and stake.has_node("SableStakeModel"))

	host.free()


func _check_ally_husk_wreck() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var wreck := AllyHuskLook.build_wreck_marker(host, Vector3.ZERO, 1.0, false)
	_t.check("AllyHuskLook.build_wreck_marker mounts ally_husk_wreck.glb", wreck.has_node("WreckBody"))
	_t.check("AllyHuskLook.build_wreck_marker avoids BoxMesh fallback", not wreck.has_node("WreckFallback"))
	var has_prim := false
	for n in wreck.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is BoxMesh or mi.mesh is SphereMesh:
			has_prim = true
	_t.check("GhostShiftWreck has zero BoxMesh/SphereMesh primitives", not has_prim)
	host.free()
