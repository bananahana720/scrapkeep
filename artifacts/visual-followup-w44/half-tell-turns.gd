extends "res://tests/boss_lead_line_test.gd"

# Run against the combined source with --script <this file> -- <30|60|90> <out|in>.
# All stock controls, including the already-turning and stopped cases, still run.
var degrees := 30.0
var direction := 1.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["30", "60", "90"] or not args[1] in ["out", "in"]:
		push_error("Supply a turn angle and side, for example 60 out")
		quit(2)
		return
	degrees = float(args[0])
	direction = 1.0 if args[1] == "out" else -1.0
	super._initialize()

func _rate(mode: String, line: Dictionary, tell: float, t: float) -> float:
	if mode != "swerve":
		return super._rate(mode, line, tell, t)
	var start := tell * 0.5
	var end := start + deg_to_rad(degrees) / SWERVE_RATE
	return direction * float(line.turn_sign) * SWERVE_RATE if t >= start and t < end else 0.0

func _swerve_line(attack_name: String, _lane: bool, share: float) -> void:
	print("%s: %d of %d hit at %d degrees, side %s, starting halfway through the tell" % [
		attack_name, roundi(share * TRIALS), TRIALS, roundi(degrees), "out" if direction > 0.0 else "in"])
