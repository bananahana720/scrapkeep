extends SceneTree

const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Contact := preload("res://src/movement/contact.gd")
const Grip := preload("res://src/movement/grip.gd")
const MathUtil := preload("res://src/core/math_util.gd")
const Palette := preload("res://src/core/palette.gd")
const Panels := preload("res://src/build/panels.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Roster := preload("res://src/combat/roster.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")

const KEST_MOVE_CONSTS := [
	"KEST_AIR_DRAW_GRAVITY",
	"KEST_AIR_DRAW_MAX_S",
	"KEST_SPIRE_VAULT_UP",
	"KEST_WALL_KICK_MULT",
	"KEST_WALL_KICK_UP_MULT",
	"KEST_WALL_KICK_CAP",
	"KEST_WALL_KICK_LOCK_S",
]

var _t := T.new("movement_owners_test")


func _initialize() -> void:
	_check_movement_combat_boundary()
	_check_kest_constants_owner()
	_check_slope_dot_owner()
	_check_basis_up_owner()
	_check_steep_face_owner()
	_check_burst_owner()
	_check_build_and_body_owners()
	quit(_t.verdict())


func _src_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(SourceScan.sources(_t, [dir_path]).keys())
	return out


func _check_movement_combat_boundary() -> void:
	var forbidden := [
		"res://src/combat/weapons.gd",
		"res://src/combat/combat.gd",
		"res://src/combat/roster.gd",
	]
	var hits: Array[String] = []
	for path in _src_files("res://src/movement"):
		var text := SourceScan.text(_t, path)
		for target in forbidden:
			if text.contains(target):
				hits.append("%s -> %s" % [path, target])
	_t.check("movement/ does not load combat weapons, combat or roster", hits.is_empty(), str(hits))


func _check_kest_constants_owner() -> void:
	var weapons_src := SourceScan.text(_t, "res://src/combat/weapons.gd")
	var dupes: Array[String] = []
	for name in KEST_MOVE_CONSTS:
		if weapons_src.contains("const " + name):
			dupes.append(name)
	_t.check("KEST movement constants are not declared in combat/weapons.gd", dupes.is_empty(), str(dupes))
	_t.near("Augments.KEST_AIR_DRAW_GRAVITY", Augments.KEST_AIR_DRAW_GRAVITY, 0.45)
	_t.near("Augments.KEST_AIR_DRAW_MAX_S", Augments.KEST_AIR_DRAW_MAX_S, 1.2)
	_t.near("Augments.KEST_SPIRE_VAULT_UP", Augments.KEST_SPIRE_VAULT_UP, 13.5)
	_t.near("Augments.KEST_WALL_KICK_MULT", Augments.KEST_WALL_KICK_MULT, 1.45)
	_t.near("Augments.KEST_WALL_KICK_UP_MULT", Augments.KEST_WALL_KICK_UP_MULT, 1.35)
	_t.near("Augments.KEST_WALL_KICK_CAP", Augments.KEST_WALL_KICK_CAP, 36.0)
	_t.near("Augments.KEST_WALL_KICK_LOCK_S", Augments.KEST_WALL_KICK_LOCK_S, 1.2)


func _check_slope_dot_owner() -> void:
	var owners: Array[String] = []
	for path in _src_files("res://src/movement"):
		var text := SourceScan.text(_t, path)
		if text.contains("const MAX_SLOPE_DOT") or text.contains("const BUMP_FLOOR_DOT"):
			owners.append(path)
	_t.eq("MAX_SLOPE_DOT has one declaration in movement/", owners, ["res://src/movement/tuning.gd"])
	var st := BallState.new()
	st.grounded = true
	st.contact_normal = Vector3(0.0, Tuning.MAX_SLOPE_DOT + 0.01, 0.89).normalized()
	_t.check("BallState.on_floor true above Tuning.MAX_SLOPE_DOT", st.on_floor())
	st.contact_normal = Vector3(0.0, Tuning.MAX_SLOPE_DOT - 0.01, 0.90).normalized()
	_t.check("BallState.on_floor false below Tuning.MAX_SLOPE_DOT", not st.on_floor())
	_t.near("Contact.bump_closing zero above Tuning.MAX_SLOPE_DOT",
		Contact.bump_closing(Vector3(0.0, -10.0, 0.0), Vector3(0.0, Tuning.MAX_SLOPE_DOT + 0.05, 0.85)), 0.0)
	_t.check("Contact.bump_closing positive at wall below Tuning.MAX_SLOPE_DOT",
		Contact.bump_closing(Vector3(-10.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)) > 9.9)


func _check_basis_up_owner() -> void:
	for path in [
		"res://src/movement/player_ball.gd",
		"res://src/build/accretion.gd",
		"res://src/build/panel_shell.gd",
	]:
		var text := SourceScan.text(_t, path)
		_t.check("%s delegates basis_up to MathUtil" % path,
			not text.contains("func _align_up(") and not text.contains("func _facing(") and text.contains("MathUtil.basis_up("))
	for dir in [
		Vector3.UP,
		Vector3.DOWN,
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.FORWARD,
		Vector3(0.95, 0.2, 0.24),
		Vector3(0.3, 0.8, -0.5),
	]:
		var b: Basis = MathUtil.basis_up(dir)
		_t.check("MathUtil.basis_up(%s) orthonormal right-handed" % str(dir),
			b.y.is_equal_approx(dir.normalized())
			and is_equal_approx(b.x.length(), 1.0)
			and is_equal_approx(b.z.length(), 1.0)
			and absf(b.x.dot(b.y)) < 0.0001
			and absf(b.y.dot(b.z)) < 0.0001
			and is_equal_approx(b.determinant(), 1.0),
			str(b))


func _check_steep_face_owner() -> void:
	var ball_src := SourceScan.text(_t, "res://src/movement/player_ball.gd")
	var kest_src := SourceScan.text(_t, "res://src/movement/kest_air.gd")
	_t.check("player_ball.gd uses Augments.steepest_face_at",
		not ball_src.contains("func _kest_steep_face") and not kest_src.contains("func _kest_steep_face")
		and kest_src.contains("Augments.steepest_face_at("))


func _check_burst_owner() -> void:
	var harpoon_src := SourceScan.text(_t, "res://src/movement/harpoon.gd")
	var ball_src := SourceScan.text(_t, "res://src/movement/player_ball.gd")
	_t.check("harpoon.gd no longer owns burst readiness",
		not harpoon_src.contains("func burst_wait") and not harpoon_src.contains("func burst_ready"))
	_t.check("player_ball.gd no longer duplicates burst list",
		not ball_src.contains("func _burst_pilot") and ball_src.contains("Augments.has_burst("))
	_t.eq("Augments.BURST_ABILITIES holds all five burst keys",
		Augments.BURST_ABILITIES,
		[Augments.SPRINT, Augments.BLINK, Augments.CLAW_PULL, Augments.SURGE, Augments.RECOIL])
	for def in ClassDef.all():
		var kit := AugmentKit.new()
		kit.abilities.fit(def)
		kit.fit(def.movement_id, def.smash_id)
		var expect_burst: bool = def.id != "pylon_engineer"
		_t.eq("has_burst for %s" % def.id, Augments.has_burst(kit), expect_burst)
		_t.eq("burst_ready fresh for %s" % def.id, Augments.burst_ready(kit), expect_burst)
		kit.mounted = true
		_t.eq("burst_ready false while mounted for %s" % def.id, Augments.burst_ready(kit), false)
		kit.mounted = false
	var kest := AugmentKit.new()
	kest.abilities.fit(ClassDef.by_id("demolitions_caster"))
	kest.fit(ClassDef.by_id("demolitions_caster").movement_id, ClassDef.by_id("demolitions_caster").smash_id)
	kest.abilities.spend(AbilityState.MOVEMENT)
	_t.check("spent blink wait is positive", Augments.burst_wait(kest) > 0.0 and not Augments.burst_ready(kest))
	kest.cloaked = true
	kest.tree._knobs["cloak_free_blink"] = true
	_t.check("cloaked free blink overrides cooldown", Augments.burst_wait(kest) == 0.0 and Augments.burst_ready(kest))
	var rivet := AugmentKit.new()
	rivet.abilities.fit(ClassDef.by_id("runner_gunner"))
	rivet.fit(ClassDef.by_id("runner_gunner").movement_id, ClassDef.by_id("runner_gunner").smash_id)
	rivet.sprinting = true
	_t.check("active sprint is not ready again", Augments.burst_wait(rivet) == INF and not Augments.burst_ready(rivet))
	_t.eq("Grip.grip flail band", Grip.grip(2.0, 1.4), Grip.FLAIL)
	_t.check("Roster.heft_of null is INF", Roster.heft_of(null) == INF)


func _check_build_and_body_owners() -> void:
	var ball_src := SourceScan.text(_t, "res://src/movement/player_ball.gd")
	_t.check("player_ball.gd removes active_body alias",
		not ball_src.contains("func active_body(") and ball_src.contains("func body()"))
	var stat_cache_src := SourceScan.text(_t, "res://src/build/stat_cache.gd")
	_t.check("stat_cache.gd delegates counting and folding to BuildSheet",
		not stat_cache_src.contains("func _counted(")
		and not stat_cache_src.contains("func _refold(")
		and not stat_cache_src.contains("func _fold_mods(")
		and not stat_cache_src.contains("func _fold_patterns(")
		and not stat_cache_src.contains("func _fold_elements(")
		and stat_cache_src.contains("BuildSheet.counted_defs(")
		and stat_cache_src.contains(".refold_category("))
	_t.eq("BuildSheet.counted_defs resolves single held part", BuildSheet.counted_defs(["hot_rivets"]).size(), 1)
	for path in [
		"res://src/build/accretion.gd",
		"res://src/build/element_field.gd",
	]:
		var text := SourceScan.text(_t, path)
		_t.check("%s uses Palette.ICE without redeclaring ICE" % path,
			not text.contains("const ICE ") and not text.contains("const ICE:") and not text.contains('Color("c8f0ff")') and text.contains("Palette.ICE"))
	for path in [
		"res://src/build/build.gd",
		"res://src/build/item_effects.gd",
	]:
		var text := SourceScan.text(_t, path)
		_t.check("%s uses Palette.ICE instead of ElementField.ICE" % path,
			not text.contains("ElementField.ICE"))
	var fab_src := SourceScan.text(_t, "res://src/build/fabricators.gd")
	_t.check("fabricators.gd delegates rarity color to RewardGates.rarity_color",
		not fab_src.contains("func _rarity_color(") and fab_src.contains("RewardGates.rarity_color("))
	_t.eq("RewardGates.rarity_color common matches Palette.ARC", RewardGates.rarity_color("common"), Palette.ARC)
	var panels_src := SourceScan.text(_t, "res://src/build/panels.gd")
	_t.eq("panels.gd defines drop_row once", panels_src.count("func drop_row("), 1)
	_t.eq("Panels.drop_row(1) reads world 1 table", Panels.drop_row(1), Panels.DROP_BY_WORLD[1])
	_t.eq("Panels.drop_row(99) falls back to DROP", Panels.drop_row(99), Panels.DROP)
	var cons_src := SourceScan.text(_t, "res://src/build/consumables.gd")
	_t.check("consumables.gd inlines cache clear in reset_for_tests",
		not cons_src.contains("func _reset(") and cons_src.contains("func reset_for_tests("))
