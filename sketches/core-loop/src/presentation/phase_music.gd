extends RefCounted

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")

# Phase tracks, the hype rule and the champion (INTEGRATION.md sections 4 and 6). Pure
# decisions: audio.gd asks what to play and when, and does the playing. A track id names a
# music_ace theme with dashes turned to underscores (brindle-p2-furnace -> brindle_p2_furnace),
# and every id here has a MusicRows row, so a theme that is not on disk is "not available" and
# the caller falls back one step instead of dropping the band.

const LAST_PHASE := 3
const BRINDLE_PHASES := ["brindle-p1-requisition", "brindle-p2-furnace", "brindle-p3-scuttle"]
# The track the last posture phase plays, and its Eurodance hype version (final phase only).
const FINAL := {"brindle": "brindle-p3-scuttle", "waking": "waking-final", "mind": "mind-final"}
const EURO := {"brindle": "euro-brindle-p3", "waking": "euro-waking-final", "mind": "euro-mind-final"}
const CHAMPION := "champion-hype"
const EURO_CHAMPION := "euro-champion"
const CHAMPION_FINAL_THIRD := 1.0 / 3.0
const BOSS_SYNTH_THEME := {"brindle": 0, "waking": 1, "mind": 2}
# Every id with a pack of its own, for MusicRows.
const TRACKS := ["brindle-p1-requisition", "brindle-p2-furnace", "brindle-p3-scuttle", "waking-final", "mind-final",
	"champion-hype", "euro-brindle-p3", "euro-waking-final", "euro-mind-final", "euro-champion"]


static func theme_of(id: String) -> String:
	return id.replace("-", "_")


static func manifest_of(id: String) -> String:
	return "res://assets/music_ace/%s/manifest.json" % theme_of(id)


# Whether the pack is on disk (source tree or export sidecar).
static func available(id: String) -> bool:
	return MusicRows.pack_on_disk(manifest_of(id))


static func is_final(phase: int) -> bool:
	return phase >= LAST_PHASE


# The track a phase change starts, "" to keep the current one. Brindle has a track per phase;
# the Waking and the Mind switch to their final track on the last posture only.
static func track_for_phase(boss: String, phase: int) -> String:
	if boss == "brindle" and phase >= 1:
		return BRINDLE_PHASES[mini(phase, LAST_PHASE) - 1]
	if FINAL.has(boss) and is_final(phase):
		return String(FINAL[boss])
	return ""


# The pack the boss's fight opens on: Brindle's phase 1 track when it is available, else the
# boss's own theme.
static func entry_track(boss: String, avail: Callable) -> String:
	if boss == "brindle" and avail.call(BRINDLE_PHASES[0]):
		return BRINDLE_PHASES[0]
	return boss


# What the last phase plays: {"track", "hype"}. The Eurodance track after a hype drop when its
# pack loads, else the base final track with no drop (the drop promises the euro), else nothing.
static func final_plan(boss: String, avail: Callable) -> Dictionary:
	var euro := String(EURO.get(boss, ""))
	if euro != "" and avail.call(euro):
		return {"track": euro, "hype": true}
	var base := String(FINAL.get(boss, ""))
	if base != "" and avail.call(base):
		return {"track": base, "hype": false}
	return {"track": "", "hype": false}


# The drop and the hype_drop start that lands on it: the next downbeat, pushed a bar at a time
# until hype_drop's riser (HYPE_DROP_LEAD_SECONDS ahead of its drop) can start at or after now.
static func drop_plan(now: int, next_bar_at: int, bar: int, rate: int) -> Dictionary:
	var lead := roundi(SfxBank.HYPE_DROP_LEAD_SECONDS * rate)
	var drop := next_bar_at
	while drop - lead < now:
		drop += maxi(bar, 1)
	return {"drop": drop, "start": drop - lead}


static func champion_in_final_third(hp: float, max_hp: float) -> bool:
	return max_hp > 0.0 and hp / max_hp <= CHAMPION_FINAL_THIRD
