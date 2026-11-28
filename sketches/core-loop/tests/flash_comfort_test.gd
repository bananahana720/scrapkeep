extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Pod := preload("res://src/combat/splitter_pod.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const GapNet := preload("res://src/combat/gap_net.gd")
const Comfort := preload("res://src/core/comfort.gd")
const T := preload("res://tests/support/t.gd")

# Wave 20 FLASH-COMFORT: the new effects read the Reduce flashes and Reduced motion settings.
# Wave 18 widens it: the scan covers src/world and src/ui too, and the gap net's crackle beat,
# the event and radio-cache pulses and lamp, and the decorative shakes (reward crate, Moss
# bubble, locked class card, pilot growl, class-preview cap) are guarded and pinned below.
# Part 1 is a source scan. SITES lists every guarded line: the file must still hold the guard
# call, so removing one goes red. Then every `emission_energy_multiplier`, `light_energy` or
# `flash_color` assignment in src/combat and src/presentation whose value varies with time and
# skips FlashGuard must be named in EXEMPT with a reason; each EXEMPT line must still exist and,
# where it leans on a guard elsewhere, that guard must still exist. Part 2 runs a real splitter
# pod, gap net, Kest fuse and the two shaking UI nodes with the setting on and off. Evidence limit:
# source text and headless values, not a rendered capture or how it feels at Andrew's screen.

const SRC := "res://src/"
const SCAN_DIRS := ["res://src/combat/", "res://src/presentation/", "res://src/world/", "res://src/ui/"]
const TIME_VARYING := "sin\\(|cos\\(|_clock|\\b_t\\b|lerpf\\(|\\.lerp\\(|_flash|pulse|swing|delta|progress|blink|fraction|level|value|charge|\\bage\\b|TIME"
const ASSIGN := "^\\s*(.*?(?:emission_energy_multiplier|light_energy|flash_color))\\s*=[^=]"

# [file under src/, snippet that must stay]
const SITES := [
	["combat/splitter_pod.gd", "FlashGuard.rate(lerpf(3.0, 10.0, burn))"],
	["combat/splitter_pod.gd", "FlashGuard.spike(GLOW_IDLE, lerpf(GLOW_IDLE, GLOW_FUSE, burn * blink))"],
	["combat/splitter.gd", "FlashGuard.whiten(flare)"],
	["combat/splitter.gd", "FlashGuard.spike(SEAM_IDLE, lerpf(SEAM_IDLE, SEAM_FLARE, flare))"],
	["combat/kest_kit.gd", "FlashGuard.blink(posmod(int(_clock * 4.0), 2) == 0)"],
	["combat/warden_look.gd", "FlashGuard.spike(1.2, OPEN_CORE_GLOW)"],
	["combat/warden_look.gd", "FlashGuard.spike(1.2, 1.2 + 2.0 * warden.charge_fraction())"],
	["combat/foreman.gd", "FlashGuard.spike(0.0, 3.0 * level)"],
	["combat/dispatcher.gd", "FlashGuard.spike(0.6 * escalation, 2.5 * clampf(_t / SUCK, 0.0, 1.0))"],
	["combat/lobber.gd", "FlashGuard.spike(0.8, 0.8 + value * 5.0)"],
	["presentation/highdraft_fx.gd", "FlashGuard.spike(0.0, level)"],
	["presentation/highdraft_fx.gd", "FlashGuard.spike(0.0, 1.0 - first if first < 1.0 else 0.0)"],
	["presentation/highdraft_fx.gd", "FlashGuard.spike(0.0, 1.0 - second if second < 1.0 else 0.0)"],
	["ui/ability_bar.gd", "FlashGuard.info(clampf(_refusals.get(slot, 0.0) / SHAKE_TIME, 0.0, 1.0))"],
	["ui/ability_bar.gd", "if Comfort.reduced_motion or _refusals.get(slot, 0.0) <= 0.0:"],
	["ui/aim_reticle.gd", "if Comfort.reduced_motion or _shake_left <= 0.0:"],
	["ui/heft_dial.gd", "FlashGuard.info(_flash / FLASH_SECONDS)"],
	["game.gd", "Comfort.reduced_motion = on"],
	["combat/gap_net.gd", "FlashGuard.rate(CRACKLE_RATE + CRACKLE_RATE_GAIN * t)"],
	["combat/gap_net.gd", "* CRACKLE_SHAKE * t * Comfort.motion_scale()"],
	["world/event_view.gd", "FlashGuard.spike(0.4, 0.4 + (pulse * 2.4 if armed else 0.0))"],
	["world/event_view.gd", "FlashGuard.spike(0.3 + model.progress() * 2.4, 0.3 + model.progress() * 4.0 * (0.6 + 0.4 * pulse))"],
	["world/event_view.gd", "FlashGuard.spike(1.2, 1.2 + pulse * 2.0)"],
	["world/radio_cache.gd", "_lamp.visible = FlashGuard.blink(fmod(_age, BLINK) < BLINK * 0.5)"],
	["ui/reward_view.gd", "var amp := (1.5 + 11.0 * p * p) * (0.0 if Comfort.reduced_motion else 1.0)"],
	["ui/reward_view.gd", "sin(t * w * 0.8) * 0.06 * p * (0.0 if Comfort.reduced_motion else 1.0)"],
	["ui/moss_bubble.gd", "if Comfort.reduced_motion:\n\t\tshake = Vector2.ZERO"],
	["ui/moss_bubble.gd", "var wag := 0.0 if Comfort.reduced_motion else"],
	["ui/class_card.gd", "rotation = 0.0 if Comfort.reduced_motion else sin(_shake * 70.0)"],
	["presentation/pilot_antics.gd", "* 0.035 * growl * (0.0 if Comfort.reduced_motion else 1.0)"],
	["ui/class_preview.gd", "(0.0 if Comfort.reduced_motion else 0.25 * sin(t * 40.0))"],
	["ui/class_preview.gd", "if thrown >= 1.0 and not Comfort.reduced_motion else 0.0"],
]

# "file:symbol" -> [line that must still exist, file holding the guard it leans on ("" if none),
# guard snippet that must still exist there, reason]. A changed line or a lost guard fails.
const EXEMPT := {
	"chaser.gd:_material.emission_energy_multiplier": ["PLATE_GLOW_LIVE * swing", "combat/enemy.gd", "const PULSE_HZ := 2.0",
		"plate pulse: 2 Hz at 14% depth, under the 3 Hz cap (check 03 pins both)"],
	"deflector.gd:_rim_material.emission_energy_multiplier": ["PLATE_GLOW_LIVE * swing", "combat/enemy.gd", "const PULSE_HZ := 2.0",
		"same plate pulse as the chaser's"],
	"enemy.gd:(mat as StandardMaterial3D).emission_energy_multiplier": ["PLATE_GLOW_LIVE * swing", "combat/enemy.gd", "const PULSE_DEPTH := 0.14",
		"same plate pulse, the will_break rim"],
	"warden_look.gd:_seam_material.emission_energy_multiplier": ["lerpf(POSTURE_SEAM_GLOW_MIN, POSTURE_SEAM_GLOW_MAX", "",
		"", "a slow meter of the guard (1.0 to 2.6), no clock term, so it cannot strobe"],
	"companion_body.gd:mat.emission_energy_multiplier": ["* (1.6 if blink else 1.0)", "presentation/companion_body.gd", "not FlashGuard.on and fill >= 1.0",
		"the halo's 2 Hz blink is switched off in the line above when the toggle is on"],
	"linker.gd:_cable_material.emission_energy_multiplier": ["PLATE_GLOW_LIVE if on else 0.0", "",
		"", "a steady cable glow; it changes only when the cable goes live or dark"],
	"requisition.gd:mat.emission_energy_multiplier": ["2.5 * glow", "boss/boss.gd", "FlashGuard.rate(4.0)",
		"glow comes from boss.gd's hazard warn pulse, whose rate is capped there"],
	"boss_model.gd:own.emission_energy_multiplier": ["emission_energy_multiplier = energy", "boss/boss.gd", "FlashGuard.rate(4.0)",
		"signal_glow's energy is the same guarded boss.gd warn pulse"],
	"jolt_layer.gd:flash()": ["flash()", "combat/enemy.gd", "FlashGuard.spike(0.0, _flash * 2.0)",
		"calls Enemy.flash, whose draw is guarded in _update_flash"],
	"combat.gd:exposure tint": ["set_shader_parameter(\"tint\", Palette.ANCIENT)", "",
		"", "the exposure mark's tint is set once; its alpha is a fade-out, not a flash"],
	"cutting_torch.gd:glow": ["ActiveFx.peak(GLOW_COLD.lerp(COLOR, hot))", "combat/actives/active_fx.gd", "FlashGuard.info",
		"drawn through ActiveFx.peak, which scales by FlashGuard.info (active_flashes_test covers it)"],
	"warden_look.gd:_glow()": ["static func _glow(color: Color, energy: float) -> StandardMaterial3D:", "",
		"", "a material constructor; the seam, core and body glows it builds are guarded or exempt above"],
}

var _t := T.new("flash_comfort_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


static func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


static func _scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + sub + "/"))
	return out


# "file:lvalue" of every time-varying brightness assignment that skips FlashGuard.
static func _unguarded(dirs: Array) -> Array:
	var out := []
	var assign := RegEx.create_from_string(ASSIGN)
	var varying := RegEx.create_from_string(TIME_VARYING)
	for dir in dirs:
		for path in _scripts(dir):
			for line in _text(path).split("\n"):
				var m := assign.search(line)
				if m == null or line.contains("FlashGuard."):
					continue
				if varying.search(line.substr(line.find("=") + 1)) != null:
					out.append("%s:%s" % [path.get_file(), m.get_string(1).strip_edges()])
	return out


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


# Upward crossings of the series through its midpoint.
static func _cycles(series: Array) -> int:
	var lo: float = series.min()
	var hi: float = series.max()
	var mid := (lo + hi) * 0.5
	var n := 0
	for i in range(1, series.size()):
		if series[i - 1] < mid and series[i] >= mid:
			n += 1
	return n


func _run() -> void:
	FlashGuard.on = false
	# --- The source scan ---------------------------------------------------------------
	var missing := []
	for site in SITES:
		if not _text(SRC + site[0]).contains(site[1]):
			missing.append("%s: %s" % [site[0], site[1]])
	_t.eq("01 every guarded site still holds its guard", missing, [])

	var flagged := _unguarded(SCAN_DIRS)
	var unlisted := flagged.filter(func(key): return not EXEMPT.has(key))
	_t.eq("02 no time-varying brightness skips FlashGuard unless EXEMPT says why", unlisted, [])
	_t.check("02b the scan sees the plate pulses and the posture seam", flagged.has("chaser.gd:_material.emission_energy_multiplier")
		and flagged.has("warden_look.gd:_seam_material.emission_energy_multiplier"), str(flagged))
	var stale := []
	for key in EXEMPT:
		var row: Array = EXEMPT[key]
		var file := String(key).split(":")[0]
		var found := false
		for path in _scripts(SRC):
			if path.get_file() == file and _text(path).contains(row[0]):
				found = true
		if not found:
			stale.append("%s: line gone: %s" % [key, row[0]])
		if row[1] != "" and not _text(SRC + row[1]).contains(row[2]):
			stale.append("%s: guard gone: %s in %s" % [key, row[2], row[1]])
		if String(row[3]).is_empty():
			stale.append("%s: no reason" % key)
	_t.eq("02c every EXEMPT line and the guard it leans on still exist", stale, [])
	_t.check("03 the plate pulse stays under the 3 Hz cap and gentle", Enemy.PULSE_HZ <= 1.0 / FlashGuard.MIN_PERIOD and Enemy.PULSE_DEPTH <= 0.2,
		"%s Hz %s deep" % [Enemy.PULSE_HZ, Enemy.PULSE_DEPTH])

	# --- The runtime part ---------------------------------------------------------------
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(2)
	await _sim(0.5)
	var combat = _game.combat

	# The splitter pod's seam blink: burn held at ~1 by a huge warn_seconds, a second of fuse sampled.
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
	var pod = combat.spawn_enemy("splitter_pod", _game.ctx.terrain.drop_point(spawn.x + 6.0, spawn.z, 1.0))
	pod.set_physics_process(false)
	pod.warn_seconds = 1000.0
	pod.phase = Pod.Phase.WARN
	var rest: float = pod._glow.emission_energy_multiplier
	var off := []
	var on := []
	for state in [false, true]:
		FlashGuard.on = state
		var series := []
		for i in 480:
			pod._t = 999.0 + i / 480.0
			pod._pose()
			series.append(pod._glow.emission_energy_multiplier)
		(on if state else off).assign(series)
	FlashGuard.on = false
	_t.check("04 off: the pod blinks faster than 3 Hz (%d cycles in a second)" % _cycles(off), _cycles(off) >= 9)
	_t.check("05 on: the pod blinks at 3 Hz or slower (%d cycles)" % _cycles(on), _cycles(on) <= 3)
	_t.check("05b on: the pod's seam spike is smaller than off", (on.max() - on.min()) < (off.max() - off.min()) * 0.5 and on.max() < off.max(),
		"%s vs %s" % [on.max(), off.max()])
	_t.check("05c the pod rested at a real glow", rest > 0.0)

	# The gap net's crackle: a live net held mid wind-up, sampled over a second of clock.
	var gap = combat.spawn_enemy("gap_net", _game.ctx.terrain.drop_point(spawn.x + 10.0, spawn.z, 1.0))
	await _sim(0.2)
	gap.set_physics_process(false)
	gap.warn_seconds = 1000.0
	gap.phase = GapNet.Phase.WARN
	var gap_mats := {false: [], true: []}
	for state in [false, true]:
		FlashGuard.on = state
		for i in 480:
			gap._t = 900.0 + i / 480.0
			gap._pose()
			for net in gap.nets:
				if net["live"] and is_instance_valid(net["mesh"]) and net["mesh"].get_child_count() > 0:
					gap_mats[state].append(1.0 if (net["mesh"].get_child(0) as MeshInstance3D).material_override == gap._mat_live else 0.0)
					break
	FlashGuard.on = false
	_t.check("06b the gap net has a live net to sample", gap_mats[false].size() == 480, str(gap_mats[false].size()))
	_t.check("06c off: the crackle strobes faster than 3 Hz (%d cycles)" % _cycles(gap_mats[false]), _cycles(gap_mats[false]) >= 9)
	_t.check("06d on: the crackle beats at 3 Hz or slower (%d cycles)" % _cycles(gap_mats[true]), _cycles(gap_mats[true]) <= 3)
	Comfort.reduced_motion = true
	var still := true
	for i in 20:
		gap._t = 999.0 + i * 0.013
		gap._pose()
		for net in gap.nets:
			if net["live"] and is_instance_valid(net["mesh"]) and not (net["mesh"].global_position as Vector3).is_equal_approx(net["origin"]):
				still = false
	Comfort.reduced_motion = false
	_t.check("06e Reduced motion: the net holds still through the wind-up", still)

	# The Kest fuse: loaded and not ready, so it blinks; sampled over a second of clock.
	var ult = combat.ultimate
	ult.set_physics_process(false)
	_t.check("06 the ultimate is the Kest kit", ult.has_method("kest_cage_state"))
	combat._line_load = {"id": "probe", "left": 999.0}
	var fuse := {false: [], true: []}
	for state in [false, true]:
		FlashGuard.on = state
		for i in 16:
			ult._clock = i * 0.0625
			fuse[state].append(float(ult.kest_cage_state()["fuse_glow"]))
	FlashGuard.on = false
	_t.check("07 off: the fuse blinks between 0 and 1", fuse[false].has(0.0) and fuse[false].has(1.0), str(fuse[false]))
	_t.check("08 on: the fuse holds steady at 1", fuse[true].all(func(v): return v == 1.0), str(fuse[true]))

	# The two UI shakes follow Reduced motion, and the refusal flash follows Reduce flashes.
	var bar := AbilityBar.new()
	bar.refuse("line")
	bar._clock = 0.01
	var reticle := AimReticle.new()
	reticle._shake_left = 0.2
	reticle._shake_clock = 0.01
	Comfort.reduced_motion = false
	_t.check("09 off: a refusal and a dry fire shake", bar.shake_offset("line") != Vector2.ZERO and reticle.shake_offset() != Vector2.ZERO)
	Comfort.reduced_motion = true
	_t.check("10 Reduced motion: neither shakes", bar.shake_offset("line") == Vector2.ZERO and reticle.shake_offset() == Vector2.ZERO)
	Comfort.reduced_motion = false
	var full_alpha := bar.flash_color("line").a
	FlashGuard.on = true
	var dim_alpha := bar.flash_color("line").a
	FlashGuard.on = false
	_t.check("11 Reduce flashes: the refusal wash keeps INFO_SHARE of its alpha", full_alpha > 0.0 and is_equal_approx(dim_alpha, full_alpha * FlashGuard.INFO_SHARE),
		"%s -> %s" % [full_alpha, dim_alpha])
	_t.check("12 Game.set_reduced_motion stills both", _set_reaches_ui(bar, reticle))
	_t.check("12b Game.set_reduced_motion sets the one owner, Comfort", _set_reaches_owner())
	bar.free()
	reticle.free()
	quit(_t.verdict())


func _set_reaches_ui(bar, reticle) -> bool:
	var saved: bool = Comfort.reduced_motion
	_game.set_reduced_motion(true)
	var still: bool = bar.shake_offset("line") == Vector2.ZERO and reticle.shake_offset() == Vector2.ZERO
	_game.set_reduced_motion(saved)
	return still and not Comfort.reduced_motion and bar.shake_offset("line") != Vector2.ZERO and reticle.shake_offset() != Vector2.ZERO


func _set_reaches_owner() -> bool:
	_game.set_reduced_motion(true)
	var on: bool = Comfort.reduced_motion and Comfort.motion_scale() == 0.0
	_game.set_reduced_motion(false)
	return on and not Comfort.reduced_motion and Comfort.motion_scale() == 1.0
