extends Node3D

const InkOutline := preload("res://src/presentation/ink_outline.gd")

const CONSUMABLE_MODELS := {
	"scrap_dice": "res://assets/models/consumables/cons_scrap_dice.glb",
	"duplicator_spool": "res://assets/models/consumables/cons_duplicator_spool.glb",
	"overload_fuse": "res://assets/models/consumables/cons_overload_fuse.glb",
}

const ACTIVE_POD_MODELS := {
	"magnet_sling": "res://assets/models/actives/act_magnet_sling_pod.glb",
	"slag_mortar": "res://assets/models/actives/act_slag_mortar_pod.glb",
}

const ACTIVE_WORLD_MODELS := {
	"magnet_sling": "res://assets/models/actives/act_magnet_sling_buoy.glb",
	"slag_mortar": "res://assets/models/actives/act_slag_mortar_shell.glb",
}

const STATION_MODELS := {
	"scrapper": "res://assets/models/stations/station_scrapper.glb",
	"part_press": "res://assets/models/stations/station_part_press.glb",
	"tri_terminal": "res://assets/models/stations/station_tri_terminal.glb",
	"scrap_ingot": "res://assets/models/stations/prop_scrap_ingot.glb",
}

const ORBITAL_MODEL := "res://assets/models/vfx/orbital_flywheel_sat.glb"
const SABLE_STAKE_MODEL := "res://assets/models/world_one/sable_stake.glb"

const RELIC_VFX_MODELS := {
	"halo_orb": "res://assets/models/vfx/relic_halo_orb.glb",
	"drill_auger": "res://assets/models/vfx/relic_drill_auger.glb",
	"voltaic_halo": "res://assets/models/vfx/relic_voltaic_halo.glb",
	"snare_beacon": "res://assets/models/vfx/relic_snare_beacon.glb",
	"mortar_shell": "res://assets/models/actives/act_slag_mortar_shell.glb",
}

const PATCH_ASSETS := {
	"pilot": "res://assets/models/pilot_patch_anim.glb",
	"shell": "res://assets/models/world_one/shell_patch.glb",
	"sticker": "res://assets/models/world_one/patch_husk_sticker.glb",
}

const VERTEX_COLOR_SLOTS := ["paint", "hydraulic", "pilot", "ancient_enamel"]

static var _packed_cache := {}
static var _orbital_mesh_cache: Mesh = null

var ctx
var _vfx_root: Node3D
var _pools := {}
var _clock := 0.0


static func reset_for_tests() -> void:
	_packed_cache.clear()
	_orbital_mesh_cache = null


static func _reset() -> void:
	reset_for_tests()


static func consumable_model_path(id: String) -> String:
	return String(CONSUMABLE_MODELS.get(id, ""))


static func active_model_path(id: String, world := false) -> String:
	var table: Dictionary = ACTIVE_WORLD_MODELS if world else ACTIVE_POD_MODELS
	return String(table.get(id, ""))


static func station_model_path(id: String) -> String:
	return String(STATION_MODELS.get(id, ""))


static func patch_assets() -> Dictionary:
	return PATCH_ASSETS.duplicate()


static func _load_packed(path: String) -> PackedScene:
	if path == "":
		return null
	if _packed_cache.has(path):
		return _packed_cache[path] as PackedScene
	var packed: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_packed_cache[path] = packed
	return packed


# Enables vertex_color_use_as_albedo on vertex-colored slots (Godot 4.7 glTF quirk).
static func instantiate_prop(path: String, node_name := "PropModel", with_outline := true) -> Node3D:
	var packed := _load_packed(path)
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	inst.name = node_name
	_apply_vertex_color_materials(inst)
	if with_outline:
		InkOutline.apply(inst, "prop")
	return inst


static func _apply_vertex_color_materials(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var mesh_copy: Mesh = mi.mesh.duplicate()
		for i in mesh_copy.get_surface_count():
			var orig := mesh_copy.surface_get_material(i)
			var mat: StandardMaterial3D
			if orig is StandardMaterial3D:
				mat = (orig as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
			var slot := orig.resource_name if orig != null else ""
			if slot in VERTEX_COLOR_SLOTS:
				mat.vertex_color_use_as_albedo = true
				mat.albedo_color = Color.WHITE
			if slot == "ancient_enamel":
				mat.emission_enabled = false
			mesh_copy.surface_set_material(i, mat)
		mi.mesh = mesh_copy


static func orbital_mesh() -> Mesh:
	if _orbital_mesh_cache != null:
		return _orbital_mesh_cache
	var packed := _load_packed(ORBITAL_MODEL)
	if packed == null:
		return null
	var inst := packed.instantiate()
	var found: Mesh = null
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var copy: Mesh = mi.mesh.duplicate()
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = Color.WHITE
			mat.metallic = 0.55
			mat.roughness = 0.34
			copy.surface_set_material(0, mat)
			found = copy
			break
	inst.free()
	_orbital_mesh_cache = found
	return _orbital_mesh_cache


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "W50AssetHooks"
	_vfx_root = Node3D.new()
	_vfx_root.name = "W50LiveProps"
	add_child(_vfx_root)
	var events = ctx.get("events") if ctx != null else null
	if events != null:
		for sig in ["stage_content_cleared", "stage_entered", "player_died", "run_ended"]:
			if events.has_signal(sig):
				var argc := SignalWire.arg_count(events, sig)
				var cb := _clear_live_props.unbind(argc) if argc > 0 else _clear_live_props
				if not events.is_connected(sig, cb):
					events.connect(sig, cb)
	if is_inside_tree():
		_connect_tree()
		_scan_existing.call_deferred()


func _enter_tree() -> void:
	_connect_tree()


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	_clear_live_props()


func _connect_tree() -> void:
	var tree := get_tree()
	if tree != null and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _scan_existing() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		_maybe_dress(n)
		stack.append_array(n.get_children())


func _on_node_added(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var nname := String(node.name)
	var interested := (
		nname.begins_with("ConsumableDrop_")
		or nname.begins_with("WorldScrapper")
		or nname.begins_with("WorldPartPress")
		or nname.begins_with("WorldTriTerminal")
		or nname == "OrbitalSatelliteMesh"
		or nname.begins_with("DroppedActive")
		or (nname.begins_with("Stake") and node.get_parent() != null and String(node.get_parent().name) == "SableStakes")
	)
	if interested:
		_maybe_dress_by_id.call_deferred(node.get_instance_id())


func _maybe_dress_by_id(id: int) -> void:
	var obj := instance_from_id(id)
	if obj is Node:
		_maybe_dress(obj as Node)


func _maybe_dress(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var nname := String(node.name)
	if nname.begins_with("ConsumableDrop_"):
		dress_consumable_drop(node as Node3D)
	elif nname.begins_with("WorldScrapper"):
		dress_station(node as Node3D, "scrapper")
	elif nname.begins_with("WorldPartPress"):
		dress_station(node as Node3D, "part_press")
	elif nname.begins_with("WorldTriTerminal"):
		dress_station(node as Node3D, "tri_terminal")
	elif nname == "OrbitalSatelliteMesh" and node is MultiMeshInstance3D:
		dress_orbital_multimesh(node as MultiMeshInstance3D)
	elif nname.begins_with("DroppedActive"):
		dress_dropped_active(node as Node3D)
	elif node.get_parent() != null and String(node.get_parent().name) == "SableStakes" and nname.begins_with("Stake"):
		dress_sable_stake(node as Node3D)


static func dress_consumable_drop(drop: Node3D) -> bool:
	if drop == null or drop.has_meta("w50_dressed"):
		return false
	var cid := String(drop.get("consumable_id")) if drop.get("consumable_id") != null else ""
	if cid == "":
		cid = String(drop.name).trim_prefix("ConsumableDrop_")
	var path := consumable_model_path(cid)
	if path == "":
		return false
	var socket := drop.find_child("SocketCartridge", true, false) as Node3D
	var host: Node3D = socket if socket != null else drop
	for child in host.get_children():
		var cname := String(child.name)
		if cname == "Cartridge" or cname == "CartridgeModel":
			host.remove_child(child)
			child.queue_free()
	var model := instantiate_prop(path, "Cartridge", true)
	if model == null:
		return false
	model.scale = Vector3.ONE * 1.15
	if socket == null:
		model.position = Vector3.UP * 0.45
	host.add_child(model)
	if drop.get("_cartridge_node") != null or drop.has_method("step"):
		drop.set("_cartridge_node", model)
	drop.set_meta("w50_dressed", true)
	return true


static func dress_station(host: Node3D, kind: String) -> bool:
	if host == null or host.has_node("StationModel"):
		return false
	var path := station_model_path(kind)
	var model := instantiate_prop(path, "StationModel", true)
	if model == null:
		return false
	for child in host.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is PrimitiveMesh:
				mi.layers = 0
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(model)
	return true


static func dress_orbital_multimesh(mmi: MultiMeshInstance3D) -> bool:
	if mmi == null or mmi.multimesh == null or mmi.has_meta("w50_dressed"):
		return false
	var mesh := orbital_mesh()
	if mesh == null:
		return false
	mmi.multimesh.mesh = mesh
	mmi.set_meta("w50_dressed", true)
	return true


static func dress_dropped_active(drop: Node3D) -> bool:
	if drop == null or drop.has_node("ActivePodModel"):
		return false
	var id := String(drop.get_meta("active_id", ""))
	if id == "":
		for child in drop.get_children():
			if child is Label or child is Label3D:
				var t := String(child.get("text")).to_lower()
				if t.contains("magnet sling"):
					id = "magnet_sling"
					break
				elif t.contains("slag mortar"):
					id = "slag_mortar"
					break
	var path := active_model_path(id, false)
	if path == "":
		return false
	var model := instantiate_prop(path, "ActivePodModel", true)
	if model == null:
		return false
	for child in drop.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is PrismMesh:
			var mi := child as MeshInstance3D
			mi.layers = 0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.position = Vector3(0.0, 0.25, 0.0)
	model.scale = Vector3.ONE * 1.15
	drop.add_child(model)
	return true


static func dress_sable_stake(stake: Node3D) -> bool:
	if stake == null or stake.has_node("SableStakeModel"):
		return false
	var model := instantiate_prop(SABLE_STAKE_MODEL, "SableStakeModel", true)
	if model == null:
		return false
	for child in stake.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			mi.layers = 0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stake.add_child(model)
	return true


func _process(delta: float) -> void:
	if ctx == null or _vfx_root == null or not is_instance_valid(_vfx_root):
		return
	_clock += delta
	var combat = ctx.get("combat")
	if combat == null:
		_hide_all_pools()
		return
	_sync_actives(combat)
	_sync_relic_swaps(combat)


func _sync_actives(combat) -> void:
	var actives = combat.get("actives")
	var kinds = actives.get("_kinds") if actives != null else null
	if not (kinds is Dictionary):
		_release_from("magnet_buoy", 0)
		_release_from("slag_shell", 0)
		return
	var magnet = kinds.get("magnet_sling")
	var buoys: Array = magnet.get("buoys") if magnet != null and magnet.get("buoys") is Array else []
	var used_buoys := 0
	for b in buoys:
		if not (b is Dictionary):
			continue
		var node := _acquire("magnet_buoy", used_buoys, ACTIVE_WORLD_MODELS["magnet_sling"])
		if node != null:
			node.visible = true
			node.position = b.get("at", Vector3.ZERO)
			node.rotation.y = _clock * 2.2
			used_buoys += 1
	_release_from("magnet_buoy", used_buoys)

	var mortar = kinds.get("slag_mortar")
	var pending_raw = mortar.get("pending") if mortar != null else null
	var used_shells := 0
	if pending_raw is Dictionary and not pending_raw.is_empty():
		var sh: Dictionary = pending_raw
		var node := _acquire("slag_shell", used_shells, ACTIVE_WORLD_MODELS["slag_mortar"])
		if node != null:
			var target: Vector3 = sh.get("at", Vector3.ZERO)
			var left: float = float(sh["left"]) if sh.has("left") else maxf(0.0, float(sh.get("warn", 0.35)) - float(sh.get("age", 0.0)))
			node.visible = true
			node.position = target + Vector3(0.0, maxf(0.0, left) * 14.0, 0.0)
			node.rotation = Vector3(PI, _clock * 3.0, 0.0)
			used_shells += 1
	_release_from("slag_shell", used_shells)


func _sync_relic_swaps(combat) -> void:
	var swaps = combat.get("relic_swaps")
	if swaps == null:
		for k in ["drill_auger", "halo_orb", "voltaic_halo", "snare_beacon", "relic_mortar"]:
			_release_from(k, 0)
		return
	var augers: Array = swaps.get("_augers") if swaps.get("_augers") is Array else []
	var n_aug := 0
	for a in augers:
		if not (a is Dictionary):
			continue
		var node := _acquire("drill_auger", n_aug, RELIC_VFX_MODELS["drill_auger"])
		if node != null:
			node.visible = true
			node.position = a.get("at", Vector3.ZERO)
			node.rotation.y = _clock * 9.0
			n_aug += 1
	_release_from("drill_auger", n_aug)

	var orbit = swaps.get("_orbit_halo")
	var n_orb := 0
	if orbit is Dictionary and float(orbit.get("left", 0.0)) > 0.0 and ctx.player != null:
		var center: Vector3 = ctx.player.shown_position() + Vector3(0.0, 0.65, 0.0)
		var r := maxf(2.0, float(orbit.get("radius", 6.0)))
		var ang := float(orbit.get("angle", _clock * 3.0))
		for k in 3:
			var a := ang + TAU * float(k) / 3.0
			var node := _acquire("halo_orb", n_orb, RELIC_VFX_MODELS["halo_orb"])
			if node != null:
				node.visible = true
				node.position = center + Vector3(cos(a) * r, 0.0, sin(a) * r)
				node.rotation.y = -a + _clock * 4.0
				n_orb += 1
	_release_from("halo_orb", n_orb)

	var halos: Array = swaps.get("_halos") if swaps.get("_halos") is Array else []
	var n_hal := 0
	for h in halos:
		if not (h is Dictionary):
			continue
		var node := _acquire("voltaic_halo", n_hal, RELIC_VFX_MODELS["voltaic_halo"])
		if node != null:
			var pos: Vector3 = h.get("pos", h.get("at", Vector3.ZERO))
			node.visible = true
			node.position = pos + Vector3(0.0, 0.45, 0.0)
			var r := maxf(0.6, float(h.get("radius", 1.5)))
			node.scale = Vector3(r * 0.65, 1.0, r * 0.65)
			node.rotation.y = _clock * 3.5
			n_hal += 1
	_release_from("voltaic_halo", n_hal)

	var snares: Array = swaps.get("_snares") if swaps.get("_snares") is Array else []
	var n_snr := 0
	for s in snares:
		if not (s is Dictionary):
			continue
		var node := _acquire("snare_beacon", n_snr, RELIC_VFX_MODELS["snare_beacon"])
		if node != null:
			var apex: Vector3 = s.get("apex", s.get("at", Vector3.ZERO))
			node.visible = true
			node.position = apex + Vector3(0.0, 0.22 * sin(_clock * 5.0), 0.0)
			node.rotation.y = _clock * 2.4
			n_snr += 1
	_release_from("snare_beacon", n_snr)

	var rmortars: Array = swaps.get("_mortars") if swaps.get("_mortars") is Array else []
	var n_rm := 0
	for m in rmortars:
		if not (m is Dictionary):
			continue
		var node := _acquire("relic_mortar", n_rm, RELIC_VFX_MODELS["mortar_shell"])
		if node != null:
			var target: Vector3 = m.get("at", Vector3.ZERO)
			var left := maxf(0.0, float(m.get("left", 0.0)))
			node.visible = true
			node.position = target + Vector3(0.0, left * 16.0, 0.0)
			node.rotation = Vector3(PI, _clock * 3.5, 0.0)
			n_rm += 1
	_release_from("relic_mortar", n_rm)


func _acquire(pool_key: String, idx: int, path: String) -> Node3D:
	var list: Array = _pools.get(pool_key, [])
	while list.size() <= idx:
		var inst := instantiate_prop(path, "%s_%d" % [pool_key, list.size()], true)
		if inst == null:
			return null
		inst.visible = false
		_vfx_root.add_child(inst)
		list.append(inst)
	_pools[pool_key] = list
	return list[idx] as Node3D


func _release_from(pool_key: String, start_idx: int) -> void:
	var list: Array = _pools.get(pool_key, [])
	for i in range(start_idx, list.size()):
		var n := list[i] as Node3D
		if n != null and is_instance_valid(n):
			n.visible = false


func _hide_all_pools() -> void:
	for k in _pools:
		_release_from(String(k), 0)


func _clear_live_props() -> void:
	for list in _pools.values():
		for n in list:
			if is_instance_valid(n):
				(n as Node).queue_free()
	_pools.clear()
