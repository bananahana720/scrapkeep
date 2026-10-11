extends Node

# The set piece on Q (design-v3/SKILL-BAR.md section 4). Wave P-B's ultimate unit builds the
# node: can_start, plan, start, recall, bail, phase, active, and the meter's one writer. The
# skill-bar unit seeds only the dispatch table, so the six pilot units of wave P-C each fill
# their own marked block and never edit the same lines (section 12, item 4).

# ultimate_id -> {tech: Callable(beat, ball, aim, heft_mult), peak: Callable(at),
# landing: Callable(at, heft_mult, chain_mult)}, plus the optional
# target: Callable(ball, aim) -> Dictionary of section 12, item 2.
var _ult_rows := {
	# --- P-C Sable ultimate ---
	# --- end Sable ---
	# --- P-C Rivet ultimate ---
	# --- end Rivet ---
	# --- P-C Kest ultimate ---
	# --- end Kest ---
	# --- P-C Tarn ultimate ---
	# --- end Tarn ---
	# --- P-C Tally ultimate ---
	# --- end Tally ---
	# --- P-C Cannon ultimate ---
	# --- end Cannon ---
}
