extends "res://src/combat/counter.gd"

# The prop crew (roster_dig.gd, world 2; design-v3/WORLD-ROSTERS.md): a Dig crew that
# shores a cracked roof over its own pack. It walks to where its pack mates stand and holds
# a timber prop up under a roof frame. It never attacks. Any ball contact on the crew (a
# ram, a stomp, a slam) knocks the prop out, and the roof comes down on everything under
# it: every enemy in the disc takes ROOF_DAMAGE, the crew too if the ram left it under, and the ball,
# but only while it is on the floor (floor_rule.gd). Ram it from the wall side and the roof
# lands on its pack and never on you.
#
# The fall is its own node (rubble_fall.gd) on the world root, so a ram that kills the crew
# still brings the roof down. It waits for the shared warning gap before it warns.

const RubbleFall := preload("res://src/world/events/rubble_fall.gd")
const FoleyAudio := preload("res://src/presentation/foley_audio.gd")

const HP := 60.0
# The body (tools/blender/world_two/enemy_prop_crew.py, PR #64) carries a 5.2 m by 4.0 m
# canopy whose underside is 3.3 m above the floor, centred behind the crew; the disc is the
# circle round it, so everything under the timber is inside the hit.
const BODY_PATH := "res://assets/models/world_two/enemy_prop_crew.glb"
const ROOF_RADIUS := 3.3
const ROOF_HEIGHT := 3.3
const CANOPY_CENTRE := Vector3(0.0, 0.0, -1.3)
const ROOF_WARN := 1.0
# Roof damage is per point of stage threat, like enemy health, so the roof crushes the
# Dig's ordinary pack (burrower 45, drill crew 90 per threat) whatever the stage.
const ROOF_DAMAGE := 120.0
const ROOF_BALL_DAMAGE := 12.0
const ROOF_SHOVE := Vector3(0.0, 4.0, 0.0)
# Where the crew looks for its pack, and how close it stands to their middle.
const GATHER_M := 22.0
const SETTLE_M := 2.5
const WALK := 3.4
const PROP_OFFSET := Vector3(0.75, 0.0, 0.35)

static var _shared := {}

var prop_up := true
var drops := 0
var last_fall: Node3D
var _threat := 1.0
var _prop: Node3D
var _roof: Node3D
var _prop_from_glb := false


func _configure(threat: float) -> void:
	_threat = threat
	_set_health(HP * threat)
	scrap_value = 5
	weight = 1.3
	walk_speed = WALK
	keep_near = 6.0
	keep_far = 16.0
	attack_range = 0.0
	warn_seconds = ROOF_WARN
	interruptible = false


func _build_tool() -> void:
	var presence := FoleyAudio.player("prop_crew_presence", self)
	if presence != null:
		presence.autoplay = true
	var parts := _parts()
	if not parts.is_empty():
		_build_body(parts)
		return
	_prop = _cylinder(0.22, ROOF_HEIGHT, Palette.SANDSTONE, PROP_OFFSET + Vector3(0.0, ROOF_HEIGHT * 0.5 - CREW_HALF, 0.0))
	_roof = _build_roof()
	add_child(_roof)


# The body's three meshes: PropCrewBody flashes with the enemy, PropShore is the prop (its
# origin at its foot, so a knock pivots it there) and PropCanopy goes into ShoredRoof, a
# holder at the canopy_centre socket and the canopy's underside, so the fall drops it by
# its middle.
func _build_body(parts: Dictionary) -> void:
	_crew.free()
	_crew = null
	_base_color = Color.WHITE
	_material.albedo_color = _base_color
	_material.vertex_color_use_as_albedo = true
	var centre: Vector3 = parts.sockets.get("canopy_centre", CANOPY_CENTRE - Vector3(0.0, CREW_HALF, 0.0))
	_roof = Node3D.new()
	_roof.name = "ShoredRoof"
	_roof.position = Vector3(centre.x, centre.y + ROOF_HEIGHT, centre.z)
	add_child(_roof)
	for part in parts.meshes:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		if part.flash >= 0:
			mi.set_surface_override_material(part.flash, _material)
		if part.name == "PropCanopy":
			mi.transform.origin -= _roof.position
			_roof.add_child(mi)
			continue
		_visual_parent().add_child(mi)
		if part.name == "PropShore":
			_prop = mi
			_prop_from_glb = true


static func _parts() -> Dictionary:
	if not _shared.is_empty() or not ResourceLoader.exists(BODY_PATH):
		return _shared
	var packed := load(BODY_PATH) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var meshes := []
	var sockets := {}
	for node in scene.find_children("*", "Node3D", true, false):
		var at: Transform3D = _local_to(scene, node)
		if node is MeshInstance3D:
			var mesh: Mesh = node.mesh.duplicate()
			var flash := -1
			for i in mesh.get_surface_count():
				var surface_material := mesh.surface_get_material(i)
				var slot := surface_material.resource_name if surface_material != null else ""
				if slot == "fleet_paint":
					flash = i
				var painted := Palette.solid(Color.WHITE)
				painted.vertex_color_use_as_albedo = true
				painted.metallic = 0.45 if slot == "working_tool" else 0.0
				painted.roughness = 0.5 if slot == "working_tool" else (0.9 if slot == "part_state" else 0.82)
				mesh.surface_set_material(i, painted)
			meshes.append({"name": String(node.name), "mesh": mesh, "xform": at, "flash": flash})
		elif String(node.name) in ["canopy_centre", "prop_hit", "crew_head"]:
			sockets[String(node.name)] = at.origin
	scene.free()
	_shared = {"meshes": meshes, "sockets": sockets}
	return _shared


# A node's transform relative to the scene root, outside the tree.
static func _local_to(root_node: Node, node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root_node:
		if walk is Node3D:
			xf = walk.transform * xf
		walk = walk.get_parent()
	return xf


# A shoring frame, not a slab: four timbers round a cracked plate, so a camera above still
# reads the pack under it.
func _build_roof() -> Node3D:
	var roof := Node3D.new()
	roof.name = "ShoredRoof"
	roof.position = CANOPY_CENTRE + Vector3(0.0, ROOF_HEIGHT - CREW_HALF, 0.0)
	var span := ROOF_RADIUS * 1.6
	for side in [-1.0, 1.0]:
		_box(Vector3(span, 0.3, 0.4), Palette.SANDSTONE.darkened(0.2), Vector3(0.0, 0.0, side * span * 0.5), 0.0, roof)
		_box(Vector3(0.4, 0.3, span), Palette.SANDSTONE.darkened(0.2), Vector3(side * span * 0.5, 0.0, 0.0), 0.0, roof)
	_box(Vector3(span * 0.7, 0.12, span * 0.7), Palette.SLATE.darkened(0.35), Vector3(0.0, 0.18, 0.0), 0.0, roof)
	for i in 3:
		_box(Vector3(span * 0.6, 0.02, 0.08), Palette.HAZARD, Vector3(0.0, 0.25, (i - 1) * span * 0.2), 0.6, roof)
	return roof


func _wants_attack(_to_ball: Vector3) -> bool:
	return false


# It walks to its pack, not to the ball; alone, it keeps its distance like any crew.
func _roam(to_ball: Vector3) -> Vector3:
	if not prop_up:
		return super._roam(to_ball)
	var mates := pack_centre()
	if mates == Vector3.INF:
		return super._roam(to_ball)
	# It stands so its roof, not itself, is over the middle of its pack.
	var to := mates - roof_centre()
	to.y = 0.0
	if to.length() <= SETTLE_M:
		return Vector3.ZERO
	return to.normalized() * walk_speed


# The middle of the other living enemies within GATHER_M, or INF when there are none.
func pack_centre() -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	var sum := Vector3.ZERO
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if String(enemy.get("kind")) == kind:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= GATHER_M:
			sum += enemy.global_position
			count += 1
	return sum / count if count > 0 else Vector3.INF


func roof_centre() -> Vector3:
	return _roof.global_position if _roof != null and _roof.is_inside_tree() else global_position


func on_struck(kind_hit: String, _part: String, _result: Dictionary) -> void:
	if kind_hit in ["ram", "stomp", "slam"]:
		knock_prop()


# The prop goes and the roof falls. Returns the fall, or null when the prop was already out.
func knock_prop() -> Node3D:
	if not prop_up or world_root == null:
		return null
	prop_up = false
	drops += 1
	var at := roof_centre()
	var ground_y: float = terrain.height(at.x, at.z) if terrain != null else at.y - ROOF_HEIGHT
	var slab := _roof
	var turn := slab.global_basis if slab.is_inside_tree() else Basis.IDENTITY
	slab.get_parent().remove_child(slab)
	slab.position = at
	slab.basis = turn
	# E31's pose (event_kinds.gd, e31_prop_kicked): the prop knocked out from under the roof.
	if _prop != null:
		if _prop_from_glb:
			_prop.rotation.x = PI * 0.4
		else:
			_prop.rotation.z = PI * 0.4
	var fall = RubbleFall.new()
	# The fall outlives the crew, so its hit goes straight to combat's player-hit path and
	# its discovery to the fleet, never through this node.
	var ball_hit := Callable()
	if fleet != null and fleet.combat != null:
		ball_hit = Callable(fleet.combat, "_on_player_hit").bind(ROOF_BALL_DAMAGE, ROOF_SHOVE, kind)
	var fall_key := "prop_roof_%d" % get_instance_id()
	fall.configure(fall_key, Vector3(at.x, ground_y, at.z), ROOF_RADIUS, ROOF_WARN,
		terrain,
		_player(), ball_hit, ROOF_DAMAGE * _threat, slab)
	fall.voice = Roster.voiced(String(Roster.faction(faction)["voice"]), _motif())
	fall.tag = String(row.get("tag", ""))
	fall.on_crush = _crush_discovery(fleet)
	fall.warn_sound = "prop_crew_strain"
	fall.land_sound = "prop_crew_collapse"
	fall.land_lead = FoleyAudio.COLLAPSE_LAND
	fall.spare_id = get_instance_id()
	world_root.add_child(fall)
	slab.global_position = at
	last_fall = fall
	_roof = null
	return fall


# Made in a static function, so the callable holds the fleet and not this crew, which the
# roof usually kills before it lands.
static func _crush_discovery(fleet_ref) -> Callable:
	return func(at: Vector3) -> void:
		if fleet_ref != null and is_instance_valid(fleet_ref):
			fleet_ref.discover("roof_drop", at)
