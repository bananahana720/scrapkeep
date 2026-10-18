extends SceneTree

const HoldRelay := preload("res://src/world/hold_relay.gd")
const RelayStake := preload("res://src/world/relay_stake.gd")
const T := preload("res://tests/support/t.gd")

# The relay's dressed devices (tools/blender/world_one/relay_stake.py, follow-up to SR10).
# (a) both GLBs load, carry their driven parts and stay inside their registry exceptions.
# (b) the stake post reads 0 to 4: k stacks light exactly the lowest k rings and turn the dial's
#     needle k marks; the wrap from 4 back to 0 puts every ring out and the needle home.
# (c) the post builds from the GLB, not the primitive mast, and stands no collider.
# (d) the coil orbs sit 17 m up, where the primitive coil sat.

const POST := "res://assets/models/world_one/relay_stake_post.glb"
const MAST := "res://assets/models/world_one/relay_mast.glb"
const LIMITS := {POST: [3000, 4800, 9], MAST: [3000, 4800, 3]}
const PARTS := {POST: ["StakePost", "Stake1", "Stake2", "Stake3", "Stake4", "StakeDial", "StakeNeedle", "CoilGlow"],
	MAST: ["RelayMast", "CoilGlow"]}
const COIL_Y := 17.0

var _t := T.new("relay_models_test")


func _initialize() -> void:
	for path: String in [POST, MAST]:
		_asset(path)
	_stake_reads()
	quit(_t.verdict())


func _asset(path: String) -> void:
	if not _t.check("%s exists" % path.get_file(), ResourceLoader.exists(path)):
		return
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var missing := []
	for part: String in PARTS[path]:
		if scene.find_child(part, true, false) == null:
			missing.append(part)
	_t.check("%s carries its driven parts" % path.get_file(), missing.is_empty(), "missing %s" % [missing])
	var tris := 0
	var verts := 0
	var draws := 0
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			verts += v.size()
			tris += (idx.size() if idx != null else v.size()) / 3
			draws += 1
	var cap: Array = LIMITS[path]
	_t.check("%s inside its exception" % path.get_file(), tris <= cap[0] and verts <= cap[1] and draws <= cap[2],
		"%d T %d V %d D, caps %s" % [tris, verts, draws, cap])
	var glow := scene.find_child("CoilGlow", true, false) as Node3D
	if glow != null:
		var xf := Transform3D.IDENTITY
		var node: Node = glow
		while node != scene:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var centre := (glow as MeshInstance3D).get_aabb().get_center()
		_t.near("%s coil orb height" % path.get_file(), (xf * centre).y, COIL_Y, 0.05)
	_t.eq("%s stands no collider" % path.get_file(), scene.find_children("*", "CollisionShape3D", true, false).size(), 0)
	scene.free()


func _stake_reads() -> void:
	var post := RelayStake.new()
	root.add_child(post)
	post.build()
	_t.check("post builds from the GLB", post.find_child("StakeNeedle", true, false) != null and post._ring_mats.size() == 4)
	var relay := HoldRelay.new({"relay": Vector2.ZERO, "ring": Vector2.ZERO}, 0.0)
	post.relay = relay
	var ok := true
	var detail := ""
	for k in range(6):
		var want: int = k % 5
		post.tick(0.0)
		var lit := 0
		var lowest := true
		for i in 4:
			var on: bool = post._ring_mats[i].emission_enabled
			lit += 1 if on else 0
			lowest = lowest and (on == (i < want))
		var angle: float = post._needle.rotation.z
		if lit != want or not lowest or absf(angle + RelayStake.STAKE_SWEEP * want) > 1e-5:
			ok = false
			detail += "k %d: lit %d, needle %.3f; " % [want, lit, angle]
		relay.stake_up()
	_t.check("stake 0 to 4 lights the lowest rings and steps the needle, then wraps", ok, detail)
	post.free()
