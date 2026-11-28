extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")
const Interact := preload("res://src/world/interact.gd")
const Roster := preload("res://src/combat/roster.gd")


const CAP_CHARGE := "cap_charge"
const NITRO_SIPHON := "nitro_siphon"
const ANCHOR_FLARE := "anchor_flare"
const OVERCLOCK_CARD := "overclock_card"
const FOREMAN_MEMO := "foreman_memo"
const MOSS_PATCH := "moss_patch"
const SCRAP_DICE := "scrap_dice"
const DUPLICATOR_SPOOL := "duplicator_spool"
const OVERLOAD_FUSE := "overload_fuse"

const ORDER: Array[String] = [
	CAP_CHARGE,
	NITRO_SIPHON,
	ANCHOR_FLARE,
	OVERCLOCK_CARD,
	FOREMAN_MEMO,
	MOSS_PATCH,
]

const ORDER_W50: Array[String] = [
	SCRAP_DICE,
	DUPLICATOR_SPOOL,
	OVERLOAD_FUSE,
]

const DUPLICATOR_WINDOW_S := 12.0
const OVERLOAD_ECHO_MULT := 0.75
const W50_STATE_META := "w50_consumable_state"

const BELT_PART_ID := "pocket_belt"
const BELT_PRICE := 90
const OFFER_PREFIX := "consumable:"
const BELT_OFFER_ID := "belt:pocket_belt"

const MODEL_DIR := "res://assets/models/consumables/"
const ICON_DIR := "res://assets/icons/"
const CRADLE_MODEL := MODEL_DIR + "cons_drop_cradle.glb"
const BALLOON_MODEL := MODEL_DIR + "cons_anchor_balloon.glb"
const DROP_GROUP := "consumable_drop"
const BALLOON_GROUP := "consumable_balloon"
const PICKUP_RADIUS := 2.4

const VERTEX_COLOR_SURFACES: Array[String] = ["paint", "hydraulic", "ancient_enamel"]

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
		"headline": "Shatters heavy walls and strips outer plate.",
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
		"headline": "Launches a 15 s overhead hook balloon 18 m up.",
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
		"headline": "8 s zero ability cooldowns and auto Skilled shots.",
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

const ROWS_W50 := {
	SCRAP_DICE: {
		"id": SCRAP_DICE,
		"name": "Foreman's Audit Die",
		"maker": "foreman",
		"icon": "cons_overclock_card",
		"model": MODEL_DIR + "cons_overclock_card.glb",
		"color": Palette.BRASS,
		"price": 75,
		"duration_s": 0.0,
		"hull_cost_share": 0.05,
		"core_cost": 1,
		"headline": "Rerolls offers to same or higher tier; costs 1 core or 5% hull.",
	},
	DUPLICATOR_SPOOL: {
		"id": DUPLICATOR_SPOOL,
		"name": "Carbon Tape",
		"maker": "moss",
		"icon": "cons_moss_patch",
		"model": MODEL_DIR + "cons_moss_patch.glb",
		"color": Palette.AMBER,
		"price": 80,
		"duration_s": DUPLICATOR_WINDOW_S,
		"max_clones": 1,
		"headline": "12 s clones next pickup, core or cartridge once.",
	},
	OVERLOAD_FUSE: {
		"id": OVERLOAD_FUSE,
		"name": "Breaker Fuse",
		"maker": "foundry",
		"icon": "cons_cap_charge",
		"model": MODEL_DIR + "cons_cap_charge.glb",
		"color": Palette.ARC,
		"price": 75,
		"duration_s": 0.0,
		"echo_mult": OVERLOAD_ECHO_MULT,
		"max_echoes": 1,
		"headline": "Next Active or Ultimate echoes once at 0.75x.",
	},
}

static var _packed_cache := {}


static func reset_for_tests() -> void:
	_packed_cache.clear()


static func all_order() -> Array[String]:
	var out: Array[String] = []
	out.append_array(ORDER)
	out.append_array(ORDER_W50)
	return out


static func all_rows() -> Dictionary:
	return ROWS.merged(ROWS_W50, true)


static func is_valid(consumable_id: String) -> bool:
	return ROWS.has(consumable_id) or ROWS_W50.has(consumable_id)


static func row_of(consumable_id: String) -> Dictionary:
	if ROWS.has(consumable_id):
		return ROWS[consumable_id]
	return ROWS_W50.get(consumable_id, {})


static func price_of(consumable_id: String) -> int:
	return int(row_of(consumable_id).get("price", 60))


static func _preferred_icon(preferred: String, fallback: String) -> String:
	if preferred != "" and ResourceLoader.exists(ICON_DIR + preferred + ".svg"):
		return preferred
	return fallback


static func _preferred_model(preferred_path: String, fallback_path: String) -> String:
	if preferred_path != "" and ResourceLoader.exists(preferred_path):
		return preferred_path
	return fallback_path


static func icon_of(consumable_id: String) -> String:
	var fallback := String(row_of(consumable_id).get("icon", ""))
	if ROWS_W50.has(consumable_id):
		return _preferred_icon("cons_" + consumable_id, fallback)
	return fallback


static func color_of(consumable_id: String) -> Color:
	return row_of(consumable_id).get("color", Palette.SAND)


static func model_path_of(consumable_id: String) -> String:
	var fallback := String(row_of(consumable_id).get("model", ""))
	if ROWS_W50.has(consumable_id):
		return _preferred_model(MODEL_DIR + "cons_" + consumable_id + ".glb", fallback)
	return fallback


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
			"icon": _preferred_icon("cons_pocket_belt", "cons_cap_charge"),
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
		"icon": icon_of(cid),
		"trigger_icon": "",
		"element_icon": "",
	}


static func roll_id(rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var full := all_order()
	var pool: Array[String] = []
	for cid in full:
		if not cid in exclude:
			pool.append(cid)
	if pool.is_empty():
		pool = full
	if rng == null:
		return pool[0]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _w50_state(run) -> Dictionary:
	if run == null:
		return {"duplicator_left": 0.0, "duplicator_armed": false, "duplicator_clones": 0, "overload_armed": false, "overload_echoes": 0}
	var raw = run.get_meta(W50_STATE_META) if run.has_meta(W50_STATE_META) else null
	if not (raw is Dictionary):
		raw = {"duplicator_left": 0.0, "duplicator_armed": false, "duplicator_clones": 0, "overload_armed": false, "overload_echoes": 0}
		run.set_meta(W50_STATE_META, raw)
	return raw


static func clear_w50(run) -> void:
	if run == null:
		return
	run.set_meta(W50_STATE_META, {"duplicator_left": 0.0, "duplicator_armed": false, "duplicator_clones": 0, "overload_armed": false, "overload_echoes": 0})


static func duplicator_left(run) -> float:
	var st := _w50_state(run)
	return float(st.get("duplicator_left", 0.0)) if bool(st.get("duplicator_armed", false)) else 0.0


static func duplicator_armed(run) -> bool:
	var st := _w50_state(run)
	return bool(st.get("duplicator_armed", false)) and float(st.get("duplicator_left", 0.0)) > 0.0


static func overload_armed(run) -> bool:
	return bool(_w50_state(run).get("overload_armed", false))


static func step_w50(ctx, delta: float) -> void:
	if ctx == null or ctx.run == null:
		return
	var st := _w50_state(ctx.run)
	if bool(st.get("duplicator_armed", false)):
		st["duplicator_left"] = maxf(0.0, float(st.get("duplicator_left", 0.0)) - delta)
		if float(st["duplicator_left"]) <= 0.0:
			st["duplicator_armed"] = false


static func consume_overload_fuse(run) -> bool:
	if run == null:
		return false
	var st := _w50_state(run)
	if not bool(st.get("overload_armed", false)):
		return false
	st["overload_armed"] = false
	st["overload_echoes"] = int(st.get("overload_echoes", 0)) + 1
	return true


static func fire_w50(cid: String, ctx, combat, at: Vector3) -> Dictionary:
	var row := row_of(cid)
	var st := _w50_state(ctx.run if ctx != null else null)
	match cid:
		SCRAP_DICE:
			var shop_res := {"rerolled": 0, "before_tiers": [], "after_tiers": []}
			if ctx != null and ctx.build != null and ctx.build.get("shop") != null and ctx.build.shop.has_method("audit_reroll"):
				shop_res = ctx.build.shop.audit_reroll()
			var gate_rerolls := _audit_reroll_gates(ctx)
			var paid_cost := "none"
			if int(shop_res.get("rerolled", 0)) + gate_rerolls > 0 and ctx != null and ctx.run != null:
				if int(ctx.run.bonus_cores) >= int(row.get("core_cost", 1)):
					ctx.run.bonus_cores -= int(row.get("core_cost", 1))
					paid_cost = "core"
				elif float(ctx.run.max_hp) > 0.0:
					var floor_hp := ceilf(float(ctx.run.max_hp) * 0.10)
					var loss := roundf(float(ctx.run.max_hp) * float(row.get("hull_cost_share", 0.05)))
					if float(ctx.run.hp) > floor_hp:
						ctx.run.hp = maxf(floor_hp, float(ctx.run.hp) - loss)
						ctx.run.since_damage = 0.0
					paid_cost = "hull"
			if combat != null and combat.get("effects") != null:
				combat.effects.ring(at, 4.5, row.get("color", Palette.BRASS))
			return {
				"rerolled_shop": int(shop_res.get("rerolled", 0)),
				"before_tiers": shop_res.get("before_tiers", []),
				"after_tiers": shop_res.get("after_tiers", []),
				"rerolled_gates": gate_rerolls,
				"cost": paid_cost,
			}
		DUPLICATOR_SPOOL:
			st["duplicator_armed"] = true
			st["duplicator_left"] = DUPLICATOR_WINDOW_S
			if combat != null and combat.has_method("post_consumable_buff"):
				combat.post_consumable_buff("consumable_duplicator_spool", icon_of(cid), row["color"], DUPLICATOR_WINDOW_S)
			if combat != null and combat.get("effects") != null:
				combat.effects.ring(at, 4.0, row.get("color", Palette.AMBER))
			return {"duration_s": DUPLICATOR_WINDOW_S, "armed": true}
		OVERLOAD_FUSE:
			st["overload_armed"] = true
			if combat != null and combat.get("effects") != null:
				combat.effects.ring(at, 4.2, row.get("color", Palette.ARC))
			return {"armed": true, "echo_mult": OVERLOAD_ECHO_MULT}
	return {}


static func _audit_reroll_gates(ctx) -> int:
	if ctx == null or ctx.build == null or ctx.build.get("gates") == null or ctx.run == null:
		return 0
	var gates = ctx.build.gates
	var offers: Array = gates.get("offers") if gates.get("offers") is Array else []
	if offers.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.run.run_seed, ctx.run.stage, "scrap_dice_gates", offers.size()])
	var changed: int = gates.reroll_offers(rng, ctx.run.class_id(), ctx.run.parts)
	if changed > 0:
		if ctx.build.has_method("note_offered"):
			for o in gates.offers:
				if o is Dictionary and o.has("part_id"):
					ctx.build.note_offered(String(o["part_id"]))
		if ctx.events != null and ctx.events.has_signal("reward_offered"):
			ctx.events.reward_offered.emit(gates.offers)
	return changed


static func try_clone_pickup(ctx, combat, kind: String, payload, at := Vector3.ZERO) -> Dictionary:
	if ctx == null or ctx.run == null:
		return {"cloned": false}
	var st := _w50_state(ctx.run)
	if not bool(st.get("duplicator_armed", false)) or float(st.get("duplicator_left", 0.0)) <= 0.0:
		return {"cloned": false}
	var valid_payload := false
	match kind:
		"consumable":
			valid_payload = is_valid(String(payload))
		"core":
			valid_payload = true
		"part":
			valid_payload = String(payload) != ""
		"cogs", "scrap":
			valid_payload = int(payload) > 0
	if not valid_payload:
		return {"cloned": false}
	st["duplicator_armed"] = false
	st["duplicator_left"] = 0.0
	st["duplicator_clones"] = int(st.get("duplicator_clones", 0)) + 1
	if combat != null and combat.has_method("clear_buff"):
		combat.clear_buff("consumable_duplicator_spool")
	match kind:
		"consumable":
			var cid := String(payload)
			if not ctx.run.add_consumable(cid) and combat != null and combat.has_method("drop_consumable"):
				combat.drop_consumable(cid, at + Vector3(3.2, 0.0, 0.0))
		"core":
			ctx.run.add_core("duplicator_spool", at)
		"part":
			ctx.run.add_part(String(payload), "duplicator_spool")
		"cogs":
			ctx.run.add_cogs(int(payload))
		"scrap":
			ctx.run.add_scrap(int(payload), at)
	return {"cloned": true, "kind": kind, "payload": payload, "clones_total": int(st["duplicator_clones"])}


static func echo_ultimate(ctx, combat, base_damage: float, at: Vector3, radius := 8.0) -> Dictionary:
	if ctx == null or ctx.run == null or combat == null:
		return {"echoed": false, "hits": 0}
	if not consume_overload_fuse(ctx.run):
		return {"echoed": false, "hits": 0}
	var dmg := maxf(1.0, base_damage * OVERLOAD_ECHO_MULT)
	var hits := 0
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.is_dead() and enemy.global_position.distance_to(at) <= radius:
			combat.deal_proc_hit(enemy, "ultimate_echo", dmg, enemy.global_position - at, 6.0, "", "item_proc", "cannon")
			hits += 1
	if combat.get("effects") != null:
		combat.effects.ring(at, radius, Palette.ARC)
	return {"echoed": true, "mult": OVERLOAD_ECHO_MULT, "damage": dmg, "hits": hits, "source": "item_proc"}


static func echo_active_fallback(ctx, combat, _active_id: String, mult := OVERLOAD_ECHO_MULT) -> int:
	if ctx == null or combat == null or ctx.player == null:
		return 0
	var at: Vector3 = ctx.player.ball_position()
	var dmg := 20.0 * mult * (float(ctx.tuning.mod("weapon_damage")) if ctx.tuning != null else 1.0)
	var hits := 0
	for enemy in combat.nearest_enemies(at, 16.0, 4):
		if is_instance_valid(enemy) and not enemy.is_dead():
			combat.deal_proc_hit(enemy, "active_echo", dmg, enemy.global_position - at, 6.0, "", "item_proc", "cannon")
			hits += 1
	if combat.get("effects") != null:
		combat.effects.ring(at, 5.5, Palette.ARC)
	return maxi(1, hits)


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


static func _instantiate_with_count(path: String, fallback_color := Palette.SAND) -> Dictionary:
	var packed: PackedScene = _packed_cache.get(path)
	if packed == null and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
		if packed != null:
			_packed_cache[path] = packed
	if packed != null:
		var inst := packed.instantiate()
		if inst is Node3D:
			var count := apply_vertex_color_materials(inst)
			return {"node": inst as Node3D, "patched": count}
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
	return {"node": fallback, "patched": 0}


static func instantiate_model(path: String, fallback_color := Palette.SAND) -> Node3D:
	return _instantiate_with_count(path, fallback_color)["node"]


static func _find_socket(root: Node, socket_name: String) -> Node3D:
	if root == null:
		return null
	var found := root.find_child(socket_name, true, false)
	return found as Node3D if found is Node3D else null


static func spawn_cradle(cid: String, at: Vector3) -> Cradle:
	var cradle := Cradle.new()
	var cradle_res := _instantiate_with_count(CRADLE_MODEL, Palette.SLATE)
	var cradle_node: Node3D = cradle_res["node"]
	var patched := int(cradle_res["patched"])
	var socket := _find_socket(cradle_node, "SocketCartridge")
	var cart_res := _instantiate_with_count(model_path_of(cid), color_of(cid))
	var cart_node: Node3D = cart_res["node"]
	patched += int(cart_res["patched"])
	cradle.setup_nodes(cid, at, cradle_node, cart_node, socket, patched)
	return cradle


static func spawn_balloon(at: Vector3, duration_s := 15.0, radius := 2.8) -> AnchorBalloon:
	var balloon := AnchorBalloon.new()
	var visual_res := _instantiate_with_count(BALLOON_MODEL, Palette.ARC)
	var visual: Node3D = visual_res["node"]
	var patched := int(visual_res["patched"])
	var bite_socket := _find_socket(visual, "SocketBite")
	balloon.setup_nodes(at, duration_s, radius, visual, bite_socket, patched)
	return balloon


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
