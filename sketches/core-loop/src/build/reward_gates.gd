extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Synergies := preload("res://src/build/synergies.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Consumables := preload("res://src/build/consumables.gd")


signal chosen(part_id: String)

const AHEAD := 38.0
const SPREAD := 9.0
const WIDTH := 8.0
const HEIGHT := 7.0
const MISSED_BEYOND := 20.0
const SLOPE_BELOW := 4.0
const LOST_BEYOND := 110.0
const TURN_STEPS := [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]
const DISTANCES := [AHEAD, 30.0, 24.0, 18.0]
const SPREADS := [SPREAD, 6.0]
const CLIMB_TOLERANCE := 0.75
const PATH_SAMPLES := 6
const PROBE_RADIUS := 1.0
const RUN_OUT := 6.0
const BLOCK_PENALTY := 1000.0
const SLOT_LINE_DROP := 1.5
const NAME_DROP := 6.0
const NAME_GAP := 12.0
const NAME_HOLD := 32.0
const DETAIL_BACK := 16.0
const ROWS_BACK := 16.0
const NAME_TIE_M := 1.0
const KEEP_CLEAR_GROUP := "word_keep_clear"
const SPEECH_KEEP_CLEAR_GROUP := "speech_keep_clear"

var offers: Array = []
var mark_for: Callable
var active_row: Callable

var _terrain
var _ball := Vector3.INF
var _name_rects: Array[Rect2] = []
var _name_frame := -1
var _shown := {}
var _detail := {}
var _rows := {}
var _above := {}
var playing := Callable()
var _ids: Array = []
var _held: Array = []
var _last_side := {}
var _gates: Array[Node3D] = []
var _spin := 0.0
var _warned_blocked := false
var _fixed := false


func _init() -> void:
	add_to_group(KEEP_CLEAR_GROUP)
	add_to_group(SPEECH_KEEP_CLEAR_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(terrain) -> void:
	_terrain = terrain
	visible = false


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
	_above.clear()
	for gate in _gates:
		gate.queue_free()
	_gates.clear()


func is_open() -> bool:
	return not offers.is_empty()


func step(ball: Vector3, heading: Vector3) -> bool:
	if offers.is_empty():
		return false
	_ball = ball
	var passed_all := true
	for i in offers.size():
		var offer: Dictionary = offers[i]
		var rel: Vector3 = ball - offer["at"]
		var along: float = rel.dot(offer["facing"])
		var was: float = _last_side.get(i, along)
		_last_side[i] = along
		var through := was < 0.0 and along >= 0.0
		if _fixed and was > 0.0 and along <= 0.0:
			through = true
		if through and inside_arch(rel, offer["facing"]):
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


static func sideways(rel: Vector3, facing: Vector3) -> float:
	return absf(rel.dot(facing.cross(Vector3.UP).normalized()))


static func inside_arch(rel: Vector3, facing: Vector3) -> bool:
	return sideways(rel, facing) <= WIDTH * 0.5 + 1.0 and rel.y < HEIGHT and rel.y > -SLOPE_BELOW


func _build_offer_record(part_id: String, at: Vector3, facing: Vector3) -> Dictionary:
	if ActiveOffers.is_offer(part_id):
		var row: Dictionary = active_row.call(ActiveOffers.active_of(part_id)) if active_row.is_valid() else {}
		return ActiveOffers.gate_record(part_id, row).merged({"at": at, "facing": facing, "width": WIDTH})
	if Consumables.is_offer(part_id):
		return Consumables.gate_record(part_id).merged({"at": at, "facing": facing, "width": WIDTH})
	var d: Resource = Parts.offer_def(part_id, _held)
	var completes := Parts.completed_by(part_id, _held)
	return {
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
	}


func reroll_offers(rng: RandomNumberGenerator, class_id: String, held: Array) -> int:
	if offers.is_empty():
		return 0
	_held = held.duplicate()
	var used: Array = []
	for o in offers:
		if o is Dictionary and o.has("part_id"):
			used.append(String(o["part_id"]))
	var changed := 0
	var next_ids: Array = []
	var spots: Array = []
	var facings: Array = []
	for i in offers.size():
		var o: Dictionary = offers[i]
		var pid := String(o.get("part_id", ""))
		spots.append(o.get("at", Vector3.ZERO))
		facings.append(o.get("facing", Vector3.FORWARD))
		if ActiveOffers.is_offer(pid) or Consumables.is_offer(pid):
			next_ids.append(pid)
			continue
		var d: Resource = Parts.def(pid)
		if d == null:
			next_ids.append(pid)
			continue
		var min_tier := int(d.tier)
		var rarities: Array = ["rare"] if min_tier >= 2 else ["common", "rare"]
		var pool: Array = Parts.offer_pool(class_id, rarities).filter(func(id):
			var pd: Resource = Parts.def(id)
			return pd != null and int(pd.tier) >= min_tier and not (id in used) and not Parts.maxed(id, held))
		if min_tier >= 2:
			var impact_pool: Array = pool.filter(func(id): return PartOffers.is_high_impact(id, Parts.def))
			if not impact_pool.is_empty():
				pool = impact_pool
		if not pool.is_empty():
			pool.sort()
			var picked := String(pool[rng.randi_range(0, pool.size() - 1)])
			next_ids.append(picked)
			used.append(picked)
			changed += 1
		else:
			next_ids.append(pid)
	if changed <= 0:
		return 0
	_ids = next_ids
	for gate in _gates:
		gate.queue_free()
	_gates.clear()
	offers = []
	_shown.clear()
	_detail.clear()
	_rows.clear()
	_above.clear()
	for i in _ids.size():
		var rec := _build_offer_record(String(_ids[i]), spots[i], facings[i])
		offers.append(rec)
		_gates.append(_build_gate(spots[i], facings[i], rec))
	return changed


func _place(ball: Vector3, heading: Vector3) -> void:
	for gate in _gates:
		gate.queue_free()
	_gates.clear()
	offers = []
	_last_side = {}
	_shown.clear()
	_detail.clear()
	_rows.clear()
	_above.clear()
	var plan := choose_placement(ball, heading)
	_fixed = plan.get("fixed", false)
	var facing: Vector3 = plan["facing"]
	for i in _ids.size():
		var at: Vector3 = plan["spots"][i]
		var rec := _build_offer_record(String(_ids[i]), at, facing)
		offers.append(rec)
		_gates.append(_build_gate(at, facing, rec))


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


static func roll_cobalt_boss_picks(rng: RandomNumberGenerator, class_id: String, held: Array, count := 2, stage := 1) -> Array:
	var plain: Array = Parts.offer_pool(class_id, ["rare"]).filter(func(key): return not PartOffers.changes_behaviour(key, Parts.def))
	var picks: Array = PartOffers.roll_for_stage(rng, ["rare"], class_id, held, count, stage, plain, {}, true, Parts.offer_ops())
	if picks.size() < count:
		var more: Array = PartOffers.roll_for_stage(rng, ["rare"], class_id, held, count - picks.size(), stage, picks, {}, true, Parts.offer_ops())
		picks.append_array(more)
	return picks


static func glyph_ids(offer: Dictionary) -> Array:
	return [offer.get("icon", ""), offer.get("trigger_icon", ""), offer.get("element_icon", "")] \
		.filter(func(id): return id != "")


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


func keep_clear_rects() -> Array[Rect2]:
	if offers.is_empty():
		return []
	if _name_frame != Engine.get_process_frames():
		_place_names()
	return _name_rects.duplicate()


static func taken_look(part_id: String) -> Dictionary:
	if ActiveOffers.is_offer(part_id):
		var row := ActiveDefs.row(ActiveOffers.active_of(part_id))
		return {"name": String(row.get("name", "")), "icon": ActiveOffers.ICON, "color": rarity_color(ActiveOffers.rarity_of(row))}
	if Consumables.is_offer(part_id):
		var rec := Consumables.gate_record(part_id)
		return {"name": String(rec.get("name", "")), "icon": String(rec.get("icon", "")), "color": rarity_color(String(rec.get("rarity", "common")))}
	var d: Resource = Parts.def(part_id)
	if d == null and Parts.token(part_id).is_empty():
		return {}
	return {
		"name": Parts.display_name(part_id),
		"icon": "cat_" + d.icon_category if d != null and d.icon_category != "" else "",
		"color": rarity_color(d.rarity if d != null else "common"),
	}


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
			"was_shown": _shown.get(i, false), "was_detail": _detail.get(i, false), "was_rows": _rows.get(i, 1), "was_above": _above.get(i, false)}))
		live.append(prompt)
	var band_end := ScreenRegions.rect("top", view.size).end.y
	var out := fit_names(entries, Rect2(0.0, band_end, view.size.x, ScreenRegions.rect("bottom", view.size).position.y - band_end))
	for k in live.size():
		var prompt: Label = live[k]
		var i: int = entries[k]["index"]
		var got: Dictionary = out[k]
		_shown[i] = got["shown"]
		_detail[i] = got["shown"] and got["detail"]
		if got["shown"]:
			_rows[i] = got["rows"]
			_above[i] = got["above"]
		prompt.visible = got["shown"]
		if not got["shown"]:
			continue
		prompt.name_rows = entries[k]["two"] if got["rows"] == 2 else PackedStringArray([prompt.parts()["title"]])
		prompt.detail_shown = got["detail"]
		prompt.position = (got["rect"] as Rect2).position
		prompt.crossbar_x = float(entries[k]["col"].x) - prompt.position.x
		prompt.size = got["rect"].size
		_name_rects.append(got["rect"])


static func fit_names(entries: Array, space := Rect2(Vector2.ZERO, Vector2.INF)) -> Array:
	var bottom := space.end.y
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
		var room := space.size.x
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
		var result := {"shown": false, "rows": 1, "detail": false, "above": false, "rect": Rect2()}
		for form in forms:
			var width: float = e["w1"] if form["rows"] == 1 else e["w2"]
			var height: float = e["h1"] if form["rows"] == 1 else e["h2"]
			if form["detail"]:
				width = maxf(width, float(e["dw"]))
				height += float(e["dh"])
			if width > space.size.x or height > space.size.y:
				continue
			var column: Vector2 = e["col"]
			var x := clampf(column.x - width * 0.5, space.position.x, space.end.x - width)
			var y := maxf(column.y + NAME_DROP, space.position.y)
			var above := y + height > bottom - (0.0 if not e.get("was_above", false) else NAME_HOLD)
			if above:
				y = clampf(column.y - NAME_DROP - height, space.position.y, bottom - height)
			var rect := Rect2(Vector2(x, y), Vector2(width, height))
			if placed.all(func(r): return _overlap(rect, r) <= reach):
				result = {"shown": true, "rows": form["rows"], "detail": form["detail"], "above": above, "rect": rect}
				break
		if result["shown"]:
			placed.append(result["rect"])
		out[k] = result
	return out


static func _overlap(a: Rect2, b: Rect2) -> float:
	var ix := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var iy := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	return minf(ix, iy)
