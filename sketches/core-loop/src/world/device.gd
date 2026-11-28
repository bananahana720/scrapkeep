extends Node3D

const Interactables := preload("res://src/world/interactables.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")

# One interactable (LOOP-REDESIGN section 9). The interact system (interact.gd) picks
# the device Interact reaches, runs its consent (roll, hold or press) and calls fire(); the
# device owns its greybox, its own rules and its prompt. A subclass overrides ready_now,
# gauge, terms, fire and tick. Travel devices also carry a RollThrough in `roll`.
#
# The prompt grammar, shared by every device: from GLYPH_REACH the family glyph alone;
# when Interact would reach it, its bound keycap, the glyph and at most PROMPT_WORDS words; a
# device that is not ready shows its gauge round the glyph and never the keycap.

var ctx
var system
var id := ""
var family := "secret"
var spec := {}
var spent := false
var roll = null
var prompt: Label
var _prompt_anchor: Node3D


func setup(ctx_ref, system_ref, spec_ref: Dictionary) -> void:
	ctx = ctx_ref
	system = system_ref
	spec = spec_ref
	id = String(spec.get("id", id))
	name = id
	_prompt_anchor = Node3D.new()
	add_child(_prompt_anchor)
	prompt = WorldPrompt.new()
	prompt.add_theme_color_override("font_color", Interactables.color(family))
	prompt.attach(_prompt_anchor, Vector3.ZERO, Interactables.GLYPH_REACH)
	_prompt_anchor.add_child(prompt)
	build()


func build() -> void:
	pass


# The point E measures reach and facing from, and the prompt hangs over.
func reach_point() -> Vector3:
	return global_position + Vector3.UP


func ready_now() -> bool:
	return not spent


# A not-ready device's fill, 0 to 1, drawn round its glyph; -1 draws none.
func gauge() -> float:
	return -1.0


# The words after the family verb.
func terms() -> String:
	return ""


func words() -> String:
	return Interactables.prompt(family, terms())


# Acts on consent. True when the device acted now; false when it will call
# system.fired(self) after its own beat.
func fire() -> bool:
	return true


func tick(_delta: float) -> void:
	pass


# E can lock it: within LOCK_REACH and inside FACING_DEG of where the camera looks. A
# travel device locks anywhere in its lane instead.
func acquirable(ball: Vector3, forward: Vector3) -> bool:
	if roll != null:
		return roll.in_lane(ball)
	var to := reach_point() - ball
	if to.length() > Interactables.LOCK_REACH:
		return false
	var flat := Vector2(to.x, to.z)
	var look := Vector2(forward.x, forward.z)
	if flat.length() < 1.5 or look.length() < 0.01:
		return true
	return absf(rad_to_deg(flat.angle_to(look))) <= Interactables.FACING_DEG


# A lock, once made, holds while this is true, facing or not: the ball may pass the
# device mid-hold. A travel lock holds while the ball is in the lane.
func holds_lock(ball: Vector3) -> bool:
	if roll != null:
		return roll.in_lane(ball)
	return ball.distance_to(reach_point()) <= Interactables.RELEASE_REACH


# Close enough to win E over a steep face Sable could mount.
func near(ball: Vector3) -> bool:
	return roll != null or ball.distance_to(reach_point()) <= Interactables.REACH


func show_prompt(targeted: bool) -> void:
	_prompt_anchor.global_position = reach_point() + Vector3.UP * 2.2
	var icon: String = Interactables.row(family)["icon"]
	if spent and not targeted:
		prompt.set_interact("", "", "", -1.0)
	elif targeted:
		prompt.set_interact(icon, words(), Glyphs.of("interact"), -1.0)
	else:
		prompt.set_interact(icon, "", "", gauge() if not ready_now() else -1.0)


func stand_down() -> void:
	pass


# A greybox box, optionally solid. Every device shape reuses these primitives.
func box(size: Vector3, at: Vector3, mat: Material, solid := false, parent: Node3D = self) -> Node3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	if not solid:
		mesh.position = at
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.add_child(mesh)
	body.position = at
	parent.add_child(body)
	return body


func cylinder(radius: float, height: float, at: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mesh.mesh = cm
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	return mesh


# The family's ring on the ground, dashed like the event ring, in the family colour.
func ground_ring(radius: float, color: Color, parent: Node3D = self) -> Node3D:
	var ring := Node3D.new()
	parent.add_child(ring)
	var mat := PaletteMaterials.solid(color, 1.4)
	for k in 20:
		var a := TAU * k / 20.0
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.35, 0.08, radius * TAU / 40.0)
		dash.mesh = dm
		dash.material_override = mat
		dash.position = Vector3(cos(a), 0.05, sin(a)) * radius
		dash.rotation.y = -a
		ring.add_child(dash)
	return ring


# The ground height under a point near the device, in the device's own frame.
func ground_y(local: Vector3) -> float:
	var world := global_transform * local
	return ctx.terrain.height(world.x, world.z) - global_position.y if ctx != null and ctx.terrain != null else 0.0
