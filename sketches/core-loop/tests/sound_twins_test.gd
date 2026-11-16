extends SceneTree

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Twins := preload("res://src/presentation/sound_twins.gd")
const Hud := preload("res://src/ui/hud.gd")
const T := preload("res://tests/support/t.gd")

# UI principle P9 (UA-07): every sound the player must act on has a visible twin. The list is
# src/presentation/sound_twins.gd. This test fails two ways: a cue the sound bank names that the
# list does not classify (so a new warning cannot be added silently), and a twin row whose
# script is missing or whose token is gone from that script's source. Each way has a planted bad
# case below that the audit must catch. Open rows (act-on, no twin) are printed and their count
# is pinned.

var _t := T.new("sound_twins_test")


# The cues the bank names: its trim table, event files, stingers, tiers and the keyed and danger lists.
static func bank_cues() -> Array:
	var seen := {}
	for id in SfxBank.TRIM_DB:
		seen[id] = true
	for id in SfxBank.EVENT_CUES:
		seen[id] = true
	for id in SfxBank.STINGER_BEATS:
		seen[id] = true
	for base in SfxBank.TIER_CUES:
		seen[base] = true
		for id in SfxBank.TIER_CUES[base]:
			seen[id] = true
	for list in [SfxBank.DANGER_SOUNDS, SfxBank.KEYED_SOUNDS, SfxBank.KEST_SOUNDS]:
		for id in list:
			seen[id] = true
	var out := seen.keys()
	out.sort()
	return out


# Every problem with a classification: unclassified cues, cues listed twice or not in the bank,
# a twin whose script or token is gone, a toast the HUD does not show, and an open count off its pin.
static func audit(cues: Array, act: Array, open: Dictionary, unwired: Dictionary, not_act: Array, open_pinned: int, toasts: Array) -> Array:
	var errors: Array = []
	var kind_of := {}
	var note := func(id: String, kind: String) -> void:
		if kind_of.has(id):
			errors.append("%s is listed twice (%s and %s)" % [id, kind_of[id], kind])
		kind_of[id] = kind
	for row in act:
		for id in row["cues"]:
			note.call(id, "act")
		var path: String = row["script"]
		if not FileAccess.file_exists(path):
			errors.append("twin for %s: script %s does not exist" % [row["cues"], path])
		elif not FileAccess.get_file_as_string(path).contains(String(row["token"])):
			errors.append("twin for %s: %s no longer contains \"%s\"" % [row["cues"], path, row["token"]])
		if row.has("toast") and not toasts.has(row["toast"]):
			errors.append("twin for %s: the HUD does not toast %s" % [row["cues"], row["toast"]])
	for id in open:
		note.call(id, "open")
	for id in unwired:
		note.call(id, "unwired")
	for group in not_act:
		if String(group["why"]) == "":
			errors.append("a not-act group has no reason")
		for id in group["cues"]:
			note.call(id, "not_act")
	for id in cues:
		if not kind_of.has(id):
			errors.append("%s is in the sound bank but not classified (act with a twin, open, unwired or not act)" % id)
	for id in kind_of:
		if not cues.has(id):
			errors.append("%s is listed but the sound bank does not name it" % id)
	if open.size() != open_pinned:
		errors.append("%d open rows, pinned at %d" % [open.size(), open_pinned])
	return errors


func _initialize() -> void:
	var cues := bank_cues()
	var toasts: Array = Hud.toast_kinds()
	var errors := audit(cues, Twins.ACT, Twins.OPEN, Twins.UNWIRED, Twins.NOT_ACT, Twins.OPEN_PINNED, toasts)
	for e in errors:
		print("  problem: %s" % e)
	_t.eq("the list classifies every bank cue and every twin is real", errors, [])

	var counts := {"act": 0, "open": Twins.OPEN.size(), "unwired": Twins.UNWIRED.size(), "not_act": 0}
	for row in Twins.ACT:
		counts["act"] += row["cues"].size()
	for group in Twins.NOT_ACT:
		counts["not_act"] += group["cues"].size()
	print("cues in the bank: %d; act-on with a twin: %d; open: %d; unwired: %d; not act-on: %d" % [cues.size(), counts["act"], counts["open"], counts["unwired"], counts["not_act"]])
	_t.eq("the kinds add up to the bank", counts["act"] + counts["open"] + counts["unwired"] + counts["not_act"], cues.size())
	for id in Twins.OPEN:
		print("  OPEN: %s plays at %s and nothing on screen carries it (%s)" % [id, Twins.OPEN[id]["plays"], Twins.OPEN[id]["what"]])
		_t.check("open row %s names a real file" % id, FileAccess.file_exists("res://" + String(Twins.OPEN[id]["plays"]).get_slice(":", 0)))

	# Planted bad case 1: a new warning cue in the bank that the list does not know.
	var planted_cues := cues.duplicate()
	planted_cues.append("planted_new_warning")
	var caught_new := audit(planted_cues, Twins.ACT, Twins.OPEN, Twins.UNWIRED, Twins.NOT_ACT, Twins.OPEN_PINNED, toasts)
	_t.check("planted: an unclassified bank cue is caught", caught_new.size() == 1 and String(caught_new[0]).begins_with("planted_new_warning is in the sound bank"), str(caught_new))

	# Planted bad case 2a: a twin whose script does not exist.
	var no_script := Twins.ACT.duplicate(true)
	no_script.append({"cues": ["planted_new_warning"], "what": "x", "script": "res://src/ui/not_a_script.gd", "token": "func x("})
	var caught_script := audit(planted_cues, no_script, Twins.OPEN, Twins.UNWIRED, Twins.NOT_ACT, Twins.OPEN_PINNED, toasts)
	_t.check("planted: a twin with a missing script is caught", caught_script.size() == 1 and String(caught_script[0]).contains("does not exist"), str(caught_script))

	# Planted bad case 2b: a twin whose function is no longer in its script.
	var no_token := Twins.ACT.duplicate(true)
	no_token.append({"cues": ["planted_new_warning"], "what": "x", "script": "res://src/ui/hud.gd", "token": "func this_function_was_deleted("})
	var caught_token := audit(planted_cues, no_token, Twins.OPEN, Twins.UNWIRED, Twins.NOT_ACT, Twins.OPEN_PINNED, toasts)
	_t.check("planted: a twin whose function is gone is caught", caught_token.size() == 1 and String(caught_token[0]).contains("no longer contains"), str(caught_token))

	# Planted bad case 3: an open row added without moving the pin.
	var more_open := Twins.OPEN.duplicate()
	more_open["planted_new_warning"] = {"plays": "x", "what": "x"}
	var caught_open := audit(planted_cues, Twins.ACT, more_open, Twins.UNWIRED, Twins.NOT_ACT, Twins.OPEN_PINNED, toasts)
	_t.check("planted: an open row past the pin is caught", caught_open.size() == 1 and String(caught_open[0]).contains("pinned at"), str(caught_open))

	# Positive control: a correct twin for the planted cue clears it.
	var good := Twins.ACT.duplicate(true)
	good.append({"cues": ["planted_new_warning"], "what": "x", "script": "res://src/ui/hud.gd", "token": "func toast_kinds("})
	_t.eq("planted: a real twin for the new cue passes", audit(planted_cues, good, Twins.OPEN, Twins.UNWIRED, Twins.NOT_ACT, Twins.OPEN_PINNED, toasts), [])
	quit(_t.verdict())
