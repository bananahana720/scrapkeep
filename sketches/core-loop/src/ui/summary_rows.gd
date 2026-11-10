extends RefCounted

# The run summary's stat rows (screens.gd draws them): an icon, the number, the word for what it
# counts, and what becomes of it. A first-time player cannot tell a run's tally from what the ball
# carried, so each row says which: the time, stages and kills are added to the player's totals
# (profile RUN_TALLY_KEYS); the scrap, the parts and the side jobs belong to the run and a new run
# starts with none (run_state.begin). The cogs are the scrap's spending twin, so they are not shown.
# Rows are [icon, value, word, meaning].

const KEPT := "kept in your totals"
const LOST := "lost with this run"


static func rows(s: Dictionary, stage_count: int) -> Array:
	var out := [
		["res_timer", "%d:%02d" % [int(s["time"]) / 60, int(s["time"]) % 60], "time", KEPT],
		["obj_beacon", "%d/%d" % [s["stages"], stage_count], "stages", KEPT],
		["res_mass", str(s["scrap"]), "scrap", LOST],
		["cat_transform", str((s["parts"] as Array).size()), "parts bolted on", LOST],
		["thr_instant", str(s["kills"]), "kills", KEPT],
	]
	# A side job is a camp cleared or a relay held on the way; a zero says nothing, so it is left out.
	if int(s["events_won"]) > 0:
		out.append(["obj_event", str(s["events_won"]), "side jobs won", LOST])
	# The earned save is a yes or no, so its row shows only on a run that used it.
	if int(s["save_used"]) > 0:
		out.append(["res_health", str(s["save_used"]), "save used", LOST])
	return out
