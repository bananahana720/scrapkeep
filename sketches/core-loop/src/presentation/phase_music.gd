extends RefCounted

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")


const LAST_PHASE := 3
const BRINDLE_PHASES := ["brindle-p1-requisition", "brindle-p2-furnace", "brindle-p3-scuttle"]
const FINAL := {"brindle": "brindle-p3-scuttle", "waking": "waking-final", "mind": "mind-final"}
const EURO := {"brindle": "euro-brindle-p3", "waking": "euro-waking-final", "mind": "euro-mind-final"}
const CHAMPION := "champion-hype"
const EURO_CHAMPION := "euro-champion"
const ANTHEM_PHASES := {
	"brindle": ["anthem-brindle", "anthem-brindle-heavy", "anthem-brindle-heavier"],
	"waking": ["anthem-waking", "anthem-waking-heavy", "anthem-waking-heavier"],
	"mind": ["anthem-mind", "anthem-mind-heavy", "anthem-mind-heavier"],
}
const ANTHEM_CHAMPION := "anthem-champion"
const CHAMPION_FINAL_THIRD := 1.0 / 3.0
const BOSS_SYNTH_THEME := {"brindle": 0, "waking": 1, "mind": 2}
const HEAVY := "-heavy"
const PICKED := {"brindle": "boss-brindle", "waking": "boss-waking", "mind": "boss-mind"}
const TRACKS := ["brindle-p1-requisition", "brindle-p2-furnace", "brindle-p3-scuttle", "waking-final", "mind-final",
	"champion-hype", "euro-brindle-p3", "euro-waking-final", "euro-mind-final", "euro-champion",
	"anthem-brindle", "anthem-brindle-heavy", "anthem-brindle-heavier", "anthem-waking", "anthem-waking-heavy",
	"anthem-waking-heavier", "anthem-mind", "anthem-mind-heavy", "anthem-mind-heavier", "anthem-champion"]


static func theme_of(id: String) -> String:
	return id.replace("-", "_")


static func manifest_of(id: String) -> String:
	return "res://assets/music_ace/%s/manifest.json" % theme_of(id)


static var _on_disk := {}


static func available(id: String) -> bool:
	var key := MusicRows.stem_dir + "|" + id
	if not _on_disk.has(key):
		_on_disk[key] = MusicRows.pack_on_disk(manifest_of(id))
	return _on_disk[key]


static func is_final(phase: int) -> bool:
	return phase >= LAST_PHASE


static func track_for_phase(boss: String, phase: int, avail := Callable()) -> String:
	if avail.is_valid() and ANTHEM_PHASES.has(boss) and avail.call(ANTHEM_PHASES[boss][0]) and not is_final(phase):
		var heavy: String = ANTHEM_PHASES[boss][1]
		return heavy if phase >= 2 and avail.call(heavy) else ""
	if boss == "brindle" and phase >= 1:
		return BRINDLE_PHASES[mini(phase, LAST_PHASE) - 1]
	if FINAL.has(boss) and is_final(phase):
		return String(FINAL[boss])
	return ""


static func entry_track(boss: String, avail: Callable) -> String:
	if ANTHEM_PHASES.has(boss) and avail.call(ANTHEM_PHASES[boss][0]):
		return String(ANTHEM_PHASES[boss][0])
	if PICKED.has(boss) and avail.call(PICKED[boss]):
		return String(PICKED[boss])
	if boss == "brindle" and avail.call(BRINDLE_PHASES[0]):
		return BRINDLE_PHASES[0]
	return boss


static func final_plan(boss: String, avail: Callable) -> Dictionary:
	var phases: Array = ANTHEM_PHASES.get(boss, [])
	var order: Array = [] if phases.is_empty() else [phases[2], phases[1]]
	order.append(String(EURO.get(boss, "")))
	if not phases.is_empty():
		order.append(phases[0])
	for track in order:
		if track != "" and avail.call(track):
			return {"track": track, "hype": true}
	var base := String(FINAL.get(boss, ""))
	if base != "" and avail.call(base):
		return {"track": base, "hype": false}
	return {"track": "", "hype": false}


static func drop_plan(now: int, next_bar_at: int, bar: int, rate: int) -> Dictionary:
	var lead := roundi(SfxBank.HYPE_DROP_LEAD_SECONDS * rate)
	var drop := next_bar_at
	while drop - lead < now:
		drop += maxi(bar, 1)
	return {"drop": drop, "start": drop - lead}


static func champion_final(avail: Callable) -> String:
	for id in [ANTHEM_CHAMPION, EURO_CHAMPION]:
		if avail.call(id):
			return id
	return ""


static func champion_in_final_third(hp: float, max_hp: float) -> bool:
	return max_hp > 0.0 and hp / max_hp <= CHAMPION_FINAL_THIRD
