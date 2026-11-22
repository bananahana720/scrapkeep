extends SceneTree
# One triangle and draw budget for all six pilots, read from the files the game loads:
# hero_assets.gd SHELLS (the shell), PILOTS (the animated pilot) and shell_path() (the heft
# layers c2 to c5, all shown at class V), plus each pilot's earned shell variants. Unit E1-03
# (wave 46), from the measured table in the wave 46 3D review section 1.2 (upgrade U-B1).
#
# What it checks:
#   roster     SHELLS and PILOTS name the same six pilots, and every shell, pilot, layer and
#              variant file loads.
#   shell      shell triangles in play (the placeholder Dome > Pilot mesh, which hero_assets
#              hides, left out) are at most SHELL_CAP. Tarn and the Cannon are over it until
#              their trim units; OVER_CAP holds each at today's count so it cannot grow, and
#              fails once a trim brings it under SHELL_CAP, so the trim unit removes its row.
#   draws      shell draws in play are within the registry row's draw exception, or the
#              shell class cap.
#   class V    shell in play + pilot model + heft layers c2 to c5, triangles and draws, at
#              most CLASS_V, today's measure. A pilot that grows fails; one that shrinks
#              prints the room it freed so the next unit can lower its row.
#   variants   each earned shell variant in play is at most SHELL_CAP or its OVER_CAP row.
# The run must make EXPECTED_CHECKS checks, so an early return or a skipped loop fails it.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const T := preload("res://tests/support/t.gd")

const BUDGETS := "res://assets/asset_budgets.json"
const REGISTRY := "res://assets/registry.json"
const PILOT_IDS := ["runner_gunner", "pylon_engineer", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
# The Hoberman shell band's top (shell_base.py SHELL_TRIS, hero_assets_test SHELL_TRIS).
const SHELL_CAP := 6500
# Shells in play over SHELL_CAP, held at their 22 Nov 2026 count until a trim unit brings them
# under it (phase 2 of the wave 46 plan). Keys are shell files, so variants share the table.
const OVER_CAP := {
	"res://assets/models/world_one/shell_tarn.glb": 7498,
	"res://assets/models/world_one/shell_cannon.glb": 7738,
	"res://assets/models/world_one/shell_rivet_calibrated.glb": 6748,
	"res://assets/models/world_one/shell_tally_abacus.glb": 6744,
	"res://assets/models/world_one/shell_tarn_redjaw_teeth.glb": 7690,
	"res://assets/models/world_one/shell_cannon_choir.glb": 7742,
}
# Class V in play (shell without its placeholder + pilot model + c2 to c5), measured 22 Nov 2026.
const CLASS_V := {
	"runner_gunner": {"tris": 18700, "draws": 22},
	"pylon_engineer": {"tris": 16176, "draws": 25},
	"demolitions_caster": {"tris": 18554, "draws": 24},
	"tarn": {"tris": 19430, "draws": 28},
	"tally": {"tris": 18085, "draws": 20},
	"remembered_cannon": {"tris": 14018, "draws": 21},
}
const EXPECTED_CHECKS := 45

var _t := T.new("hero_six_pilot_budget_test")
var _registry := {}
var _shell_draws := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	for e in doc["assets"]:
		_registry[String(e.get("path", ""))] = e
	_shell_draws = int(JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))["classes"]["shell"]["draws"])
	var shells := HeroAssets.SHELLS.keys()
	var pilots := HeroAssets.PILOTS.keys()
	shells.sort()
	pilots.sort()
	var want := PILOT_IDS.duplicate()
	want.sort()
	_t.check("six pilots in SHELLS and PILOTS", shells == want and pilots == want, "SHELLS %s, PILOTS %s" % [shells, pilots])
	_t.check("a class V row for each pilot", CLASS_V.keys().size() == 6 and PILOT_IDS.all(func(p): return CLASS_V.has(p)), str(CLASS_V.keys()))
	var paths := Cosmetics.asset_paths()
	print("pilot               shell tris/draws  pilot tris/draws  c2-c5 tris/draws  class V tris/draws")
	for pilot in PILOT_IDS:
		_pilot(pilot, paths)
	_finish()


func _finish() -> void:
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _pilot(pilot: String, paths: Dictionary) -> void:
	var shell_file := HeroAssets.shell_path(pilot, "", 1, {})
	var shell := _counts(shell_file, true)
	var body := _counts(String(HeroAssets.PILOTS[pilot]), false)
	var heft := {"tris": 0, "draws": 0}
	var layers_ok := true
	for n in HeroAssets.HEFT_LAYERS:
		var c := _counts(HeroAssets.shell_path(pilot, "", n, {}), false)
		layers_ok = layers_ok and not c.is_empty()
		if not c.is_empty():
			heft.tris += c.tris
			heft.draws += c.draws
	_t.check(pilot + " files load", not shell.is_empty() and not body.is_empty() and layers_ok,
		"%s, %s and its c2 to c5 layers" % [shell_file, HeroAssets.PILOTS[pilot]])
	if shell.is_empty() or body.is_empty() or not layers_ok:
		return
	_shell_band(pilot, shell_file, shell)
	var exception: Dictionary = _registry.get(shell_file, {}).get("exception", {})
	var draw_cap := int(exception.get("draws", _shell_draws))
	_t.check(pilot + " shell draws", shell.draws <= draw_cap, "%d draws in play within %d (%s)"
		% [shell.draws, draw_cap, "registry exception" if exception.has("draws") else "shell class"])
	var total := {"tris": shell.tris + body.tris + heft.tris, "draws": shell.draws + body.draws + heft.draws}
	print("%-19s %6d / %-2d       %6d / %-2d      %6d / %-2d      %6d / %d" % [pilot, shell.tris, shell.draws,
		body.tris, body.draws, heft.tris, heft.draws, total.tris, total.draws])
	var row: Dictionary = CLASS_V[pilot]
	for key in ["tris", "draws"]:
		var room := int(row[key]) - int(total[key])
		_t.check("%s class V %s" % [pilot, key], room >= 0, "%d within %d%s" % [total[key], row[key],
			", %d freed: lower CLASS_V" % room if room > 0 else ""])
	for id in Cosmetics.for_slot("shell", pilot):
		if Cosmetics.row(id).get("pilot", "") != pilot:
			continue
		var file := HeroAssets.shell_path(pilot, id, 1, paths)
		var variant := _counts(file, true)
		_t.check(id + " loads", not variant.is_empty(), file)
		if not variant.is_empty():
			_shell_band(id, file, variant)


# Triangles in play at most SHELL_CAP, or held at its OVER_CAP row while it is still over.
func _shell_band(label: String, file: String, c: Dictionary) -> void:
	if OVER_CAP.has(file):
		var ceiling := int(OVER_CAP[file])
		_t.check(label + " shell tris held", c.tris <= ceiling and c.tris > SHELL_CAP,
			"%d tris in play, held at %d until its trim; under %d means remove its OVER_CAP row" % [c.tris, ceiling, SHELL_CAP])
	else:
		_t.check(label + " shell tris", c.tris > 0 and c.tris <= SHELL_CAP, "%d tris in play within %d" % [c.tris, SHELL_CAP])


# Triangles and draws (surfaces) of every mesh in a file; with in_play, the placeholder pilot
# mesh hero_assets hides (a MeshInstance3D named Pilot under Dome) is left out. {} if it fails to load.
static func _counts(path: String, in_play: bool) -> Dictionary:
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var out := {"tris": 0, "draws": 0}
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if scene is MeshInstance3D:
		meshes.append(scene)
	for mi: MeshInstance3D in meshes:
		if in_play and mi.name == &"Pilot" and mi.get_parent() != null and mi.get_parent().name == &"Dome":
			continue
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			out.draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			out.tris += idx.size() / 3 if idx != null and idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	scene.free()
	return out
