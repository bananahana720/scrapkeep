extends SceneTree

const Game := preload("res://src/game.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const ArmourMarks := preload("res://src/presentation/armour_marks.gd")
const T := preload("res://tests/support/t.gd")

# Damage families (design-v3/FIELDS-AND-CASTS.md section 6). Andrew's Q5 "Lean, never a wall"
# and Q6 "Learn on first hit" (2026-10-17 22:12:39Z):
# - plated resists kinetic to 60% and is weak to arc and abilities at 150%; weak beats resisted
#   on one hit; an unarmoured target and a neutral family take 100%; nothing reads below 60%.
# - live, a drill crew (plated) loses 60%, 100% and 150% of the same punch to a kinetic weapon
#   bolt, a frost hit and an arc hit; a hit that falls short of its plating only chips, unread.
# - the first resisted and the first weak hit each stamp their word, DENT and ZZAP!, once per
#   run; would_crush asks the same armour question the strike answers (F005);
#   the first read discovers the codex entry, and from then on plated crews wear the icon,
#   above the interrupted star and far off the ground telegraphs, on a crew spawned later too.

const PUNCH := 30.0
const EXPECTED_CHECKS := 20

var _t := T.new("damage_families_test")
var _game
var _ready := false


func _initialize() -> void:
	_rows()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


# An enemy naming its armour (a Dig elite from its spawn spec), or naming none.
class Specced:
	var kind := "drill_crew"
	var own := ""
	func armour_class() -> String:
		return own


func _rows() -> void:
	_t.eq("Q5 values", [DamageFamilies.RESISTED, DamageFamilies.WEAK], [0.6, 1.5])
	_t.eq("plated: kinetic resisted, arc and abilities weak, frost neutral",
		[DamageFamilies.mult("plated", "ram", "ram_or_contact"), DamageFamilies.mult("plated", "arc", "item_proc"),
			DamageFamilies.mult("plated", "claw", "special"), DamageFamilies.mult("plated", "frost", "weapon")],
		[0.6, 1.5, 1.5, 1.0])
	_t.eq("no armour reads nothing", [DamageFamilies.verdict("", "ram", "weapon"), DamageFamilies.mult("", "arc", "special")], ["", 1.0])
	var floor := 1.0
	for armour in DamageFamilies.ARMOUR:
		for kind in ["ram", "arc", "frost", "claw"]:
			for source in ["weapon", "special", "ram_or_contact"]:
				floor = minf(floor, DamageFamilies.mult(armour, kind, source))
	_t.check("never a wall: nothing reads below 60%", floor >= DamageFamilies.RESISTED, "floor %.2f" % floor)
	var bare := Specced.new()
	var named := Specced.new()
	named.kind = "chaser"
	named.own = "plated"
	_t.eq("an own class wins, an empty one falls through to the kind",
		[DamageFamilies.armour_of(named), DamageFamilies.armour_of(bare)], ["plated", "plated"])
	_t.eq("the words", [DamageFamilies.word("plated", "resisted"), DamageFamilies.word("plated", "weak")], ["DENT", "ZZAP!"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _ready:
		_ready = true
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_live()
	_game.free()
	quit(_t.verdict())
	return true


# Ahead of the start, in the camera's view, unless `behind`: a read word stands beside its foe on
# screen and waits for a later hit while the foe is out of view (player_fx.read_word).
func _crew(offset: float, behind := false) -> Node3D:
	var terrain = _game.ctx.terrain
	var at: Vector3 = terrain.spawn_point(1) + Vector3(offset, 0.0, 14.0 if behind else -14.0)
	var crew: Node3D = _game.ctx.spawner.spawn_enemy("drill_crew", terrain.drop_point(at.x, at.z, 1.5))
	crew.set_process(false)
	crew.set_physics_process(false)
	return crew


func _loss(crew: Node3D, kind: String, punch: float, source := "") -> float:
	var before: float = crew.hp
	_game.combat.strike(crew, kind, punch, "", source)
	return before - float(crew.hp)


func _live() -> void:
	var marks = _game.presentation.armour_marks if _game.get("presentation") != null else null
	var codex = _game.ctx.codex
	_t.check("the drill crew is plated", DamageFamilies.armour_of(_crew(-40.0)) == "plated")
	_t.check("the codex does not know plating yet", codex != null and not codex.known("armour_plated"))
	# The drill crew's own plate takes the first breaking hit whole (drill_crew.gd); popped
	# here, so the losses compare the families alone.
	var hidden := _crew(-8.0, true)
	hidden.plates = 0
	_loss(hidden, "test_bolt", PUNCH, "weapon")
	_t.check("a first read on a crew out of view is not spent", marks != null and marks.stamped.is_empty(), str(marks.stamped if marks != null else null))
	var a := _crew(-8.0)
	a.plates = 0
	var lost_kinetic := _loss(a, "test_bolt", PUNCH, "weapon")
	_t.eq("the next resisted hit, in view, stamps DENT", Array(marks.stamped) if marks != null else [], ["DENT"])
	_t.eq("a kinetic bolt reads resisted", String(a.get_meta("armour_read", "")), "resisted")
	_t.check("the first read discovers the codex entry and badges the crew", codex.known("armour_plated") and a.has_node("ArmourIcon"),
		"known %s" % codex.known("armour_plated"))
	var b := _crew(0.0)
	b.plates = 0
	var lost_frost := _loss(b, "frost", PUNCH)
	var c := _crew(8.0)
	c.plates = 0
	var lost_arc := _loss(c, "arc", PUNCH)
	_t.near("kinetic deals 60% of a neutral hit", lost_kinetic / lost_frost, 0.6, 0.01)
	_t.near("arc deals 150% of a neutral hit", lost_arc / lost_frost, 1.5, 0.01)
	var d := _crew(16.0)
	var chip := _loss(d, "test_bolt", 10.0, "weapon")
	_t.check("a hit short of the plating only chips, unread", String(d.get_meta("armour_read", "x")) == "" and chip < 10.0 * 0.6,
		"chip %.2f" % chip)
	_loss(a, "test_bolt", PUNCH, "weapon")
	_t.eq("DENT and ZZAP! stamp once each per run", Array(marks.stamped) if marks != null else [], ["DENT", "ZZAP!"])
	var f := _crew(32.0)
	f.plates = 0
	f.plating = 0.0
	f.hp = 20.0
	var combat = _game.combat
	_t.eq("would_crush asks the armour too: 30 kinetic, 15 frost, 15 arc on 20 hp",
		[combat.would_crush(f, "test_bolt", 30.0), combat.would_crush(f, "frost", 15.0), combat.would_crush(f, "arc", 15.0)],
		[false, false, true])
	var e := _crew(24.0)
	var icon := e.get_node_or_null("ArmourIcon") as Node3D
	_t.check("a crew spawned after the read wears the icon", icon != null)
	_t.check("the icon sits above the interrupted star, clear of ground telegraphs",
		icon != null and icon.position.y >= 2.4 + ArmourMarks.ICON_SIZE and icon.position.y - ArmourMarks.ICON_SIZE * 0.5 > 2.0,
		"icon at %.2f m" % (icon.position.y if icon != null else -1.0))
	_t.eq("the check count", _t.checks + 1, EXPECTED_CHECKS)
