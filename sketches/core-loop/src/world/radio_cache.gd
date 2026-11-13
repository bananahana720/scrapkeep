extends Node3D

const Palette := preload("res://src/core/palette.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const MODEL := "res://assets/models/world_one/radio_cache.glb"
const REQUIRED := ["RadioMast", "RadioLamp", "RadioPulse"]
const LAMP_AT := Vector3(0.0, 2.66, 0.05)

# A Signal cache: a small antenna mast with a dish and a blinking lamp, standing at a deliberate
# spot in a park (catalogue rows whose found rule is {"on": "cache"}). Rolling within REACH of it
# collects its take through radio_deck.cache_found. The spots' coordinates live in
# assets/radio/cache_spots.json, by take id, filled in by the park-dressing work; a take with no
# spot yet has no cache in the world. spawn_for builds every unfound cache of the stage's map.

const SPOTS := "res://assets/radio/cache_spots.json"
const REACH := 3.5
const BLINK := 0.9
const GROUP := "radio_cache"

var take_id := ""
var deck
var player: Node3D
var _lamp: MeshInstance3D
var _ring: MeshInstance3D
var _age := 0.0


static func spots() -> Dictionary:
	var text := FileAccess.get_file_as_string(SPOTS)
	var parsed = JSON.parse_string(text) if text != "" else null
	return parsed.get("spots", {}) if parsed is Dictionary else {}


# The caches of a map not yet found, as [take id, position] pairs.
static func wanted(map_id: String, found: Callable, table: Dictionary = {}) -> Array:
	if table.is_empty():
		table = spots()
	var out: Array = []
	for t in RadioTakes.takes():
		var rule: Dictionary = t["found"]
		var id := String(t["id"])
		if rule.get("on") != "cache" or rule.get("park") != map_id or found.call(id) or not table.has(id):
			continue
		var at: Array = table[id]
		out.append([id, Vector3(float(at[0]), float(at[1]), float(at[2]))])
	return out


static func spawn_for(map_id: String, found: Callable, parent: Node, deck_ref, player_ref: Node3D) -> Array:
	var made: Array = []
	for pair in wanted(map_id, found):
		var cache = load("res://src/world/radio_cache.gd").new()
		cache.take_id = pair[0]
		cache.deck = deck_ref
		cache.player = player_ref
		cache.name = "RadioCache_" + String(pair[0])
		parent.add_child(cache)
		cache.global_position = pair[1]
		made.append(cache)
	return made


func _ready() -> void:
	add_to_group(GROUP)
	if _parts.is_empty():
		_parts = _make_parts()
	if not _build_model():
		_build_plain()


# The crew mast model (W1-23, tools/blender/world_one/radio_cache.py): the lamp sits on the dish's
# feed horn and the pulse ring widens round the dish. False, with nothing built, when it is missing.
func _build_model() -> bool:
	if ModelKit.part(MODEL, REQUIRED, "RadioMast", self) == null:
		return false
	_lamp = ModelKit.part(MODEL, REQUIRED, "RadioLamp", self)
	_lamp.position = LAMP_AT
	_lamp.material_override = _parts.lamp
	_ring = ModelKit.part(MODEL, REQUIRED, "RadioPulse", self)
	_ring.position.y = 2.2
	_ring.material_override = _parts.ring
	return true


func _build_plain() -> void:
	var mast := MeshInstance3D.new()
	mast.mesh = _parts.pole
	mast.position.y = 1.2
	mast.material_override = _parts.copper
	add_child(mast)
	var dish := MeshInstance3D.new()
	dish.mesh = _parts.bowl
	dish.position = Vector3(0.0, 2.2, 0.0)
	dish.rotation_degrees = Vector3(-120.0, 0.0, 0.0)
	dish.material_override = _parts.brass
	add_child(dish)
	_lamp = MeshInstance3D.new()
	_lamp.mesh = _parts.bulb
	_lamp.position.y = 2.55
	_lamp.material_override = _parts.lamp
	add_child(_lamp)
	_ring = MeshInstance3D.new()
	_ring.mesh = _parts.torus
	_ring.position.y = 2.2
	_ring.material_override = _parts.ring
	add_child(_ring)


# Every cache is the same mast, dish, lamp and ring, so the meshes and materials are made once
# and shared: a primitive mesh builds its arrays and a material its shader on first use, which
# was 1.5 ms a cache on the stage entry frame.
static var _parts := {}

static func _make_parts() -> Dictionary:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.1
	pole.height = 2.4
	var bowl := SphereMesh.new()
	bowl.radius = 0.55
	bowl.height = 0.35
	bowl.is_hemisphere = true
	var bulb := SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	return {"pole": pole, "bowl": bowl, "bulb": bulb, "torus": torus, "copper": _metal(Palette.COPPER),
		"brass": _metal(Palette.BRASS), "lamp": _glow(Palette.ARC), "ring": _glow(Color(Palette.ARC, 0.5))}


static func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.7
	m.roughness = 0.45
	return m


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color, 1.0)
	m.emission_energy_multiplier = 2.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _process(delta: float) -> void:
	_age += delta
	if _lamp != null:
		_lamp.visible = FlashGuard.blink(fmod(_age, BLINK) < BLINK * 0.5)
	if _ring != null:
		var pulse := fmod(_age, BLINK * 2.0) / (BLINK * 2.0)
		_ring.scale = Vector3.ONE * lerpf(0.4, 2.2, pulse)
		_ring.transparency = pulse


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or deck == null:
		return
	# The game hands over its PlayerBall, a node that never leaves the origin (its body moves under
	# it): the ball's place at the tick is ball_position().
	var ball: Vector3 = player.ball_position() if player.has_method("ball_position") else player.global_position
	if ball.distance_to(global_position + Vector3.UP) <= REACH:
		collect()


# The cache goes once the deck has its take on file; while the deck refuses (the run is not in
# play) it stays where it is.
func collect() -> bool:
	var ok: bool = deck != null and deck.cache_found(take_id)
	if ok:
		queue_free()
	return ok
