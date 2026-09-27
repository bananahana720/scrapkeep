extends RefCounted

# What the player keeps doing this run, read from the bus: the Mind's hands adapt to it
# (DESIGN-V2 section 10, STORY-THREADS T5) and the director weights packs to test it
# (section 15.5). Counts decay with a HALF_LIFE, so "most used" means lately, and every
# count resets on run_started: the Mind learns within a run only (Andrew, primer
# question 6). Memory across runs stays a hook, off.

const HALF_LIFE := 45.0
# The Mind adapts only once a habit has been used this many times, lately.
const MIN_HABIT := 3.0
# A laser volley lands many small hits; each counts this much, so a gun reads as one
# verb among the others rather than drowning them.
const WEAPON_HIT := 0.25

# habit -> the strike kinds a brace against it hardens, and the trigger icon the
# Mind's lens shows while it counters it (VISUAL-LANGUAGE section 11).
const BRACES := {
	"ram": {"kinds": ["ram"], "icon": "trg_on_speed_tier_up"},
	"rebound": {"kinds": ["ram", "stomp"], "icon": "trg_on_rebound"},
	"stomp": {"kinds": ["stomp"], "icon": "trg_on_land"},
	"smash": {"kinds": ["slam"], "icon": "trg_on_smash"},
	"vault": {"kinds": ["stomp", "slam"], "icon": "trg_on_vault"},
	"weapon": {"kinds": ["runner", "arc", "turret", "sticky", "shell"], "icon": "trg_on_hit"},
	"special": {"kinds": ["line", "runner", "arc", "turret"], "icon": "trg_on_charge_release"},
}
# The habits that are movement, not a way to hit: the director reads them for air or
# speed builds; the Mind does not brace against them.
const MOVES := ["jump", "air", "boost", "grapple", "glide"]
const WEAPON_KINDS := ["runner", "arc", "turret", "sticky", "shell"]

var counts := {}
var class_id := ""
var runs := 0


func bind(events) -> void:
	events.run_started.connect(func(id: String): reset(id))
	events.enemy_struck.connect(func(_enemy: Node3D, kind: String, _force: float): _on_struck(kind))
	events.enemy_rebounded.connect(func(_enemy: Node3D, _speed: float): add("rebound"))
	events.vault_kicked.connect(func(_at: Vector3, _speed: float): add("vault"))
	events.special_used.connect(func(_id: String, _at: Vector3): add("special"))
	events.slammed.connect(func(_at: Vector3, _strength: float, _flatness: float): add("smash"))
	events.jumped.connect(func(air: bool): add("air" if air else "jump", 0.5))
	events.boosted.connect(func(_dir: Vector3): add("boost", 0.5))
	events.grapple_fired.connect(func(_anchor: Vector3): add("grapple"))


func reset(id := "") -> void:
	counts.clear()
	class_id = id
	runs += 1


func add(habit: String, amount := 1.0) -> void:
	counts[habit] = float(counts.get(habit, 0.0)) + amount


func tick(delta: float) -> void:
	var keep := pow(0.5, delta / HALF_LIFE)
	for habit in counts:
		counts[habit] = float(counts[habit]) * keep


func count(habit: String) -> float:
	return float(counts.get(habit, 0.0))


# The brace-able habit used most lately, or "" while none has reached MIN_HABIT.
func top() -> String:
	var best := ""
	var best_count := MIN_HABIT - 0.001
	for habit in BRACES:
		if count(habit) > best_count:
			best = habit
			best_count = count(habit)
	return best


# Every habit's share of the total, 0 to 1, for the director's build read.
func shares() -> Dictionary:
	var total := 0.0
	for habit in counts:
		total += float(counts[habit])
	var out := {}
	if total <= 0.0:
		return out
	for habit in counts:
		out[habit] = float(counts[habit]) / total
	return out


func _on_struck(kind: String) -> void:
	match kind:
		"ram":
			add("ram")
		"stomp":
			add("stomp")
		"slam":
			pass
		_:
			if kind in WEAPON_KINDS:
				add("weapon", WEAPON_HIT)
