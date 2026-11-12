extends "res://src/world/device.gd"

const Altar := preload("res://src/world/ambush_altar.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const HullMark := preload("res://src/world/hull_mark.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")

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

var kind := "trade_chest"
var offer := {}
var last := {}


static func pays(device_kind: String) -> Array:
	return KINDS[device_kind]["pays"]


static func floor_hp(run) -> float:
	return ceilf(run.max_hp * FLOOR_SHARE)


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
	if not KINDS.has(kind):
		kind = "trade_chest"
	var device_id := String(spec_ref.get("id", kind))
	var rng: RandomNumberGenerator = system_ref.luck(device_id)
	var marks: bool = ctx_ref.tuning != null and ctx_ref.tuning.option("marked_hull") == "on"
	offer = make_offer(kind, int(spec_ref.get("tier", 1)), String(spec_ref.get("pay", pays(kind)[0])), ctx_ref.run, rng, marks)
	super.setup(ctx_ref, system_ref, spec_ref)


func build() -> void:
	var tier: int = offer.get("tier", 1)
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


func reach_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func ready_now() -> bool:
	return not spent and can_take(offer, ctx.run)


# Not ready on a health price: how close the hull is to paying and keeping the floor.
func gauge() -> float:
	if spent or String(offer.get("cost_kind", "")) != "hp":
		return 0.0
	var need: float = float(offer["cost"]) + float(offer["floor"])
	return clampf(ctx.run.hp / need, 0.0, 1.0)


func words() -> String:
	return offer_words(offer)


func fire() -> bool:
	last = take(offer, ctx.run, reach_point())
	spent = bool(last.get("ok", false)) or spent
	return true
