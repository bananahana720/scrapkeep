extends SceneTree
# F6 2026-10-04: the Warden magnet ring is gone; the pulse and core rings stay.

const Game := preload("res://src/game.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Warden := preload("res://src/combat/warden.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")

# Every telegraph and hazard is created with an explicit attack type: the source names
# one at each creation site, no factory defaults it, and the live game tags each attack
# with the type its audit row in DESIGN-NOTES (v2 W2) gives it. Each type's warn sound
# has its own recipe.

const DT := 1.0 / 90.0
const CREATION := "(Telegraph\\.(ring|lane|wedge|wave)|_commit_ring|_commit_lane|\\.commit_(sector|annulus|lane))\\("
const NAMED := "Type\\.(INSTANT|WAVE|PROJECTILE|LANE)|\\bthreat_type\\b"
const FOLDERS := ["res://src/combat", "res://src/boss"]
# The audit: file -> the type each creation site in it passes, in source order.
const AUDIT := {
	"res://src/combat/enemy.gd": ["threat_type", "threat_type"],
	"res://src/combat/chaser.gd": ["LANE"],
	"res://src/combat/miniboss.gd": ["PROJECTILE", "LANE"],
	# 2026-10-04 (wave 9): the scanner now finds a third (LANE) site. 2026-10-19 (Challenge): the
	# counter-pulse ring is a fourth, INSTANT like the core ring it shares. 2026-11-25 (W46-S1):
	# mounted World 1 reactor splashes add overheat ring (INSTANT), flume jet lane (LANE), and dam
	# vent ring (INSTANT) before the slag lane and pulse/counter rings.
	"res://src/combat/warden.gd": ["INSTANT", "LANE", "INSTANT", "LANE", "INSTANT", "INSTANT", "INSTANT"],
	"res://src/combat/projectile.gd": ["PROJECTILE", "PROJECTILE"],
	# 2026-11-12 (FX-03): the phase beat's harmless previews come first in source order, a bone slag ring and a bone charge lane.
	"res://src/boss/boss.gd": ["INSTANT", "LANE", "WAVE", "INSTANT", "INSTANT", "LANE", "INSTANT"],
	# v2 W7 counter units and ancients: one telegraph each, in its threat type.
	# 2026-11-24 W47-E3: mag_trapper adds Polarity Repulse Ring (INSTANT) alongside its primary pit ring.
	"res://src/combat/mag_trapper.gd": ["INSTANT", "INSTANT"],
	"res://src/combat/netcaster.gd": ["INSTANT"],
	"res://src/combat/plated_brute.gd": ["INSTANT", "LANE", "INSTANT", "INSTANT"],  # 2026-10-15 (w13 close): SG6's stamp, rail and rear-blast sites, then the slam.
	"res://src/combat/gyro_jammer.gd": ["INSTANT"],
	"res://src/combat/swatter.gd": ["INSTANT"],
	"res://src/combat/ramp_flipper.gd": ["INSTANT"],
	"res://src/combat/catch_trap.gd": ["INSTANT"],
	"res://src/combat/reactor_relic.gd": ["INSTANT"],
	"res://src/combat/hooker.gd": ["LANE"],
	"res://src/combat/deflector.gd": ["LANE"],
	"res://src/combat/winch_drone.gd": ["LANE"],
	"res://src/combat/swarm_remnant.gd": ["LANE"],
	"res://src/combat/mind_hand.gd": ["LANE"],
	"res://src/combat/bola_thrower.gd": ["PROJECTILE"],
	# 2026-10-04 (wave 9): six new enemies, one telegraph each.
	# 2026-11-25 (W48-COMBAT): 5 Dig 2-attack kits add secondary LANE/INSTANT/PROJECTILE sites.
	"res://src/combat/anchor_crew.gd": ["LANE"],
	"res://src/combat/burrower.gd": ["LANE", "INSTANT"],
	"res://src/combat/drill_crew.gd": ["LANE", "INSTANT"],
	"res://src/combat/kite_drone.gd": ["LANE", "INSTANT"],
	"res://src/combat/lamp_swarm.gd": ["LANE", "WAVE"],
	"res://src/combat/line_cutter.gd": ["LANE", "PROJECTILE"],
	"res://src/combat/pit_jaw.gd": ["PROJECTILE", "INSTANT"],
	"res://src/combat/prop_crew.gd": ["INSTANT"],
	"res://src/combat/boom_tender.gd": ["LANE"],
	# 2026-10-17 (wave 18): the Splitter's fuse blast.
	"res://src/combat/splitter_pod.gd": ["INSTANT"],
	# 2026-10-24 (pack pressure E, flag only): the silt boil ring.
	"res://src/combat/silt_boil.gd": ["INSTANT"],
	# 2026-10-17 (stage/alpha-w16): the Dispatcher's tube drop (#59) and the jolt layer's mat (#65).
	"res://src/combat/dispatcher.gd": ["PROJECTILE"],
	# 2026-11-24 W47-E3: Foreman's Overtime Sync Whistle commits an INSTANT HAZARD ring.
	"res://src/combat/foreman.gd": ["INSTANT"],
	"res://src/combat/jolt_layer.gd": ["LANE", "INSTANT"],  # 2026-11-25 (W47-E2): Cable Whip Overload lane + primary mat ring.
	# 2026-10-17 Highdraft roster: the ballast heavy and the gap net.
	# 2026-11-25 (W49-COMBAT): Highdraft 2-attack kits add secondary LANE sites.
	"res://src/combat/ballast_heavy.gd": ["LANE", "INSTANT"],
	"res://src/combat/gap_net.gd": ["LANE"],
	# 2026-10-23 rogue fleet mini-bosses (#385): sweep, haul and harpoon lanes; drop and dump rings; the whip ring.
	# 2026-11-17 MG-11: the sweep's lane leads a held line, so it commits apart from haul and harpoon.
	"res://src/combat/rogue.gd": ["LANE", "LANE", "PROJECTILE", "PROJECTILE", "INSTANT"],
	"res://src/boss/hazard.gd": ["descriptor", "descriptor", "descriptor"],
}
# Descriptor-built hazards: file -> the type each _base( descriptor names, in source order.
const DESCRIPTORS := {
	"res://src/boss/mind_attacks.gd": ["INSTANT", "WAVE", "LANE"],
}
const FACTORIES := {
	"res://src/combat/telegraph.gd": ["ring", "lane", "wedge"],
	"res://src/boss/hazard.gd": ["commit_sector", "commit_annulus", "commit_lane"],
	"res://src/combat/enemy.gd": ["_commit_ring", "_commit_lane"],
}

# Preserve the legacy three-stage rule on a double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _step := 0


func _initialize() -> void:
	_check_sources()
	_check_factories()
	_check_sounds()
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _step == 0:
		_step = 1
		_check_boss()
		_game.free()
		_game = LegacyGame.new()
		_game.test_mode = true
		root.add_child(_game)
		return false
	_check_combat()
	print("threat_sites_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key) or str(a[key]) != str(b[key]):
			return false
	return true


func _check_sources() -> void:
	var found := {}
	var sources := SourceScan.sources(self, FOLDERS)
	for path in sources:
		if not String(path).get_base_dir() in FOLDERS:
			continue
		var file := String(path).get_file()
		var lines := String(sources[path]).split("\n")
		for i in lines.size():
			var line: String = lines[i].strip_edges()
			if line.begins_with("func ") or line.begins_with("static func ") or line.begins_with("#"):
				continue
			var calls := SourceScan.search(self, line, CREATION)
			if calls.is_empty():
				continue
			var hit := calls[0]
			if hit.get_string(2) == "wave":
				(found.get_or_add(path, []) as Array).append("WAVE")
				continue
			if line.contains("d[\"type\"]"):
				(found.get_or_add(path, []) as Array).append("descriptor")
				continue
			var tags := SourceScan.search(self, line.substr(hit.get_end()), NAMED)
			var tag: RegExMatch = null if tags.is_empty() else tags[0]
			(found.get_or_add(path, []) as Array).append(tag.get_string(1) if tag != null and tag.get_string(1) != "" else ("threat_type" if tag != null else "none (%s:%d)" % [file, i + 1]))
	var sites := 0
	for path in found:
		sites += (found[path] as Array).size()
	check("explicit type at every site", _same(found, AUDIT),
		"%d creation sites in combat and boss, each naming its type: %s" % [sites, found])
	var described := {}
	for path in DESCRIPTORS:
		for line in SourceScan.text(self, path).split("\n"):
			line = line.strip_edges()
			if line.begins_with("static func ") or line.begins_with("func ") or not line.contains("_base("):
				continue
			var tags := SourceScan.search(self, line, NAMED)
			var tag: RegExMatch = null if tags.is_empty() else tags[0]
			(described.get_or_add(path, []) as Array).append(tag.get_string(1) if tag != null and tag.get_string(1) != "" else "none")
	check("explicit type in every descriptor", _same(described, DESCRIPTORS),
		"each hazard descriptor names its type: %s" % [described])


func _check_factories() -> void:
	var loose: Array = []
	for path in FACTORIES:
		var script: Script = load(path)
		for method in script.get_script_method_list():
			if not method["name"] in FACTORIES[path]:
				continue
			var args: Array = method["args"].map(func(a): return a["name"])
			var at := args.find("threat_type")
			if at < 0 or at >= args.size() - (method["default_args"] as Array).size():
				loose.append("%s.%s(%s)" % [path.get_file(), method["name"], ", ".join(args)])
	check("no default type", loose.is_empty(),
		"every telegraph, hazard and enemy factory takes the attack type as a required argument; loose: %s" % [loose])


func _check_sounds() -> void:
	var bad: Array = []
	for type in Threat.KINDS.size():
		var id: String = Threat.row(type).get("sound", "")
		var wav := SfxBank.stream(id)
		if not SfxBank.has_recipe(id) or Synth.wav_peak(wav) < 0.1:
			bad.append(id)
	check("warn sounds", bad.is_empty(), "each type's warn sound has its own non-silent recipe; failing %s" % [bad])


func _check_combat() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.flow.enter_stage(3, Vector3.ZERO, false)
	var ball: Vector3 = _game.player.ball_position()
	var tags := {}
	var chaser: Node3D = ctx.spawner.spawn_enemy("chaser", ball + Vector3(8.0, 0.0, 0.0))
	chaser._begin_windup(ball - chaser.global_position)
	tags["chaser lunge"] = chaser.telegraph()
	var miniboss: Node3D = ctx.spawner.spawn_enemy("miniboss", ball + Vector3(-14.0, 0.0, 0.0))
	miniboss._begin_attack(ball - miniboss.global_position)
	tags["miniboss leap slam"] = miniboss.telegraph()
	var slam_has_flight: bool = miniboss.telegraph() != null and miniboss.telegraph().descriptor().has("launch")
	miniboss._begin_attack(ball - miniboss.global_position)
	tags["miniboss charge"] = miniboss.telegraph()
	var warden: Node3D = ctx.spawner.spawn_enemy("warden", ball + Vector3(0.0, 0.0, 12.0))
	warden._pulse_clock = Warden.PULSE_CYCLE - Warden.PULSE_TELEGRAPH
	warden._step_pulse(DT, true)
	tags["warden pulse"] = warden.telegraph()
	tags["warden core"] = warden.get("_core_ring")
	ctx.spawner._on_lobber_fired(ball + Vector3(20.0, 3.0, 0.0), ball, 1.9, null)
	for shell in _game.get_tree().get_nodes_in_group("enemy_shot"):
		tags["lobber shell"] = shell.ring
	var want := {"chaser lunge": "LANE", "miniboss leap slam": "PROJECTILE", "miniboss charge": "LANE", "warden pulse": "INSTANT",
		"warden core": "INSTANT", "lobber shell": "PROJECTILE"}
	var got := {}
	for key in want:
		var node = tags.get(key)
		got[key] = Threat.Type.keys()[node.type] if node != null and Threat.valid(node.type) else "missing"
	var lift_harmless: bool = tags["warden pulse"] != null and not tags["warden pulse"].is_hostile() and tags["warden core"] != null and tags["warden core"].is_hostile()
	check("combat attacks tagged", _same(got, want) and slam_has_flight and lift_harmless,
		"live combat telegraphs carry their audited types %s; the leap slam draws the miniboss's flight: %s; the Warden's lift ring is a harmless field and its core ring a threat: %s"
			% [got, slam_has_flight, lift_harmless])


func _check_boss() -> void:
	Harness.install(_game)
	var boss = _game.boss
	_game.ctx.calm = false
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	var want := {"crane": "WAVE", "slag": "INSTANT", "charge": "LANE", "drone_pad": "INSTANT"}
	var got := {}
	var grouped := true
	for phase in 3:
		if phase > 0:
			boss.jump_to_phase(phase + 1)
		var until: float = boss.clock + 14.0
		while boss.clock < until:
			boss.advance(DT)
			_game.run.heal(1000.0)
			var live: Array = boss.active_hazards()
			for d in boss.get("_drones"):
				live.append(d["marker"])
			for h in live:
				if not is_instance_valid(h):
					continue
				grouped = grouped and h.is_in_group(Threat.GROUP) == (h.attack_id != "drone_pad")
				for family in want:
					if h.attack_id.begins_with(family):
						got[family] = Threat.Type.keys()[h.type] if Threat.valid(h.type) else "unset"
	check("boss attacks tagged", _same(got, want) and grouped,
		"Brindle's hazards carry their audited types %s, each attack in group %s and the amber drone pad out of it: %s" % [got, Threat.GROUP, grouped])
