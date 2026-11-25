extends "res://src/world/device.gd"

const Altar := preload("res://src/world/ambush_altar.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const HullMark := preload("res://src/world/hull_mark.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# Stake devices (W13-INTEGRATION-3 SI2): a trade chest, a blood shrine and a healing ward.
# Each states what is paid and what is won on its prompt before E commits, and none takes
# scrap. A placement spec names the kind (`device`), the tier (1 to 3) and, for a chest,
# the payment (`pay`: "health" or "cogs"); a pocket that wants a choice stands three side
# by side, so every device is one readable trade a rolling ball can take with a hold.
#
#   trade_chest   pays a part of power tier 1, 2 or 3 for 25, 50 or 75% of max health, or
#                 for the off-shelf cogs price of that tier (Fabricators.off_shelf_price,
#                 without the held-parts growth).
#   blood_shrine  pays scrap for 25, 50 or 75% of max health at SCRAP_PER_HP_PAID.
#   healing_ward  pays 1, 2 or 3 bonus cores for a heal of 25, 50 or 75% of max health,
#                 its ring wider at each tier.
#
# No option can kill: a health price is open only while the hull keeps the stated floor
# (FLOOR_SHARE of max health when offered, in HP, carried on the offer) after paying, and
# the gauge round the glyph fills toward it.
# One purchase per device per stage: the stage rebuilds its devices. A chest's part is
# drawn from the interact system's stream for this device, run and stage (as bet_crate.gd
# draws its luck), so a stage restart rebuilds the same offer and fishing pays nothing.
# The price never rises: it is a pure function of the tier and the hull's max.
#
# The offer is a plain Dictionary the static model below builds, checks and settles, so
# the device and the sweep in tests/stake_devices_test.gd read the same numbers.
#
# Marked hull (hull_mark.gd, `--marked-hull=on`): a health price also marks that much max
# health until the next Warden break, and the offer says so ("marks": true, and the verb is
# "Weld": the hull bar shows the mark as a welded plate edged in the Warden's colour). A ward's
# heal lifts any mark before it heals.

const KINDS := {
	"trade_chest": {"verb": "Trade", "pays": ["health", "cogs"], "wins": "part"},
	"blood_shrine": {"verb": "Bleed", "pays": ["health"], "wins": "scrap"},
	"healing_ward": {"verb": "Mend", "pays": ["cores"], "wins": "heal"},
}
const TIERS := [1, 2, 3]
# Start values (comps/gunfire/run-pacing-and-economy.md:91, the trade chest's fixed
# visible shares): the share of max health each tier costs, or the ward heals.
const HEALTH_SHARES := [0.25, 0.5, 0.75]
# Start value: the hull a health price must leave, as a share of max health.
const FLOOR_SHARE := 0.1
# Start value (comps/ror2/events-and-objectives.md:79, the blood shrine's ratio): scrap
# paid per health point given.
const SCRAP_PER_HP_PAID := 0.5
# Start values (comps/ror2/events-and-objectives.md:80, base + bonus x (tier - 1)): the
# ward's ring in metres. Drawn only; the heal lands at once.
const WARD_RADIUS_BASE := 3.0
const WARD_RADIUS_BONUS := 1.5

# Whose trade spot a device stands in (trade_pockets.gd devices, ruling ci); a device placed with no owner keeps the
# plain greybox. The two bodies face each other in meaning: the gamble is keeper work, the kindness is the works'.
#   gamble    the keeper's gamble: a salvaged plate bolted on with brass heads, its odds chalked on the face in tally
#             strokes. Hand-made: the old body with the hands' marks on it.
#   kindness  the foreman's kindness: one cast piece, seamless, dull petrol enamel with crisp bevels and no fastener,
#             and World 1's one purple (Palette.KINDNESS, hue 315) as its glow. Nothing else in World 1 is that hue.
# Each body is one cached mesh in one shared material (RecipeProps.piece), and its glow or its marks one more.
const OWNERS := ["gamble", "kindness"]
# The bus fact the kindness sends the first time it makes its offer (the ball reaches it and its price comes up):
# world_fact(KINDNESS_FACT, reach point). The Foreman's voice hooks it, and since W46-A1 it has its own WORLD_ROWS row, so
# the bus plays its sound; the device sounds KINDNESS_CHIME itself only while the fact has no row.
const KINDNESS_FACT := "kindness_offered"
# The offer's sound: the pilot's own motif played back one note wrong (sfx_bank.gd mind_wrong_<motif>; STORY-MAP, the
# foreman's kindness row), and this device's glow swells with it to KINDNESS_PULSE and settles back over PULSE_S.
const KINDNESS_CHIME := "mind_wrong_"
const KINDNESS_GLOW := 1.0
const KINDNESS_PULSE := 2.6
const PULSE_S := 0.6

# RoR2 Challenge Stake Stacking (W50-ISAAC-ECONOMY, Shrine of the Mountain pattern):
# Stackable per-stage challenge stakes with a bounded cap and +1 extra Warden gate roll per
# stack. Per rulings al/cu, stacks raise aggression and pack pressure ONLY — zero enemy HP
# inflation (CHALLENGE_HP_MULT is strictly 1.0).
const CHALLENGE_DEVICE := "challenge_stake"
const CHALLENGE_STAKE_CAP := 3
const CHALLENGE_GATE_ROLLS_PER_STACK := 1
const CHALLENGE_AGGRESSION_PER_STACK := 0.15
const CHALLENGE_PACK_EXTRA_PER_STACK := 1
const CHALLENGE_HP_MULT := 1.0
const CHALLENGE_META := "w50_challenge_stakes"

var kind := "trade_chest"
var offer := {}
var last := {}
var spot_owner := ""
var _offered := false
var _pulse: Tween


static func pays(device_kind: String) -> Array:
	return KINDS[device_kind]["pays"]


static func floor_hp(run) -> float:
	return ceilf(run.max_hp * FLOOR_SHARE)


# ---- RoR2 Challenge Stake Stacking (bounded cap, zero enemy HP inflation) -------------

static func challenge_state(run) -> Dictionary:
	if run == null:
		return {"stage": 0, "stacks": 0, "cap": CHALLENGE_STAKE_CAP}
	var cur_stage := int(run.stage)
	var raw = run.get_meta(CHALLENGE_META) if run.has_meta(CHALLENGE_META) else null
	if not (raw is Dictionary) or int(raw.get("stage", -1)) != cur_stage:
		raw = {"stage": cur_stage, "stacks": 0, "cap": CHALLENGE_STAKE_CAP}
		run.set_meta(CHALLENGE_META, raw)
	return raw


static func challenge_stacks(run) -> int:
	return int(challenge_state(run).get("stacks", 0))


static func can_stack_challenge(run) -> bool:
	return run != null and run.alive() and challenge_stacks(run) < CHALLENGE_STAKE_CAP


static func challenge_modifiers(run) -> Dictionary:
	var stacks := challenge_stacks(run)
	return {
		"stacks": stacks,
		"cap": CHALLENGE_STAKE_CAP,
		"gate_rolls_bonus": stacks * CHALLENGE_GATE_ROLLS_PER_STACK,
		"aggression_mult": 1.0 + float(stacks) * CHALLENGE_AGGRESSION_PER_STACK,
		"pack_pressure_bonus": stacks * CHALLENGE_PACK_EXTRA_PER_STACK,
		"hp_mult": CHALLENGE_HP_MULT,
	}


static func warden_gate_bonus_rolls(run) -> int:
	return challenge_stacks(run) * CHALLENGE_GATE_ROLLS_PER_STACK


static func stack_challenge(run, at := Vector3.ZERO) -> Dictionary:
	if run == null or not run.alive():
		return {"ok": false, "reason": "dead", "stacks": challenge_stacks(run), "cap": CHALLENGE_STAKE_CAP, "hp_mult": CHALLENGE_HP_MULT}
	var st := challenge_state(run)
	var cur := int(st.get("stacks", 0))
	if cur >= CHALLENGE_STAKE_CAP:
		return challenge_modifiers(run).merged({"ok": false, "reason": "capped", "at": at}, true)
	st["stacks"] = cur + 1
	return challenge_modifiers(run).merged({"ok": true, "reason": "ok", "at": at}, true)


static func reset_challenge_stakes(run) -> void:
	if run == null:
		return
	run.set_meta(CHALLENGE_META, {"stage": int(run.stage), "stacks": 0, "cap": CHALLENGE_STAKE_CAP})


# The one trade a device of this kind and tier makes, before commitment. `rng` is the
# device's luck stream; only a chest draws from it.
static func make_offer(device_kind: String, tier: int, pay: String, run, rng: RandomNumberGenerator, marks := false) -> Dictionary:
	var row: Dictionary = KINDS[device_kind]
	tier = clampi(tier, TIERS[0], TIERS[-1])
	if not pay in row["pays"]:
		pay = String(row["pays"][0])
	var share: float = HEALTH_SHARES[tier - 1]
	var o := {"kind": device_kind, "tier": tier, "pay": pay, "verb": row["verb"],
		"win_kind": row["wins"], "floor": int(floor_hp(run))}
	match pay:
		"health":
			o["cost_kind"] = "hp"
			o["cost"] = int(round(run.max_hp * share))
			if marks:
				# The price welds a plate over the top of the hull bar (gauge.gd set_cap), so the
				# verb names the weld and the words stay inside PROMPT_WORDS.
				o["marks"] = true
				o["verb"] = "Weld"
		"cores":
			o["cost_kind"] = "cores"
			o["cost"] = tier
	match String(row["wins"]):
		"part":
			o["win"] = _pick_part(tier, run, rng)
			o["part_tier"] = tier
			if pay == "cogs":
				o["cost_kind"] = "cogs"
				# Off the shelf: 10, 16 and 26 cogs (Fabricators.OFF_SHELF; docs/systems-audit/economy/README.md).
				o["cost"] = Fabricators.off_shelf_price(tier, 0)
		"scrap":
			o["win"] = int(round(float(o["cost"]) * SCRAP_PER_HP_PAID))
		"heal":
			o["win"] = int(round(run.max_hp * share))
			o["radius"] = WARD_RADIUS_BASE + WARD_RADIUS_BONUS * (tier - 1)
	return o


# A part of exactly this power tier (Parts: tier 1 +10 to 15%, 2 +25%, 3 +50%) the class
# may be offered, one it does not hold when it can, drawn from the device's stream. A part held
# at its top level (SG15) would give nothing, so it is never the win.
static func _pick_part(tier: int, run, rng: RandomNumberGenerator) -> String:
	var pool: Array = Parts.offer_pool(run.class_id(), ItemGen.RARITIES).filter(
		func(key): return Parts.def(key) != null and Parts.def(key).tier == tier and not Parts.maxed(key, run.parts))
	pool.sort()
	var fresh: Array = pool.filter(func(key): return not key in run.parts)
	if not fresh.is_empty():
		pool = fresh
	return String(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else ""


static func can_take(o: Dictionary, run) -> bool:
	if o.is_empty() or not run.alive():
		return false
	if String(o["win_kind"]) == "part" and String(o["win"]) == "":
		return false
	# A heal that would restore no health and lift no mark takes no payment.
	if String(o["win_kind"]) == "heal" and run.hp >= run.max_hp and HullMark.held(run) <= 0.0:
		return false
	var cost: int = o["cost"]
	match String(o["cost_kind"]):
		"hp":
			return run.hp - float(cost) >= float(o["floor"]) and float(o["floor"]) > 0.0
		"cogs":
			return run.cogs >= cost
		"cores":
			return run.bonus_cores >= cost
	return false


# Charges exactly the stated cost and pays the stated win, or changes nothing. run_state
# has no health or core payment mutator yet, so the hull and the cores are written here;
# a health price is a payment, not a hit, so it skips mitigation, scrap and hit facts.
static func take(o: Dictionary, run, at: Vector3) -> Dictionary:
	if not can_take(o, run):
		return {"ok": false, "charged": 0}
	var cost: int = o["cost"]
	match String(o["cost_kind"]):
		"hp":
			run.hp -= float(cost)
			# Paid health waits out the regen delay like a hit, so regen does not refund it at once.
			run.since_damage = 0.0
			if o.get("marks", false):
				HullMark.stake(run, float(cost))
		"cogs":
			if not run.spend_cogs(cost):
				return {"ok": false, "charged": 0}
		"cores":
			run.bonus_cores -= cost
	match String(o["win_kind"]):
		"part":
			run.add_part(String(o["win"]), String(o["kind"]))
		"scrap":
			run.add_scrap(int(o["win"]), at)
		"heal":
			HullMark.lift(run)
			run.heal(float(o["win"]))
	return {"ok": true, "charged": cost, "won": o["win"]}


# The prompt: the verb, the price in HUD units, then the win, PROMPT_WORDS words at most.
static func offer_words(o: Dictionary) -> String:
	var cost: int = o["cost"]
	var price: String
	match String(o["cost_kind"]):
		"hp":
			price = "%d HP" % cost
		"cogs":
			price = "%d cogs" % cost
		_:
			price = "%d %s" % [cost, "core" if cost == 1 else "cores"]
	var win: String
	match String(o["win_kind"]):
		"part":
			win = "tier-%d part" % int(o["part_tier"])
		"scrap":
			win = "%d scrap" % int(o["win"])
		_:
			win = "%d HP" % int(o["win"])
	return "%s %s: %s" % [o["verb"], price, win]


func _init() -> void:
	family = "bet"


func setup(ctx_ref, system_ref, spec_ref: Dictionary) -> void:
	kind = String(spec_ref.get("device", kind))
	if kind == CHALLENGE_DEVICE:
		spot_owner = ""
		offer = {"kind": CHALLENGE_DEVICE, "verb": "Raise", "cost_kind": "stake", "cost": 1, "win_kind": "warden_roll", "win": 1}
		super.setup(ctx_ref, system_ref, spec_ref)
		return
	if not KINDS.has(kind):
		kind = "trade_chest"
	spot_owner = String(spec_ref.get("owner", ""))
	if not spot_owner in OWNERS:
		spot_owner = ""
	var device_id := String(spec_ref.get("id", kind))
	var rng: RandomNumberGenerator = system_ref.luck(device_id)
	var marks: bool = ctx_ref.tuning != null and ctx_ref.tuning.option("marked_hull") == "on"
	offer = make_offer(kind, int(spec_ref.get("tier", 1)), String(spec_ref.get("pay", pays(kind)[0])), ctx_ref.run, rng, marks)
	super.setup(ctx_ref, system_ref, spec_ref)


func build() -> void:
	var tier: int = offer.get("tier", 1)
	if spot_owner == "kindness":
		_build_kindness(tier)
		return
	match kind:
		"blood_shrine":
			box(Vector3(1.6, 2.4, 1.6), Vector3.UP * 1.2, Altar.finish(Palette.RUST), true)
			cylinder(0.5, 0.3, Vector3.UP * 2.55, Palette.solid(Palette.HAZARD, 0.9))
		"healing_ward":
			cylinder(0.35, 2.8, Vector3.UP * 1.4, Altar.finish(Palette.BRASS))
			cylinder(0.6, 0.25, Vector3.UP * 2.9, Palette.solid(Palette.ARC, 0.9))
			ground_ring(float(offer.get("radius", WARD_RADIUS_BASE)), Palette.ARC)
		_:
			box(Vector3(2.2, 1.3, 1.5), Vector3.UP * 0.65, Altar.finish(Palette.VERDIGRIS), true)
			box(Vector3(2.3, 0.3, 1.6), Vector3.UP * 1.45, Palette.solid(Palette.COPPER))
	# One brass stud per tier on the front face, so the stake reads before the words.
	for i in tier:
		box(Vector3(0.22, 0.22, 0.1), Vector3(-0.35 * (tier - 1) * 0.5 + 0.35 * i, 1.0, 0.85), Palette.solid(Palette.BRASS))
	if spot_owner == "gamble":
		_dress(gamble_marks_mesh(kind, "bolts"), bolt_material(), "GambleBolts")
		_dress(gamble_marks_mesh(kind, "chalk"), chalk_material(), "GambleChalk")


func reach_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func ready_now() -> bool:
	if kind == CHALLENGE_DEVICE:
		return not spent and can_stack_challenge(ctx.run)
	return not spent and can_take(offer, ctx.run)


# Not ready on a health price: how close the hull is to paying and keeping the floor.
func gauge() -> float:
	if spent or String(offer.get("cost_kind", "")) != "hp":
		return 0.0
	var need: float = float(offer["cost"]) + float(offer["floor"])
	return clampf(ctx.run.hp / need, 0.0, 1.0)


func words() -> String:
	if kind == CHALLENGE_DEVICE:
		return "Raise stake: +1 Warden roll"
	return offer_words(offer)


func fire() -> bool:
	if kind == CHALLENGE_DEVICE:
		last = stack_challenge(ctx.run, reach_point())
		spent = bool(last.get("ok", false)) or spent
		return true
	last = take(offer, ctx.run, reach_point())
	spent = bool(last.get("ok", false)) or spent
	return true


# The ball has reached the device and its price is up. The kindness makes its offer once: the fact on the bus, the
# chime, the glow's swell.
func show_prompt(targeted: bool) -> void:
	super.show_prompt(targeted)
	if targeted and spot_owner == "kindness" and not _offered and not spent:
		_offered = true
		_offer_made()


func _offer_made() -> void:
	var at := reach_point()
	if ctx != null and ctx.get("events") != null:
		ctx.events.world_fact.emit(KINDNESS_FACT, at)
	var motif := ""
	if ctx != null and ctx.run != null and ctx.run.class_def != null:
		motif = String(ctx.run.class_def.motif)
	var audio = _audio()
	if EventKinds.world_row(KINDNESS_FACT).is_empty() and audio != null and SfxBank.has_recipe(KINDNESS_CHIME + motif):
		audio.play_at("world_fact", at, 0.0, 1.0, "SFX", KINDNESS_CHIME + motif)
	_swell()


# The swell lights this device's own copy of the glow, so the shared material never moves and a second kindness in the
# pocket swells on its own; the copy hands back to the shared material when it settles.
func _swell() -> void:
	var view := get_node_or_null("KindnessGlow") as MeshInstance3D
	if view == null:
		return
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	var own := glow_material().duplicate() as StandardMaterial3D
	view.material_override = own
	_pulse = create_tween()
	_pulse.tween_property(own, "emission_energy_multiplier", KINDNESS_PULSE, PULSE_S * 0.25).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(own, "emission_energy_multiplier", KINDNESS_GLOW, PULSE_S * 0.75).set_ease(Tween.EASE_IN)
	_pulse.finished.connect(func(): view.material_override = glow_material())


func _audio():
	var root = ctx.get("root") if ctx != null else null
	return root.audio() if root != null and root.has_method("audio") else null


func offered() -> bool:
	return _offered


# --- the bodies ---

# The kindness: the cast body, its purple glow (the slot lens, the seam and one pip per tier; a ward's heal ring), and
# the chest's solid, the same box the greybox chest stood on, so the ball meets it where it always did.
func _build_kindness(tier: int) -> void:
	var radius := float(offer.get("radius", WARD_RADIUS_BASE)) if kind == "healing_ward" else 0.0
	_dress(kindness_mesh(kind), cast_material(), "KindnessBody")
	var glow := _dress(kindness_glow_mesh(kind, tier, radius), glow_material(), "KindnessGlow")
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind != "healing_ward":
		var body := StaticBody3D.new()
		body.name = "KindnessSolid"
		var shape := CollisionShape3D.new()
		var size := BoxShape3D.new()
		size.size = Vector3(2.2, 1.3, 1.5)
		shape.shape = size
		body.add_child(shape)
		body.position = Vector3.UP * 0.65
		add_child(body)


func _dress(mesh: Mesh, material: Material, node_name: String) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = node_name
	view.mesh = mesh
	view.material_override = material
	add_child(view)
	return view


# The cast body of a kind (a ward is a pillar, a chest or a shrine a kiosk), in the device's frame, +Z its face.
static func kindness_mesh(device_kind: String) -> ArrayMesh:
	var pillar := device_kind == "healing_ward"
	return RecipeProps.piece("kindness_body_" + ("pillar" if pillar else "kiosk"), func(st: SurfaceTool):
		var foot := Color(0.78, 0.78, 0.78)
		if pillar:
			RecipeProps.add_hull(st, RecipeProps.prism(Vector3.ZERO, 8, 0.78, 0.72, 0.0, 0.18, 0.05), foot)
			RecipeProps.add_hull(st, RecipeProps.prism(Vector3.ZERO, 8, 0.46, 0.33, 0.18, 2.55, 0.0))
			RecipeProps.add_hull(st, RecipeProps.prism(Vector3.ZERO, 8, 0.42, 0.2, 2.65, 2.98, 0.09))
		else:
			RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-1.22, 0.0, -0.87), Vector3(1.22, 0.14, 0.87), 0.05), foot)
			RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-1.1, 0.14, -0.75), Vector3(1.1, 1.3, 0.75), 0.11, 0.1))
			RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-0.84, 1.33, -0.5), Vector3(0.84, 1.64, 0.5), 0.12, 0.09)))


# The glow: on a kiosk the slot lens across its face, the seam round its crown and the tier pips on the crown's face;
# on a pillar the band under its cap, the pips down its face and the heal ring on the ground at radius.
static func kindness_glow_mesh(device_kind: String, tier: int, radius: float) -> ArrayMesh:
	var pillar := device_kind == "healing_ward"
	var key := "kindness_glow_%s_%d_%.2f" % ["pillar" if pillar else "kiosk", tier, radius]
	return RecipeProps.piece(key, func(st: SurfaceTool):
		if pillar:
			RecipeProps.add_hull(st, RecipeProps.prism(Vector3.ZERO, 8, 0.36, 0.36, 2.55, 2.65))
			# The pillar's face leans in 0.13 m over its 2.37 m rise.
			var lean := atan2(0.13, 2.37)
			for i in tier:
				var y := 1.75 - 0.3 * i
				var face := 0.46 - 0.13 * (y - 0.18) / 2.37
				_lens(st, Vector3(0.0, y, face * cos(PI / 8.0)), Vector3(0.16, 0.16, 0.04), lean)
			_ring(st, radius, 0.16, 0.03, 48)
		else:
			# The body's face leans in 0.1 m over its 1.16 m rise; the crown's 0.09 m over 0.31 m.
			var lean := atan2(0.1, 1.16)
			_lens(st, Vector3(0.0, 0.92, 0.75 - 0.1 * (0.92 - 0.14) / 1.16), Vector3(1.5, 0.11, 0.04), lean)
			RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-0.92, 1.3, -0.58), Vector3(0.92, 1.34, 0.58), 0.02))
			var crown := atan2(0.09, 0.31)
			for i in tier:
				var x := -0.2 * (tier - 1) * 0.5 + 0.2 * i
				_lens(st, Vector3(x, 1.49, 0.5 - 0.09 * (1.49 - 1.33) / 0.31), Vector3(0.11, 0.11, 0.04), crown))


# A thin glowing slab centred at `at` on a face that leans back by lean radians, standing proud of it by half its depth.
static func _lens(st: SurfaceTool, at: Vector3, size: Vector3, lean: float) -> void:
	var xf := Transform3D(Basis(Vector3.RIGHT, -lean), at)
	RecipeProps.add_hull(st, RecipeProps.bevel_box(-size * 0.5, size * 0.5, minf(size.x, size.y) * 0.2), Color.WHITE, xf)


# A flat ring on the ground: radius r at its middle, width w, y up, in segments quads facing up.
static func _ring(st: SurfaceTool, r: float, w: float, y: float, segments: int) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var quad := [Vector3(cos(a0) * (r - w * 0.5), y, sin(a0) * (r - w * 0.5)), Vector3(cos(a0) * (r + w * 0.5), y, sin(a0) * (r + w * 0.5)),
			Vector3(cos(a1) * (r + w * 0.5), y, sin(a1) * (r + w * 0.5)), Vector3(cos(a1) * (r - w * 0.5), y, sin(a1) * (r - w * 0.5))]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k])


# The gamble's hands' marks on the greybox body of a kind: "bolts" (brass heads at the plate's corners) or "chalk"
# (a five-bar tally and two strokes of odds on its face).
static func gamble_marks_mesh(device_kind: String, marks: String) -> ArrayMesh:
	var shrine := device_kind == "blood_shrine"
	# The greybox face: half width, top, front z (a shrine 1.6 by 2.4 by 1.6, a chest 2.2 by 1.3 by 1.5).
	var half := 0.8 if shrine else 1.1
	var top := 2.4 if shrine else 1.3
	var front := 0.8 if shrine else 0.75
	return RecipeProps.piece("gamble_%s_%s" % [marks, "shrine" if shrine else "chest"], func(st: SurfaceTool):
		if marks == "bolts":
			var face_up := Basis(Vector3.RIGHT, PI * 0.5)
			var side_up := Basis(Vector3.BACK, -PI * 0.5)
			for y in [0.16, top - 0.16]:
				for sx in [-1.0, 1.0]:
					RecipeProps.add_hull(st, RecipeProps.prism(Vector3.ZERO, 6, 0.065, 0.055, 0.0, 0.045, 0.012), Color.WHITE,
						Transform3D(face_up, Vector3(sx * (half - 0.15), y, front)))
					for sz in [-1.0, 1.0]:
						RecipeProps.add_hull(st, RecipeProps.prism(Vector3.ZERO, 6, 0.065, 0.055, 0.0, 0.045, 0.012), Color.WHITE,
							Transform3D(side_up.rotated(Vector3.UP, 0.0 if sx > 0.0 else PI), Vector3(sx * half, y, sz * (front - 0.15))))
		else:
			# Chalk strokes, each a little off true as a hand draws them; the same every time.
			var base := Vector3(-half * 0.45, 0.62 if shrine else 0.34, front + 0.006)
			var strokes := [[0.0, 0.0, 0.03, 0.34], [0.09, 0.01, 0.1, 0.35], [0.18, 0.0, 0.17, 0.33], [0.27, 0.02, 0.29, 0.36],
				[-0.05, 0.06, 0.34, 0.27], [0.48, 0.03, 0.5, 0.34], [0.57, 0.02, 0.56, 0.33], [-0.04, -0.1, 0.62, -0.08]]
			for s in strokes:
				var a: Vector3 = base + Vector3(s[0], s[1], 0.0)
				var b: Vector3 = base + Vector3(s[2], s[3], 0.0)
				var across := (b - a).cross(Vector3.BACK).normalized() * 0.018
				# Clockwise seen from the face (Godot's front), so the strokes are not culled.
				for p in [a - across, b + across, a + across, a - across, b - across, b + across]:
					st.set_color(Color.WHITE)
					st.set_normal(Vector3.BACK)
					st.add_vertex(p))


# --- the shared materials: one each, so every body of a kind draws in the same material ---

static var _cast: StandardMaterial3D
static var _glow: StandardMaterial3D
static var _bolt: StandardMaterial3D
static var _chalk: StandardMaterial3D


# Tests share one engine: drop the shared materials, so the next body builds them fresh at rest.
static func reset_for_tests() -> void:
	_cast = null
	_glow = null
	_bolt = null
	_chalk = null


# Cast enamel: the old works' dull petrol (Roster's ancient enamel), satin, a little metal; the foot a shade darker
# through its vertex colour.
static func cast_material() -> StandardMaterial3D:
	if _cast == null:
		_cast = StandardMaterial3D.new()
		_cast.resource_name = "kindness_cast"
		_cast.albedo_color = Palette.VERDIGRIS
		_cast.vertex_color_use_as_albedo = true
		_cast.roughness = 0.38
		_cast.metallic = 0.35
	return _cast


# The one purple: a flat glow in Palette.KINDNESS, its albedo the same hue darker so it reads purple lit or not.
static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.resource_name = "kindness_glow"
		_glow.albedo_color = Color(Palette.KINDNESS * 0.6, 1.0)
		_glow.roughness = 0.5
		_glow.emission_enabled = true
		_glow.emission = Palette.KINDNESS
		_glow.emission_energy_multiplier = KINDNESS_GLOW
	return _glow


static func bolt_material() -> StandardMaterial3D:
	if _bolt == null:
		_bolt = Palette.solid(Palette.BRASS, 0.0, false)
		_bolt.resource_name = "gamble_bolt"
	return _bolt


# Chalk: ledger cream, dry and matt, with a little light of its own so the strokes read in a pocket's shade.
static func chalk_material() -> StandardMaterial3D:
	if _chalk == null:
		_chalk = StandardMaterial3D.new()
		_chalk.resource_name = "gamble_chalk"
		_chalk.albedo_color = Palette.LEDGER_CREAM
		_chalk.roughness = 1.0
		_chalk.emission_enabled = true
		_chalk.emission = Palette.LEDGER_CREAM
		_chalk.emission_energy_multiplier = 0.25
	return _chalk
