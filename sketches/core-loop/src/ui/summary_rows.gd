extends RefCounted

# The run summary's stat rows (screens.gd draws them): an icon, the number, the word for what it
# counts, and the group it belongs to. A first-time player cannot tell a run's tally from what the
# ball carried, so the screen draws each group once under one header instead of a line on every
# row: the time, stages and kills are added to the player's totals (profile RUN_TALLY_KEYS); the
# scrap, the parts and the side jobs belong to the run and a new run starts with none
# (run_state.begin). The cogs are the scrap's spending twin, so they are not shown. The earned save
# is neither, so it stands under no header. Rows are [icon, value, word, group].

const KEPT := "kept"
const LOST := "lost"
const NEITHER := ""
# The header each group is drawn under, in the order the screen draws them.
const HEADERS := [[KEPT, "Kept in your totals"], [LOST, "Lost with this run"], [NEITHER, ""]]


static func rows(s: Dictionary, stage_count: int) -> Array:
	var out := [
		["res_timer", "%d:%02d" % [int(s["time"]) / 60, int(s["time"]) % 60], "time", KEPT],
		["obj_beacon", "%d/%d" % [s["stages"], stage_count], "stages", KEPT],
		["res_mass", str(s["scrap"]), "scrap", LOST],
		["cat_transform", str((s["parts"] as Array).size()), "parts bolted on", LOST],
		["thr_instant", str(s["kills"]), "clocked out", KEPT],
	]
	# A side job is a camp cleared or a relay held on the way; a zero says nothing, so it is left out.
	if int(s["events_won"]) > 0:
		out.append(["obj_event", str(s["events_won"]), "side jobs won", LOST])
	# The earned save is a yes or no, so its row shows only on a run that used it.
	if int(s["save_used"]) > 0:
		out.append(["res_health", str(s["save_used"]), "save used", NEITHER])
	return out


# The rows as [header, rows] blocks, in HEADERS order, empty groups left out.
static func grouped(all_rows: Array) -> Array:
	var out := []
	for pair in HEADERS:
		var in_group := all_rows.filter(func(row): return row[3] == pair[0])
		if not in_group.is_empty():
			out.append([pair[1], in_group])
	return out
