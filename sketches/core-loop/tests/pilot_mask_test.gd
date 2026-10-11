extends SceneTree
# 2026-10-10 (PD-0b): new. tools/pilot_mask.gd, headless: on the neutral shell with Sable's rig
# it writes every mask.json field in plausible ranges over 16 roll angles, and a seeded opaque
# sphere closed over the Pod hides the pilot (under 5% visible), so a mask that sees through
# everything cannot pass.

const PilotMask := preload("res://tools/pilot_mask.gd")
const T := preload("res://tests/support/t.gd")
const NEUTRAL := "res://assets/models/world_one/shell_neutral.glb"
const FIELDS := ["pilot_visible_pct", "head_visible_pct", "head_px", "rows", "pilot_px_area", "head_px_area", "neck_y", "first_blocker_pct"]

var _t := T.new("pilot_mask_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var res: Dictionary = await PilotMask.measure(self, {"shell": NEUTRAL, "pilot": "pylon_engineer"})
	_t.check("the neutral mask measures", not res.has("error"), str(res.get("error", "")))
	var missing := FIELDS.filter(func(f): return not res.has(f))
	_t.check("mask.json carries every field", missing.is_empty(), "missing %s" % [missing])
	if missing.is_empty():
		_t.eq("16 roll angles", (res["rows"] as Array).size(), 16)
		_t.check("the pilot covers a plausible area", int(res["pilot_px_area"]) > 1000 and int(res["head_px_area"]) > 200,
			"%d pilot px, %d head px" % [res["pilot_px_area"], res["head_px_area"]])
		_t.check("pilot visible share in range", float(res["pilot_visible_pct"]) > 5.0 and float(res["pilot_visible_pct"]) <= 100.0, "%.1f%%" % res["pilot_visible_pct"])
		_t.check("head visible share in range", float(res["head_visible_pct"]) > 5.0 and float(res["head_visible_pct"]) <= 100.0, "%.1f%%" % res["head_visible_pct"])
		_t.check("head height in range", float(res["head_px"]) >= 20.0 and float(res["head_px"]) <= 200.0, "%.1f px" % res["head_px"])
		_t.check("the lattice blocks some pilot pixels", float((res["first_blocker_pct"] as Dictionary).get("lattice", 0.0)) > 0.0, str(res["first_blocker_pct"]))
	var sealed: Dictionary = await PilotMask.measure(self, {"shell": NEUTRAL, "pilot": "pylon_engineer", "samples": 4, "seed-sphere": 0.95})
	_t.check("a sphere closed over the Pod hides the pilot", not sealed.has("error") and float(sealed.get("pilot_visible_pct", 100.0)) < 5.0,
		"%.1f%% visible, error %s" % [sealed.get("pilot_visible_pct", -1.0), sealed.get("error", "")])
	quit(_t.verdict())
