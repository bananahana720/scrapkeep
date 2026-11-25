extends RefCounted


const KEPT := "kept"
const LOST := "lost"
const NEITHER := ""
const HEADERS := [[KEPT, "Kept in your totals"], [LOST, "Lost with this run"], [NEITHER, ""]]


static func rows(s: Dictionary, stage_count: int) -> Array:
	var out := [
		["res_timer", "%d:%02d" % [int(s["time"]) / 60, int(s["time"]) % 60], "time", KEPT],
		["obj_beacon", "%d/%d" % [s["stages"], stage_count], "stages", KEPT],
		["res_mass", str(s["scrap"]), "scrap", LOST],
		["cat_transform", str((s["parts"] as Array).size()), "parts bolted on", LOST],
		["thr_instant", str(s["kills"]), "clocked out", KEPT],
	]
	if int(s["events_won"]) > 0:
		out.append(["obj_event", str(s["events_won"]), "side jobs won", LOST])
	if int(s["save_used"]) > 0:
		out.append(["res_health", str(s["save_used"]), "save used", NEITHER])
	return out


static func grouped(all_rows: Array) -> Array:
	var out := []
	for pair in HEADERS:
		var in_group := all_rows.filter(func(row): return row[3] == pair[0])
		if not in_group.is_empty():
			out.append([pair[1], in_group])
	return out
