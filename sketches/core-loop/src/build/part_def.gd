extends Resource

# One part, as data (TADR-008). A part never holds run state: the run's part list says
# how many copies are held, and build_sheet.gd folds every held copy into one derived
# sheet. A new value is a row edit in parts.gd; a new kind of effect is a code change.

# Rarity is shown twice, as a colour and as a shape on the gate or fabricator topper,
# so colour never carries it alone.
const RARITIES := ["common", "rare", "epic", "milestone"]

@export var id := ""
@export var display_name := ""
# One line a player can read at speed from 30 m away.
@export var text := ""
@export var rarity := "common"
# 1 modest, 2 strong, 3 run-defining. Later stages weight offers toward higher tiers.
@export var tier := 1
# weapon | pattern | mobility | class | stat | milestone: picks the hardware shape the
# ball grows for this part and the family glyph on its gate.
@export var family := "stat"
# Only this class is offered the part; "" means any class.
@export var class_id := ""
# Only a won event grants it (milestone_won); gates and fabricators never offer it.
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
