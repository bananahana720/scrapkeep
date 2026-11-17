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
const ScreenRegions := preload("res://src/ui/screen_regions.gd")

# The roll-through reward gates after the beacon. Two arches stand ahead of the ball on
# its line; rolling through one takes its part. There is no collider and no menu, so
# choosing never costs speed. If you roll past both, they are put ahead of you again
# rather than waiting behind you.
#
# Each gate says what it gives while you approach: the part's name, then (when there is room) its effect in
# one line, and a star line when it would complete a named synergy ("* completes Storm Lattice *") or is a
# known ingredient ("* ingredient: ??? *"); prompt_parts builds them. Rarity shows twice: the arch's colour and the topper's shape
# (a bar for common, a star for rare, a tall star with a mint
# heart for relic), so colour never carries it alone. Red is only for what hurts
# you (DESIGN-V2 section 11), so relic is mint with its own heart. A hot-wired offer adds an amber stripe.
#
# v2 W4: a gate also reads without words, as its family glyph (cat_), trigger glyph
# (trg_) and element glyph (el_) beside the topper, the same ids the shop and the
# cards use; a gate whose part completes a synergy pulses.
#
# The name is a screen prompt (WorldPrompt, owner_placed) that its own gate places every frame at the
# gate's projected crossbar point, with the gate's column inside its sign (PF-22).
# An edge sign opens inward from the crossbar. One type size, the name on one row or two when
# its room is narrow; the effect lines under a one-row name when they fit the room. When names would still
# overlap, the gate farther from the ball hides its name only (fit_names), with hysteresis so the set of
# named gates does not flip with a pixel of camera sway. The groups "word_keep_clear" (sound words) and
# "speech_keep_clear" (the speech bubble) carry keep_clear_rects(), the shown names' screen rects.

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
# The name's top stands this far under the crossbar point. A name or effect line is "room" wide: the
# distance to the nearest other gate's column less NAME_GAP. A shown name stays until it overlaps another by
# at all, and a hidden one returns only with NAME_HOLD px clear. The effect lines come back only with
# DETAIL_BACK px to spare, and a name goes back to one row only with ROWS_BACK px to spare.
const NAME_DROP := 6.0
const NAME_GAP := 12.0
const NAME_HOLD := 32.0
const DETAIL_BACK := 16.0
const ROWS_BACK := 16.0
const NAME_TIE_M := 1.0
const KEEP_CLEAR_GROUP := "word_keep_clear"
const SPEECH_KEEP_CLEAR_GROUP := "speech_keep_clear"

var offers: Array = []
# Build's offer_mark(part_id) -> String; the star line under an offer, or "".
var mark_for: Callable
# Build's active row lookup (id) -> Dictionary, for an active offer (ActiveOffers): one more arch
# beside the parts, tagged with its maker, that racks the active on F instead of adding a part.
var active_row: Callable

var _terrain
var _ball := Vector3.INF
var _name_rects: Array[Rect2] = []
var _name_frame := -1
# Per gate index: whether its name and its effect lines were shown last frame (the hysteresis).
var _shown := {}
var _detail := {}
var _rows := {}
# Asked each frame: is the game in play? Build sets it from flow. Names hide when it is not.
var playing := Callable()
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
	add_to_group(SPEECH_KEEP_CLEAR_GROUP)
	# Runs through a pause only to hide the names, so a menu over the world is not wearing them.
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	_name_rects.clear()
	_shown.clear()
	_detail.clear()
	_rows.clear()
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
	_shown.clear()
	_detail.clear()
	_rows.clear()
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
	gate.add_child(_name_prompt(offer, tint))
	return gate


# The gate's name: its own prompt, sized and placed each frame (_place_names). Its measurements are what
# fit_names reads: the name on one row and on two, and the effect lines.
static func _name_prompt(offer: Dictionary, tint: Color) -> Label:
	var parts := prompt_parts(offer)
	var prompt := WorldPrompt.new()
	prompt.name = "Name"
	prompt.owner_placed = true
	prompt.set_parts(parts["title"], parts["detail"], parts["icon"])
	prompt.add_theme_color_override("font_color", tint.lerp(Color.WHITE, 0.25))
	prompt.visible = false
	var one := PackedStringArray([parts["title"]])
	var two := WorldPrompt.split_name(parts["title"])
	var lines := String(parts["detail"]).split("\n", false)
	var big := WorldPrompt.SIGN_NAME_SIZE
	var small := WorldPrompt.SIGN_DETAIL_SIZE
	var font := UiFonts.bold()
	var detail_w := 0.0
	for line in lines:
		detail_w = maxf(detail_w, WorldPrompt.row_width(line, small))
	var two_w := 0.0
	for row in two:
		two_w = maxf(two_w, WorldPrompt.row_width(row, big))
	prompt.set_meta("fit", {
		"w1": WorldPrompt.row_width(one[0], big) + 2.0 * WorldPrompt.SIGN_PAD,
		"w2": two_w + 2.0 * WorldPrompt.SIGN_PAD, "two": two,
		"h1": font.get_height(big), "h2": 2.0 * font.get_height(big) + WorldPrompt.LINE_GAP,
		"dw": detail_w + 2.0 * WorldPrompt.SIGN_PAD,
		"dh": lines.size() * (font.get_height(small) + WorldPrompt.LINE_GAP),
	})
	return prompt


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
	if get_tree().paused:
		_place_names()
		return
	_spin += delta * 1.8
	for gate in _gates:
		var topper := gate.get_node_or_null("Topper") as Node3D
		if topper != null:
			topper.rotation = Vector3(0.0, _spin, 0.0)
			var pulse: float = 1.0 + 0.18 * sin(_spin * 3.0) if gate.get_meta("pulse", false) else 1.0
			topper.scale = Vector3.ONE * pulse
	_place_names()


# The shown names' rects in viewport pixels, for the words that stamp on screen (KEEP_CLEAR_GROUP) and
# the speech bubble (SPEECH_KEEP_CLEAR_GROUP) to keep off. A gate behind the camera or off the screen's sides, or whose name is hidden, has none.
func keep_clear_rects() -> Array[Rect2]:
	if offers.is_empty():
		return []
	if _name_frame != Engine.get_process_frames():
		_place_names()
	return _name_rects.duplicate()


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


# Puts every gate's name at its own crossbar point for this frame.
func _place_names() -> void:
	_name_frame = Engine.get_process_frames()
	_name_rects.clear()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := get_viewport().get_visible_rect()
	if is_inside_tree() and (get_tree().paused or (playing.is_valid() and not playing.call())):
		for gate in _gates:
			var hidden := gate.get_node_or_null("Name") as Label
			if hidden != null:
				hidden.visible = false
		# _shown and _rows stay: the same names return with the play, not only once each has 32 px clear.
		return
	var from: Vector3 = _ball if _ball.is_finite() else (cam.global_position if cam != null else Vector3.ZERO)
	var entries: Array = []
	var live: Array = []
	for i in _gates.size():
		var gate: Node3D = _gates[i]
		var prompt := gate.get_node_or_null("Name") as Label
		if prompt == null:
			continue
		var point := gate.global_position + Vector3.UP * HEIGHT
		var col := Vector2.ZERO if cam == null or cam.is_position_behind(point) else cam.unproject_position(point)
		if cam == null or cam.is_position_behind(point) or col.x < view.position.x or col.x > view.end.x or col.y > view.end.y:
			prompt.visible = false
			_shown[i] = false
			continue
		var fit: Dictionary = prompt.get_meta("fit")
		entries.append(fit.merged({"index": i, "col": col, "dist": from.distance_to(gate.global_position),
			"was_shown": _shown.get(i, false), "was_detail": _detail.get(i, false), "was_rows": _rows.get(i, 1)}))
		live.append(prompt)
	var out := fit_names(entries, ScreenRegions.rect("top", view.size).end.y, view.size)
	for k in live.size():
		var prompt: Label = live[k]
		var i: int = entries[k]["index"]
		var got: Dictionary = out[k]
		_shown[i] = got["shown"]
		_detail[i] = got["shown"] and got["detail"]
		if got["shown"]:
			_rows[i] = got["rows"]
		prompt.visible = got["shown"]
		if not got["shown"]:
			continue
		prompt.name_rows = entries[k]["two"] if got["rows"] == 2 else PackedStringArray([prompt.parts()["title"]])
		prompt.detail_shown = got["detail"]
		prompt.position = (got["rect"] as Rect2).position
		prompt.crossbar_x = float(entries[k]["col"].x) - prompt.position.x
		prompt.size = got["rect"].size
		_name_rects.append(got["rect"])


# Which names show and how, a pure rule over screen numbers. Each entry: index (the gate's), col (its crossbar
# point on screen), dist (from the ball), w1 and h1 (the name on one row), w2 and h2 (on two), dw and dh (its
# effect lines, widths including padding), was_shown and was_detail (last frame). A name hangs under its
# column, centred until a screen edge requires the sign to open inward. A name wider than its room (the distance to the nearest other gate's
# column less NAME_GAP) takes two rows before anything hides; the effect lines show only under a one-row name
# and only when they fit the room. Nearest gates first (distance in NAME_TIE_M steps, then a name already shown,
# then the lower index, so a tie never depends on sort order): a name whose rect would overlap one placed by
# at all (a hidden name: by less than NAME_HOLD px of clear room) hides, and that gate's name only. A name on two rows
# goes back to one only with ROWS_BACK px to spare (was_rows). A name whose crossbar point is above band_end (the top
# HUD band's lower edge) drops straight down its own column to just under it, and returns to the point below the band.
# Returns, per entry in order, {shown, rows, detail, rect}.
static func fit_names(entries: Array, band_end := 0.0, view_size := Vector2.INF) -> Array:
	var order: Array = range(entries.size())
	order.sort_custom(func(a, b):
		var ea: Dictionary = entries[a]
		var eb: Dictionary = entries[b]
		var da := snappedf(float(ea["dist"]), NAME_TIE_M)
		var db := snappedf(float(eb["dist"]), NAME_TIE_M)
		if da != db:
			return da < db
		if bool(ea["was_shown"]) != bool(eb["was_shown"]):
			return bool(ea["was_shown"])
		return int(ea["index"]) < int(eb["index"]))
	var out: Array = []
	out.resize(entries.size())
	var placed: Array[Rect2] = []
	for k in order:
		var e: Dictionary = entries[k]
		var room := view_size.x
		for other in entries:
			if other != e:
				room = minf(room, absf(float(other["col"].x) - float(e["col"].x)) - NAME_GAP)
		var forms: Array = []
		var one_row := float(e["w1"]) + (ROWS_BACK if int(e.get("was_rows", 1)) == 2 else 0.0) <= room
		if one_row:
			var spare := 0.0 if e["was_detail"] else DETAIL_BACK
			if float(e["dh"]) > 0.0 and float(e["dw"]) + spare <= room:
				forms.append({"rows": 1, "detail": true})
			forms.append({"rows": 1, "detail": false})
		else:
			forms.append({"rows": 2, "detail": false})
		var reach := 0.0 if e["was_shown"] else -NAME_HOLD
		var result := {"shown": false, "rows": 1, "detail": false, "rect": Rect2()}
		for form in forms:
			var width: float = e["w1"] if form["rows"] == 1 else e["w2"]
			var height: float = e["h1"] if form["rows"] == 1 else e["h2"]
			if form["detail"]:
				width = maxf(width, float(e["dw"]))
				height += float(e["dh"])
			if width > view_size.x or height > view_size.y - band_end:
				continue
			var column: Vector2 = e["col"]
			var x := clampf(column.x - width * 0.5, 0.0, view_size.x - width)
			var y := maxf(column.y + NAME_DROP, band_end)
			if y + height > view_size.y:
				y = maxf(column.y - NAME_DROP - height, band_end)
			var rect := Rect2(Vector2(x, y), Vector2(width, height))
			if placed.all(func(r): return _overlap(rect, r) <= reach):
				result = {"shown": true, "rows": form["rows"], "detail": form["detail"], "rect": rect}
				break
		if result["shown"]:
			placed.append(result["rect"])
		out[k] = result
	return out


# How far two rects overlap: the smaller of their overlaps along x and y, negative by the clear room when apart.
static func _overlap(a: Rect2, b: Rect2) -> float:
	var ix := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var iy := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	return minf(ix, iy)
