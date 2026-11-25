extends Node3D

const Augments := preload("res://src/movement/augments.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")

# W47-GRAPPLE-CODE: 4-part hardware grapple rig presenter (Rules G0, G1, TADR-008).
#
# Binds strictly ONE hardware rig onto the player's ONE standing harpoon line and ChainState
# (Rule G0: zero second standing line, universal HOOK-CHAIN unchanged for all 6 pilots).
# Each pilot's live line_id maps to its 4-part hardware assembly:
#   Mount  hub socket on Pod (sable, kest, cannon, tally) or Pod/WeaponRing (rivet, tarn)
#   Drive  spool / capstan / drum / winch at socket_drive, rotating about local +X on payout (+)
#          and rewind/winch/haul (-)
#   Line   1 m tile from socket_line aimed at Head and scaled along local -Z
#   Head   bite hardware docked at socket_head at rest, seated on anchor when hooked
#
# Five pilots bind their Blender GLBs from assets/models/grapple/grapple_<stem>_{mount,drive,line,head}.glb.
# Tally binds her copper alligator-clamp head, sheathed copper patch-lead line, and spring lead spool
# cleanly alongside shell_tally.glb using Palette.COPPER and Palette.AMBER (zero HAZARD/KINDNESS/ANCIENT).
#
# TADR-008: CommittedAim draws the committed aim ray and target ring BEFORE hit from player.kit.aim,
# and the committed tether lock ring from player.kit.anchor while hooked. Presentation never decides
# gameplay outcomes.

const MODEL_DIR := "res://assets/models/grapple/"

const RIG_SPECS := {
	"pylon_engineer": {
		"pilot": "sable",
		"line_id": "bank_shot",
		"kind": "glb",
		"frame": "Pod",
		"mount_bone": "lever",
		"head_bones": ["latch"],
	},
	"runner_gunner": {
		"pilot": "rivet",
		"line_id": "line_drive",
		"kind": "glb",
		"frame": "Pod/WeaponRing",
		"mount_bone": "guide",
		"head_bones": ["toggle"],
	},
	"demolitions_caster": {
		"pilot": "kest",
		"line_id": "cable_charge",
		"kind": "glb",
		"frame": "Pod",
		"mount_bone": "trolley",
		"head_bones": ["fluke.0", "fluke.1", "fluke.2"],
	},
	"tarn": {
		"pilot": "tarn",
		"line_id": "claw_drag",
		"kind": "glb",
		"frame": "Pod/WeaponRing",
		"mount_bone": "pawl",
		"head_bones": ["talon.0", "talon.1", "talon.2"],
	},
	"tally": {
		"pilot": "tally",
		"line_id": "link_clips",
		"kind": "shell_hardware",
		"frame": "Pod",
		"mount_bone": "",
		"head_bones": [],
	},
	"remembered_cannon": {
		"pilot": "cannon",
		"line_id": "cannon_lane_charge",
		"kind": "glb",
		"frame": "Pod",
		"mount_bone": "lock",
		"head_bones": ["cap"],
	},
}

const LINE_ID_TO_CLASS := {
	"bank_shot": "pylon_engineer",
	"line_drive": "runner_gunner",
	"cable_charge": "demolitions_caster",
	"claw_drag": "tarn",
	"link_clips": "tally",
	"link_double": "tally",
	"cannon_lane_charge": "remembered_cannon",
}

const DRIVE_RADIUS_M := 0.24
const PAYOUT_BURST_S := 0.14
const PAYOUT_BURST_OMEGA := 18.0
const WINCH_OMEGA := -22.0
const RECOIL_OMEGA := -16.0
const DRIVE_COAST_DAMP := 10.0

const DRY_DART_M := 8.0
const DRY_TIME_S := 0.25
const DRY_REACH_S := 0.08
const LET_GO_TIME_S := 0.16
const BROKE_TIME_S := 0.28
const RELEASE_ACTUATOR_S := 0.24
const SKILL_PULSE_S := 0.45

const AIM_RING_SEGMENTS := 24
const AIM_RING_RADIUS := 0.72
const AIM_LINE_HALF := 0.045
const LOCK_RING_RADIUS := 0.85

# Radial tangent angles matching tools/blender/grapple_rigs.py (Kest.flukes / Tarn.talons).
# In every grapple_*.glb armature the root bone carries -90 deg about X, so child bone-local
# space is Blender space (+X right, +Y forward along Godot -Z, +Z up = Godot +Y).
const KEST_FLUKE_PHIS := [PI * 0.5, PI * 0.5 + TAU / 3.0, PI * 0.5 + 2.0 * TAU / 3.0]
const TARN_TALON_PHIS := [deg_to_rad(48.0), deg_to_rad(132.0), deg_to_rad(270.0)]

var ctx
var player
var hero_assets
var line_view
var events

var active_class_id := ""
var active_line_id := ""
var mount_frame_path := "Pod"

var rig_root: Node3D
var mount_node: Node3D
var drive_node: Node3D
var line_node: Node3D
var head_node: Node3D
var socket_drive: Node3D
var socket_line: Node3D
var socket_head: Node3D
var mount_skeleton: Skeleton3D
var head_skeleton: Skeleton3D

# Drive kinematics telemetry (local +X axle spin: + payout, - rewind/winch/haul).
var drive_angle := 0.0
var drive_omega := 0.0
var last_drive_delta := 0.0
var drive_direction := 0

# TADR-008 committed aim / tether geometry mesh.
var committed_mesh_node: MeshInstance3D
var _committed_material: StandardMaterial3D
var _committed_state := {
	"visible": false,
	"phase": "none",
	"from": Vector3.ZERO,
	"to": Vector3.ZERO,
	"point": Vector3.ZERO,
	"target": null,
}

var _scene_cache := {}
var _materials := {}
var _mount_rest := {}
var _head_rest := {}
var _tally_jaws: Array[Node3D] = []
var _was_hooked := false
var _prev_length := 0.0
var _payout_left := 0.0
var _dry_age := -1.0
var _dry_dir := Vector3.FORWARD
var _let_go_age := -1.0
var _broke_age := -1.0
var _gone_anchor := Vector3.ZERO
var _release_age := -1.0
var _skill_pulse_age := -1.0
var _last_actuator := {}


func setup(ctx_ref, hero_assets_ref = null, line_view_ref = null) -> void:
	ctx = ctx_ref
	name = "GrappleRig"
	player = ctx.player if ctx != null and "player" in ctx else null
	events = ctx.events if ctx != null and "events" in ctx else null
	hero_assets = hero_assets_ref
	line_view = line_view_ref
	_ensure_containers()
	_wire_events()
	_sync_pilot()


func setup_standalone(player_ref, events_ref = null, hero_assets_ref = null, line_view_ref = null) -> void:
	ctx = null
	name = "GrappleRig"
	player = player_ref
	events = events_ref
	hero_assets = hero_assets_ref
	line_view = line_view_ref
	_ensure_containers()
	_wire_events()
	_sync_pilot()


func _ensure_containers() -> void:
	if rig_root == null:
		rig_root = Node3D.new()
		rig_root.name = "RigMountRoot"
		add_child(rig_root)
	if committed_mesh_node == null:
		_committed_material = StandardMaterial3D.new()
		_committed_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_committed_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_committed_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_committed_material.no_depth_test = true
		_committed_material.render_priority = 11
		_committed_material.albedo_color = Palette.AMBER
		committed_mesh_node = MeshInstance3D.new()
		committed_mesh_node.name = "CommittedAim"
		committed_mesh_node.mesh = ImmediateMesh.new()
		committed_mesh_node.material_override = _committed_material
		committed_mesh_node.visible = false
		committed_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		committed_mesh_node.extra_cull_margin = 4096.0
		add_child(committed_mesh_node)


func _wire_events() -> void:
	if events == null:
		return
	if events.has_signal("line_state_changed") and not events.line_state_changed.is_connected(_on_line_state):
		events.line_state_changed.connect(_on_line_state)
	if events.has_signal("grapple_fired") and not events.grapple_fired.is_connected(_on_grapple_fired):
		events.grapple_fired.connect(_on_grapple_fired)
	if events.has_signal("grapple_released") and not events.grapple_released.is_connected(_on_grapple_released):
		events.grapple_released.connect(_on_grapple_released)
	if events.has_signal("line_skill_fired") and not events.line_skill_fired.is_connected(_on_line_skill_fired):
		events.line_skill_fired.connect(_on_line_skill_fired)
	if events.has_signal("run_started") and not events.run_started.is_connected(_on_run_started):
		events.run_started.connect(_on_run_started)


func _exit_tree() -> void:
	if events != null and is_instance_valid(events):
		if events.has_signal("line_state_changed") and events.line_state_changed.is_connected(_on_line_state):
			events.line_state_changed.disconnect(_on_line_state)
		if events.has_signal("grapple_fired") and events.grapple_fired.is_connected(_on_grapple_fired):
			events.grapple_fired.disconnect(_on_grapple_fired)
		if events.has_signal("grapple_released") and events.grapple_released.is_connected(_on_grapple_released):
			events.grapple_released.disconnect(_on_grapple_released)
		if events.has_signal("line_skill_fired") and events.line_skill_fired.is_connected(_on_line_skill_fired):
			events.line_skill_fired.disconnect(_on_line_skill_fired)
		if events.has_signal("run_started") and events.run_started.is_connected(_on_run_started):
			events.run_started.disconnect(_on_run_started)


func _process(delta: float) -> void:
	step(delta)


func reset() -> void:
	drive_angle = 0.0
	drive_omega = 0.0
	last_drive_delta = 0.0
	drive_direction = 0
	_was_hooked = false
	_prev_length = 0.0
	_payout_left = 0.0
	_dry_age = -1.0
	_let_go_age = -1.0
	_broke_age = -1.0
	_release_age = -1.0
	_skill_pulse_age = -1.0
	_last_actuator.clear()
	_committed_state = {"visible": false, "phase": "none", "from": Vector3.ZERO, "to": Vector3.ZERO, "point": Vector3.ZERO, "target": null}
	if drive_node != null and is_instance_valid(drive_node):
		drive_node.rotation = Vector3.ZERO
	if line_node != null and is_instance_valid(line_node):
		line_node.visible = false
	if committed_mesh_node != null and is_instance_valid(committed_mesh_node):
		(committed_mesh_node.mesh as ImmediateMesh).clear_surfaces()
		committed_mesh_node.visible = false


static func spec_for(class_id: String, line_id := "") -> Dictionary:
	if RIG_SPECS.has(class_id):
		return RIG_SPECS[class_id]
	var mapped := String(LINE_ID_TO_CLASS.get(line_id, "pylon_engineer"))
	return RIG_SPECS.get(mapped, RIG_SPECS["pylon_engineer"])


static func glb_paths_for(pilot_stem: String) -> Dictionary:
	return {
		"mount": "%sgrapple_%s_mount.glb" % [MODEL_DIR, pilot_stem],
		"drive": "%sgrapple_%s_drive.glb" % [MODEL_DIR, pilot_stem],
		"line": "%sgrapple_%s_line.glb" % [MODEL_DIR, pilot_stem],
		"head": "%sgrapple_%s_head.glb" % [MODEL_DIR, pilot_stem],
	}


func parts() -> Dictionary:
	return {
		"class_id": active_class_id,
		"line_id": active_line_id,
		"frame": mount_frame_path,
		"mount": mount_node,
		"drive": drive_node,
		"line": line_node,
		"head": head_node,
		"socket_drive": socket_drive,
		"socket_line": socket_line,
		"socket_head": socket_head,
		"mount_skeleton": mount_skeleton,
		"head_skeleton": head_skeleton,
		"rig_count": 1 if mount_node != null else 0,
	}


func committed_geometry() -> Dictionary:
	return _committed_state.duplicate()


func actuator_state() -> Dictionary:
	return _last_actuator.duplicate()


func _on_run_started(_class_id: String) -> void:
	reset()
	_sync_pilot()


func _on_grapple_fired(anchor: Vector3) -> void:
	_payout_left = PAYOUT_BURST_S
	_dry_age = -1.0
	_let_go_age = -1.0
	_broke_age = -1.0
	_release_age = -1.0
	_gone_anchor = anchor


func _on_grapple_released() -> void:
	_release_age = 0.0
	_payout_left = 0.0


func _on_line_skill_fired(_id: String, _target: Node3D, _at: Vector3, _on: String) -> void:
	_skill_pulse_age = 0.0


func _on_line_state(state: String, _target: Node3D, at: Vector3, _cause: String) -> void:
	match state:
		"dry_fire":
			_dry_age = 0.0
			_dry_dir = _dry_direction(at)
		"let_go":
			_let_go_age = 0.0
			_release_age = 0.0
			_gone_anchor = at
		"broke":
			_broke_age = 0.0
			_release_age = 0.0
			_gone_anchor = at


func _dry_direction(from: Vector3) -> Vector3:
	var state := _read_state()
	var aim: Dictionary = state.get("aim", {})
	if int(aim.get("state", Augments.AIM_NONE)) != Augments.AIM_NONE:
		var delta_v: Vector3 = (aim.get("point", Vector3.ZERO) as Vector3) - from
		if delta_v.length_squared() > 0.01:
			return delta_v.normalized()
	if ctx != null and ctx.has_method("aim_forward"):
		var fwd: Vector3 = ctx.aim_forward()
		if fwd.length_squared() > 0.01:
			return fwd.normalized()
	return Vector3.FORWARD


func _read_state() -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	if player.has_method("grapple_rig_state"):
		return player.grapple_rig_state()
	var kit = player.get("kit")
	var class_def = player.get("class_def")
	var class_id := String(class_def.id) if class_def != null else "pylon_engineer"
	var line_id := String(class_def.line_id) if class_def != null else "bank_shot"
	var pos: Vector3 = player.shown_position() if player.has_method("shown_position") else Vector3.ZERO
	return {
		"class_id": class_id,
		"line_id": line_id,
		"hooked": bool(kit.hooked) if kit != null else false,
		"on_body": bool(kit.on_body) if kit != null else false,
		"winching": bool(kit.winching) if kit != null else false,
		"rope": float(kit.rope) if kit != null else 0.0,
		"anchor": kit.anchor if kit != null else Vector3.ZERO,
		"anchor_body": kit.anchor_body if kit != null else null,
		"anchor_normal": kit.anchor_normal if kit != null else Vector3.ZERO,
		"aim": kit.aim if kit != null else Augments.no_aim(),
		"line_state": int(kit.line_state) if kit != null else Augments.LINE_IDLE,
		"shown_position": pos,
		"velocity": Vector3.ZERO,
		"chain": player.chain.snapshot() if player.get("chain") != null and player.chain.has_method("snapshot") else {},
	}


func _sync_pilot() -> void:
	var state := _read_state()
	if state.is_empty():
		return
	var want_class := String(state.get("class_id", "pylon_engineer"))
	var want_line := String(state.get("line_id", ""))
	if want_class == "":
		want_class = String(LINE_ID_TO_CLASS.get(want_line, "pylon_engineer"))
	if want_class == active_class_id and mount_node != null and is_instance_valid(mount_node):
		active_line_id = want_line if want_line != "" else String(spec_for(want_class)["line_id"])
		return
	_build_rig(want_class, want_line)


func _clear_rig() -> void:
	for node in [mount_node, line_node, head_node]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	mount_node = null
	drive_node = null
	line_node = null
	head_node = null
	socket_drive = null
	socket_line = null
	socket_head = null
	mount_skeleton = null
	head_skeleton = null
	_mount_rest.clear()
	_head_rest.clear()
	_tally_jaws.clear()


func _build_rig(class_id: String, line_id: String) -> void:
	_clear_rig()
	_ensure_containers()
	var spec := spec_for(class_id, line_id)
	active_class_id = class_id
	active_line_id = line_id if line_id != "" else String(spec["line_id"])
	mount_frame_path = String(spec["frame"])
	if String(spec["kind"]) == "glb":
		_build_glb_rig(String(spec["pilot"]))
	else:
		_build_tally_hardware()
	reset()


func _build_glb_rig(pilot_stem: String) -> void:
	var paths := glb_paths_for(pilot_stem)
	mount_node = _instantiate_glb(String(paths["mount"]), "GrappleMount")
	if mount_node == null:
		mount_node = Node3D.new()
		mount_node.name = "GrappleMount"
	rig_root.add_child(mount_node)
	socket_drive = mount_node.find_child("socket_drive", true, false) as Node3D
	socket_line = mount_node.find_child("socket_line", true, false) as Node3D
	socket_head = mount_node.find_child("socket_head", true, false) as Node3D
	if socket_drive == null:
		socket_drive = Node3D.new()
		socket_drive.name = "socket_drive"
		mount_node.add_child(socket_drive)
	if socket_line == null:
		socket_line = Node3D.new()
		socket_line.name = "socket_line"
		mount_node.add_child(socket_line)
	if socket_head == null:
		socket_head = Node3D.new()
		socket_head.name = "socket_head"
		mount_node.add_child(socket_head)

	drive_node = _instantiate_glb(String(paths["drive"]), "GrappleDrive")
	if drive_node == null:
		drive_node = Node3D.new()
		drive_node.name = "GrappleDrive"
	socket_drive.add_child(drive_node)

	line_node = _instantiate_glb(String(paths["line"]), "GrappleLine")
	if line_node == null:
		line_node = Node3D.new()
		line_node.name = "GrappleLine"
	line_node.visible = false
	add_child(line_node)

	head_node = _instantiate_glb(String(paths["head"]), "GrappleHead")
	if head_node == null:
		head_node = Node3D.new()
		head_node.name = "GrappleHead"
	add_child(head_node)

	mount_skeleton = mount_node.find_child("MountRig", true, false) as Skeleton3D
	if mount_skeleton == null:
		var skels := mount_node.find_children("*", "Skeleton3D", true, false)
		mount_skeleton = skels[0] as Skeleton3D if not skels.is_empty() else null
	head_skeleton = head_node.find_child("HeadRig", true, false) as Skeleton3D
	if head_skeleton == null:
		var hskels := head_node.find_children("*", "Skeleton3D", true, false)
		head_skeleton = hskels[0] as Skeleton3D if not hskels.is_empty() else null
	_capture_rest(mount_skeleton, _mount_rest)
	_capture_rest(head_skeleton, _head_rest)


# Tally's copper alligator-clamp and sheathed copper patch-lead hardware riding cleanly alongside
# shell_tally.glb: warm COPPER + AMBER + CHARCOAL sheath only (zero HAZARD, KINDNESS or ANCIENT).
func _build_tally_hardware() -> void:
	var copper_mat := _hardware_material("tally_copper", Palette.COPPER, 0.65, 0.35, 0.0)
	var amber_mat := _hardware_material("tally_amber", Palette.AMBER, 0.25, 0.45, 0.35)
	var sheath_mat := _hardware_material("tally_sheath", Palette.CHARCOAL, 0.1, 0.85, 0.0)

	mount_node = Node3D.new()
	mount_node.name = "GrappleMount"
	rig_root.add_child(mount_node)
	var bracket := MeshInstance3D.new()
	bracket.name = "TallyClipBracket"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.18, 0.28)
	bracket.mesh = bm
	bracket.material_override = copper_mat
	bracket.position = Vector3(0.42, 0.08, -0.58)
	mount_node.add_child(bracket)

	socket_drive = Node3D.new()
	socket_drive.name = "socket_drive"
	socket_drive.position = Vector3(0.56, 0.10, -0.54)
	mount_node.add_child(socket_drive)

	socket_line = Node3D.new()
	socket_line.name = "socket_line"
	socket_line.position = Vector3(0.42, 0.08, -0.76)
	mount_node.add_child(socket_line)

	socket_head = Node3D.new()
	socket_head.name = "socket_head"
	socket_head.position = Vector3(0.42, 0.08, -0.84)
	mount_node.add_child(socket_head)

	drive_node = Node3D.new()
	drive_node.name = "GrappleDrive"
	socket_drive.add_child(drive_node)
	var spool := MeshInstance3D.new()
	spool.name = "TallyLeadSpool"
	var sm := CylinderMesh.new()
	sm.top_radius = 0.14
	sm.bottom_radius = 0.14
	sm.height = 0.12
	spool.mesh = sm
	spool.rotation.z = PI * 0.5
	spool.material_override = copper_mat
	drive_node.add_child(spool)
	var spoke := MeshInstance3D.new()
	spoke.name = "TallySpoolMarker"
	var km := BoxMesh.new()
	km.size = Vector3(0.14, 0.24, 0.04)
	spoke.mesh = km
	spoke.material_override = amber_mat
	drive_node.add_child(spoke)

	line_node = Node3D.new()
	line_node.name = "GrappleLine"
	line_node.visible = false
	add_child(line_node)
	var lead := MeshInstance3D.new()
	lead.name = "TallyPatchLead"
	var lm := CylinderMesh.new()
	lm.top_radius = 0.045
	lm.bottom_radius = 0.045
	lm.height = 1.0
	lead.mesh = lm
	lead.rotation.x = PI * 0.5
	lead.position = Vector3(0.0, 0.0, -0.5)
	lead.material_override = sheath_mat
	line_node.add_child(lead)
	var stripe := MeshInstance3D.new()
	stripe.name = "TallyCopperCore"
	var cm := BoxMesh.new()
	cm.size = Vector3(0.06, 0.06, 1.0)
	stripe.mesh = cm
	stripe.position = Vector3(0.0, 0.0, -0.5)
	stripe.material_override = copper_mat
	line_node.add_child(stripe)

	head_node = Node3D.new()
	head_node.name = "GrappleHead"
	add_child(head_node)
	var boot := MeshInstance3D.new()
	boot.name = "TallyClampBoot"
	var boot_m := BoxMesh.new()
	boot_m.size = Vector3(0.16, 0.14, 0.22)
	boot.mesh = boot_m
	boot.position = Vector3(0.0, 0.0, -0.10)
	boot.material_override = amber_mat
	head_node.add_child(boot)
	for side_sign: float in [1.0, -1.0]:
		var jaw := Node3D.new()
		jaw.name = "JawTop" if side_sign > 0.0 else "JawBot"
		jaw.position = Vector3(0.0, side_sign * 0.04, -0.18)
		var tooth := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.12, 0.05, 0.28)
		tooth.mesh = tm
		tooth.position = Vector3(0.0, 0.0, -0.14)
		tooth.material_override = copper_mat
		jaw.add_child(tooth)
		head_node.add_child(jaw)
		_tally_jaws.append(jaw)


func _instantiate_glb(path: String, label: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("grapple_rig: missing GLB %s" % path)
		return null
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var packed := _scene_cache[path] as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate() as Node3D
	if root == null:
		return null
	root.name = label
	_paint_tree(root)
	return root


func _paint_tree(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i)
			var slot := String(orig.resource_name) if orig != null else ""
			var mat := _slot_material(slot)
			if mat != null:
				mi.set_surface_override_material(i, mat)


func _slot_material(slot_name: String) -> StandardMaterial3D:
	if _materials.has(slot_name):
		return _materials[slot_name]
	var mat := StandardMaterial3D.new()
	match slot_name:
		"hydraulic":
			mat.albedo_color = Color.WHITE
			mat.vertex_color_use_as_albedo = true
			mat.vertex_color_is_srgb = true
			mat.metallic = 0.4
			mat.roughness = 0.35
		"paint":
			mat.albedo_color = Color.WHITE
			mat.vertex_color_use_as_albedo = true
			mat.vertex_color_is_srgb = true
			mat.metallic = 0.15
			mat.roughness = 0.72
		"copper":
			mat.albedo_color = Palette.COPPER
			mat.metallic = 0.6
			mat.roughness = 0.4
		_:
			mat.albedo_color = Color.WHITE
			mat.vertex_color_use_as_albedo = true
			mat.vertex_color_is_srgb = true
			mat.metallic = 0.35
			mat.roughness = 0.45
	_materials[slot_name] = mat
	return mat


func _hardware_material(key: String, color: Color, metallic: float, roughness: float, emit: float) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emit
	_materials[key] = mat
	return mat


static func _capture_rest(skeleton: Skeleton3D, out: Dictionary) -> void:
	out.clear()
	if skeleton == null:
		return
	for i in skeleton.get_bone_count():
		out[skeleton.get_bone_name(i)] = {
			"idx": i,
			"pos": skeleton.get_bone_pose_position(i),
			"rot": skeleton.get_bone_pose_rotation(i),
		}


func step(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_sync_pilot()
	if mount_node == null or not is_instance_valid(mount_node):
		return
	var state := _read_state()
	if state.is_empty():
		return
	_advance_timers(delta)
	_sync_mount_frame(state)
	var hooked: bool = bool(state.get("hooked", false))
	var fresh_hook := hooked and not _was_hooked
	if fresh_hook:
		_payout_left = PAYOUT_BURST_S
		_dry_age = -1.0
		_let_go_age = -1.0
		_broke_age = -1.0
		_release_age = -1.0
	elif _was_hooked and not hooked and _release_age < 0.0:
		_release_age = 0.0
	_was_hooked = hooked

	var fairlead: Vector3 = socket_line.global_position if socket_line != null and socket_line.is_inside_tree() else (state["shown_position"] as Vector3)
	var dock_xform: Transform3D = socket_head.global_transform if socket_head != null and socket_head.is_inside_tree() else Transform3D(Basis.IDENTITY, fairlead)
	var head_pos := dock_xform.origin
	var line_active := false

	if hooked:
		head_pos = state["anchor"] as Vector3
		line_active = true
		_pose_head_world(head_pos, fairlead, state.get("anchor_normal", Vector3.ZERO) as Vector3)
	elif _dry_age >= 0.0:
		var reach := DRY_DART_M * clampf(_dry_age / DRY_REACH_S, 0.0, 1.0)
		var back := clampf((_dry_age - DRY_REACH_S) / maxf(0.01, DRY_TIME_S - DRY_REACH_S), 0.0, 1.0)
		head_pos = fairlead + _dry_dir * (reach * (1.0 - back))
		line_active = true
		_pose_head_world(head_pos, fairlead, Vector3.ZERO)
	elif _let_go_age >= 0.0:
		var t := clampf(_let_go_age / LET_GO_TIME_S, 0.0, 1.0)
		head_pos = _gone_anchor.lerp(dock_xform.origin, t)
		line_active = t < 0.99
		_pose_head_world(head_pos, fairlead, Vector3.ZERO)
	elif _broke_age >= 0.0:
		var t := clampf(_broke_age / BROKE_TIME_S, 0.0, 1.0)
		head_pos = _gone_anchor.lerp(dock_xform.origin, t)
		line_active = t < 0.99
		_pose_head_world(head_pos, fairlead, Vector3.ZERO)
	else:
		if head_node != null and head_node.is_inside_tree():
			head_node.global_transform = dock_xform

	var span_len := fairlead.distance_to(head_pos) if line_active else 0.0
	_pose_line(fairlead, head_pos, line_active, span_len)
	_step_drive(delta, state, line_active, fresh_hook, span_len)
	_step_actuators(state, line_active)
	_draw_committed_geometry(state, fairlead)


func _advance_timers(delta: float) -> void:
	if _payout_left > 0.0:
		_payout_left = maxf(0.0, _payout_left - delta)
	if _dry_age >= 0.0:
		_dry_age += delta
		if _dry_age >= DRY_TIME_S:
			_dry_age = -1.0
	if _let_go_age >= 0.0:
		_let_go_age += delta
		if _let_go_age >= LET_GO_TIME_S:
			_let_go_age = -1.0
	if _broke_age >= 0.0:
		_broke_age += delta
		if _broke_age >= BROKE_TIME_S:
			_broke_age = -1.0
	if _release_age >= 0.0:
		_release_age += delta
		if _release_age >= RELEASE_ACTUATOR_S:
			_release_age = -1.0
	if _skill_pulse_age >= 0.0:
		_skill_pulse_age += delta
		if _skill_pulse_age >= SKILL_PULSE_S:
			_skill_pulse_age = -1.0


func _sync_mount_frame(state: Dictionary) -> void:
	var target_frame := _resolve_mount_frame()
	if target_frame != null and target_frame.is_inside_tree():
		rig_root.global_transform = target_frame.global_transform
	else:
		rig_root.global_transform = Transform3D(Basis.IDENTITY, state["shown_position"] as Vector3)


func _resolve_mount_frame() -> Node3D:
	if hero_assets != null and is_instance_valid(hero_assets) and hero_assets.has_method("shell_of"):
		var shell: Dictionary = hero_assets.shell_of(player)
		var pod := shell.get("pod") as Node3D
		if pod != null and is_instance_valid(pod) and pod.is_inside_tree():
			if mount_frame_path == "Pod/WeaponRing":
				var ring := pod.get_node_or_null("WeaponRing") as Node3D
				if ring != null and ring.is_inside_tree():
					return ring
			return pod
	return null


func _pose_head_world(head_pos: Vector3, fairlead: Vector3, normal: Vector3) -> void:
	if head_node == null or not head_node.is_inside_tree():
		return
	var forward := head_pos - fairlead
	if forward.length_squared() < 0.0001 and normal.length_squared() > 0.0001:
		forward = -normal
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	head_node.global_transform = Transform3D(Basis.looking_at(forward, up), head_pos)


func _pose_line(from: Vector3, to: Vector3, show_line: bool, span_len: float) -> void:
	if line_node == null or not line_node.is_inside_tree():
		return
	line_node.visible = show_line and span_len > 0.05
	if not line_node.visible:
		return
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	line_node.global_transform = Transform3D(basis, from)
	line_node.scale = Vector3(1.0, 1.0, maxf(0.05, span_len))


func _step_drive(delta: float, state: Dictionary, line_active: bool, fresh_hook: bool, span_len: float) -> void:
	var hooked: bool = bool(state.get("hooked", false))
	var winching: bool = bool(state.get("winching", false)) or int(state.get("line_state", Augments.LINE_IDLE)) == Augments.LINE_SMASH
	var target_omega := 0.0
	if hooked:
		if fresh_hook:
			_prev_length = span_len
			target_omega = PAYOUT_BURST_OMEGA
		else:
			var delta_len := span_len - _prev_length
			_prev_length = span_len
			if winching:
				target_omega = minf(WINCH_OMEGA, delta_len / maxf(0.001, delta * DRIVE_RADIUS_M))
			elif _payout_left > 0.0 and delta_len >= -0.02:
				target_omega = maxf(PAYOUT_BURST_OMEGA, delta_len / maxf(0.001, delta * DRIVE_RADIUS_M))
			elif absf(delta_len) > 0.002:
				target_omega = clampf(delta_len / maxf(0.001, delta * DRIVE_RADIUS_M), -28.0, 28.0)
	elif _dry_age >= 0.0:
		target_omega = PAYOUT_BURST_OMEGA if _dry_age <= DRY_REACH_S else RECOIL_OMEGA
		_prev_length = span_len
	elif _let_go_age >= 0.0 or _broke_age >= 0.0:
		target_omega = RECOIL_OMEGA
		_prev_length = span_len
	else:
		_prev_length = 0.0
		target_omega = 0.0

	if line_active or absf(target_omega) > 0.01:
		drive_omega = target_omega
	else:
		drive_omega = move_toward(drive_omega, 0.0, DRIVE_COAST_DAMP * delta * maxf(1.0, absf(drive_omega)))
	last_drive_delta = drive_omega * delta
	drive_angle = wrapf(drive_angle + last_drive_delta, -TAU * 8.0, TAU * 8.0)
	if last_drive_delta > 0.0005:
		drive_direction = 1
	elif last_drive_delta < -0.0005:
		drive_direction = -1
	else:
		drive_direction = 0
	if drive_node != null and is_instance_valid(drive_node):
		drive_node.rotation = Vector3(drive_angle, 0.0, 0.0)


func _step_actuators(state: Dictionary, _line_active: bool) -> void:
	var hooked: bool = bool(state.get("hooked", false))
	var spec := spec_for(active_class_id, active_line_id)
	var pilot := String(spec["pilot"])
	var release_t := 1.0 - clampf(_release_age / RELEASE_ACTUATOR_S, 0.0, 1.0) if _release_age >= 0.0 else 0.0
	var skill_t := clampf(_skill_pulse_age / SKILL_PULSE_S, 0.0, 1.0) if _skill_pulse_age >= 0.0 else 0.0
	var summary := {"pilot": pilot, "hooked": hooked}

	match pilot:
		"sable":
			var lever_deg := -18.0 if hooked else 0.0
			var latch_deg := 55.0 * release_t
			_pose_bone_rot(mount_skeleton, _mount_rest, "lever", Vector3.UP, deg_to_rad(lever_deg))
			_pose_bone_rot(head_skeleton, _head_rest, "latch", Vector3.RIGHT, deg_to_rad(latch_deg))
			summary["lever_deg"] = lever_deg
			summary["latch_deg"] = latch_deg
		"rivet":
			var guide_m := 0.09 * sin(drive_angle)
			var toggle_deg := 90.0 if hooked else 0.0
			_pose_bone_slide(mount_skeleton, _mount_rest, "guide", Vector3(0.0, guide_m, 0.0))
			_pose_bone_rot(head_skeleton, _head_rest, "toggle", Vector3.RIGHT, deg_to_rad(toggle_deg))
			summary["guide_m"] = guide_m
			summary["toggle_deg"] = toggle_deg
		"kest":
			var in_flight := _dry_age >= 0.0
			var fluke_deg := -50.0 if in_flight else 0.0
			var trolley_m := 0.24 * skill_t if _skill_pulse_age >= 0.0 else (0.08 if hooked else 0.0)
			_pose_bone_slide(mount_skeleton, _mount_rest, "trolley", Vector3(0.0, trolley_m, 0.0))
			for k in KEST_FLUKE_PHIS.size():
				var phi := float(KEST_FLUKE_PHIS[k])
				var tg := Vector3(-sin(phi), 0.0, cos(phi))
				_pose_bone_rot(head_skeleton, _head_rest, "fluke.%d" % k, tg, deg_to_rad(fluke_deg))
			summary["trolley_m"] = trolley_m
			summary["fluke_deg"] = fluke_deg
		"tarn":
			var pawl_deg := 20.0 if absf(drive_omega) > 0.25 else 0.0
			var talon_deg := 35.0 if hooked else 0.0
			_pose_bone_rot(mount_skeleton, _mount_rest, "pawl", Vector3.RIGHT, deg_to_rad(pawl_deg))
			for k in TARN_TALON_PHIS.size():
				var phi := float(TARN_TALON_PHIS[k])
				var tg := Vector3(-sin(phi), 0.0, cos(phi))
				_pose_bone_rot(head_skeleton, _head_rest, "talon.%d" % k, tg, deg_to_rad(talon_deg))
			summary["pawl_deg"] = pawl_deg
			summary["talon_deg"] = talon_deg
		"cannon":
			var lock_deg := -25.0 if hooked else 0.0
			var cap_m := 0.25 * maxf(release_t, 1.0 - skill_t if _skill_pulse_age >= 0.0 else 0.0)
			_pose_bone_rot(mount_skeleton, _mount_rest, "lock", Vector3.UP, deg_to_rad(lock_deg))
			_pose_bone_slide(head_skeleton, _head_rest, "cap", Vector3(0.0, -cap_m, 0.0))
			summary["lock_deg"] = lock_deg
			summary["cap_m"] = cap_m
		"tally":
			var jaw_deg := 4.0 if hooked else (24.0 if release_t > 0.0 else 14.0)
			if _tally_jaws.size() >= 2:
				_tally_jaws[0].rotation.x = deg_to_rad(jaw_deg)
				_tally_jaws[1].rotation.x = -deg_to_rad(jaw_deg)
			summary["jaw_deg"] = jaw_deg
	_last_actuator = summary


static func _pose_bone_rot(skeleton: Skeleton3D, rest_map: Dictionary, bone_name: String, axis: Vector3, angle: float) -> void:
	if skeleton == null or not rest_map.has(bone_name):
		return
	var row: Dictionary = rest_map[bone_name]
	var rest_rot: Quaternion = row["rot"]
	skeleton.set_bone_pose_rotation(int(row["idx"]), rest_rot * Quaternion(axis.normalized(), angle))


static func _pose_bone_slide(skeleton: Skeleton3D, rest_map: Dictionary, bone_name: String, offset: Vector3) -> void:
	if skeleton == null or not rest_map.has(bone_name):
		return
	var row: Dictionary = rest_map[bone_name]
	var rest_pos: Vector3 = row["pos"]
	skeleton.set_bone_pose_position(int(row["idx"]), rest_pos + offset)


# TADR-008: draws committed grapple target geometry strictly from kit.aim (before hit) or
# kit.anchor (while hooked), so what the player sees is the exact geometry the grapple uses.
func _draw_committed_geometry(state: Dictionary, fairlead: Vector3) -> void:
	if committed_mesh_node == null or not is_instance_valid(committed_mesh_node):
		return
	var mesh := committed_mesh_node.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var hooked: bool = bool(state.get("hooked", false))
	var aim: Dictionary = state.get("aim", {})
	var aim_state: int = int(aim.get("state", Augments.AIM_NONE))
	if not hooked and aim_state == Augments.AIM_NONE:
		committed_mesh_node.visible = false
		_committed_state = {"visible": false, "phase": "none", "from": Vector3.ZERO, "to": Vector3.ZERO, "point": Vector3.ZERO, "target": null}
		return

	var point: Vector3 = (state["anchor"] as Vector3) if hooked else (aim.get("point", Vector3.ZERO) as Vector3)
	var normal: Vector3 = (state.get("anchor_normal", Vector3.UP) as Vector3) if hooked else (aim.get("normal", Vector3.UP) as Vector3)
	var target = state.get("anchor_body") if hooked else aim.get("body")
	var phase := "latched" if hooked else "aim"
	var color: Color = EventKinds.line_color("latched_world") if hooked else EventKinds.line_color("locked")
	_committed_material.albedo_color = Color(color.r, color.g, color.b, 0.85 if hooked else 0.72)

	var span := point - fairlead
	if span.length_squared() > 0.0025:
		var dir := span.normalized()
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = dir.cross(Vector3.RIGHT)
		side = side.normalized() * AIM_LINE_HALF
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		mesh.surface_add_vertex(fairlead + side)
		mesh.surface_add_vertex(fairlead - side)
		mesh.surface_add_vertex(point + side)
		mesh.surface_add_vertex(fairlead - side)
		mesh.surface_add_vertex(point - side)
		mesh.surface_add_vertex(point + side)
		mesh.surface_end()

	var ring_n := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	var tangent := ring_n.cross(Vector3.UP)
	if tangent.length_squared() < 0.001:
		tangent = ring_n.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := ring_n.cross(tangent).normalized()
	var radius := LOCK_RING_RADIUS if hooked else AIM_RING_RADIUS
	var inner := radius - 0.08
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in AIM_RING_SEGMENTS + 1:
		var a := TAU * float(i) / float(AIM_RING_SEGMENTS)
		var radial := tangent * cos(a) + bitangent * sin(a)
		mesh.surface_add_vertex(point + ring_n * 0.04 + radial * inner)
		mesh.surface_add_vertex(point + ring_n * 0.04 + radial * radius)
	mesh.surface_end()

	committed_mesh_node.visible = mesh.get_surface_count() > 0
	_committed_state = {
		"visible": committed_mesh_node.visible,
		"phase": phase,
		"from": fairlead,
		"to": point,
		"point": point,
		"target": target,
	}
