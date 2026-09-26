extends Resource

# One part, as data (TADR-008). A part never holds run state: the run's part list says
# how many copies are held, and build_sheet.gd folds every held copy into one derived
# sheet. A new value is a row edit in parts.gd; a new kind of effect is a code change.

# Rarity is set by where a part comes from (DEMO-SPEC): gates offer common and
# uncommon (higher with bonus cores), fabricators uncommon, vaults rare, won events
# rare_plus. It is shown twice, as a colour and as a topper shape, so colour never
# carries it alone.
const RARITIES := ["common", "uncommon", "rare", "rare_plus"]
# The tag vocabulary. Every part carries one or two; named synergies are tag pairs, so
# a combination makes sense before you try it.
const TAGS := ["frost", "arc", "kinetic", "split", "spiral", "chain", "anchor", "speed", "mass"]

@export var id := ""
@export var display_name := ""
# One line a player can read at speed from 30 m away.
@export var text := ""
# What the part makes you do, as a short action ("Split shots into a cross").
@export var verb := ""
# Flat per-hit weapon damage it adds, before the weapon multipliers; may be 0.
@export var punch := 0.0
@export var tags: Array = []
@export var rarity := "common"
# 1 modest, 2 strong, 3 run-defining. Later stages weight offers toward higher tiers.
@export var tier := 1
# weapon | pattern | mobility | class | stat | milestone: picks the hardware shape the
# ball grows for this part and the family glyph on its gate.
@export var family := "stat"
# Only this class is offered the part; "" means any class.
@export var class_id := ""
# A won event grants it (milestone_won). Only a gate overcharged by two or more bonus
# cores may also offer it; fabricators and vaults never do.
@export var milestone_only := false
# Multipliers per knob, applied through tuning.set_mod. Keys are Tuning.SPECS keys for
# movement, or the weapon keys in SEAMS.md (weapon_damage, weapon_rate, ...), which
# combat reads with tuning.mod(key).
@export var mods := {}
# Scales the shared boost and dash cooldown; 1.0 leaves it alone.
@export var cooldown_scale := 1.0
# Weapon-pattern transformer levels this part adds, pattern id to levels.
@export var patterns := {}
# Element triggers: which element an action applies. Keys: dash, slam, roll_on_water.
@export var elements := {}
# Scrap magnet reach multiplier and kill-scrap multiplier.
@export var magnet := 1.0
@export var kill_scrap := 1.0
@export var max_hp_bonus := 0.0


static func from_row(row_id: String, row: Dictionary) -> Resource:
	var def: Resource = load("res://src/build/part_def.gd").new()
	def.id = row_id
	def.display_name = row.get("name", row_id)
	def.text = row.get("text", "")
	def.verb = row.get("verb", "")
	def.punch = row.get("punch", 0.0)
	def.tags = row.get("tags", [])
	def.rarity = row.get("rarity", "common")
	def.tier = row.get("tier", 1)
	def.family = row.get("family", "stat")
	def.class_id = row.get("class_id", "")
	def.milestone_only = row.get("milestone_only", false)
	def.mods = row.get("mods", {})
	def.cooldown_scale = row.get("cooldown_scale", 1.0)
	def.patterns = row.get("patterns", {})
	def.elements = row.get("elements", {})
	def.magnet = row.get("magnet", 1.0)
	def.kill_scrap = row.get("kill_scrap", 1.0)
	def.max_hp_bonus = row.get("max_hp_bonus", 0.0)
	return def


# True when the part only scales numbers: no punch, pattern, element or behaviour. Only
# a common part may be this plain (DEMO-SPEC catalogue rule).
func percentage_only() -> bool:
	return punch <= 0.0 and patterns.is_empty() and elements.is_empty() and magnet == 1.0 and kill_scrap == 1.0 \
		and max_hp_bonus == 0.0


# A gate pair must hold at least one part that raises punch or transforms a pattern.
func hits_harder() -> bool:
	return punch > 0.0 or not patterns.is_empty()
