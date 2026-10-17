extends "res://src/combat/counter.gd"

# The Splitter (kill-first special, roster_specials.gd; ENEMY-PRIORITY.md 7b and 4a): a fat
# scrap-bomb crawler of three welded pods. It crawls in and fuses a scrap blast around
# itself, again and again, so a Splitter left alone keeps hurting you while you fight its
# pack. How it dies is the read:
#
# - killed at ground level from close (a ram, a close shot or claw): its seams flare white
#   for POP_DELAY and it pops into three pieces, small chasers that keep the lunge lane;
# - killed by a stomp or slam from above, or by any hit from CLEAN_RANGE or more: one clean
#   pop and nothing follows.
#
# The effects contract (design-v3/MACHINE-VFX.md, PR #51, and the special cues): the
# committed-telegraph frame fires special_tell("tell") and SpecialCues.tell(self), and meta
# "split" is set before died goes out. Pieces are made by the spawner as ordinary chasers,
# then shrunk and dressed (make_piece), so each is an attacker in its own right; they keep
# the Splitter's director pack, so the attacker budget reads them as one volley. A piece is
# light (PIECE_WEIGHT), so a grown ball's harpoon swings it as a flail.

const ChaserScript := preload("res://src/combat/chaser.gd")
# The specials' cue hub (CONTRACTS.md "Special cues"); loaded only once that file lands.
const CUES := "res://src/combat/special_cues.gd"

signal special_tell(moment: String)

const HP := 90.0
const SCRAP := 6
const WEIGHT := 2.0
# The recipe's suggested collider (tools/blender/world_one/enemy_splitter.py).
const BODY_RADIUS := 1.3
const BODY_HALF := 1.35
const WALK := 5.0
const BLAST_RADIUS := 4.5
const BLAST_RANGE := 4.0
const BLAST_DAMAGE := 10.0
const BLAST_SHOVE := 8.0
const FUSE := 1.0
const CLEAN_RANGE := 15.0
const CLEAN_KINDS := ["stomp", "slam"]
const POP_DELAY := 0.4
const PIECES := 3
const PIECE_SCALE := 0.6
const PIECE_HP := 25.0
const PIECE_WEIGHT := 0.6
const PIECE_SPREAD := 1.6
const SEAM_IDLE := 0.4
const SEAM_FLARE := 4.0
const SEAM_WHITE := Color("f4efe2")
const SEAM_BRASS := Palette.BRASS
# A seam flare not yet popped: enemies still to come, so a fight is not over while one stands.
const PENDING := "enemy_pending"

var blasts := 0
var split := false
var _last_hit := {}
var _seam_material: StandardMaterial3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = SCRAP
	weight = WEIGHT
	walk_speed = WALK
	keep_near = 1.0
	keep_far = 30.0
	attack_range = BLAST_RANGE
	warn_seconds = FUSE
	live_seconds = 0.15
	rest_seconds = 2.6
	first_rest = 1.0


# The body (enemy_splitter.glb, PR #24): the three pods on fleet paint, which flashes, and
# one lit seam surface (seams, caps, eyes and the fuse lamp) that glows up as the fuse
# burns. The collider is the recipe's suggested capsule, not the counter crew's.
func _build_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Palette.RUST).free()
	_seam_material = Palette.solid(SEAM_BRASS, SEAM_IDLE)
	var parts := body_parts()
	for part in parts["meshes"]:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		mi.set_surface_override_material(0, _material if part.paint else _seam_material)
		_visual_parent().add_child(mi)
		if part.paint:
			_crew = mi
	_base_color = Color.WHITE
	_material.albedo_color = _base_color
	_material.vertex_color_use_as_albedo = true


static var _body := {}
static var _piece := {}


# A glb's meshes, each flagged paint (fleet_paint) or lit (anything else), and its sockets.
static func _read(path: String) -> Dictionary:
	var out := {"meshes": [], "sockets": {}}
	var scene := (load(path) as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "", true, false):
		if node is MeshInstance3D:
			var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
			var surface := mesh.surface_get_material(0)
			var paint := surface != null and surface.resource_name == "fleet_paint"
			for i in mesh.get_surface_count():
				mesh.surface_set_material(i, painted)
			out["meshes"].append({"name": String(node.name), "mesh": mesh, "xform": node.transform, "paint": paint})
		elif node is Node3D:
			out["sockets"][String(node.name)] = (node as Node3D).transform
	scene.free()
	return out


static func body_parts() -> Dictionary:
	if _body.is_empty():
		_body = _read("res://assets/models/world_one/enemy_splitter.glb")
	return _body


static func piece_parts() -> Dictionary:
	if _piece.is_empty():
		_piece = _read("res://assets/models/world_one/enemy_splitter_piece.glb")
	return _piece


# Where each piece pops out: straight out from its pod's socket, PIECE_SPREAD from the middle.
func pod_offsets() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var sockets: Dictionary = body_parts()["sockets"]
	for i in PIECES:
		var name := "pod_" + "abc"[i]
		var angle := TAU * i / PIECES
		var flat := Vector3(cos(angle), 0.0, sin(angle))
		if sockets.has(name):
			var at: Vector3 = global_basis * (sockets[name] as Transform3D).origin
			at.y = 0.0
			if at.length() > 0.01:
				flat = at.normalized()
		out.append(flat * PIECE_SPREAD)
	return out


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	var ring := _commit_ring(Threat.Type.INSTANT, global_position, BLAST_RADIUS, 2.2, Palette.HAZARD)
	if ring != null:
		special_tell.emit("tell")
		if ResourceLoader.exists(CUES):
			load(CUES).tell(self)
	return ring


func _go_live() -> void:
	blasts += 1
	var ring := telegraph()
	var ball := _real_ball()
	if ring == null or not ring.contains(ball):
		return
	var out: Vector3 = ball - global_position
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	hit_player.emit(BLAST_DAMAGE, dir * BLAST_SHOVE + Vector3.UP * 3.0)


# The seams and lamp glow up and blink faster as the fuse burns down.
func _pose() -> void:
	if _seam_material == null:
		return
	var burn := clampf(_warn_progress(), 0.0, 1.0) if phase == Phase.WARN else 0.0
	var blink := 0.5 + 0.5 * sin(_t * TAU * lerpf(2.0, 8.0, burn))
	_seam_material.emission_energy_multiplier = lerpf(SEAM_IDLE, SEAM_FLARE, burn * blink)


# Every hit lands here before its damage, so the killing hit is always the last one seen.
func on_struck(kind: String, _part: String, _result: Dictionary) -> void:
	var ball := _real_ball()
	_last_hit = {"kind": kind, "range": Vector2(ball.x - global_position.x, ball.z - global_position.z).length(),
		"frame": Engine.get_physics_frames()}


# Whether a hit of this kind from this far kills the Splitter clean.
static func clean_kill(hit_kind: String, hit_range: float) -> bool:
	return hit_kind in CLEAN_KINDS or hit_range >= CLEAN_RANGE


func _die() -> void:
	var fresh: bool = not _last_hit.is_empty() and Engine.get_physics_frames() - int(_last_hit["frame"]) <= 1
	split = fresh and not clean_kill(String(_last_hit["kind"]), float(_last_hit["range"]))
	set_meta("split", split)
	var at := global_position
	if not split and fresh and fleet != null:
		fleet.discover("split_pop", at)
	super()
	if split and fleet != null and fleet.combat != null and world_root != null:
		var pop := Pop.new()
		pop.combat = fleet.combat
		pop.offsets = pod_offsets()
		pop.maker = get_script()
		pop.pack = int(get_meta("pack_seq", -1))
		world_root.add_child(pop)
		pop.global_position = at


# A chaser made into a Splitter piece: shrunk body and collider, a share of a chaser's
# health (so the stage's health dial carries through) and a light body to flail.
static func make_piece(piece: Node3D) -> void:
	if piece == null or not is_instance_valid(piece):
		return
	piece._set_health(piece.max_hp * PIECE_HP / ChaserScript.HP)
	piece.weight = PIECE_WEIGHT
	piece.scrap_value = 1
	piece.radius *= PIECE_SCALE
	piece.half_height *= PIECE_SCALE
	_dress_piece(piece)
	for child in piece.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			var capsule := (child.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
			capsule.radius *= PIECE_SCALE
			capsule.height *= PIECE_SCALE
			child.shape = capsule
	piece.set_meta("splitter_piece", true)


# The piece glb in place of the chaser's wedge, under one rig node that takes the
# chaser's body pose, so the piece still rears up before its lunge.
static func _dress_piece(piece: Node3D) -> void:
	var wedge: Node3D = piece.get("_mesh")
	if wedge == null:
		return
	for child in wedge.get_children():
		child.free()
	var rig := Node3D.new()
	rig.name = "SplitterPiece"
	wedge.add_child(rig)
	var glow := Palette.solid(Palette.AMBER, 2.0)
	for part in piece_parts()["meshes"]:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		mi.set_surface_override_material(0, piece.get("_material") if part.paint else glow)
		rig.add_child(mi)
	piece.set("_pose_parts", {"ChaserBody": {"node": rig, "rest": Transform3D.IDENTITY}})
	piece.set("_base_color", Color.WHITE)
	var body_material: StandardMaterial3D = piece.get("_material")
	body_material.albedo_color = Color.WHITE
	body_material.vertex_color_use_as_albedo = true


# The seam flare: a white shell where the Splitter stood, POP_DELAY long, then the pieces.
class Pop extends Node3D:
	var combat
	var pack := -1
	var offsets: Array[Vector3] = []
	# This script, for make_piece: an inner class cannot call its outer class's functions.
	var maker: Script
	var _left := POP_DELAY
	var _shell: MeshInstance3D

	func _ready() -> void:
		add_to_group(PENDING)
		var sphere := SphereMesh.new()
		sphere.radius = BODY_RADIUS * 1.1
		sphere.height = BODY_RADIUS * 2.2
		_shell = MeshInstance3D.new()
		_shell.mesh = sphere
		_shell.material_override = Palette.solid(SEAM_WHITE, SEAM_FLARE * 2.0)
		add_child(_shell)

	func _physics_process(delta: float) -> void:
		_left -= delta
		_shell.scale = Vector3.ONE * lerpf(1.0, 1.3, 1.0 - _left / POP_DELAY)
		if _left > 0.0:
			return
		set_physics_process(false)
		var flow = combat.ctx.flow if is_instance_valid(combat) else null
		if flow != null and flow.in_play():
			for offset in offsets:
				var piece: Node3D = combat.spawn_enemy("chaser", global_position + offset)
				maker.make_piece(piece)
				if piece != null and pack >= 0:
					piece.set_meta("pack_seq", pack)
				if piece != null:
					piece.knock(offset, 6.0)
		queue_free()
