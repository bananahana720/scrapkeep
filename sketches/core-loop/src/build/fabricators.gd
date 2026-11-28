extends Node3D

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Relics := preload("res://src/build/relics.gd")
const Palette := preload("res://src/core/palette.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")


const RING := 5.0
const SINK := 1.5
const WIDTH := 8.0
const COG_PRICES := {
	"part_base": 40.0, "part_tier": {1: 1.0, 2: 1.6, 3: 2.6}, "part_growth": 1.06,
	"reroll_base": 30, "reroll_growth": 1.5, "cell_base": 40, "cell_growth": 1.6, "sell_share": 0.5,
	"weigh_lump": 50, "mass_per_cog": 2.0,
}
const OFF_SHELF := {"part_base": 10.0, "part_growth": 1.15}
const RESTOCK := 2.5
const AVOID_BEACON := 55.0
const AVOID_SPAWN := 25.0
const SPACING := 40.0
const ALONG_LINE := 0.55
const PROMPT_REACH := 45.0

const INGOT_TIERS := [1, 2, 3]
const INGOT_RARITY := {1: "common", 2: "rare", 3: "relic"}
const INGOT_NAMES := {1: "Common Scrap Ingot", 2: "Rare Scrap Ingot", 3: "Relic Scrap Ingot"}
const INGOT_META := "w50_scrap_ingots"

var _rng: RandomNumberGenerator
var _class_id := ""
var _stage := 1
var _fabs: Array[Dictionary] = []
var _scrappers: Array[Dictionary] = []
var _presses: Array[Dictionary] = []
var mark_for: Callable


static func price(part_id: String, parts_held: int) -> int:
	return int(round(COG_PRICES["part_base"] * COG_PRICES["part_tier"].get(_tier(part_id), 1.0) * pow(COG_PRICES["part_growth"], parts_held)))


static func off_shelf_price(tier: int, parts_held: int) -> int:
	return int(round(OFF_SHELF["part_base"] * COG_PRICES["part_tier"].get(tier, 1.0) * pow(OFF_SHELF["part_growth"], parts_held)))


static func hoop_price(part_id: String, parts_held: int) -> int:
	return off_shelf_price(_tier(part_id), parts_held)


static func _tier(part_id: String) -> int:
	var d: Resource = Parts.def(part_id)
	return d.tier if d != null else 1


func lay_out(terrain, stage: int, class_id: String, rng: RandomNumberGenerator, held: Array) -> void:
	clear()
	_rng = rng
	_class_id = class_id
	_stage = stage
	var want := 1 + stage
	var beacon: Vector3 = terrain.beacon_point(stage)
	var spawn: Vector3 = terrain.spawn_point(stage)
	var placed: Array[Vector3] = []
	for line in terrain.scrap_lines(stage):
		if placed.size() >= want:
			break
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var spot := from.lerp(to, ALONG_LINE)
		var at: Vector3 = terrain.drop_point(spot.x, spot.y, 0.0)
		if _flat(at, beacon) < AVOID_BEACON or _flat(at, spawn) < AVOID_SPAWN:
			continue
		var crowded := false
		for other in placed:
			if _flat(at, other) < SPACING:
				crowded = true
		if crowded:
			continue
		var dir := to - from
		var facing := Vector3(dir.x, 0.0, dir.y).normalized()
		placed.append(at)
		_add(at, facing, held)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func clear() -> void:
	for fab in _fabs:
		fab["node"].queue_free()
	_fabs.clear()
	for station in _scrappers:
		if is_instance_valid(station.get("node")):
			(station["node"] as Node).queue_free()
	_scrappers.clear()
	for station in _presses:
		if is_instance_valid(station.get("node")):
			(station["node"] as Node).queue_free()
	_presses.clear()


static func tier_of(part_id: String) -> int:
	return clampi(_tier(part_id), INGOT_TIERS[0], INGOT_TIERS[-1])


static func can_scrap(part_id: String, run) -> bool:
	if run == null or part_id == "" or not (part_id in run.parts):
		return false
	var d: Resource = Parts.def(part_id)
	return d != null and d.patterns.is_empty() and not Relics.is_relic(part_id) and String(d.rarity) != "relic"


static func _ingot_store(run) -> Dictionary:
	if run == null:
		return {1: 0, 2: 0, 3: 0}
	var raw = run.get_meta(INGOT_META) if run.has_meta(INGOT_META) else null
	if not (raw is Dictionary):
		raw = {1: 0, 2: 0, 3: 0}
		run.set_meta(INGOT_META, raw)
	for t in INGOT_TIERS:
		if not raw.has(t):
			raw[t] = 0
	return raw


static func scrap_ingots(run) -> Dictionary:
	var store := _ingot_store(run)
	return {1: int(store.get(1, 0)), 2: int(store.get(2, 0)), 3: int(store.get(3, 0))}


static func ingot_count(run, tier: int) -> int:
	if not tier in INGOT_TIERS:
		return 0
	return int(_ingot_store(run).get(tier, 0))


static func reset_ingots(run) -> void:
	if run == null:
		return
	run.set_meta(INGOT_META, {1: 0, 2: 0, 3: 0})


static func ingots_to_doc(run) -> Dictionary:
	var counts := scrap_ingots(run)
	return {"1": int(counts[1]), "2": int(counts[2]), "3": int(counts[3])}


static func ingots_from_doc(run, doc) -> bool:
	if run == null or not (doc is Dictionary):
		return false
	var next := {}
	for t in INGOT_TIERS:
		var raw = doc.get(str(t), doc.get(t, 0))
		if not (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT) or not is_finite(float(raw)) \
				or float(raw) < 0.0 or float(raw) != floorf(float(raw)):
			return false
		next[t] = int(raw)
	run.set_meta(INGOT_META, next)
	return true


static func scrap_part(run, part_id: String, build = null) -> Dictionary:
	if run == null or part_id == "" or run.parts.is_empty():
		return {"ok": false, "reason": "empty", "part_id": part_id}
	if not (part_id in run.parts):
		return {"ok": false, "reason": "not_held", "part_id": part_id}
	if not can_scrap(part_id, run):
		return {"ok": false, "reason": "welded", "part_id": part_id}
	var tier := tier_of(part_id)
	if not run.remove_part(part_id):
		return {"ok": false, "reason": "not_held", "part_id": part_id}
	var store := _ingot_store(run)
	store[tier] = int(store.get(tier, 0)) + 1
	if build != null and build.has_method("recompute"):
		build.recompute()
	return {
		"ok": true,
		"reason": "ok",
		"part_id": part_id,
		"tier": tier,
		"rarity": String(INGOT_RARITY.get(tier, "common")),
		"ingot_name": String(INGOT_NAMES.get(tier, "Scrap Ingot")),
		"ingots": int(store[tier]),
	}


static func press_part(run, target_part_id: String, rng: RandomNumberGenerator = null, build = null) -> Dictionary:
	if run == null or target_part_id == "":
		return {"ok": false, "reason": "empty", "part_id": target_part_id}
	var d: Resource = Parts.def(target_part_id)
	if d == null or Relics.is_relic(target_part_id) or String(d.rarity) == "relic":
		return {"ok": false, "reason": "invalid_target", "part_id": target_part_id}
	if Parts.stacked_out(target_part_id, run.parts) or Parts.maxed(target_part_id, run.parts):
		return {"ok": false, "reason": "capped", "part_id": target_part_id}
	var tier := tier_of(target_part_id)
	var store := _ingot_store(run)
	if int(store.get(tier, 0)) > 0:
		store[tier] = int(store[tier]) - 1
		run.add_part(target_part_id, "part_press")
		if build != null and build.has_method("recompute"):
			build.recompute()
		return {
			"ok": true,
			"reason": "ok",
			"part_id": target_part_id,
			"tier": tier,
			"paid_kind": "ingot",
			"sacrificed": "",
			"ingots_left": int(store[tier]),
		}
	var fuel: Array[String] = []
	for held_id in run.parts:
		var sid := String(held_id)
		if sid != target_part_id and tier_of(sid) == tier and can_scrap(sid, run):
			fuel.append(sid)
	if fuel.is_empty():
		return {"ok": false, "reason": "no_fuel", "part_id": target_part_id, "tier": tier}
	var pick_idx := rng.randi_range(0, fuel.size() - 1) if rng != null else 0
	var sacrificed := fuel[pick_idx]
	if not run.remove_part(sacrificed):
		return {"ok": false, "reason": "no_fuel", "part_id": target_part_id, "tier": tier}
	run.add_part(target_part_id, "part_press")
	if build != null and build.has_method("recompute"):
		build.recompute()
	return {
		"ok": true,
		"reason": "ok",
		"part_id": target_part_id,
		"tier": tier,
		"paid_kind": "part",
		"sacrificed": sacrificed,
		"ingots_left": int(store.get(tier, 0)),
	}


func add_scrapper_at(at: Vector3, facing := Vector3.FORWARD) -> Dictionary:
	var node := Node3D.new()
	node.name = "WorldScrapper"
	add_child(node)
	node.global_position = at
	if facing.length_squared() > 0.001:
		node.global_basis = Basis.looking_at(facing.normalized(), Vector3.UP)
	var rec := {"kind": "scrapper", "at": at, "facing": facing, "node": node, "uses": 0}
	_scrappers.append(rec)
	return rec


func add_press_at(at: Vector3, facing: Vector3, part_id: String) -> Dictionary:
	var node := Node3D.new()
	node.name = "WorldPartPress"
	add_child(node)
	node.global_position = at
	if facing.length_squared() > 0.001:
		node.global_basis = Basis.looking_at(facing.normalized(), Vector3.UP)
	var rec := {"kind": "part_press", "part_id": part_id, "tier": tier_of(part_id), "at": at, "facing": facing, "node": node, "uses": 0}
	_presses.append(rec)
	return rec


func presses() -> Array[Dictionary]:
	return _presses


func use_press(press: Dictionary, run, rng: RandomNumberGenerator = null, build = null) -> Dictionary:
	var res := press_part(run, String(press.get("part_id", "")), rng, build)
	if bool(res.get("ok", false)):
		press["uses"] = int(press.get("uses", 0)) + 1
	return res


func records() -> Array[Dictionary]:
	return _fabs


func add_at(at: Vector3, facing: Vector3, part_id: String) -> Dictionary:
	return _add(at, facing, [], part_id)


func _add(at: Vector3, facing: Vector3, held: Array, part_id := "") -> Dictionary:
	if part_id == "":
		part_id = _roll(held)
	var node := Node3D.new()
	add_child(node)
	node.global_position = at
	node.global_basis = Basis.looking_at(facing, Vector3.UP)
	var fab := {"part_id": part_id, "at": at, "facing": facing, "width": WIDTH, "node": node,
		"last": 0.0, "fresh": true, "restock": 0.0, "text": ""}
	_build_hoop(fab)
	_fabs.append(fab)
	return fab


func _roll(held: Array) -> String:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	var rarities := PartOffers.source_rarities("fabricator", _stage)
	var picks: Array = PartOffers.roll_for_stage(_rng, rarities, _class_id, held, 1, _stage, [], {}, _stage >= PartOffers.WORLD_ESCALATION_STAGE_W3, Parts.offer_ops()) \
		if _stage >= PartOffers.WORLD_ESCALATION_STAGE_W2 \
		else Parts.roll(_rng, rarities, _class_id, held, 1)
	return picks[0] if not picks.is_empty() else "hot_rivets"


func step(ball: Vector3, delta: float, cogs: int, held: Array) -> Array[Dictionary]:
	var crossings: Array[Dictionary] = []
	for fab in _fabs:
		if fab["restock"] > 0.0:
			fab["restock"] -= delta
			if fab["restock"] <= 0.0:
				fab["part_id"] = _roll(held)
				_refresh_glyph(fab)
		var rel: Vector3 = ball - fab["at"]
		var along: float = rel.dot(fab["facing"])
		var side: float = RewardGates.sideways(rel, fab["facing"])
		var was: float = along if fab["fresh"] else fab["last"]
		fab["fresh"] = false
		fab["last"] = along
		var crossed: bool = signf(was) != signf(along) and was != 0.0
		if crossed and side <= WIDTH * 0.5 + 0.5 and rel.y > -1.5 and rel.y < RING * 2.0 - SINK and fab["restock"] <= 0.0:
			crossings.append(fab)
		_refresh_label(fab, cogs, held)
	return crossings


func sold(fab: Dictionary) -> void:
	fab["restock"] = RESTOCK
	_refresh_glyph(fab)


func _build_hoop(fab: Dictionary) -> void:
	var node: Node3D = fab["node"]
	var views := RecipeProps.base("fabricator_hoop", node, Transform3D.IDENTITY)
	RecipeProps.shells("fabricator_hoop", node, Transform3D.IDENTITY)
	fab["state_views"] = RecipeProps.steel_views(views)
	_paint_state(fab, false)
	for dir in [-1.0, 1.0]:
		var chevron := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(2.4, 1.6, 0.12)
		chevron.mesh = prism
		chevron.material_override = Palette.unshaded(Color(Palette.AMBER, 0.7))
		chevron.rotation = Vector3(-PI * 0.5 * dir, 0.0, 0.0)
		chevron.position = Vector3(0.0, 0.15, -3.5 * dir)
		node.add_child(chevron)
	var glyph := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.7
	gem.height = 1.6
	gem.radial_segments = 4
	gem.rings = 2
	glyph.mesh = gem
	glyph.position = Vector3(0.0, RING - SINK + 1.2, 0.0)
	node.add_child(glyph)
	var label := WorldPrompt.new()
	label.name = "Prompt"
	label.attach(node, Vector3(0.0, RING * 2.0 - SINK, 0.0), PROMPT_REACH)
	node.add_child(label)
	fab["glyph"] = glyph
	fab["label"] = label
	_refresh_glyph(fab)


func _refresh_glyph(fab: Dictionary) -> void:
	var d: Resource = Parts.def(fab["part_id"])
	var rarity: String = d.rarity if d != null else "common"
	var color: Color = RewardGates.rarity_color(rarity)
	var glyph: MeshInstance3D = fab["glyph"]
	glyph.material_override = Palette.solid(color, 2.4)
	glyph.visible = fab["restock"] <= 0.0
	fab["text"] = ""


func _refresh_label(fab: Dictionary, cogs: int, held: Array) -> void:
	var part_id: String = fab["part_id"]
	var cost := price(part_id, held.size())
	var text := ""
	var ready: bool = fab["restock"] <= 0.0 and cogs >= cost
	if fab["restock"] > 0.0:
		text = "FABRICATING..."
	else:
		var d: Resource = Parts.offer_def(part_id, held)
		text = "%s\n%s\n%s" % [Parts.offer_headline(part_id, held), d.text if d != null else "",
			"ROLL THROUGH: %d cogs" % cost if ready else "need %d cogs (have %d)" % [cost, cogs]]
		var mark: String = mark_for.call(part_id) if mark_for.is_valid() else ""
		if mark != "":
			text += "\n" + mark
	if text == fab["text"]:
		return
	fab["text"] = text
	var label: Label = fab["label"]
	label.text = text
	label.set_parts(prompt_title(part_id) if fab["restock"] <= 0.0 else "Fabricating",
		_detail(text), "obj_fabricator")
	label.modulate = Palette.AMBER if ready else Palette.SAND.darkened(0.25)
	_paint_state(fab, ready)


static func state_tint(ready: bool) -> Color:
	return Palette.AMBER if ready else Palette.COPPER.darkened(0.3)


func _paint_state(fab: Dictionary, ready: bool) -> void:
	for view: GeometryInstance3D in fab["state_views"]:
		view.set_instance_shader_parameter("state_tint", state_tint(ready))


static func prompt_title(part_id: String) -> String:
	var words: PackedStringArray = Parts.display_name(part_id).split(" ", false)
	return " ".join(words.slice(0, WorldPrompt.TITLE_WORDS))


static func _detail(text: String) -> String:
	var lines := Array(text.split("\n", false))
	if lines.is_empty():
		return ""
	var head: String = lines.pop_front()
	var colon: int = head.find(":")
	if colon > 0:
		lines.push_front(head.substr(colon + 1).strip_edges())
	return "\n".join(PackedStringArray(lines))


func _process(delta: float) -> void:
	for fab in _fabs:
		var glyph: MeshInstance3D = fab["glyph"]
		glyph.rotate_y(delta * 2.2)
