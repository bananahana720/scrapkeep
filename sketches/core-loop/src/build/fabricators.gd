extends Node3D

const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")

# Drive-through fabricators: hoops standing across the scrap lines. Each shows the part
# it makes and its price while you approach; roll through the hoop with enough cogs
# and it spends the cogs and bolts the part on, at full speed. There is no collider,
# no stop and no menu (momentum is sacred). Short of cogs, you roll through and
# nothing happens; the hoop says how much more you need. After a sale it restocks
# with a new part after a short beat.
#
# Price is a pure function of the part's tier and how many parts the run holds, so a
# retry that restores the part list restores the prices too.

const RING := 5.0
const SINK := 1.5
const WIDTH := 8.0
# Every cog price in one table (CG1), so a retune is one edit. A shelf part costs part_base x
# part_tier[tier] x part_growth^parts_held; the shop's reroll, charge cells and sell-back read
# the rest. Values from the economy pass (systems audit pass B,
# docs/systems-audit/economy/README.md), measured on Moss's shelf and his scale.
const PART_GROWTH := 1.06
const COG_PRICES := {
	"part_base": 40.0, "part_tier": {1: 1.0, 2: 1.6, 3: 2.6}, "part_growth": PART_GROWTH,
	"reroll_base": 30, "reroll_growth": 1.5, "cell_base": 40, "cell_growth": 1.6, "sell_share": 0.5,
	# Moss's scale (shop.gd weigh, `--moss-scale=on`). One press weighs up to weigh_lump mass;
	# every mass_per_cog of it pays one cog, so a sale pays less than the scrap paid on the way in.
	"weigh_lump": 50, "mass_per_cog": 2.0,
}
# Parts priced off Moss's shelf (a trade chest's cogs price, a rack active offer, a legacy
# hoop) share PART_GROWTH (1.06) with Moss's shelf so late World 2/3 builds (25-30 held parts)
# never outrun Moss's shelf curve, while keeping the lower 10-cog base for off-shelf tiers.
const OFF_SHELF := {"part_base": 10.0, "part_growth": PART_GROWTH}
const RESTOCK := 2.5
const AVOID_BEACON := 55.0
const AVOID_SPAWN := 25.0
const SPACING := 40.0
const ALONG_LINE := 0.55
const PROMPT_REACH := 45.0

var _rng: RandomNumberGenerator
var _class_id := ""
var _stage := 1
var _fabs: Array[Dictionary] = []
# Build's offer_mark(part_id) -> String; the star line under an offer, or "".
var mark_for: Callable


# Moss's shelf price of a part.
static func price(part_id: String, parts_held: int) -> int:
	return int(round(COG_PRICES["part_base"] * COG_PRICES["part_tier"].get(_tier(part_id), 1.0) * pow(COG_PRICES["part_growth"], parts_held)))


# A part of `tier` priced off the shelf (OFF_SHELF).
static func off_shelf_price(tier: int, parts_held: int) -> int:
	return int(round(OFF_SHELF["part_base"] * COG_PRICES["part_tier"].get(tier, 1.0) * pow(OFF_SHELF["part_growth"], parts_held)))


# A legacy hoop's price for a part.
static func hoop_price(part_id: String, parts_held: int) -> int:
	return off_shelf_price(_tier(part_id), parts_held)


static func _tier(part_id: String) -> int:
	var d: Resource = Parts.def(part_id)
	return d.tier if d != null else 1


# Stands count hoops across the scrap lines, away from the beacon and the spawn.
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


func records() -> Array[Dictionary]:
	return _fabs


# Places a fabricator at a chosen spot; the tests use it to put one on a known line.
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
	var picks: Array = Parts.roll(_rng, Parts.SOURCE_RARITIES["fabricator"], _class_id, held, 1)
	return picks[0] if not picks.is_empty() else "hot_rivets"


# Returns the part ids bought this tick. The caller spends the cogs through the run
# state first; buy() is told whether the spend went through. `cogs` is the wallet.
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
		var side: float = (rel - (fab["facing"] as Vector3) * along).length()
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
	# The authored hoop (recipe row fabricator_hoop): its origin is the ground under the ring, ring centre RING - SINK up,
	# ring in the node's XY plane, so it stands across the line at IDENTITY. Its steel views wear the hoop's state.
	var views := RecipeProps.base("fabricator_hoop", node, Transform3D.IDENTITY)
	RecipeProps.shells("fabricator_hoop", node, Transform3D.IDENTITY)
	fab["state_views"] = RecipeProps.steel_views(views)
	_paint_state(fab, false)
	# Ground chevrons pointing through the hoop both ways say "roll through here".
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
	# The price is a screen prompt the HUD keeps in the prompts band (screen_regions.gd),
	# shown while you approach, so it never sits over the toasts or the objective.
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
	var color: Color = _rarity_color(rarity)
	var glyph: MeshInstance3D = fab["glyph"]
	glyph.material_override = Palette.solid(color, 2.4)
	glyph.visible = fab["restock"] <= 0.0
	fab["text"] = ""


static func _rarity_color(rarity: String) -> Color:
	var id := ItemGen.resolve_rarity(rarity)
	return ItemGen.RARITY[id if id != "" else "common"]["color"]


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


# The hoop's state on its steel views: amber when you can buy, dark copper when you cannot.
static func state_tint(ready: bool) -> Color:
	return Palette.AMBER if ready else Palette.COPPER.darkened(0.3)


func _paint_state(fab: Dictionary, ready: bool) -> void:
	for view: GeometryInstance3D in fab["state_views"]:
		view.set_instance_shader_parameter("state_tint", state_tint(ready))


# The prompt's title at range: the part's name, at most three words.
static func prompt_title(part_id: String) -> String:
	var words: PackedStringArray = Parts.display_name(part_id).split(" ", false)
	return " ".join(words.slice(0, WorldPrompt.TITLE_WORDS))


# Everything after the headline's name: the verb and punch, the effect, the price line
# and the star line.
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
