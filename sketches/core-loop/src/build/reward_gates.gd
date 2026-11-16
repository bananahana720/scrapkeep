extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Synergies := preload("res://src/build/synergies.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")

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
# cards use; a gate whose part completes a synergy pulses.
#
# The name is a plate in the world, under the crossbar, facing the ball's approach (a gate that
# opens both ways wears a second one back to back): the part's name and one short effect line.
# It shows whenever its gate stands, so a name is never apart from its gate (PF-22). A name's
# drawn cap height never falls under NAME_FLOOR_PX on screen: the plate grows with distance
# (_fit_plates). When two names would overlap at that size, the nearer to the ball keeps its size and
# the farther shrinks to NAME_MIN_PX and then hides, plate and all; nothing moves off its gate
# (fit_names). The group "word_keep_clear" carries keep_clear_rects(), the plates' screen rects,
# for the words that stamp on screen.

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
# How far a gate stood past the map's slot row may sit off the slots' mean ground (_slot_plan).
const SLOT_LINE_DROP := 1.5
# The plate: the name's cap height in metres before any growth (a name too wide for the arch
# shrinks to fit it), the effect line's, and the share of the font's size that is cap height.
const NAME_CAP_M := 0.9
const EFFECT_CAP_M := 0.5
const CAP_RATIO := 0.714
const PLATE_FONT := 64
const PLATE_FIT_WIDTH := WIDTH - 0.6
const PLATE_DROP := 0.25
const NAME_DROP := 0.75
const EFFECT_DROP := 1.75
const PLATE_DEPTH := 0.15
const EFFECT_WORDS := 6
# On screen at 1280x720 (they scale with the screen's height): the name's cap height never falls under the floor; an overlap shrinks the
# farther name to the minimum, then hides it. The effect line shows while it is this tall.
const NAME_FLOOR_PX := 14.0
const NAME_MIN_PX := 10.0
const EFFECT_MIN_PX := 8.0
const KEEP_CLEAR_GROUP := "word_keep_clear"
const PLATE_BOARD_H := 2.3
const NAME_ONLY_SHARE := 0.62

var offers: Array = []
# Build's offer_mark(part_id) -> String; the star line under an offer, or "".
var mark_for: Callable
# Build's active row lookup (id) -> Dictionary, for an active offer (ActiveOffers): one more arch
# beside the parts, tagged with its maker, that racks the active on F instead of adding a part.
var active_row: Callable

var _terrain
var _ball := Vector3.INF
var _plate_rects := {}
var _plate_frame := -1
var _ids: Array = []
var _held: Array = []
var _last_side := {}
var _gates: Array[Node3D] = []
var _spin := 0.0
var _warned_blocked := false
# Gates standing on the map's slots never move to follow the ball, so they open from both sides.
var _fixed := false


func _init() -> void:
	add_to_group(KEEP_CLEAR_GROUP)


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
	_plate_rects.clear()
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
	_ball = ball
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
# rim, 4 m up a bank from a ball at the bottom. More gates than several slots stand on the
# slots' own line, centred on the row at the slots' spacing (a quick Warden break's third part
# beside the hot-wired one puts four gates on the dam's three slots), unless a spot past the
# row stands off the slots' ground by more than SLOT_LINE_DROP (a Highdraft island's edge), when
# the ordinary placement takes them.
func _slot_plan(count: int) -> Dictionary:
	var m = _terrain.map() if _terrain.has_method("map") else null
	if m == null or not "gate_slots" in m or (m.gate_slots as Array).is_empty():
		return {}
	var slots: Array = m.gate_slots
	var facing: Vector3 = slots[0]["facing"]
	var spots: Array[Vector3] = []
	if count > slots.size():
		var first: Vector2 = slots[0]["at"]
		var last: Vector2 = slots[-1]["at"]
		var centre := (first + last) * 0.5
		var across := facing.cross(Vector3.UP)
		var step := Vector2(across.x, across.z).normalized() * 2.0 * SPREAD
		if slots.size() > 1:
			step = (last - first) / float(slots.size() - 1)
		var ground := 0.0
		for slot in slots:
			ground += _terrain.height(slot["at"].x, slot["at"].y) / slots.size()
		for i in count:
			var at := centre + step * (float(i) - (count - 1) * 0.5)
			if slots.size() > 1 and absf(_terrain.height(at.x, at.y) - ground) > SLOT_LINE_DROP:
				return {}
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
	_build_plate(gate, offer, tint)
	return gate


# The plate under the crossbar: a dark board with the name and one effect line, facing the ball's
# approach (the gate's local +Z; the gate looks along -Z). Its pivot is the crossbar's underside,
# so growing it with distance (_fit_plates) hangs it lower and never over the topper or the glyphs.
func _build_plate(gate: Node3D, offer: Dictionary, tint: Color) -> void:
	var parts := prompt_parts(offer)
	var title: String = parts["title"]
	var effect := " ".join(String(parts["detail"]).split("\n", false)[0].split(" ", false).slice(0, EFFECT_WORDS))
	var font := UiFonts.bold()
	var name_pixel := _fit_pixel(font, title, NAME_CAP_M)
	var effect_pixel := _fit_pixel(font, effect, EFFECT_CAP_M)
	var name_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT).x * name_pixel
	var effect_w := font.get_string_size(effect, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT).x * effect_pixel
	var plate := Node3D.new()
	plate.name = "Plate"
	plate.position = Vector3(0.0, HEIGHT - PLATE_DROP, 0.0)
	plate.set_meta("name_cap_m", PLATE_FONT * name_pixel * CAP_RATIO)
	plate.set_meta("effect_cap_m", PLATE_FONT * effect_pixel * CAP_RATIO)
	plate.set_meta("name_w_m", name_w)
	plate.set_meta("board_w_m", maxf(name_w, effect_w) + 0.8)
	gate.add_child(plate)
	var board := MeshInstance3D.new()
	board.name = "Board"
	var box := BoxMesh.new()
	box.size = Vector3(maxf(name_w, effect_w) + 0.8, PLATE_BOARD_H, PLATE_DEPTH)
	board.mesh = box
	board.material_override = Palette.solid(tint.darkened(0.75), 0.4)
	board.position = Vector3(0.0, -0.05 - PLATE_BOARD_H * 0.5, 0.0)
	plate.add_child(board)
	var sides: Array = [[0.0, PLATE_DEPTH * 0.5 + 0.01]]
	if _fixed:
		sides.append([PI, PLATE_DEPTH * 0.5 + 0.01])
	for side in sides:
		var face := Node3D.new()
		face.name = "Face"
		face.rotation.y = side[0]
		plate.add_child(face)
		face.add_child(_plate_label("Nameplate", title, name_pixel, -NAME_DROP, side[1], tint.lerp(Color.WHITE, 0.7)))
		face.add_child(_plate_label("Effect", effect, effect_pixel, -EFFECT_DROP, side[1], tint.lerp(Color.WHITE, 0.45)))


# The size of a plate line's pixels so its cap is cap_m tall, or smaller when the line would be wider than the arch.
static func _fit_pixel(font: Font, text: String, cap_m: float) -> float:
	var pixel := cap_m / (PLATE_FONT * CAP_RATIO)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT).x * pixel
	return pixel * minf(1.0, PLATE_FIT_WIDTH / width) if width > 0.0 else pixel


# One line of a plate. Single-sided: seen from behind it is culled, so each face of a gate that opens both ways reads right.
static func _plate_label(label_name: String, text: String, pixel: float, y: float, z: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font = UiFonts.bold()
	label.font_size = PLATE_FONT
	label.pixel_size = pixel
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	label.modulate = color
	label.outline_modulate = Color(0.04, 0.04, 0.05)
	label.outline_size = 14
	label.render_priority = 2
	label.outline_render_priority = 1
	label.position = Vector3(0.0, y, z)
	return label


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
	_fit_plates()


# The standing plates' rects in viewport pixels, for the words that stamp on screen to keep off
# (group KEEP_CLEAR_GROUP). A plate behind the camera, or one whose name the overlap rule hid, has none.
func keep_clear_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if offers.is_empty() or not visible:
		return out
	if _plate_frame != Engine.get_process_frames():
		_fit_plates()
	for rect in _plate_rects.values():
		out.append(rect)
	return out


# What a taken part looks like on the launch take: its name, its family glyph id and its rarity colour. {} for an id that
# names no part.
static func taken_look(part_id: String) -> Dictionary:
	if ActiveOffers.is_offer(part_id):
		var row := ActiveDefs.row(ActiveOffers.active_of(part_id))
		return {"name": String(row.get("name", "")), "icon": ActiveOffers.ICON, "color": rarity_color(ActiveOffers.rarity_of(row))}
	var d: Resource = Parts.def(part_id)
	if d == null and Parts.token(part_id).is_empty():
		return {}
	return {
		"name": Parts.display_name(part_id),
		"icon": "cat_" + d.icon_category if d != null and d.icon_category != "" else "",
		"color": rarity_color(d.rarity if d != null else "common"),
	}


# Sizes every plate for this frame: the name's cap height on screen is at least NAME_FLOOR_PX and
# the overlap rule (fit_names) shrinks or hides the farther name. Sets _plate_rects to each shown plate's
# board rect in viewport pixels.
func _fit_plates() -> void:
	_plate_frame = Engine.get_process_frames()
	_plate_rects.clear()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return
	var view := get_viewport().get_visible_rect().size
	var focal := view.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5) if cam.keep_aspect == Camera3D.KEEP_HEIGHT \
		else view.x * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	var tall := view.y / 720.0
	var from: Vector3 = _ball if _ball.is_finite() else cam.global_position
	var live: Array = []
	var entries: Array = []
	for gate in _gates:
		var plate := gate.get_node_or_null("Plate") as Node3D
		if plate == null or cam.is_position_behind(plate.global_position):
			continue
		var depth := (plate.global_position - cam.global_position).dot(-cam.global_basis.z)
		if depth <= 0.1:
			continue
		var cap_m: float = plate.get_meta("name_cap_m")
		var natural := cap_m * focal / depth
		var start := maxf(natural, NAME_FLOOR_PX * tall)
		var up := gate.global_basis.y.normalized()
		var centre := cam.unproject_position(plate.global_position - up * NAME_DROP * start / natural)
		live.append({"gate": gate, "plate": plate, "depth": depth, "natural": natural})
		entries.append({"dist": from.distance_to(plate.global_position), "centre": centre, "natural": natural,
			"aspect": float(plate.get_meta("name_w_m")) / cap_m})
	var fitted := fit_names(entries, NAME_FLOOR_PX * tall, NAME_MIN_PX * tall)
	for i in live.size():
		var plate: Node3D = live[i]["plate"]
		var gate: Node3D = live[i]["gate"]
		var cap: float = fitted[i]["cap"]
		var grow: float = cap / float(live[i]["natural"])
		plate.visible = not fitted[i]["hidden"]
		if fitted[i]["hidden"]:
			continue
		plate.scale = Vector3.ONE * grow
		var shows_effect := float(plate.get_meta("effect_cap_m")) * grow * focal / float(live[i]["depth"]) >= EFFECT_MIN_PX * tall
		for label in plate.find_children("Effect", "Label3D", true, false):
			label.visible = shows_effect
		var board := plate.get_node("Board") as Node3D
		var share := 1.0 if shows_effect else NAME_ONLY_SHARE
		board.scale.y = share
		board.position.y = -0.05 - PLATE_BOARD_H * 0.5 * share
		var up := gate.global_basis.y.normalized()
		var mid: Vector3 = plate.global_position + up * board.position.y * grow
		var px := focal / float(live[i]["depth"]) * grow
		var size := Vector2(float(plate.get_meta("board_w_m")), PLATE_BOARD_H * share) * px
		_plate_rects[plate] = Rect2(cam.unproject_position(mid) - size * 0.5, size)


# The names' sizes, a pure rule. Each entry is {dist: distance from the ball, centre: the name's
# screen point, natural: its cap height in px at the plate's own size, aspect: its width over its
# cap height}. Each name is drawn at least floor_px tall (its own size when that is more),
# centred on its own point. Nearest first, a name whose rect would overlap one already drawn
# shrinks px by px to min_px, and when it still overlaps it is hidden. Returns {cap, hidden} per
# entry, in the entries' order. A hidden name takes no room from a farther one.
static func fit_names(entries: Array, floor_px := NAME_FLOOR_PX, min_px := NAME_MIN_PX) -> Array:
	var order: Array = range(entries.size())
	order.sort_custom(func(a, b): return entries[a]["dist"] < entries[b]["dist"])
	var out: Array = []
	out.resize(entries.size())
	var drawn: Array[Rect2] = []
	for i in order:
		var e: Dictionary = entries[i]
		var cap := maxf(float(e["natural"]), floor_px)
		var placed := false
		while true:
			var size := Vector2(cap * float(e["aspect"]), cap)
			var rect := Rect2((e["centre"] as Vector2) - size * 0.5, size).grow(2.0)
			if not drawn.any(func(r): return r.intersects(rect)):
				drawn.append(rect)
				placed = true
				break
			if cap <= min_px:
				break
			cap = maxf(min_px, cap - 1.0)
		out[i] = {"cap": cap, "hidden": not placed}
	return out
