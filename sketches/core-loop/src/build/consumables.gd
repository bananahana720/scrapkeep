extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")
const Interact := preload("res://src/world/interact.gd")
const Roster := preload("res://src/combat/roster.gd")

# Pocket Consumable Belt (W47-C1; SOUTHWEST-SONIC-MECHA-NORTHSTAR section 4.2,
# SCRAPKEEP-REBASELINE-MASTER-BIBLE section 3.3, LEGIBILITY section 13).
# Six one-shot hardware cartridges racked on the belt (1 slot default, expandable to 2)
# and fired instantaneously on quick-tap (C / D-pad Up) with zero movement tax.

const CAP_CHARGE := "cap_charge"
const NITRO_SIPHON := "nitro_siphon"
const ANCHOR_FLARE := "anchor_flare"
const OVERCLOCK_CARD := "overclock_card"
const FOREMAN_MEMO := "foreman_memo"
const MOSS_PATCH := "moss_patch"

const ORDER: Array[String] = [
	CAP_CHARGE,
	NITRO_SIPHON,
	ANCHOR_FLARE,
	OVERCLOCK_CARD,
	FOREMAN_MEMO,
	MOSS_PATCH,
]

const BELT_PART_ID := "pocket_belt"
const BELT_PRICE := 90
const OFFER_PREFIX := "consumable:"
const BELT_OFFER_ID := "belt:pocket_belt"

const MODEL_DIR := "res://assets/models/consumables/"
const CRADLE_MODEL := MODEL_DIR + "cons_drop_cradle.glb"
const BALLOON_MODEL := MODEL_DIR + "cons_anchor_balloon.glb"
const DROP_GROUP := "consumable_drop"
const BALLOON_GROUP := "consumable_balloon"
const PICKUP_RADIUS := 2.4

# W47-C1-3D review note: Godot 4.7.2 glTF importer preserves COLOR_0 while leaving
# vertex_color_use_as_albedo = false on surface 0. Patch these surfaces on instantiation.
const VERTEX_COLOR_SURFACES: Array[String] = ["paint", "hydraulic", "ancient_enamel"]

# Secondary-counter enemies that may drop a Pocket Consumable on death.
const SECONDARY_COUNTER_KINDS: Array[String] = [
	"boom_tender",
	"jolt_layer",
	"gap_net",
	"hooker",
	"mag_trapper",
	"netcaster",
	"bola_thrower",
	"plated_brute",
	"deflector",
	"winch_drone",
	"gyro_jammer",
	"swatter",
	"ramp_flipper",
	"catch_trap",
	"linker",
]
const COUNTER_DROP_CHANCE := 0.35
const DESTRUCTIBLE_CHANCE := {3: 0.35, 4: 0.55, 5: 0.80}

# Canonical metadata for all 6 cartridges. Zero HAZARD red; Palette.KINDNESS (#D936B0)
# appears strictly as a flat non-emissive stripe on Foreman's Memo (B6: never a floor glow/grid).
const ROWS := {
	CAP_CHARGE: {
		"id": CAP_CHARGE,
		"name": "Blasting Cap",
		"maker": "foundry",
		"icon": "cons_cap_charge",
		"model": MODEL_DIR + "cons_cap_charge.glb",
		"color": Palette.AMBER,
		"price": 55,
		"duration_s": 0.0,
		"radius_m": 6.0,
		"max_tier": 5,
		"blast_damage": 38.0,
		"warden_posture": 45.0,
		"headline": "Shatters up to Tier 5 walls and strips outer plate.",
	},
	NITRO_SIPHON: {
		"id": NITRO_SIPHON,
		"name": "Nitro Siphon",
		"maker": "foundry",
		"icon": "cons_nitro_siphon",
		"model": MODEL_DIR + "cons_nitro_siphon.glb",
		"color": Palette.COPPER,
		"price": 60,
		"duration_s": 6.0,
		"grip_bonus": 0.50,
		"rip_radius_m": 14.0,
		"headline": "6 s Blazing floor, +50% carve grip, auto-rips snares.",
	},
	ANCHOR_FLARE: {
		"id": ANCHOR_FLARE,
		"name": "Anchor Flare",
		"maker": "anchor",
		"icon": "cons_anchor_flare",
		"model": MODEL_DIR + "cons_anchor_flare.glb",
		"color": Palette.ARC,
		"price": 55,
		"duration_s": 15.0,
		"height_m": 18.0,
		"bite_radius_m": 2.8,
		"headline": "Launches a 15 s sky-grapple balloon 18 m overhead.",
	},
	OVERCLOCK_CARD: {
		"id": OVERCLOCK_CARD,
		"name": "Overclock Punchcard",
		"maker": "foundry",
		"icon": "cons_overclock_card",
		"model": MODEL_DIR + "cons_overclock_card.glb",
		"color": Palette.SAND,
		"price": 70,
		"duration_s": 8.0,
		"skilled_damage_mult": 1.5,
		"headline": "8 s zero Movement/Special CD and auto Skilled shots.",
	},
	FOREMAN_MEMO: {
		"id": FOREMAN_MEMO,
		"name": "Foreman's Memo",
		"maker": "foreman",
		"icon": "cons_foreman_memo",
		"model": MODEL_DIR + "cons_foreman_memo.glb",
		"color": Palette.KINDNESS,
		"price": 65,
		"duration_s": 5.0,
		"radius_m": 24.0,
		"hull_cost_share": 0.10,
		"core_cost": 1,
		"weak_mult": 1.5,
		"formation_spacing_m": 2.6,
		"no_floor_glow": true,
		"headline": "5 s freezes ordinary crews in line; costs 1 core or 10% hull.",
	},
	MOSS_PATCH: {
		"id": MOSS_PATCH,
		"name": "Moss's Emergency Patch",
		"maker": "moss",
		"icon": "cons_moss_patch",
		"model": MODEL_DIR + "cons_moss_patch.glb",
		"color": Palette.VERDIGRIS,
		"price": 65,
		"duration_s": 0.0,
		"heal_share": 0.35,
		"knock_radius_m": 12.0,
		"knock_force": 18.0,
		"grace_s": 1.5,
		"headline": "+35% hull repair, 12 m knockback, 1.5 s grace.",
	},
}

static var _packed_cache := {}


static func _reset() -> void:
	_packed_cache.clear()


static func is_valid(consumable_id: String) -> bool:
	return ROWS.has(consumable_id)


static func row_of(consumable_id: String) -> Dictionary:
	return ROWS.get(consumable_id, {})


static func price_of(consumable_id: String) -> int:
	return int(ROWS.get(consumable_id, {}).get("price", 60))


static func icon_of(consumable_id: String) -> String:
	return String(ROWS.get(consumable_id, {}).get("icon", ""))


static func color_of(consumable_id: String) -> Color:
	return ROWS.get(consumable_id, {}).get("color", Palette.SAND)


static func model_path_of(consumable_id: String) -> String:
	return String(ROWS.get(consumable_id, {}).get("model", ""))


static func is_secondary_counter(kind: String) -> bool:
	return kind in SECONDARY_COUNTER_KINDS or kind in Roster.SPECIALS


static func is_offer(offer_id: String) -> bool:
	return offer_id == BELT_OFFER_ID or (offer_id.begins_with(OFFER_PREFIX) and is_valid(offer_id.substr(OFFER_PREFIX.length())))


static func offer_consumable_id(offer_id: String) -> String:
	if offer_id.begins_with(OFFER_PREFIX):
		var cid := offer_id.substr(OFFER_PREFIX.length())
		return cid if is_valid(cid) else ""
	return ""


static func gate_record(offer_id: String) -> Dictionary:
	if offer_id == BELT_OFFER_ID:
		return {
			"part_id": offer_id,
			"name": "Pocket Belt",
			"headline": "Adds a second Pocket Consumable slot.",
			"verb": "",
			"punch": 0.0,
			"text": "Hold two cartridges.",
			"rarity": "rare",
			"hotwired": false,
			"tier": 2,
			"synergy": "",
			"mark": "",
			"family": "utility",
			"icon": "cons_cap_charge",
			"trigger_icon": "",
			"element_icon": "",
		}
	var cid := offer_consumable_id(offer_id)
	var row: Dictionary = row_of(cid)
	return {
		"part_id": offer_id,
		"name": String(row.get("name", cid)),
		"headline": String(row.get("headline", "")),
		"verb": "",
		"punch": 0.0,
		"text": String(row.get("headline", "")),
		"rarity": "common",
		"hotwired": false,
		"tier": 1,
		"synergy": "",
		"mark": "",
		"family": "utility",
		"icon": String(row.get("icon", "")),
		"trigger_icon": "",
		"element_icon": "",
	}


static func roll_id(rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var pool: Array[String] = []
	for cid in ORDER:
		if not cid in exclude:
			pool.append(cid)
	if pool.is_empty():
		pool = ORDER.duplicate()
	if rng == null:
		return pool[0]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func roll_for_destructible(seed_val: int, run_id: String, stage: int, piece_id: String, tier: int) -> String:
	var chance: float = float(DESTRUCTIBLE_CHANCE.get(tier, 0.0))
	if chance <= 0.0:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(seed_val, run_id, stage, "destructible_cons:" + piece_id)
	if rng.randf() >= chance:
		return ""
	return roll_id(rng)


static func roll_for_counter_kill(rng: RandomNumberGenerator, kind: String, force := false) -> String:
	if not is_secondary_counter(kind):
		return ""
	if not force and kind not in Roster.SPECIALS:
		if rng == null or rng.randf() >= COUNTER_DROP_CHANCE:
			return ""
	return roll_id(rng)


# Enables vertex_color_use_as_albedo = true on paint/hydraulic/ancient_enamel surfaces
# (and any non-emissive vertex-colored glTF surface) so Godot 4.7.2 displays baked vertex colors.
# Uses mesh.duplicate() + surface_set_material() (avoiding Godot 4.7.2 Dummy renderer's null-override
# warning) and preserves B6: ancient_enamel stays strictly non-emissive.
static func apply_vertex_color_materials(root: Node) -> int:
	if root == null:
		return 0
	var patched := 0
	var meshes: Array = []
	if root is MeshInstance3D:
		meshes.append(root)
	meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for view in meshes:
		var mi := view as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mesh := mi.mesh
		var mesh_copy: Mesh = null
		for s in mesh.get_surface_count():
			var mat: Material = mesh.surface_get_material(s)
			if not (mat is StandardMaterial3D):
				continue
			var std := mat as StandardMaterial3D
			var mat_name := String(std.resource_name).to_lower()
			var arrays := mesh.surface_get_arrays(s)
			var has_colors: bool = arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_COLOR] != null and not (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).is_empty()
			var want := mat_name in VERTEX_COLOR_SURFACES or (has_colors and not std.emission_enabled)
			if not want:
				continue
			if mesh_copy == null:
				mesh_copy = mesh.duplicate() as Mesh
			var copy := std.duplicate() as StandardMaterial3D
			copy.vertex_color_use_as_albedo = true
			if mat_name == "ancient_enamel":
				copy.emission_enabled = false
			mesh_copy.surface_set_material(s, copy)
			patched += 1
		if mesh_copy != null:
			mi.mesh = mesh_copy
	return patched


static func instantiate_model(path: String, fallback_color := Palette.SAND) -> Node3D:
	var packed: PackedScene = _packed_cache.get(path)
	if packed == null and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
		if packed != null:
			_packed_cache[path] = packed
	if packed != null:
		var inst := packed.instantiate()
		if inst is Node3D:
			apply_vertex_color_materials(inst)
			return inst as Node3D
		if inst != null:
			inst.free()
	var fallback := Node3D.new()
	var view := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	view.mesh = box
	var mat := Palette.solid(fallback_color)
	mat.vertex_color_use_as_albedo = true
	view.material_override = mat
	fallback.add_child(view)
	return fallback


static func _find_socket(root: Node, socket_name: String) -> Node3D:
	if root == null:
		return null
	var found := root.find_child(socket_name, true, false)
	return found as Node3D if found is Node3D else null


static func spawn_cradle(cid: String, at: Vector3) -> Cradle:
	var cradle := Cradle.new()
	var cradle_node := instantiate_model(CRADLE_MODEL, Palette.SLATE)
	var patched := apply_vertex_color_materials(cradle_node)
	var socket := _find_socket(cradle_node, "SocketCartridge")
	var cart_node := instantiate_model(model_path_of(cid), color_of(cid))
	patched += apply_vertex_color_materials(cart_node)
	cradle.setup_nodes(cid, at, cradle_node, cart_node, socket, patched)
	return cradle


static func spawn_balloon(at: Vector3, duration_s := 15.0, radius := 2.8) -> AnchorBalloon:
	var balloon := AnchorBalloon.new()
	var visual := instantiate_model(BALLOON_MODEL, Palette.ARC)
	var patched := apply_vertex_color_materials(visual)
	var bite_socket := _find_socket(visual, "SocketBite")
	balloon.setup_nodes(at, duration_s, radius, visual, bite_socket, patched)
	return balloon


# World drop cradle (cons_drop_cradle.glb + cartridge GLB on SocketCartridge).
# Zero floor glow on Foreman's Memo (B6). Auto-collected on roll-through with zero speed tax.
class Cradle:
	extends Node3D

	var consumable_id := ""
	var collected := false
	var age := 0.0
	var patched_surfaces := 0
	var _cradle_node: Node3D
	var _cartridge_node: Node3D
	var _cartridge_base_y := 0.45

	func setup_nodes(cid: String, at: Vector3, cradle_node: Node3D, cart_node: Node3D, socket: Node3D, patched: int) -> void:
		consumable_id = cid
		name = "ConsumableDrop_" + cid
		add_to_group(DROP_GROUP)
		position = at
		patched_surfaces = patched
		_cradle_node = cradle_node
		_cradle_node.name = "DropCradle"
		add_child(_cradle_node)
		_cartridge_node = cart_node
		_cartridge_node.name = "Cartridge"
		if socket != null:
			socket.add_child(_cartridge_node)
			_cartridge_base_y = 0.0
		else:
			_cartridge_node.position = Vector3.UP * 0.45
			add_child(_cartridge_node)
			_cartridge_base_y = 0.45

	func step(delta: float, ball_pos: Vector3, run) -> bool:
		if collected:
			return false
		age += delta
		if is_instance_valid(_cartridge_node):
			_cartridge_node.rotation.y += delta * 1.4
			_cartridge_node.position.y = _cartridge_base_y + sin(age * 3.0) * 0.08
		if run == null or not run.has_method("can_hold_consumable") or not run.can_hold_consumable():
			return false
		var flat_dist := Vector2(ball_pos.x - global_position.x, ball_pos.z - global_position.z).length()
		if flat_dist <= PICKUP_RADIUS and absf(ball_pos.y - global_position.y) <= 3.0:
			if run.add_consumable(consumable_id):
				collected = true
				return true
		return false


# Hovering sky-grapple balloon (Anchor Flare): 18 m overhead for 15 s with 360-degree bite points.
# Joins Augments.STAKE_GROUP + Augments.ANCHOR_GROUP on STAKE_MASK so Harpoon.target() bites it
# from every direction and uses the player's single ChainState (G0).
class AnchorBalloon:
	extends StaticBody3D

	var time_left := 15.0
	var expired := false
	var bite_radius := 2.8
	var patched_surfaces := 0
	var _visual: Node3D
	var _bite_socket: Node3D
	var _base_y := 0.0
	var _age := 0.0

	func setup_nodes(at: Vector3, duration_s: float, radius: float, visual: Node3D, bite_socket: Node3D, patched: int) -> void:
		name = "AnchorFlareBalloon"
		time_left = maxf(0.1, duration_s)
		bite_radius = maxf(1.0, radius)
		position = at
		_base_y = at.y
		patched_surfaces = patched
		collision_layer = Augments.STAKE_MASK
		collision_mask = 0
		add_to_group(Augments.STAKE_GROUP)
		add_to_group(Augments.ANCHOR_GROUP)
		add_to_group(BALLOON_GROUP)
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = bite_radius
		col.shape = sphere
		add_child(col)
		_visual = visual
		_visual.name = "BalloonVisual"
		add_child(_visual)
		_bite_socket = bite_socket

	func step(delta: float) -> bool:
		if expired:
			return false
		_age += delta
		time_left -= delta
		if time_left <= 0.0:
			expired = true
			return false
		position.y = _base_y + sin(_age * 1.8) * 0.25
		return true

	func is_dead() -> bool:
		return expired

	func anchor_velocity() -> Vector3:
		return Vector3.ZERO

	func anchor_point(_at: Vector3) -> Vector3:
		if is_instance_valid(_bite_socket) and _bite_socket.is_inside_tree():
			return _bite_socket.global_position
		return global_position
