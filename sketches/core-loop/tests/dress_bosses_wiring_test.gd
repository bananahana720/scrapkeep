extends SceneTree

const Game := preload("res://src/game.gd")
const BossHarness := preload("res://tests/doubles/boss_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const Warden := preload("res://src/combat/warden.gd")
const T := preload("res://tests/support/t.gd")

# The boss GLBs are wired into the running game, and each primitive stays as the fallback.
# For Brindle, the Waking, the Mind and a Mind hand this enters the real arena (or spawns the
# real enemy) and checks the visible meshes come from the GLB, the clip matches the state the
# script tracks (a phase turn, a committed attack, a stagger, a floor warning), and that with
# the GLB path pointed at a missing file the primitive body is built instead. Gameplay is
# untouched; this only reads what the dress nodes added.
#
# Evidence limit: headless, no GPU. Clip names are read from the AnimationPlayers; what the
# clips look like is the coordinator's capture.

const MISSING := "res://assets/models/bosses/__missing__.glb"
const FRAME_CAP := 90 * 40

var _t := T.new("dress_bosses_wiring_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.calm = true
	await _brindle()
	await _waking()
	await _mind()
	await _hand()
	_game.free()
	quit(_t.verdict())


# Visible meshes under a node: layers on and every ancestor up to the node visible.
func _visible_meshes(node: Node) -> Array:
	var out: Array = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var shown: bool = mesh.layers != 0 and mesh.mesh != null
		var walk: Node = mesh
		while walk != null and walk != node.get_parent():
			if walk is Node3D and not walk.visible:
				shown = false
			walk = walk.get_parent()
		if shown:
			out.append(mesh)
	return out


func _from_glb(meshes: Array) -> Array:
	return meshes.filter(func(m): return m.mesh is ArrayMesh)


func _primitive(meshes: Array) -> Array:
	return meshes.filter(func(m): return m.mesh is BoxMesh or m.mesh is CylinderMesh or m.mesh is SphereMesh or m.mesh is CapsuleMesh)


# --- Brindle -----------------------------------------------------------------------------

func _brindle() -> void:
	var game = _game
	game.ctx.spawner = game.combat
	var boss = game.boss
	BossHarness.start_run(game)
	BossHarness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	var ship = boss.ship
	_t.check("Brindle builds the fortress GLB", ship.model != null and ship.model.get_child_count() > 0,
			"model %s" % [ship.model])
	var meshes := _visible_meshes(ship)
	var named := meshes.map(func(m): return String(m.name))
	# The two modelled cable spans keep their original moving endpoints.
	var prims := _primitive(meshes)
	_t.check("Brindle shows the GLB hull, drums, armour and two vertex-coloured cable spans",
			named.has("Hull") and named.has("DrumL0") and named.has("Armour0") and named.has("CraneMasts") and prims.is_empty()
			and named.has("CableSpan0") and named.has("CableSpan1")
			and ship._cables.all(func(c): return c.mesh is ArrayMesh and c.material_override.vertex_color_use_as_albedo),
			"%d visible, %d primitives, hull named %s" % [meshes.size(), prims.size(), named.has("Hull")])
	_t.eq("phase 1 plays the idle roll", ship._anim.assigned_animation, "idle_roll")
	boss.jump_to_phase(2)
	_t.eq("phase 2 plays enter_furnace", ship._anim.assigned_animation, "enter_furnace")
	boss.jump_to_phase(3)
	_t.eq("phase 3 plays enter_scuttle", ship._anim.assigned_animation, "enter_scuttle")
	# The clip blows the panels off on the model, so they stay visible until it has played.
	_t.check("phase 3 entry keeps the armour up for enter_scuttle to blow off",
			ship._model_armour.all(func(p): return p.visible))
	_t.check("phase 3 entry keeps the shield up for enter_scuttle to flip", ship._model_shield.visible)
	ship._anim.advance(ship._anim.get_animation("enter_scuttle").length + 0.05)
	var armour_shed: bool = ship._model_armour.all(func(p): return not p.visible)
	_t.check("phase 3 sheds the model's armour and opens its shield", armour_shed and not ship._model_shield.visible,
			"armour shed %s, shield visible %s" % [armour_shed, ship._model_shield.visible])
	boss._commit_charge()
	_t.eq("a committed charge plays charge_warn", ship._anim.assigned_animation, "charge_warn")
	boss._stun(2.0)
	_t.eq("a wall stun plays wall_stun", ship._anim.assigned_animation, "wall_stun")
	boss.jump_to_phase(4)
	_t.eq("the eject plays on the hull", ship._anim.assigned_animation, "eject")
	var scooter_model: Node = boss.scooter.get_node_or_null("ScooterModel")
	_t.check("the eject builds the scooter GLB", scooter_model != null and boss._scooter_anim != null
			and boss._scooter_anim.assigned_animation == "eject", "model %s" % [scooter_model])
	var scooter_prims := _primitive(_visible_meshes(boss.scooter))
	_t.check("the scooter's box is hidden behind the model", scooter_prims.is_empty(), "%d primitives" % scooter_prims.size())
	var frames := 0
	while not boss.scooter_landed() and frames < FRAME_CAP:
		boss.advance(1.0 / 90.0)
		frames += 1
	_t.check("the landed scooter runs the chase clip", boss.scooter_landed() and boss._scooter_anim.assigned_animation == "chase",
			"landed %s, clip %s" % [boss.scooter_landed(), boss._scooter_anim.assigned_animation])
	boss.exit_arena()
	# Fallback: the same arena with the GLB missing keeps the primitive fortress.
	Requisition.model_path = MISSING
	Requisition.scooter_path = MISSING
	BossHarness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	ship = boss.ship
	var fallback := _visible_meshes(ship)
	var fallback_names := fallback.map(func(m): return String(m.name))
	var box_hull: bool = fallback.any(func(m): return m.mesh is BoxMesh and (m.mesh as BoxMesh).size == Requisition.HULL)
	_t.check("with the GLB missing Brindle builds the box fortress", ship.model == null and not fallback_names.has("Hull") and box_hull
			and _primitive(fallback).size() >= 10, "model %s, hull box %s, %d primitives" % [ship.model, box_hull, _primitive(fallback).size()])
	boss.jump_to_phase(4)
	_t.check("with the GLB missing the scooter stays a box", boss.scooter.get_node_or_null("ScooterModel") == null
			and boss._scooter_anim == null and _primitive(_visible_meshes(boss.scooter)).size() == 1, "scooter %s" % [boss.scooter])
	boss.exit_arena()
	Requisition.model_path = Requisition.MODEL
	Requisition.scooter_path = Requisition.SCOOTER_MODEL


# --- The Waking --------------------------------------------------------------------------

func _waking() -> void:
	var game = _game
	Harness.boot(game)
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	var warden = mod.warden
	_t.check("the Waking builds the architecture and the seat kit", mod._dress != null and mod._dress.base != null and warden.get_node_or_null("WakingKit") != null,
			"dress %s" % [mod._dress])
	await physics_frame
	var body := _from_glb(_visible_meshes(warden))
	var native := _primitive(_visible_meshes(warden))
	_t.check("only the kit meshes show under the Waking's Warden", body.size() >= 8 and native.is_empty(), "%d GLB, %d primitives" % [body.size(), native.size()])
	var core: Node3D = warden.get_node("WakingKit").find_child("CoreSocket", true, false)
	_t.check("the kit's core sits on the Warden's family point", core.global_position.distance_to(warden.family_point_at()) < 0.01,
			"core %s, point %s" % [core.global_position, warden.family_point_at()])
	_t.check("the architecture hangs at the pit's centre", absf(mod._dress.base.global_position.y - mod._center.y) < 0.01
			and mod._dress.base.find_child("BellHousing", true, false).global_position.y > mod._center.y + 20.0, "base %s" % [mod._dress.base.global_position])
	_t.eq("the fight opens on the wake clip", mod._dress._kit_anim.assigned_animation, "wake")
	mod._dropping = 1
	mod._drop_left = 1.0
	await physics_frame
	_t.eq("a floor warning plays its collar clip", mod._dress._kit_anim.assigned_animation, "floor_warn")
	mod._drop_left = 0.0
	await physics_frame
	_t.eq("the floor drop plays its clip", mod._dress._kit_anim.assigned_animation, "floor_drop")
	var frames := 0
	while not warden.staggered() and frames < FRAME_CAP:
		if frames % 20 == 0:
			Harness.hit(mod)
		frames += 1
		await physics_frame
	await physics_frame
	_t.check("a stagger opens the core on its own player", warden.staggered() and mod._dress._core_anim.assigned_animation == "core_open",
			"staggered %s, clip %s" % [warden.staggered(), mod._dress._core_anim.assigned_animation])
	mod.exit_arena()
	WakingDress.base_path = MISSING
	Harness.enter_world(game, 2)
	mod = Harness.module(game, 2)
	await physics_frame
	_t.check("with the GLB missing the Waking keeps the stub Warden body", mod._dress == null and mod.warden.get_node_or_null("WakingKit") == null
			and mod.warden._look.visible, "dress %s, kit %s, look %s, warden %s" % [mod._dress, mod.warden.get_node_or_null("WakingKit"), mod.warden._look.visible, mod.warden])
	mod.exit_arena()
	WakingDress.base_path = WakingDress.BASE


# --- The Mind ----------------------------------------------------------------------------

func _mind() -> void:
	var game = _game
	Harness.boot(game)
	Harness.enter_world(game, 3)
	var mod = Harness.module(game, 3)
	var warden = mod.warden
	_t.check("the Mind builds the crown and the seat kit", mod._dress != null and warden.get_node_or_null("MindKit") != null, "dress %s" % [mod._dress])
	await physics_frame
	var body := _from_glb(_visible_meshes(warden))
	var native := _primitive(_visible_meshes(warden))
	_t.check("only the kit meshes show under the Mind's Warden", body.size() >= 8 and native.is_empty(), "%d GLB, %d primitives" % [body.size(), native.size()])
	var crown: Node3D = mod._dress.base.find_child("CrownFrame", true, false)
	_t.check("the crown stands over the pad at the final boss's scale", crown.global_position.y > mod.pad.global_position.y + 20.0, "crown y %s" % crown.global_position.y)
	var lens: Node3D = mod._dress._lens
	_t.check("the lens rides the Warden's open choir seat", lens.global_position.distance_to(warden.family_point_at()) < 0.01,
			"lens %s, seat %s" % [lens.global_position, warden.family_point_at()])
	var frames := 0
	var seen := 0
	var warn_ok := true
	var clips: Array = []
	while seen < 2 and frames < FRAME_CAP:
		await physics_frame
		frames += 1
		if mod.attack_count > seen:
			seen = mod.attack_count
			var family: String = String(mod._family)
			var clip: String = mod._dress._kit_anim.assigned_animation
			clips.append("%s:%s" % [family, clip])
			warn_ok = warn_ok and clip == MindDress.FAMILY_CLIPS[family]
	_t.check("each committed attack plays its family warning clip", seen >= 2 and warn_ok, "attacks %s" % [clips])
	var strike := false
	frames = 0
	while frames < 400 and not strike:
		await physics_frame
		frames += 1
		strike = mod._dress._kit_anim.assigned_animation == "family_strike"
	_t.check("a live hazard plays the family strike", strike, "frames %d" % frames)
	mod.exit_arena()
	MindDress.base_path = MISSING
	Harness.enter_world(game, 3)
	mod = Harness.module(game, 3)
	await physics_frame
	_t.check("with the GLB missing the Mind keeps the stub Warden body", mod._dress == null and mod.warden.get_node_or_null("MindKit") == null
			and mod.warden._look.visible, "dress %s" % [mod._dress])
	mod.exit_arena()
	MindDress.base_path = MindDress.BASE


# --- A Mind hand -------------------------------------------------------------------------

func _hand() -> void:
	var game = _game
	game.ctx.spawner = game.combat
	var hand = game.ctx.spawner.spawn_enemy("mind_hand", Vector3(100, 20, 100))
	hand.set_physics_process(false)
	await process_frame
	_t.check("the Mind hand builds the skinned GLB", hand._model != null and hand._anim != null and hand._anim.assigned_animation == "still_track",
			"model %s" % [hand._model])
	var meshes := _visible_meshes(hand)
	_t.check("only the skin shows on the hand", _from_glb(meshes).size() == 1 and _primitive(meshes).is_empty(),
			"%d GLB, %d primitives" % [_from_glb(meshes).size(), _primitive(meshes).size()])
	_t.near("the hand keeps its collider radius", hand.radius, 0.7)
	hand.phase = MindHand.Phase.WARN
	hand._pose()
	_t.eq("a committed quote plays quote_warn", hand._anim.assigned_animation, "quote_warn")
	hand.phase = MindHand.Phase.LIVE
	hand._pose()
	_t.eq("the strike plays exact_strike then queues the brace", hand._anim.assigned_animation, "exact_strike")
	hand.phase = MindHand.Phase.ROAM
	hand._pose()
	_t.eq("the end of the brace plays the recovery", hand._anim.assigned_animation, "recover")
	hand.free()
	MindHand.model_path = MISSING
	var plain = game.ctx.spawner.spawn_enemy("mind_hand", Vector3(100, 20, 100))
	plain.set_physics_process(false)
	await process_frame
	var plain_meshes := _visible_meshes(plain)
	_t.check("with the GLB missing the hand keeps its primitives", plain._model == null and _from_glb(plain_meshes).is_empty()
			and _primitive(plain_meshes).size() >= 8, "model %s, %d primitives" % [plain._model, _primitive(plain_meshes).size()])
	plain.free()
	MindHand.model_path = MindHand.MODEL
