extends RefCounted

const Triggers := preload("res://src/build/triggers.gd")
const Parts := preload("res://src/build/parts.gd")
const PartMutations := preload("res://src/build/part_mutations.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Palette := preload("res://src/core/palette.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")


const MAX_CHARGES := 4
const SLOTS := ["weapon", "movement", "special", "smash"]
const BASE_HIT := 14.0
const EFFECTS := {
	"zap": "chance", "burst": "chance", "extra_hit": "chance", "speed": "gain", "air_jump": "",
	"grant_charge": "", "pin_bonus": "bonus", "pin_chain": "count", "ballast": "", "rebound_crit": "",
	"relaunch_pin": "", "scrap_burst": "chance", "echo_release": "chance", "cloak_extend": "seconds",
	"domino": "chance", "arm_hit": "bonus", "rebound_strike": "mult", "last_word": "bonus",
	"vault_cooldown": "per", "vault_charges": "count", "dash": "speed", "return_arc": "share",
	"damage_reduction": "per", "heal_back": "chance", "brace": "share", "hp_per_mass": "per", "floor_hp": "",
	"bonus_scrap": "chance", "ping": "", "price_scale": "per", "perk": "", "drone": "chance",
	"slot_cooldown": "per", "overcharge": "damage", "burden_payout": "per", "pike_fuse": "",
	"dash_wake": "", "reel_chain": "", "slam_crack": "", "second_bell": "", "line_leash": "",
	"boomerang_return": "damage_per_stack", "orbital_satellites": "count", "prism_refract": "per_stack",
	"coin_shot": "scale_per", "slag_zone": "radius_per", "pocket_aura": "per",
	"seismic_cone": "per_stack", "air_static": "per_stack",
}
const PASSIVE_EFFECTS := ["slot_cooldown", "damage_reduction", "price_scale", "hp_per_mass", "perk", "ballast",
	"vault_cooldown", "vault_charges", "pike_fuse", "dash_wake", "reel_chain", "slam_crack", "second_bell", "line_leash",
	"boomerang_return", "orbital_satellites", "prism_refract", "coin_shot", "slag_zone", "pocket_aura",
	"seismic_cone", "air_static"]
const VERB_EFFECTS := ["dash_wake", "reel_chain", "slam_crack", "second_bell", "line_leash"]
const DOMINO_MAX_PER_WINDOW := 3
const PING_RADIUS := 9.0

var build
var copies := {}
var burden_count := 0
var by_kind := {}
var timed: Array = []
var charges := {}
var cooldown_scale := {}
var damage_reduction := 0.0
var price_scale := 1.0
var hp_per_mass := 0.0
var hp_mass_step := 50.0
var hp_mass_cap := 0.0
var perks := {}
var vault_cooldown_scale := 1.0
var vault_charges := 0
var pike := {}
var verbs := {}
var micro_mutations := {}
var grapple_mutations := {}
var grapple_mutation_ids := {}
var _held_parts: Array = []
var procs := {}

var _clock := 0.0
var _ready_at := {}
var _timers := {}
var _armed_hit := 0.0
var _pin_until := {}
var _pins: Array = []
var _recent_pins: Array = []
var _rebounds: Array[float] = []
var _rebound_window := 4.0
var _rebound_need := 3
var _last_word_used := false
var _last_word_pending := false
var _ward_used := false
var _brace_until := 0.0
var _brace_share := 0.0
var _brace_source := ""
var _hit_seq := 0
var _drone_until := 0.0
var _drone_magnet := 1.0
var _domino_marks := {}
var _domino_count := 0
var _domino_serial := 0


func _init(build_ref) -> void:
	build = build_ref


static func stack_key(effect_id: String) -> String:
	return EFFECTS.get(effect_id, "")


static func stacked(d: Resource, key: String, n: int) -> float:
	if key == "" or not d.effect.has(key):
		return 0.0
	return PartDef.Stacking.value(d.stack_rule, float(d.effect[key]), n, d.stack_cap)


func refresh(held: Array) -> void:
	copies = {}
	burden_count = 0
	var order: Array = []
	for part_id in held:
		if Parts.is_burden(part_id):
			burden_count += 1
		if not copies.has(part_id):
			order.append(part_id)
		copies[part_id] = copies.get(part_id, 0) + 1
	by_kind = {}
	timed = []
	charges = {}
	cooldown_scale = {}
	damage_reduction = 0.0
	price_scale = 1.0
	hp_per_mass = 0.0
	hp_mass_cap = 0.0
	perks = {}
	vault_cooldown_scale = 1.0
	vault_charges = 0
	pike = {}
	verbs = {}
	micro_mutations = {}
	grapple_mutations = Parts.active_grapple_mutations(held, MakerSets.live_grapple_mutations(held))
	grapple_mutation_ids = {}
	for slot in grapple_mutations:
		var gm: Dictionary = grapple_mutations[slot]
		grapple_mutation_ids[String(gm["id"])] = gm
	_held_parts = held.duplicate()
	var index := 0
	for part_id in order:
		if PartMutations.MICRO_MUTATIONS.has(part_id) or PartMutations.FLAT_MICRO_MUTATIONS.has(part_id):
			micro_mutations[part_id] = PartMutations.micro_mutation(part_id)
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		var n: int = copies[part_id]
		for slot in d.charges:
			var add: float = PartDef.Stacking.value(d.stack_rule, float(d.charges[slot]), n, d.stack_cap)
			charges[slot] = charges.get(slot, 0) + int(add)
		var effect_id: String = d.effect.get("do", "")
		match effect_id:
			"slot_cooldown":
				var slot: String = d.effect.get("slot", "special")
				cooldown_scale[slot] = cooldown_scale.get(slot, 1.0) * (1.0 - stacked(d, "per", n))
			"damage_reduction":
				damage_reduction = 1.0 - (1.0 - damage_reduction) * (1.0 - stacked(d, "per", n))
			"price_scale":
				price_scale *= maxf(0.5, 1.0 - stacked(d, "per", n))
			"hp_per_mass":
				hp_per_mass += stacked(d, "per", n)
				hp_mass_step = d.effect.get("mass", 50.0)
				hp_mass_cap = maxf(hp_mass_cap, d.effect.get("cap_hp", 40.0))
			"perk":
				perks[d.effect.get("perk", "")] = true
			"vault_cooldown":
				vault_cooldown_scale *= maxf(0.2, 1.0 - stacked(d, "per", n))
			"vault_charges":
				vault_charges += int(stacked(d, "count", n))
			"pike_fuse":
				pike = {"every": maxi(2, int(d.effect.get("every", 6))), "cap_mult": maxf(1.0, float(d.effect.get("cap_mult", 6.0))),
					"range_mult": maxf(1.0, float(d.effect.get("range_mult", 1.25))), "idle_s": maxf(0.1, float(d.effect.get("idle_s", 3.0)))}
		if effect_id in VERB_EFFECTS:
			verbs[effect_id] = d.effect.duplicate(true)
		if d.trigger == "":
			continue
		var entry := {"id": part_id, "def": d, "copies": n, "index": index}
		index += 1
		if d.trigger == "timed":
			timed.append(entry)
			_timers[part_id] = _timers.get(part_id, 0.0)
		var kind := Triggers.kind_of(d.trigger)
		var list: Array = by_kind.get(kind, [])
		list.append(entry)
		by_kind[kind] = list


func pike_fuse() -> Dictionary:
	return pike.duplicate()


func verb_row(effect_id: String) -> Dictionary:
	return (verbs.get(effect_id, {}) as Dictionary).duplicate(true)


func has_micro_mutation(part_id: String) -> bool:
	return micro_mutations.has(part_id)


func micro_mutation(part_id: String) -> Dictionary:
	return (micro_mutations.get(part_id, {}) as Dictionary).duplicate(true)


func active_micro_mutations() -> Array:
	return PartMutations.active_micro_mutations(_held_parts)


func active_grapple_mutations() -> Dictionary:
	return grapple_mutations.duplicate(true)


func has_grapple_mutation(mut_id: String) -> bool:
	return grapple_mutation_ids.has(PartMutations.grapple_mutation_id_of(mut_id))


func grapple_mutation(mut_id: String) -> Dictionary:
	var mid := PartMutations.grapple_mutation_id_of(mut_id)
	return (grapple_mutation_ids.get(mid, {}) as Dictionary).duplicate(true)


static func part_synergy_info(part_id: String) -> Dictionary:
	var d: Resource = Parts.def(part_id)
	if d == null:
		return {}
	return {"tags": d.tags, "bits": d.bits}


func has_cross_synergy(id: String, context := {}) -> bool:
	return Synergies.cross_system_awake(id, _held_parts, Callable(self, "part_synergy_info"), context)


func part_copies(part_id: String) -> int:
	return int(copies.get(part_id, 0))


func has_part(part_id: String) -> bool:
	return part_copies(part_id) > 0


func boomerang_stats() -> Dictionary:
	var n := part_copies("boomerang_spool")
	if n <= 0:
		return {}
	var d: Resource = Parts.def("boomerang_spool")
	var fx: Dictionary = d.effect
	var dmg_add := PartDef.Stacking.value("linear", float(fx.get("damage_per_stack", 0.20)), n - 1, float(d.stack_cap))
	var wid_add := PartDef.Stacking.value("linear", float(fx.get("width_per_stack", 0.25)), n - 1, float(d.stack_cap))
	return {
		"stacks": n,
		"pause_s": float(fx.get("pause_s", 0.15)),
		"damage_mult": minf(float(fx.get("max_damage_mult", 2.0)), 1.0 + dmg_add),
		"width_mult": minf(float(fx.get("max_width_mult", 2.25)), 1.0 + wid_add),
	}


func orbital_count() -> int:
	var n := part_copies("orbital_flywheel")
	if n <= 0:
		return 0
	var d: Resource = Parts.def("orbital_flywheel")
	var fx: Dictionary = d.effect
	var cap_n := int(fx.get("max_count", 5))
	return clampi(int(PartDef.Stacking.value("capped", float(fx.get("count", 1)), n, float(cap_n))), 1, cap_n)


func prism_rays() -> int:
	var n := part_copies("prism_splitter")
	if n <= 0:
		return 0
	var d: Resource = Parts.def("prism_splitter")
	var fx: Dictionary = d.effect
	var base_rays := int(fx.get("base_rays", 2))
	var max_rays := int(fx.get("max_rays", 5))
	return clampi(base_rays + int(PartDef.Stacking.value("linear", float(fx.get("per_stack", 1)), n, float(d.stack_cap))), base_rays + 1, max_rays)


func coin_shot_damage() -> float:
	var n := part_copies("debt_collector")
	if n <= 0:
		return 0.0
	var d: Resource = Parts.def("debt_collector")
	var fx: Dictionary = d.effect
	var scale := PartDef.Stacking.value("hyperbolic", float(fx.get("scale_per", 0.35)), n, float(d.stack_cap))
	return float(fx.get("damage", 16.0)) * (1.0 + scale * 1.5)


func slag_radius(extra_bonus := 0.0) -> float:
	var n := part_copies("slag_furnace")
	if n <= 0:
		return 0.0
	var d: Resource = Parts.def("slag_furnace")
	var fx: Dictionary = d.effect
	var base_r := float(fx.get("base_radius", 3.2))
	var max_r := float(fx.get("max_radius", 6.5))
	var frac := PartDef.Stacking.value("hyperbolic", float(fx.get("radius_per", 0.45)), n - 1, float(d.stack_cap))
	return minf(max_r, base_r + (max_r - base_r) * frac) + maxf(0.0, extra_bonus)


func pocket_aura_bonus(has_consumable: bool) -> float:
	var n := part_copies("patch_tether")
	if n <= 0 or not has_consumable:
		return 0.0
	var d: Resource = Parts.def("patch_tether")
	var fx: Dictionary = d.effect
	var cap_b := float(fx.get("cap_bonus", 0.65))
	return PartDef.Stacking.value("hyperbolic", float(fx.get("per", 0.22)), n, cap_b)


func basalt_cone_damage() -> float:
	var n := part_copies("basalt_ram")
	if n <= 0:
		return 0.0
	var d: Resource = Parts.def("basalt_ram")
	var fx: Dictionary = d.effect
	var add := PartDef.Stacking.value("linear", float(fx.get("per_stack", 0.25)), n - 1, float(d.stack_cap))
	return float(fx.get("damage", 24.0)) * minf(float(fx.get("max_mult", 2.0)), 1.0 + add)


func storm_static_mult() -> float:
	var n := part_copies("storm_capacitor")
	if n <= 0:
		return 0.0
	var d: Resource = Parts.def("storm_capacitor")
	var fx: Dictionary = d.effect
	var frac := PartDef.Stacking.value("hyperbolic", float(fx.get("per_stack", 0.35)), n, float(d.stack_cap))
	return 1.0 + frac * 1.6


func burden_payout(d: Resource, n: int) -> float:
	return d.stack_cap * PartDef.Stacking.value(d.stack_rule, float(d.effect["per"]), burden_count * n, 0.0)


func apply_abilities(player) -> void:
	if player == null or player.get("abilities") == null:
		return
	var abilities = player.abilities
	if player.has_method("set_vault_cooldown_scale"):
		player.set_vault_cooldown_scale(vault_cooldown_scale)
	if player.has_method("set_vault_charges"):
		player.set_vault_charges(1 + vault_charges)
	for slot in SLOTS:
		var s = abilities.slot(slot)
		var base: int = s.max_charges - s.item_charges
		var want: int = clampi(base + int(charges.get(slot, 0)), 1, MAX_CHARGES)
		var before: int = s.max_charges
		abilities.set_max_charges(slot, want)
		s.item_charges = want - base
		if want > before:
			abilities.grant(slot, want - before)
		var scale: float = cooldown_scale.get(slot, 1.0)
		var base_scale: float = s.cooldown_scale / s.item_scale if s.item_scale > 0.0 else 1.0
		abilities.set_cooldown_scale(slot, base_scale * scale)
		s.item_scale = scale


func mass_health(mass: float) -> float:
	if hp_per_mass <= 0.0:
		return 0.0
	return minf(hp_mass_cap, floorf(mass / hp_mass_step) * hp_per_mass)


func reset_stage() -> void:
	for pin_id in _pin_until:
		_clear_buff("item_" + String(pin_id))
	_clear_buff("item_armed_hit")
	_clear_buff("item_rebound_crit")
	_clear_buff("item_brace")
	_clear_buff("item_drone")
	_ready_at = {}
	_armed_hit = 0.0
	if _last_word_pending:
		_last_word_used = false
		_last_word_pending = false
	_pin_until = {}
	_pins.clear()
	_recent_pins.clear()
	_rebounds.clear()
	_ward_used = false
	_brace_until = 0.0
	_drone_until = 0.0
	_domino_marks = {}
	_domino_count = 0
	_domino_serial = 0
	for key in _timers:
		_timers[key] = 0.0


func reset_run() -> void:
	reset_stage()
	_last_word_used = false
	procs = {}
	micro_mutations = {}
	grapple_mutations = {}
	grapple_mutation_ids = {}
	_held_parts = []


func magnet_boost() -> float:
	return _drone_magnet if _clock < _drone_until else 1.0


func tick(delta: float, bus) -> void:
	_clock += delta
	for entry in timed:
		var every: float = entry["def"].effect.get("every", 10.0)
		var t: float = _timers.get(entry["id"], 0.0) + delta
		if t >= every:
			t -= every
			bus.post(Triggers.Commitment.new(Triggers.Kind.TIMED, entry["id"], Triggers.DISCRETE_PROC,
				build.ctx.player.ball_position()))
		_timers[entry["id"]] = t
	_step_pins()
	_step_rebounds()


func _step_rebounds() -> void:
	if _rebounds.is_empty():
		return
	var before := _rebounds.size()
	while not _rebounds.is_empty() and _clock - _rebounds[0] > _rebound_window:
		_rebounds.pop_front()
	if _rebounds.size() == before:
		return
	_sync_rebound_buff()


func _sync_rebound_buff() -> void:
	if _rebounds.is_empty():
		_clear_buff("item_rebound_crit")
		return
	var left := maxf(0.0, _rebound_window - (_clock - _rebounds[-1]))
	_post_buff("item_rebound_crit", {
		"icon": "cat_damage",
		"tone": Palette.COPPER,
		"duration_s": _rebound_window,
		"left_s": left,
		"kind": BuffLedger.KIND_COUNT,
		"stacks": _rebounds.size(),
		"max_stacks": _rebound_need,
	})


func note_pin(victim: Node3D, damage: float) -> void:
	if is_instance_valid(victim):
		_pins.append({"victim": victim, "damage": damage, "at": victim.global_position})
		_recent_pins.append({"victim": victim, "t": _clock})


func resolve(c, draw: float) -> void:
	if c.kind == Triggers.Kind.ON_DAMAGE_TAKEN:
		_soften(c)
	if c.kind == Triggers.Kind.ON_HIT and _armed_hit > 0.0 and c.enemy != null and c.base_proc > 0.0:
		var bonus: float = _armed_hit
		_armed_hit = 0.0
		_last_word_pending = false
		_clear_buff("item_armed_hit")
		build.item_hit(c.enemy, c.amount * bonus, "")
		_count("armed_hit")
	for entry in by_kind.get(c.kind, []):
		if c.kind == Triggers.Kind.TIMED and entry["id"] != c.source:
			continue
		var d: Resource = entry["def"]
		var id: String = entry["id"]
		if _clock < _ready_at.get(id, -1.0):
			continue
		var fx: Dictionary = d.effect
		var key: String = stack_key(fx.get("do", ""))
		if fx.has("chance"):
			var chance: float = stacked(d, "chance", entry["copies"]) * c.base_proc * d.proc_coeff
			if Triggers.roll(draw, c.index, entry["index"]) >= chance:
				continue
		elif c.base_proc * d.proc_coeff <= 0.0:
			continue
		var power: float = stacked(d, key, entry["copies"]) if key != "" and key != "chance" else 0.0
		if _apply(id, d, fx, c, power, draw, entry["index"]):
			_count(id)
			if fx.has("every") and d.trigger != "timed":
				_ready_at[id] = _clock + float(fx["every"])


func _count(id: String) -> void:
	procs[id] = procs.get(id, 0) + 1


func _apply(id: String, d: Resource, fx: Dictionary, c, power: float, draw: float, item_index: int) -> bool:
	var ctx = build.ctx
	var element: String = fx.get("element", d.element)
	match fx.get("do", ""):
		"burden_payout":
			var bonus := burden_payout(d, int(copies.get(id, 0)))
			var weapon_scale: float = build.sheet.mod("weapon_damage")
			if bonus <= 0.0 or weapon_scale <= 0.0 or c.amount <= 0.0 or not is_instance_valid(c.enemy):
				return false
			build.item_hit(c.enemy, c.amount * bonus / weapon_scale, element)
			return true
		"zap":
			var from: Vector3 = c.enemy.global_position if is_instance_valid(c.enemy) else c.at
			var near: Array = build.enemies_near(from, fx.get("reach", 10.0), 2)
			for enemy in near:
				if enemy != c.enemy:
					build.field.zap_line(from, enemy.global_position)
					build.item_hit(enemy, fx.get("damage", 6.0), element)
					return true
			return false
		"burst":
			var at: Vector3 = c.enemy.global_position if is_instance_valid(c.enemy) else c.at
			var damage: float = power if not fx.has("chance") and power > 0.0 else fx.get("damage", 8.0)
			return _burst(at, fx.get("radius", 5.0), damage, element, fx.get("min_impact", 0.0), c)
		"extra_hit":
			if not is_instance_valid(c.enemy):
				return false
			build.item_hit(c.enemy, c.amount * fx.get("mult", 1.0), element)
			return true
		"arm_hit":
			_armed_hit = maxf(_armed_hit, power)
			_post_buff("item_armed_hit", {
				"icon": "cat_damage",
				"tone": Palette.AMBER,
				"duration_s": 0.0,
				"kind": BuffLedger.KIND_COUNT,
				"stacks": 1,
				"max_stacks": 1,
			})
			return true
		"last_word":
			if _last_word_used or ctx.run.hp > ctx.run.max_hp * fx.get("below", 0.25) or not ctx.run.alive():
				return false
			_last_word_used = true
			_last_word_pending = true
			_armed_hit = maxf(_armed_hit, power)
			_post_buff("item_armed_hit", {
				"icon": "cat_damage",
				"tone": Palette.AMBER,
				"duration_s": 0.0,
				"kind": BuffLedger.KIND_COUNT,
				"stacks": 1,
				"max_stacks": 1,
			})
			return true
		"speed":
			return _surge(power, fx.get("max_speed", 45.0), c)
		"dash":
			var dir: Vector3 = ctx.player.planar_velocity()
			if dir.length() < 0.5:
				dir = ctx.aim_forward()
			dir.y = 0.0
			ctx.player.add_external_accel(dir.normalized() * power / _step())
			return true
		"air_jump":
			ctx.player.refresh_air()
			return true
		"grant_charge":
			ctx.player.abilities.grant(fx.get("slot", "movement"))
			return true
		"overcharge":
			_burst(ctx.player.ball_position(), fx.get("radius", 9.0), power * maxf(0.3, c.amount), element, 0.0, c)
			if Triggers.roll(draw, c.index + 3, item_index) < fx.get("refund", 0.0):
				ctx.player.abilities.grant("special")
			return true
		"echo_release":
			return _burst(ctx.player.ball_position(), fx.get("radius", 8.0), fx.get("damage", 16.0) * maxf(0.3, c.amount), element, 0.0, c)
		"pin_bonus", "pin_chain", "domino":
			var pin_window := float(fx.get("window", 1.5))
			_pin_until[id] = _clock + pin_window
			if fx.get("do") == "domino":
				_domino_count = 0
			_post_buff("item_" + id, {
				"icon": "cat_" + d.icon_category,
				"tone": Palette.SAND,
				"duration_s": pin_window,
				"kind": BuffLedger.KIND_TIMER,
				"stacks": 1,
				"max_stacks": 1,
			})
			return true
		"rebound_crit":
			_rebound_window = float(fx.get("window", 4.0))
			_rebound_need = int(fx.get("count", 3))
			_rebounds.append(_clock)
			while not _rebounds.is_empty() and _clock - _rebounds[0] > _rebound_window:
				_rebounds.pop_front()
			if _rebounds.size() < _rebound_need or not is_instance_valid(c.enemy):
				_sync_rebound_buff()
				return false
			_rebounds.clear()
			_clear_buff("item_rebound_crit")
			build.item_hit(c.enemy, c.amount * fx.get("mult", 2.0), element)
			return true
		"rebound_strike":
			if not is_instance_valid(c.enemy):
				return false
			build.item_hit(c.enemy, (BASE_HIT + build.punch_bonus()) * power, element)
			return true
		"relaunch_pin":
			var any := false
			var ball: Vector3 = ctx.player.ball_position()
			for pin in _recent_pins:
				var victim = pin["victim"]
				if _clock - pin["t"] <= fx.get("window", 2.0) and _pinnable(victim) \
						and victim.global_position.distance_to(ball) <= fx.get("radius", 7.0):
					var away: Vector3 = victim.global_position - ball
					away.y = 0.0
					victim.knock(away.normalized() + Vector3.UP * 0.6, fx.get("speed", 10.0) * float(victim.weight))
					any = true
			return any
		"scrap_burst":
			return _scatter(ctx.player.ball_position(), fx.get("radius", 7.0), fx.get("speed", 11.0))
		"return_arc":
			var near: Array = build.enemies_near(ctx.player.ball_position(), fx.get("reach", 12.0), 1)
			if near.is_empty():
				return false
			build.field.zap_line(ctx.player.ball_position(), near[0].global_position)
			build.item_hit(near[0], c.amount * power, "arc")
			return true
		"heal_back":
			if ctx.run.armor_mode:
				return false
			ctx.run.heal(c.amount * fx.get("share", 1.0))
			return true
		"brace":
			if c.kind == Triggers.Kind.ON_LAND and c.amount < fx.get("min_impact", 0.0):
				return false
			var held_share: float = _brace_share if _clock < _brace_until else 0.0
			var brace_window := float(fx.get("window", 1.0))
			_brace_until = _clock + brace_window
			_brace_share = maxf(held_share, power)
			_brace_source = c.enemy.get("kind") if c.kind == Triggers.Kind.ON_REBOUND and is_instance_valid(c.enemy) else ""
			_post_buff("item_brace", {
				"icon": "cat_defense",
				"tone": Palette.STEEL,
				"duration_s": brace_window,
				"kind": BuffLedger.KIND_TIMER,
				"stacks": 1,
				"max_stacks": 1,
			})
			return true
		"floor_hp":
			if ctx.run.armor_mode:
				return false
			var floor_hp: float = ctx.run.max_hp * fx.get("floor", 0.2)
			if _ward_used or not ctx.run.alive() or ctx.run.hp >= floor_hp:
				return false
			_ward_used = true
			ctx.run.heal(floor_hp - ctx.run.hp)
			return true
		"bonus_scrap":
			if not ctx.flow.in_stage():
				return false
			build.scrap.drop(c.at, int(fx.get("amount", 12)), build.loot_rng)
			return true
		"drone":
			var drone_seconds := float(fx.get("seconds", 4.0))
			_drone_until = _clock + drone_seconds
			_drone_magnet = fx.get("magnet", 3.0)
			_post_buff("item_drone", {
				"icon": "cat_utility",
				"tone": Palette.STEEL,
				"duration_s": drone_seconds,
				"kind": BuffLedger.KIND_TIMER,
				"stacks": 1,
				"max_stacks": 1,
			})
			return true
		"ping":
			return _ping(fx.get("target", "beacon"))
		"cloak_extend":
			if ctx.spawner != null and ctx.spawner.has_method("extend_cloak"):
				ctx.spawner.extend_cloak(power)
				return true
			return false
	return false


func brace_share_for(source: String) -> float:
	if _clock < _brace_until and (_brace_source == "" or source == _brace_source):
		return _brace_share
	return 0.0


func deflect_for(_source: String) -> bool:
	_hit_seq += 1
	for entry in by_kind.get(Triggers.Kind.ON_DAMAGE_TAKEN, []):
		var d: Resource = entry["def"]
		if d.effect.get("do", "") != "heal_back" or _clock < _ready_at.get(entry["id"], -1.0):
			continue
		var roll := fposmod(_clock * 7.31 + float(_hit_seq) * Triggers.SPREAD, 1.0)
		if roll < stacked(d, "chance", entry["copies"]) * d.proc_coeff:
			_count(entry["id"])
			return true
	return false


func ward_floor_for(hp_after: float) -> float:
	if _ward_used:
		return hp_after
	for entry in by_kind.get(Triggers.Kind.ON_DAMAGE_TAKEN, []):
		var fx: Dictionary = entry["def"].effect
		if fx.get("do", "") != "floor_hp":
			continue
		var floor_hp: float = build.ctx.run.max_hp * fx.get("floor", 0.2)
		if hp_after >= floor_hp:
			return hp_after
		_ward_used = true
		_count(entry["id"])
		return floor_hp
	return hp_after


func death_save_hull() -> float:
	if not perks.has("death_save") or build.ctx.run.death_save_spent:
		return 0.0
	var floor_share := 0.2
	for part_id in copies:
		var d: Resource = Parts.def(part_id)
		if d != null and d.effect.get("perk", "") == "death_save":
			floor_share = float(d.effect.get("floor", 0.2))
			_count(part_id)
	return maxf(1.0, build.ctx.run.max_hp * floor_share)


func _soften(c) -> void:
	var ctx = build.ctx
	if not ctx.run.alive():
		return
	if ctx.run.armor_mode:
		return
	var share: float = damage_reduction
	if _clock < _brace_until and (_brace_source == "" or c.source == _brace_source):
		share = 1.0 - (1.0 - share) * (1.0 - _brace_share)
	if share > 0.0:
		ctx.run.heal(c.amount * share)


func _burst(at: Vector3, radius: float, damage: float, element: String, min_impact: float, c) -> bool:
	if c.kind == Triggers.Kind.ON_LAND and c.amount < min_impact:
		return false
	var color: Color = Palette.ARC if element == "arc" else (Palette.ICE if element == "frost" else Palette.AMBER)
	build.field.flash_ring(at, radius, color)
	for enemy in build.enemies_near(at, radius, 6):
		build.item_hit(enemy, damage, "")
	if element != "":
		build.field.apply(element, at, "item")
	return true


func _surge(gain: float, cap_speed: float, c) -> bool:
	var ctx = build.ctx
	var v: Vector3 = ctx.player.planar_velocity()
	var speed: float = v.length()
	if speed < 1.0 or speed >= cap_speed:
		return false
	var target: float = minf(cap_speed, speed * (1.0 + gain))
	ctx.player.add_external_accel(v.normalized() * (target - speed) / _step())
	return true


func _scatter(at: Vector3, radius: float, speed: float) -> bool:
	var any := false
	for enemy in build.enemies_near(at, radius, 6):
		if not _pinnable(enemy):
			continue
		var away: Vector3 = enemy.global_position - at
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3.FORWARD
		enemy.knock(away.normalized() + Vector3.UP * 0.3, speed * float(enemy.weight))
		any = true
	return any


func _ping(target: String) -> bool:
	var ctx = build.ctx
	var at := Vector3.INF
	if target == "vault":
		var best := INF
		for node in build.get_tree().get_nodes_in_group("enemy"):
			if node is Node3D and is_instance_valid(node) and node.get("kind") == "vault":
				var dist: float = node.global_position.distance_to(ctx.player.ball_position())
				if dist < best:
					best = dist
					at = node.global_position
	elif ctx.flow.in_stage():
		at = ctx.terrain.beacon_point(ctx.flow.stage())
	if at == Vector3.INF:
		return false
	build.field.flash_ring(at + Vector3.UP * 0.5, PING_RADIUS, Palette.ARC)
	return true


func _step_pins() -> void:
	if _pins.is_empty():
		return
	var pins := _pins
	_pins = []
	while not _recent_pins.is_empty() and _clock - _recent_pins[0]["t"] > 3.0:
		_recent_pins.pop_front()
	for pin in pins:
		var victim = pin["victim"]
		if not is_instance_valid(victim):
			continue
		for id in _pin_until:
			if _clock > _pin_until[id]:
				continue
			var d: Resource = Parts.def(id)
			var n: int = copies.get(id, 0)
			if d == null or n == 0:
				continue
			match d.effect.get("do", ""):
				"pin_bonus":
					build.item_hit(victim, pin["damage"] * stacked(d, "bonus", n), "")
					_count(id)
				"pin_chain":
					var pushed := 0
					var limit: int = int(stacked(d, "count", n))
					for other in build.enemies_near(pin["at"], 5.0, limit + 1):
						if other == victim or not _pinnable(other) or pushed >= limit:
							continue
						var away: Vector3 = other.global_position - pin["at"]
						away.y = 0.0
						other.knock(away.normalized() + Vector3.UP * 0.2, d.effect.get("speed", 9.0) * float(other.weight))
						pushed += 1
					if pushed > 0:
						_count(id)
				"domino":
					_domino(id, d, n, victim)


func _domino(id: String, d: Resource, n: int, victim: Node3D) -> void:
	var key: int = victim.get_instance_id()
	var mark: Dictionary = _domino_marks.get(key, {})
	var mask: int = mark.get("mask", 0) if _clock - float(mark.get("t", -9.0)) < 1.0 else 0
	var bit: int = Triggers.chain_bit("domino")
	if not Triggers.chain_allows(mask, bit):
		return
	if _domino_count >= DOMINO_MAX_PER_WINDOW:
		return
	var roll: float = fposmod(_clock * 7.31 + float(_domino_serial % 997) * Triggers.SPREAD, 1.0)
	_domino_serial += 1
	if roll >= stacked(d, "chance", n):
		return
	var near: Array = build.enemies_near(victim.global_position, 8.0, 2)
	for other in near:
		if other == victim or not _pinnable(other):
			continue
		var to: Vector3 = other.global_position - victim.global_position
		to.y = 0.0
		victim.knock(to.normalized() + Vector3.UP * 0.2, d.effect.get("speed", 10.0) * float(victim.weight))
		_domino_marks[other.get_instance_id()] = {"mask": Triggers.chain_add(mask, bit), "t": _clock}
		_domino_count += 1
		_count(id)
		return


static func _pinnable(enemy) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("knock") and enemy.has_method("is_dead") and not enemy.is_dead()


func _buffs():
	if build == null:
		return null
	var ctx = build.get("ctx")
	return ctx.get("buffs") if ctx != null else null


func _post_buff(id: String, spec: Dictionary) -> void:
	var ledger = _buffs()
	if ledger != null:
		ledger.post(id, spec)


func _clear_buff(id: String) -> void:
	var ledger = _buffs()
	if ledger != null:
		ledger.clear_id(id)


func _step() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)
