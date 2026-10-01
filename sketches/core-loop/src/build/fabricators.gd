extends Node3D

const Parts := preload("res://src/build/parts.gd")
const Palette := preload("res://src/core/palette.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")

# Drive-through fabricators: hoops standing across the scrap lines. Each shows the part
# it makes and its price while you approach; roll through the hoop with enough scrap
# and it spends the scrap and bolts the part on, at full speed. There is no collider,
# no stop and no menu (momentum is sacred). Short of scrap, you roll through and
# nothing happens; the hoop says how much more you need. After a sale it restocks
# with a new part after a short beat.
#
# Price is a pure function of the part's tier and how many parts the run holds, so a
# retry that restores the part list restores the prices too.

const RING := 5.0
const SINK := 1.5
const WIDTH := 8.0
const BASE_PRICE := 10.0
const TIER_PRICE := {1: 1.0, 2: 1.6, 3: 2.6}
const PRICE_GROWTH := 1.15
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


static func price(part_id: String, parts_held: int) -> int:
	var d: Resource = Parts.def(part_id)
	var tier: int = d.tier if d != null else 1
	return int(round(BASE_PRICE * TIER_PRICE.get(tier, 1.0) * pow(PRICE_GROWTH, parts_held)))


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


# Returns the part ids bought this tick. The caller spends the scrap through the run
# state first; buy() is told whether the spend went through.
func step(ball: Vector3, delta: float, scrap: int, held: Array) -> Array[Dictionary]:
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
		_refresh_label(fab, scrap, held)
	return crossings


func sold(fab: Dictionary) -> void:
	fab["restock"] = RESTOCK
	_refresh_glyph(fab)


func _build_hoop(fab: Dictionary) -> void:
	var node: Node3D = fab["node"]
	var hoop := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING - 0.35
	torus.outer_radius = RING
	torus.rings = 48
	hoop.mesh = torus
	# Upright, facing along the line: the torus lies in XZ, so tip it onto XY.
	hoop.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	hoop.position = Vector3(0.0, RING - SINK, 0.0)
	var hoop_mat := Palette.solid(Palette.COPPER, 0.4)
	hoop.material_override = hoop_mat
	node.add_child(hoop)
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
	fab["hoop_mat"] = hoop_mat
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
	match rarity:
		"uncommon":
			return Palette.ARC
		"rare":
			return Palette.AMBER
		"rare_plus":
			return Palette.AMBER
	return Palette.SANDSTONE


func _refresh_label(fab: Dictionary, scrap: int, held: Array) -> void:
	var part_id: String = fab["part_id"]
	var cost := price(part_id, held.size())
	var text := ""
	var ready: bool = fab["restock"] <= 0.0 and scrap >= cost
	if fab["restock"] > 0.0:
		text = "FABRICATING..."
	else:
		var d: Resource = Parts.def(part_id)
		text = "%s\n%s\n%s" % [Parts.headline(part_id), d.text if d != null else "",
			"ROLL THROUGH: %d scrap" % cost if ready else "need %d scrap (have %d)" % [cost, scrap]]
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
	var mat: StandardMaterial3D = fab["hoop_mat"]
	mat.albedo_color = Palette.AMBER if ready else Palette.COPPER.darkened(0.3)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.2 if ready else 0.15


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
