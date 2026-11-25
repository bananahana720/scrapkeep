extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# W47-TALLY-B-CODE Ghost Shift Ally-Husk Look & Mandatory B6 Readability Contract:
#   (a) Allied attack zones drawn strictly in warm Palette.AMBER #E5A044 (NEVER Palette.HAZARD).
#   (b) Zero enemy telegraphs: no hostile klaxons, no red brow flashes, no 45-deg hazard stripes.
#   (c) Attaches W47-TALLY-B-3D overlays onto every raised husk:
#         - 2x amber-sparking copper alligator jumper clips (ally_husk_clip.glb)
#         - 1x forged oxblood/amber Hollerith punched card tag (ally_husk_tag.glb)
#         - 1x raised amber-sparking Jacob's-ladder clip mast & frayed trailing copper lead (ally_husk_mast.glb)
#         - 2x arched copper jumper leads bridging clips -> mast (ally_husk_lead.glb)
#   Clean per-instance mesh/material duplication: never mutates shared PackedScene resources.

const CLIP_PATH := "res://assets/models/ally_husk/ally_husk_clip.glb"
const TAG_PATH := "res://assets/models/ally_husk/ally_husk_tag.glb"
const MAST_PATH := "res://assets/models/ally_husk/ally_husk_mast.glb"
const LEAD_PATH := "res://assets/models/ally_husk/ally_husk_lead.glb"

const ENEMY_CHASSIS := {
	"chaser": "res://assets/models/world_one/enemy_chaser.glb",
	"plated_brute": "res://assets/models/world_one/enemy_plated_brute.glb",
	"lobber": "res://assets/models/world_one/enemy_lobber.glb",
	"boom_tender": "res://assets/models/world_one/enemy_boom_tender.glb",
}

# Exact Godot-space anchor offsets from tools/blender/ally_husk_overlay.py (W47-TALLY-B-3D).
const ANCHORS := {
	"chaser": {
		"body_y": 1.50, "forward_z": -1.0,
		"clip_l": Vector3(-0.82, 0.56, 0.04), "clip_l_rot": Vector3(0.0, 75.0, 10.0),
		"clip_r": Vector3(0.82, 0.56, 0.04), "clip_r_rot": Vector3(0.0, -75.0, -10.0),
		"tag": Vector3(0.0, 0.88, -0.46), "tag_rot": Vector3(12.0, 0.0, 0.0),
		"mast": Vector3(0.0, 1.16, 0.34), "mast_rot": Vector3(0.0, 0.0, 0.0),
	},
	"plated_brute": {
		"body_y": 1.10, "forward_z": 1.0,
		"clip_l": Vector3(-1.42, 0.88, 0.10), "clip_l_rot": Vector3(0.0, 105.0, 10.0),
		"clip_r": Vector3(1.42, 0.88, 0.10), "clip_r_rot": Vector3(0.0, -105.0, -10.0),
		"tag": Vector3(0.0, 1.08, 1.16), "tag_rot": Vector3(-10.0, 180.0, 0.0),
		"mast": Vector3(0.0, 1.10, -0.35), "mast_rot": Vector3(0.0, 180.0, 0.0),
	},
	"lobber": {
		"body_y": 2.00, "forward_z": 1.0,
		"clip_l": Vector3(-1.12, 1.28, -0.10), "clip_l_rot": Vector3(0.0, 95.0, 8.0),
		"clip_r": Vector3(1.12, 1.28, -0.10), "clip_r_rot": Vector3(0.0, -95.0, -8.0),
		"tag": Vector3(0.0, 0.52, 0.84), "tag_rot": Vector3(-14.0, 180.0, 0.0),
		"mast": Vector3(0.86, 1.48, -0.82), "mast_rot": Vector3(0.0, 165.0, -8.0),
	},
	"boom_tender": {
		"body_y": 0.0, "forward_z": -1.0,
		"clip_l": Vector3(-1.14, 1.02, -0.20), "clip_l_rot": Vector3(0.0, 82.0, 8.0),
		"clip_r": Vector3(1.14, 1.02, -0.20), "clip_r_rot": Vector3(0.0, -82.0, -8.0),
		"tag": Vector3(0.0, 1.18, -1.26), "tag_rot": Vector3(12.0, 0.0, 0.0),
		"mast": Vector3(0.0, 1.56, 0.82), "mast_rot": Vector3(0.0, 0.0, 0.0),
	},
}

const ZONE_PRIORITY := 36
const ZONE_LIFT := 0.18
const AMBER_HEX := "e5a044"


static func attach_husk_look(host: Node3D, kind: String, body_radius := 1.0, half_height := 1.5, elite := false) -> Dictionary:
	var visual := Node3D.new()
	visual.name = "AllyHuskLook"
	host.add_child(visual)

	var anchor: Dictionary = ANCHORS.get(kind, _fallback_anchor(body_radius, half_height))
	var chassis_root := Node3D.new()
	chassis_root.name = "ChassisRoot"
	chassis_root.position = Vector3(0.0, float(anchor["body_y"]), 0.0)
	if float(anchor["forward_z"]) > 0.0:
		chassis_root.rotation.y = PI
	if elite:
		chassis_root.scale = Vector3.ONE * 1.12
	visual.add_child(chassis_root)

	# 1. Retained Fleet oxide chassis with hostile brow/visor darkened (B6: zero hostile flashes).
	var body_node := _build_chassis(kind, body_radius, half_height)
	body_node.name = "HuskChassis"
	chassis_root.add_child(body_node)

	# 2. W47-TALLY-B-3D overlays (clean per-instance duplicates, never mutating PackedScene).
	var amber_mats: Array = []
	var clip_l := _instantiate_overlay(CLIP_PATH, "ClipL", amber_mats)
	var clip_r := _instantiate_overlay(CLIP_PATH, "ClipR", amber_mats)
	var tag := _instantiate_overlay(TAG_PATH, "WorkOrderTag", amber_mats)
	var mast := _instantiate_overlay(MAST_PATH, "ClipMast", amber_mats)

	clip_l.position = anchor["clip_l"]
	clip_l.rotation_degrees = anchor["clip_l_rot"]
	clip_r.position = anchor["clip_r"]
	clip_r.rotation_degrees = anchor["clip_r_rot"]
	tag.position = anchor["tag"]
	tag.rotation_degrees = anchor["tag_rot"]
	mast.position = anchor["mast"]
	mast.rotation_degrees = anchor["mast_rot"]

	chassis_root.add_child(clip_l)
	chassis_root.add_child(clip_r)
	chassis_root.add_child(tag)
	chassis_root.add_child(mast)

	# 3. Arched copper jumper leads bridging each alligator clip -> Jacob's-ladder mast.
	var lead_l := _bridge_lead(chassis_root, clip_l, mast, "socket_clip_feed_l", "JumperLeadL", amber_mats)
	var lead_r := _bridge_lead(chassis_root, clip_r, mast, "socket_clip_feed_r", "JumperLeadR", amber_mats)

	# 4. Crisp warm AMBER #E5A044 allied base ring (zero stripes, zero HAZARD) for Blazing read.
	var foot_ring := _build_footprint_ring(maxf(1.35, body_radius * 1.45), amber_mats)
	foot_ring.name = "AllyFootprintRing"
	visual.add_child(foot_ring)

	# 5. Shift-countdown tick pips on the tag sockets (3 pips ticking down 12 s shift).
	var tick_pips := _build_tick_pips(tag)

	return {
		"root": visual,
		"chassis": chassis_root,
		"clip_l": clip_l,
		"clip_r": clip_r,
		"tag": tag,
		"mast": mast,
		"lead_l": lead_l,
		"lead_r": lead_r,
		"footprint": foot_ring,
		"amber_mats": amber_mats,
		"tick_pips": tick_pips,
		"base_y": float(anchor["body_y"]),
		"base_yaw": PI if float(anchor["forward_z"]) > 0.0 else 0.0,
		"pulse_clock": 0.0,
	}


static func update_husk_look(look: Dictionary, shift_fraction: float, overclocked: bool, delta: float) -> void:
	if look.is_empty():
		return
	var root = look.get("root")
	if root == null or not is_instance_valid(root):
		return
	look["pulse_clock"] = float(look.get("pulse_clock", 0.0)) + delta * (10.0 if overclocked else 4.0)
	var pulse := 0.5 + 0.5 * sin(float(look["pulse_clock"]))
	var energy := (2.6 + 1.1 * pulse) if overclocked else (1.55 + 0.35 * pulse)
	for mat in look.get("amber_mats", []):
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			sm.albedo_color = Palette.AMBER
			sm.emission = Palette.AMBER
			sm.emission_energy_multiplier = energy
	var chassis = look.get("chassis")
	if chassis != null and is_instance_valid(chassis):
		# Distinct overclocked lowered hunch silhouette tell when surged by flywheel_surge.
		var target_pitch := deg_to_rad(-9.0) if overclocked else 0.0
		var target_y := float(look.get("base_y", 1.0)) - (0.14 if overclocked else 0.0)
		chassis.rotation.x = lerpf(chassis.rotation.x, target_pitch, minf(1.0, delta * 12.0))
		chassis.position.y = lerpf(chassis.position.y, target_y, minf(1.0, delta * 12.0))
	var pips: Array = look.get("tick_pips", [])
	for i in pips.size():
		var pip = pips[i]
		if pip != null and is_instance_valid(pip):
			var threshold := float(i) / float(maxi(1, pips.size()))
			pip.visible = shift_fraction > threshold


# Ground marker for a 6 s raiseable ordinary Fleet wreck (copper/amber ring + slumped relay body).
static func build_wreck_marker(parent: Node3D, at: Vector3, radius := 1.0, elite := false) -> Node3D:
	var root := Node3D.new()
	root.name = "GhostShiftWreck"
	root.position = at
	parent.add_child(root)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var s := 1.15 if elite else 0.90
	box.size = Vector3(1.1 * s, 0.55 * s, 1.3 * s)
	body.mesh = box
	body.position = Vector3(0.0, 0.28 * s, 0.0)
	body.rotation = Vector3(deg_to_rad(14.0), deg_to_rad(25.0), deg_to_rad(-18.0))
	body.material_override = Palette.solid(Palette.RUST)
	root.add_child(body)

	var ring := _build_ring_mesh(maxf(1.2, radius * 1.35), 0.10, Palette.COPPER, 0.85, 34)
	ring.name = "WreckRing"
	ring.position = Vector3(0.0, ZONE_LIFT, 0.0)
	root.add_child(ring)

	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.20 * s
	sphere.height = 0.40 * s
	spark.mesh = sphere
	spark.position = Vector3(0.0, 0.72 * s, 0.0)
	spark.material_override = Palette.solid(Palette.AMBER, 2.0, false)
	root.add_child(spark)
	return root


static func _fallback_anchor(body_radius: float, half_height: float) -> Dictionary:
	var r := maxf(0.8, body_radius)
	var h := maxf(0.9, half_height)
	return {
		"body_y": h, "forward_z": -1.0,
		"clip_l": Vector3(-r * 0.85, h * 0.35, 0.0), "clip_l_rot": Vector3(0.0, 75.0, 10.0),
		"clip_r": Vector3(r * 0.85, h * 0.35, 0.0), "clip_r_rot": Vector3(0.0, -75.0, -10.0),
		"tag": Vector3(0.0, h * 0.55, -r * 0.55), "tag_rot": Vector3(12.0, 0.0, 0.0),
		"mast": Vector3(0.0, h * 0.82, r * 0.25), "mast_rot": Vector3(0.0, 0.0, 0.0),
	}


static func _build_chassis(kind: String, body_radius: float, half_height: float) -> Node3D:
	var path := String(ENEMY_CHASSIS.get(kind, ""))
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			_dress_husk_chassis(inst)
			return inst
	var fallback := Node3D.new()
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = body_radius * 0.85
	cyl.bottom_radius = body_radius * 0.95
	cyl.height = half_height * 1.8
	mi.mesh = cyl
	mi.material_override = Palette.solid(Palette.RUST)
	fallback.add_child(mi)
	return fallback


# Duplicates meshes and applies neutral Fleet oxide + DARK charcoal visor/brow (zero red glow).
static func _dress_husk_chassis(root: Node) -> void:
	var oxide := Palette.solid(Palette.RUST)
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var steel := Palette.solid(Palette.STEEL)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var mesh_copy: Mesh = mi.mesh.duplicate()
		var lower := String(mi.name).to_lower()
		for i in mesh_copy.get_surface_count():
			var sm := mesh_copy.surface_get_material(i)
			var slot := sm.resource_name if sm != null else ""
			if slot == "fleet_paint":
				mesh_copy.surface_set_material(i, oxide)
			elif slot == "requisition_tag" or lower.contains("bulb") or lower.contains("visor") or lower.contains("eye"):
				# B6: raised husk visor/brow is powered down — NEVER red or orange hostile flash.
				mesh_copy.surface_set_material(i, charcoal)
			elif lower.contains("plate") or lower.contains("slab"):
				mesh_copy.surface_set_material(i, steel)
			else:
				mesh_copy.surface_set_material(i, charcoal)
		mi.mesh = mesh_copy
		mi.material_override = null


# Clean per-instance GLB instantiation; duplicates Mesh & Materials so PackedScene stays untouched.
static func _instantiate_overlay(path: String, node_name: String, amber_mats: Array) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	if not ResourceLoader.exists(path):
		return holder
	var packed := load(path) as PackedScene
	if packed == null:
		return holder
	var inst := packed.instantiate()
	holder.add_child(inst)
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var mesh_copy: Mesh = mi.mesh.duplicate()
		for i in mesh_copy.get_surface_count():
			var orig := mesh_copy.surface_get_material(i)
			var mat: StandardMaterial3D
			var slot := orig.resource_name if orig != null else ""
			if orig is StandardMaterial3D:
				mat = (orig as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
			if slot == "class_accent":
				mat.albedo_color = Palette.AMBER
				mat.emission_enabled = true
				mat.emission = Palette.AMBER
				mat.emission_energy_multiplier = 1.8
				mat.roughness = 0.35
				amber_mats.append(mat)
			elif slot == "hydraulic":
				mat.vertex_color_use_as_albedo = true
				mat.metallic = 0.45
				mat.roughness = 0.36
			elif slot == "paint":
				mat.vertex_color_use_as_albedo = true
				mat.roughness = 0.82
			mesh_copy.surface_set_material(i, mat)
		mi.mesh = mesh_copy
	return holder


static func _bridge_lead(parent: Node3D, clip: Node3D, mast: Node3D, mast_socket_name: String, lead_name: String, amber_mats: Array) -> Node3D:
	var lead := _instantiate_overlay(LEAD_PATH, lead_name, amber_mats)
	parent.add_child(lead)
	var clip_sock := clip.find_child("socket_lead", true, false) as Node3D
	var mast_sock := mast.find_child(mast_socket_name, true, false) as Node3D
	var p_start: Vector3 = clip.position
	if clip_sock != null:
		p_start = _local_in(clip_sock, parent)
	var p_end: Vector3 = mast.position + Vector3(0.0, 0.55, 0.0)
	if mast_sock != null:
		p_end = _local_in(mast_sock, parent)
	var span := p_end - p_start
	var dist := span.length()
	lead.position = p_start
	if dist > 0.05:
		var dir := span / dist
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.96 else Vector3.RIGHT
		var basis := Basis.looking_at(dir, up)
		lead.basis = basis
		lead.scale = Vector3(1.0, 1.0, dist)
	return lead


static func _local_in(node: Node3D, ancestor: Node3D) -> Vector3:
	var xform := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xform = (cur as Node3D).transform * xform
		cur = cur.get_parent()
	return xform.origin


static func _build_tick_pips(tag: Node3D) -> Array:
	var pips: Array = []
	for i in 3:
		var sock := tag.find_child("socket_tick_%d" % i, true, false) as Node3D
		if sock == null:
			continue
		var pip := MeshInstance3D.new()
		pip.name = "ShiftTickPip_%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.085, 0.095, 0.085)
		pip.mesh = box
		pip.material_override = Palette.solid(Palette.AMBER, 2.2, false)
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sock.add_child(pip)
		pips.append(pip)
	return pips


static func _build_footprint_ring(radius: float, amber_mats: Array) -> Node3D:
	var holder := Node3D.new()
	var key := _build_ring_mesh(radius, 0.16, Palette.CHARCOAL, 0.85, ZONE_PRIORITY - 2)
	key.position = Vector3(0.0, ZONE_LIFT - 0.02, 0.0)
	holder.add_child(key)
	var rim_mat := _zone_material(Palette.AMBER, 0.95, ZONE_PRIORITY - 1)
	amber_mats.append(rim_mat)
	var rim := _build_ring_mesh_with_mat(radius, 0.11, rim_mat)
	rim.position = Vector3(0.0, ZONE_LIFT, 0.0)
	holder.add_child(rim)
	return holder


static func _zone_material(col: Color, alpha: float, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = priority
	return mat


static func _build_ring_mesh(radius: float, thickness: float, col: Color, alpha: float, priority: int) -> MeshInstance3D:
	return _build_ring_mesh_with_mat(radius, thickness, _zone_material(col, alpha, priority))


static func _build_ring_mesh_with_mat(radius: float, thickness: float, mat: Material, segs := 48) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r_in := maxf(0.05, radius - thickness * 0.5)
	var r_out := radius + thickness * 0.5
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * r_in, 0.0, sin(a0) * r_in)
		var p1 := Vector3(cos(a0) * r_out, 0.0, sin(a0) * r_out)
		var p2 := Vector3(cos(a1) * r_out, 0.0, sin(a1) * r_out)
		var p3 := Vector3(cos(a1) * r_in, 0.0, sin(a1) * r_in)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
		st.add_vertex(p0)
		st.add_vertex(p2)
		st.add_vertex(p3)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- Mandatory B6 Allied Attack Zone (Warm Palette.AMBER #E5A044 ONLY, Zero Stripes) -------

class AllyZone extends Node3D:
	const PaletteRef := preload("res://src/core/palette.gd")

	# B6 immutable contract: always warm AMBER #E5A044, never HAZARD, never hostile, zero stripes.
	var color: Color = PaletteRef.AMBER
	var shape := "ring"
	var center := Vector3.ZERO
	var radius := 4.0
	var dir := Vector3.FORWARD
	var length := 9.0
	var width := 2.8
	var reach_up := 4.0
	var progress := 0.0
	var terrain = null

	var _fill_node: MeshInstance3D
	var _fill_mat: StandardMaterial3D


	func is_hostile() -> bool:
		return false


	func has_hazard_stripes() -> bool:
		return false


	func descriptor() -> Dictionary:
		return {
			"shape": shape,
			"color": color,
			"hostile": false,
			"stripes": false,
			"center": center,
			"radius": radius,
			"dir": dir,
			"length": length,
			"width": width,
			"reach_up": reach_up,
			"progress": progress,
		}


	# TADR-008: damage and drawn zone consume the exact same committed geometry.
	func contains(point: Vector3) -> bool:
		var above := point.y - center.y
		if above > reach_up or above < -2.5:
			return false
		var flat := Vector3(point.x - center.x, 0.0, point.z - center.z)
		if shape == "ring":
			return flat.length() <= radius
		var along := flat.dot(dir)
		if along < -0.5 or along > length:
			return false
		return (flat - dir * along).length() <= width * 0.5


	func build_ring(at: Vector3, r: float, terrain_ref = null, reach := 4.0) -> void:
		shape = "ring"
		color = PaletteRef.AMBER
		radius = r
		reach_up = reach
		terrain = terrain_ref
		center = at
		position = center + Vector3(0.0, ZONE_LIFT, 0.0)
		add_to_group("ally_zone")
		# Charcoal keyline + crisp AMBER rim + clean translucent AMBER fill (no stripes!).
		var key := _ring_mesh(radius, 0.28, PaletteRef.CHARCOAL, 0.90, ZONE_PRIORITY - 1)
		key.position.y = -0.02
		add_child(key)
		var rim := _ring_mesh(radius, 0.18, PaletteRef.AMBER, 0.96, ZONE_PRIORITY + 1)
		add_child(rim)
		_fill_mat = _mat(PaletteRef.AMBER, 0.20, ZONE_PRIORITY)
		_fill_node = _build_disc_mesh(radius, _fill_mat)
		_fill_node.scale = Vector3(0.12, 1.0, 0.12)
		add_child(_fill_node)


	func build_lane(from: Vector3, heading: Vector3, lane_length: float, lane_width: float, terrain_ref = null, reach := 4.0) -> void:
		shape = "lane"
		color = PaletteRef.AMBER
		var flat := Vector3(heading.x, 0.0, heading.z)
		dir = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
		length = lane_length
		width = lane_width
		reach_up = reach
		terrain = terrain_ref
		center = from
		position = center + Vector3(0.0, ZONE_LIFT, 0.0)
		basis = Basis.looking_at(dir, Vector3.UP)
		add_to_group("ally_zone")
		# Charcoal keyline rails + AMBER rails + clean AMBER growing fill (zero 45-deg stripes).
		var hw := width * 0.5
		var key_mat := _mat(PaletteRef.CHARCOAL, 0.90, ZONE_PRIORITY - 1)
		var rim_mat := _mat(PaletteRef.AMBER, 0.96, ZONE_PRIORITY + 1)
		for sx in [-1.0, 1.0]:
			var rail_key := _quad_mesh(0.24, length, key_mat)
			rail_key.position = Vector3(sx * hw, -0.02, -length * 0.5)
			add_child(rail_key)
			var rail := _quad_mesh(0.15, length, rim_mat)
			rail.position = Vector3(sx * hw, 0.0, -length * 0.5)
			add_child(rail)
		var cap_key := _quad_mesh(width + 0.24, 0.26, key_mat)
		cap_key.position = Vector3(0.0, -0.02, -length)
		add_child(cap_key)
		var cap := _quad_mesh(width + 0.15, 0.16, rim_mat)
		cap.position = Vector3(0.0, 0.0, -length)
		add_child(cap)
		_fill_mat = _mat(PaletteRef.AMBER, 0.22, ZONE_PRIORITY)
		_fill_node = _quad_mesh(maxf(0.2, width - 0.18), length, _fill_mat)
		_fill_node.position = Vector3(0.0, -0.005, -length * 0.5)
		_fill_node.scale = Vector3(0.15, 1.0, 1.0)
		add_child(_fill_node)


	static func _mat(col: Color, alpha: float, priority: int) -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(col.r, col.g, col.b, alpha)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = priority
		return mat


	static func _ring_mesh(r: float, thickness: float, col: Color, alpha: float, priority: int, segs := 48) -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var r_in := maxf(0.05, r - thickness * 0.5)
		var r_out := r + thickness * 0.5
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var p0 := Vector3(cos(a0) * r_in, 0.0, sin(a0) * r_in)
			var p1 := Vector3(cos(a0) * r_out, 0.0, sin(a0) * r_out)
			var p2 := Vector3(cos(a1) * r_out, 0.0, sin(a1) * r_out)
			var p3 := Vector3(cos(a1) * r_in, 0.0, sin(a1) * r_in)
			st.add_vertex(p0)
			st.add_vertex(p1)
			st.add_vertex(p2)
			st.add_vertex(p0)
			st.add_vertex(p2)
			st.add_vertex(p3)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _mat(col, alpha, priority)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi


	func set_progress(p: float) -> void:
		progress = clampf(p, 0.0, 1.0)
		if _fill_node == null or not is_instance_valid(_fill_node):
			return
		var fill_scale := lerpf(0.15, 0.98, progress)
		if shape == "ring":
			_fill_node.scale = Vector3(fill_scale, 1.0, fill_scale)
		else:
			_fill_node.scale = Vector3(fill_scale, 1.0, 1.0)
		if _fill_mat != null:
			_fill_mat.albedo_color = Color(PaletteRef.AMBER.r, PaletteRef.AMBER.g, PaletteRef.AMBER.b, lerpf(0.16, 0.42, progress))


	func _ground_at(at: Vector3) -> float:
		if terrain == null:
			return at.y
		if terrain.has_method("height_at"):
			return float(terrain.height_at(at))
		if terrain.has_method("height"):
			return float(terrain.height(at.x, at.z))
		return at.y


	static func _build_disc_mesh(r: float, mat: Material, segs := 40) -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(cos(a0) * r, 0.0, sin(a0) * r))
			st.add_vertex(Vector3(cos(a1) * r, 0.0, sin(a1) * r))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi


	static func _quad_mesh(w: float, l: float, mat: Material) -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hw := w * 0.5
		var hl := l * 0.5
		var p0 := Vector3(-hw, 0.0, -hl)
		var p1 := Vector3(hw, 0.0, -hl)
		var p2 := Vector3(hw, 0.0, hl)
		var p3 := Vector3(-hw, 0.0, hl)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
		st.add_vertex(p0)
		st.add_vertex(p2)
		st.add_vertex(p3)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi


static func create_ring_zone(parent: Node3D, at: Vector3, radius: float, terrain = null, reach := 4.0) -> AllyZone:
	var zone := AllyZone.new()
	zone.name = "AllyAmberRingZone"
	parent.add_child(zone)
	zone.build_ring(at, radius, terrain, reach)
	return zone


static func create_lane_zone(parent: Node3D, from: Vector3, heading: Vector3, lane_length: float, lane_width: float, terrain = null, reach := 4.0) -> AllyZone:
	var zone := AllyZone.new()
	zone.name = "AllyAmberLaneZone"
	parent.add_child(zone)
	zone.build_lane(from, heading, lane_length, lane_width, terrain, reach)
	return zone
