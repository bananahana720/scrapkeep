extends SceneTree

const Combat := preload("res://src/combat/combat.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")

# A ram pilot can break Brindle's hull with its own verb (BRINDLE-SCUTTLE, 2026-10-15).
# A heavy ram at the top roll meets the hull plating and fills the posture bar at a full
# ram's rate; a cruise ram, or the same top-roll ram on a bare ball, stays under it, so
# the hull is still plated to everything short of a built, fast ram.
# Fixtures from the 2026-10-15 skipper trial (scratch/w14/brindle, f0d5cecb): Tally entered
# the stage-2 arena at heft 2.502 to 2.564 (bots.ndjson boss.entry_heft, seeds 3 and 4),
# and its trace speed caps at 24.0 m/s; cruise is the movement tuning's 14.

const ENTRY_HEFT := 2.5
const TOP_ROLL := 24.0
const CRUISE := 14.0

var _failures := 0


func _initialize() -> void:
	var ram: Array = Combat.STRIKE_DAMAGE["ram"]
	var heavy_top: float = (ram[0] + TOP_ROLL * ram[1]) * ENTRY_HEFT
	var heavy_cruise: float = (ram[0] + CRUISE * ram[1]) * ENTRY_HEFT
	var bare_top: float = (ram[0] + TOP_ROLL * ram[1]) * 1.0
	var plating: float = Rules.HULL_PLATING
	_report("heavy top-roll ram meets the hull", heavy_top >= plating,
		"ram at %.0f m/s and heft %.1f punches %.1f against hull plating %.0f" % [TOP_ROLL, ENTRY_HEFT, heavy_top, plating])
	var posture := BossPosture.new(Rules.POSTURE)
	var hit: Dictionary = posture.judge({"kind": "ram", "punch": heavy_top, "plating": plating, "frame": 1})
	var full_rate: float = float(BossPosture.BASE["ram"])
	_report("heavy top-roll ram fills the bar at a full ram's rate", float(hit["gain"]) >= full_rate,
		"gain %.2f per hit against a full ram's %.1f (curve %.1f)" % [float(hit["gain"]), full_rate, float(Rules.POSTURE["curve"])])
	_report("a heavy cruise ram stays under the plating", heavy_cruise < plating,
		"ram at %.0f m/s and heft %.1f punches %.1f against %.0f" % [CRUISE, ENTRY_HEFT, heavy_cruise, plating])
	_report("a bare top-roll ram stays under the plating and is not a glance", bare_top < plating and not bool(posture.judge({"kind": "ram", "punch": bare_top, "plating": plating, "frame": 2})["glance"]),
		"ram at %.0f m/s and heft 1.0 punches %.1f against %.0f" % [TOP_ROLL, bare_top, plating])
	var ok := _failures == 0
	print("brindle_heavy_ram_test: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
