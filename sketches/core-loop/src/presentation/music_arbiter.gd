extends RefCounted

# Pure music deck ownership arbiter (Sound V4, verified by SoundArbiter.tla).
# Every music-deck decision reads one deterministic priority stack:
#   dead > menu > boss_finale > launch > boss (unless radio pinned) > warden (unless radio pinned)
#   > ult_flight > radio > champion > moment > stage > menu.

const OWNER_DEAD := "dead"
const OWNER_MENU := "menu"
const OWNER_BOSS_FINALE := "boss_finale"
const OWNER_LAUNCH := "launch"
const OWNER_BOSS := "boss"
const OWNER_WARDEN := "warden"
const OWNER_ULT := "ult"
const OWNER_RADIO := "radio"
const OWNER_CHAMPION := "champion"
const OWNER_MOMENT := "moment"
const OWNER_STAGE := "stage"


static func resolve(state: Dictionary) -> Dictionary:
	var flow := String(state.get("flow", ""))
	if flow == "dead":
		return _plan(OWNER_DEAD, "dead", "none", false, false)
	var in_play := bool(state.get("in_play", false))
	if not in_play:
		return _plan(OWNER_MENU, "menu", "menu", false, false)
	var boss_active := bool(state.get("boss_active", false))
	var boss_track := String(state.get("boss_track", "brindle"))
	var boss_finale := bool(state.get("boss_finale", false))
	if boss_active and boss_finale:
		return _plan(OWNER_BOSS_FINALE, boss_track, "boss_finale", false, true)
	var launch_armed := bool(state.get("launch_armed", false))
	if launch_armed and not boss_active:
		return _plan(OWNER_LAUNCH, "level", "synth", false, false)
	var radio_hold := String(state.get("radio_hold", ""))
	var radio_pinned := bool(state.get("radio_pinned", false)) and radio_hold != ""
	if boss_active:
		if radio_pinned:
			return _plan(OWNER_RADIO, "radio", "radio", false, false)
		return _plan(OWNER_BOSS, boss_track, "boss", false, false)
	var warden_live := bool(state.get("warden_fighting", false)) or (bool(state.get("warden_engaged", false)) and bool(state.get("warden_sealed", false)))
	if warden_live:
		if radio_pinned:
			return _plan(OWNER_RADIO, "radio", "radio", false, false)
		return _plan(OWNER_WARDEN, "warden", "warden", true, false)
	if bool(state.get("ult_flight", false)):
		return _plan(OWNER_ULT, "level", "synth", false, false)
	if radio_hold != "":
		return _plan(OWNER_RADIO, "radio", "radio", false, false)
	if bool(state.get("champion_alive", false)):
		return _plan(OWNER_CHAMPION, "level", "champion", false, false)
	var miniboss_live := bool(state.get("miniboss_live", false))
	var level_track := "miniboss" if miniboss_live else "level"
	if String(state.get("moment_id", "")) != "":
		return _plan(OWNER_MOMENT, level_track, "moment", false, false)
	if int(state.get("stage", 0)) > 0:
		return _plan(OWNER_STAGE, level_track, "stage", true, false)
	return _plan(OWNER_MENU, "menu", "menu", false, false)


static func _plan(owner: String, track: String, pack_kind: String, allow_dj: bool, is_boss_finale: bool) -> Dictionary:
	return {
		"owner": owner,
		"track": track,
		"pack_kind": pack_kind,
		"allow_dj": allow_dj,
		"is_boss_finale": is_boss_finale,
	}
