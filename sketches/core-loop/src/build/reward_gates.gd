extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Synergies := preload("res://src/build/synergies.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Icons := preload("res://src/ui/icons.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")

# The roll-through reward gates after the beacon. Two arches stand ahead of the ball on
# its line; rolling through one takes its part. There is no collider and no menu, so
# choosing never costs speed. If you roll past both, they are put ahead of you again
# rather than waiting behind you.
#
# Each gate says what it gives while you approach, in the order you need it:
# "{name}: {verb}. Punch +{n}", its effect in one line, and a star line when it would
# complete a named synergy ("* completes Storm Lattice *") or is a known ingredient
# ("* ingredient: ??? *"). Rarity shows twice: the arch's colour and the topper's shape
# (a bar for common, a star for rare, a tall star with a mint
# heart for relic), so colour never carries it alone. Red is only for what hurts
# you (DESIGN-V2 section 11), so relic is mint with its own heart. A hot-wired offer adds an amber stripe.
#
# v2 W4: a gate also reads without words, as its family glyph (cat_), trigger glyph
# (trg_) and element glyph (el_) beside the topper, the same ids the shop and the
# cards use; a gate whose part completes a synergy pulses. The prompt passes its parts
# through set_parts(title, detail, "obj_gate").

signal chosen(part_id: String)

const AHEAD := 38.0
const SPREAD := 9.0
const WIDTH := 8.0
const HEIGHT := 7.0
const MISSED_BEYOND := 20.0
const LOST_BEYOND := 110.0
# Gates go downhill of the ball, never up a bank (momentum is sacred): candidate
# headings are tried nearest the ball's own line first, at these distances and
# spreads, and the first whose gate spots and approach lines stay at or below the
# ground under the ball (within CLIMB_TOLERANCE) wins. If none does, the candidate that
# climbs least is used.
const TURN_STEPS := [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]
const DISTANCES := [AHEAD, 30.0, 24.0, 18.0]
const SPREADS := [SPREAD, 6.0]
const CLIMB_TOLERANCE := 0.75
const PATH_SAMPLES := 6
# A candidate is also rejected when a static prop (a kerb, a bench, anything built by a
# map's build_props, or an element hazard like ice) stands across its approach or its
# roll-out: an unforeseen stop is exactly what momentum is sacred forbids. The probe is
# a ball-sized sphere swept on the physics layer terrain and props share (layer 1); the
# terrain's own "Ground" bodies are excluded by RID so only real obstacles count. A
# blocked candidate is penalised, never returned outright, unless every candidate is
# blocked, in which case the least-blocked one is used and a warning is pushed once.
const PROBE_RADIUS := 1.0
const RUN_OUT := 6.0
const BLOCK_PENALTY := 1000.0
# A gate's offer prompt shows while the gate is this close, the whole time it can be chosen.
const PROMPT_REACH := LOST_BEYOND

var offers: Array = []
# Build's offer_mark(part_id) -> String; the star line under an offer, or "".
var mark_for: Callable
# Build's active row lookup (id) -> Dictionary, for an active offer (ActiveOffers): one more arch
# beside the parts, tagged with its maker, that racks the active on F instead of adding a part.
var active_row: Callable

var _terrain
var _ids: Array = []
var _held: Array = []
var _last_side := {}
var _gates: Array[Node3D] = []
var _spin := 0.0
var _warned_blocked := false
# Gates standing on the map's slots never move to follow the ball, so they open from both sides.
var _fixed := false


func setup(terrain) -> void:
	_terrain = terrain
	visible = false


# Returns the published offers: part_id, at (ground centre), facing (the way through)
# and width, plus name, text, rarity, tier and synergy for anything that draws them.
func open(part_ids: Array, ball: Vector3, heading: Vector3, held: Array = []) -> Array:
	_ids = part_ids
	_held = held.duplicate()
	_place(ball, heading)
	visible = true
	return offers


func close() -> void:
	visible = false
	offers = []
	for gate in _gates:
		gate.queue_free()
	_gates.clear()


func is_open() -> bool:
	return not offers.is_empty()


# Returns true when the gates moved, so the owner can publish the new offers. Gates on the
# map's slots stay put when the ball passes them all.
func step(ball: Vector3, heading: Vector3) -> bool:
	if offers.is_empty():
		return false
	var passed_all := true
	for i in offers.size():
		var offer: Dictionary = offers[i]
		var rel: Vector3 = ball - offer["at"]
		var along: float = rel.dot(offer["facing"])
		var side: float = (rel - (offer["facing"] as Vector3) * along).length()
		var was: float = _last_side.get(i, along)
		_last_side[i] = along
		var through := was < 0.0 and along >= 0.0
		if _fixed and was > 0.0 and along <= 0.0:
			through = true
		if through and side <= WIDTH * 0.5 + 1.0 and absf(rel.y) < HEIGHT + 4.0:
			var id: String = offer["part_id"]
			close()
			chosen.emit(id)
			return false
		if along < MISSED_BEYOND and rel.length() < LOST_BEYOND:
			passed_all = false
	if passed_all and not _fixed:
		_place(ball, heading)
		return true
	return false


func _place(ball: Vector3, heading: Vector3) -> void:
	for gate in _gates:
		gate.queue_free()
	_gates.clear()
	offers = []
	_last_side = {}
	var plan := choose_placement(ball, heading)
	_fixed = plan.get("fixed", false)
	var facing: Vector3 = plan["facing"]
	for i in _ids.size():
		var at: Vector3 = plan["spots"][i]
		var part_id: String = _ids[i]
		if ActiveOffers.is_offer(part_id):
			var row: Dictionary = active_row.call(ActiveOffers.active_of(part_id)) if active_row.is_valid() else {}
			offers.append(ActiveOffers.gate_record(part_id, row).merged({"at": at, "facing": facing, "width": WIDTH}))
			_gates.append(_build_gate(at, facing, offers[-1]))
			continue
		var d: Resource = Parts.offer_def(part_id, _held)
		var completes := Parts.completed_by(part_id, _held)
		offers.append({
			"part_id": part_id, "at": at, "facing": facing, "width": WIDTH,
			"name": Parts.display_name(part_id),
			"headline": Parts.offer_headline(part_id, _held),
			"verb": d.verb if d != null else "",
			"punch": d.punch if d != null else 0.0,
			"text": d.text if d != null else "",
			"rarity": d.rarity if d != null else "common",
			"hotwired": not Parts.hotwired(part_id).is_empty(),
			"tier": d.tier if d != null else 1,
			"synergy": Synergies.ROWS[completes]["name"] if completes != "" else "",
			"mark": mark_for.call(part_id) if mark_for.is_valid() else "",
			"family": d.family if d != null else "stat",
			"icon": "cat_" + d.icon_category if d != null and d.icon_category != "" else "",
			"trigger_icon": "trg_" + d.trigger if d != null and d.trigger != "" else "",
			"element_icon": "el_" + d.element if d != null and d.element != "" else "",
		})
		_gates.append(_build_gate(at, facing, offers[-1]))


# The gate spots for count gates: {facing, spots, climb}. Climb is the most any gate
# spot or approach sample rises above the ground under the ball.
func choose_placement(ball: Vector3, heading: Vector3) -> Dictionary:
	var count := maxi(1, _ids.size())
	var fixed := _slot_plan(count)
	if not fixed.is_empty():
		return fixed
	var ground: float = _terrain.height(ball.x, ball.z)
	var base := Vector3(heading.x, 0.0, heading.z).normalized()
	if base.length() < 0.5:
		base = Vector3.FORWARD
	var best := {}
	var exclude := _prop_probe_exclude()
	for turn in TURN_STEPS:
		var facing := base.rotated(Vector3.UP, deg_to_rad(turn))
		for distance in DISTANCES:
			for spread in SPREADS:
				var plan := _candidate(ball, ground, facing, distance, spread, count, exclude)
				if plan["climb"] <= CLIMB_TOLERANCE and not plan["blocked"]:
					return plan
				if best.is_empty() or plan["climb"] < best["climb"]:
					best = plan
	if best.get("blocked", false) and not _warned_blocked:
		_warned_blocked = true
		push_warning("reward_gates: every gate candidate is blocked by a static prop; using the least-blocked spot")
	return best


# A map with gate slots stands its gates there whatever the ball does. With fewer gates
# than slots the outermost slots are used, and a single gate takes the middle one. A map
# with one slot (the pit, the sinkhole) stands more gates in a row centred on it, across its
# facing, 2 * SPREAD apart: the ordinary placement put the sinkhole's two gates on its bowl's
# rim, 4 m up a bank from a ball at the bottom. More gates than several slots fall back to
# the ordinary placement, which keeps them off a Highdraft island's edge.
func _slot_plan(count: int) -> Dictionary:
	var m = _terrain.map() if _terrain.has_method("map") else null
	if m == null or not "gate_slots" in m or (m.gate_slots as Array).is_empty():
		return {}
	var slots: Array = m.gate_slots
	if count > slots.size() and slots.size() > 1:
		return {}
	var facing: Vector3 = slots[0]["facing"]
	var spots: Array[Vector3] = []
	if count > slots.size():
		var centre: Vector2 = slots[0]["at"]
		var across := facing.cross(Vector3.UP)
		var side := Vector2(across.x, across.z).normalized()
		for i in count:
			var at := centre + side * (float(i) - (count - 1) * 0.5) * 2.0 * SPREAD
			spots.append(_terrain.drop_point(at.x, at.y, 0.0))
		return {"facing": facing, "spots": spots, "climb": 0.0, "distance": 0.0, "blocked": false, "fixed": true}
	for i in count:
		var pick := (slots.size() - 1) / 2 if count == 1 else roundi(float(i) * (slots.size() - 1) / (count - 1))
		var at: Vector2 = slots[mini(pick, slots.size() - 1)]["at"]
		spots.append(_terrain.drop_point(at.x, at.y, 0.0))
	return {"facing": facing, "spots": spots, "climb": 0.0, "distance": 0.0, "blocked": false, "fixed": true}


func _candidate(ball: Vector3, ground: float, facing: Vector3, distance: float, spread: float, count: int, exclude: Array) -> Dictionary:
	var side := facing.cross(Vector3.UP).normalized()
	var spots: Array[Vector3] = []
	var climb := -INF
	var blocked := false
	for i in count:
		var offset := (float(i) - (count - 1) * 0.5) * 2.0 * spread
		var spot := ball + facing * distance + side * offset
		var at: Vector3 = _terrain.drop_point(spot.x, spot.z, 0.0)
		spots.append(at)
		for k in PATH_SAMPLES + 1:
			var p := ball.lerp(spot, float(k) / PATH_SAMPLES)
			climb = maxf(climb, _terrain.height(p.x, p.z) - ground)
		if _segment_blocked(ball, spot, exclude) or _segment_blocked(spot, spot + facing * RUN_OUT, exclude):
			blocked = true
	var result := {"facing": facing, "spots": spots, "climb": climb, "distance": distance, "blocked": blocked}
	if blocked:
		result["climb"] += BLOCK_PENALTY
	return result


# The RIDs of the active stage's ground bodies, so the shape probe below can tell "a
# static prop is in the way" from "the ground itself is under the sphere". Both are
# StaticBody3D on the same physics layer (map_spillway.gd's box()/cylinder() helpers
# never set a layer of their own). Old maps name their single body "Ground"; parks
# put their tiles under that node. No RID means no exclusion, never a query
# that silently forbids every candidate.
func _prop_probe_exclude() -> Array:
	if _terrain == null or not _terrain.has_method("geometry_root"):
		return []
	var holder: Node3D = _terrain.geometry_root(_terrain.stage)
	if holder == null:
		return []
	var ground := holder.get_node_or_null("Ground")
	var exclude: Array[RID] = []
	if ground == null:
		return exclude
	if ground is CollisionObject3D:
		exclude.append(ground.get_rid())
	for body in ground.find_children("*", "CollisionObject3D", true, false):
		exclude.append(body.get_rid())
	return exclude


# A ball-sized sphere swept from `from` to `to`, both raised to the terrain height at
# that x/z plus PROBE_RADIUS so the sweep sits where the ball actually rolls. Anything
# on layer 1 other than the excluded terrain body blocks: a kerb, a bench, an ice slab.
# Runs only once in the tree, since choose_placement always runs from open()/step()
# after build.gd has parented this node (build.gd setup()); off the tree there is no
# physics space to ask, so nothing is reported blocked rather than failing the plan.
func _segment_blocked(from_xz: Vector3, to_xz: Vector3, exclude: Array) -> bool:
	if not is_inside_tree():
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	if space == null:
		return false
	var from := Vector3(from_xz.x, _terrain.height(from_xz.x, from_xz.z) + PROBE_RADIUS, from_xz.z)
	var to := Vector3(to_xz.x, _terrain.height(to_xz.x, to_xz.z) + PROBE_RADIUS, to_xz.z)
	var sphere := SphereShape3D.new()
	sphere.radius = PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	return space.cast_motion(query)[1] < 1.0


static func rarity_color(rarity: String) -> Color:
	var id := ItemGen.resolve_rarity(rarity)
	return ItemGen.RARITY[id]["color"] if id != "" else ItemGen.RARITY["common"]["color"]


# The glyphs a gate wears, left to right: family, trigger, element.
static func glyph_ids(offer: Dictionary) -> Array:
	return [offer.get("icon", ""), offer.get("trigger_icon", ""), offer.get("element_icon", "")] \
		.filter(func(id): return id != "")


# The prompt's structured parts: the name (at most three words), and under it the effect line
# (the row's text, with "+N punch" added when the text lacks it; the verb only when there is no
# text, because verb and text said the same thing) and the star line.
static func prompt_parts(offer: Dictionary) -> Dictionary:
	var words: PackedStringArray = String(offer.get("name", "")).split(" ", false)
	var title := " ".join(words.slice(0, WorldPrompt.TITLE_WORDS))
	var first := String(offer.get("text", ""))
	if first == "":
		first = String(offer.get("verb", ""))
	if offer.get("punch", 0.0) > 0.0 and not "punch" in first.to_lower():
		first += ", +%d punch" % int(offer["punch"])
	var lines := PackedStringArray([first])
	if offer.get("mark", "") != "":
		lines.append(offer["mark"])
	return {"title": title, "detail": "\n".join(lines), "icon": "obj_gate"}


func _build_gate(at: Vector3, facing: Vector3, offer: Dictionary) -> Node3D:
	var gate := Node3D.new()
	add_child(gate)
	gate.global_position = at
	gate.global_basis = Basis.looking_at(facing, Vector3.UP)
	var tint := rarity_color(offer["rarity"])
	var mat := Palette.solid(tint, 1.4)
	for x in [-WIDTH * 0.5, WIDTH * 0.5]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, HEIGHT, 0.5)
		post.mesh = box
		post.material_override = mat
		post.position = Vector3(x, HEIGHT * 0.5, 0.0)
		gate.add_child(post)
	var bar := MeshInstance3D.new()
	var bar_box := BoxMesh.new()
	bar_box.size = Vector3(WIDTH + 0.5, 0.5, 0.5)
	bar.mesh = bar_box
	bar.material_override = mat
	bar.position = Vector3(0.0, HEIGHT, 0.0)
	gate.add_child(bar)
	var topper := _topper(offer["rarity"], Palette.solid(tint, 2.6))
	topper.name = "Topper"
	topper.position = Vector3(0.0, HEIGHT + 1.2, 0.0)
	gate.add_child(topper)
	if offer.get("hotwired", false):
		topper.add_child(_stripe())
	if offer["rarity"] == "relic":
		var heart := MeshInstance3D.new()
		var core := SphereMesh.new()
		core.radius = 0.45
		core.height = 0.9
		heart.mesh = core
		heart.material_override = Palette.solid(Palette.ARC, 3.0)
		topper.add_child(heart)
	var ids := glyph_ids(offer)
	for i in ids.size():
		var glyph := Sprite3D.new()
		glyph.name = "Glyph%d" % i
		glyph.texture = Icons.texture(ids[i])
		glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glyph.pixel_size = 0.018
		glyph.modulate = Icons.tint(ids[i], tint.lerp(Color.WHITE, 0.4))
		glyph.position = Vector3((float(i) - (ids.size() - 1) * 0.5) * 1.5, HEIGHT + 2.9, 0.0)
		gate.add_child(glyph)
	gate.set_meta("pulse", offer["synergy"] != "")
	# The offer is a screen prompt the HUD keeps in the prompts band (screen_regions.gd),
	# under the gate's column, so it never climbs into the objective or the toasts.
	var label := WorldPrompt.new()
	label.name = "Prompt"
	var lines := "%s\n%s" % [offer["headline"], offer["text"]]
	if offer["mark"] != "":
		lines += "\n" + offer["mark"]
	label.text = lines
	var parts := prompt_parts(offer)
	label.set_parts(parts["title"], parts["detail"], parts["icon"])
	label.add_theme_color_override("font_color", tint.lerp(Color.WHITE, 0.25))
	label.attach(gate, Vector3(0.0, HEIGHT + 1.2, 0.0), PROMPT_REACH)
	# A gate is chosen by steering at it, long before the ball is beside it, so what each gives
	# shows as far as its name does.
	label.detail_range = PROMPT_REACH
	label.leader = true
	gate.add_child(label)
	return gate


# The hot-wired flag, drawn as a thin diagonal amber band across the topper. It does not
# change the rarity or its colour.
static func _stripe() -> MeshInstance3D:
	var band := MeshInstance3D.new()
	band.name = "Stripe"
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.18, 0.5)
	band.mesh = box
	band.rotation = Vector3(0.0, 0.0, deg_to_rad(35.0))
	band.material_override = Palette.solid(Palette.AMBER, 3.2)
	return band


static func _topper(rarity: String, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	match ItemGen.resolve_rarity(rarity):
		"rare", "relic", "evolved":
			var star := PrismMesh.new()
			star.size = Vector3(1.8, 2.8 if rarity != "rare" else 1.8, 0.4)
			node.mesh = star
		_:
			var slab := BoxMesh.new()
			slab.size = Vector3(1.6, 0.4, 0.4)
			node.mesh = slab
	node.material_override = mat
	return node


func _process(delta: float) -> void:
	if offers.is_empty():
		return
	_spin += delta * 1.8
	for gate in _gates:
		var topper := gate.get_node_or_null("Topper") as Node3D
		if topper != null:
			topper.rotation = Vector3(0.0, _spin, 0.0)
			var pulse: float = 1.0 + 0.18 * sin(_spin * 3.0) if gate.get_meta("pulse", false) else 1.0
			topper.scale = Vector3.ONE * pulse
