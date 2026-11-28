extends "res://tests/kest_kit_test.gd"

# 2026-10-12 (PC-KEST round 4): the shared runner adds three Cable Charge bot-hand fixtures.

# 2026-10-11 (PC-KEST): fixed-step carrier, payload and posture integration.
# Expected 63 checks, including count guard. The bot suite separately runs real physics.
# 2026-11-08 (w32 gate): 62 -> 63. #624 (ruling bl, d244fbb8) added the inherited "waits out the
# re-press gap" bite-hand check to kest_kit_test; this count was not bumped with it.
const EXPECTED_SET_PIECE_CHECKS := 63
const Kest := preload("res://src/combat/kest_kit.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")

var _peak_modes: Array = []
var _cloak_breaks: Array = []


func _expected() -> int:
	return EXPECTED_SET_PIECE_CHECKS


func _aim(at: Vector3) -> Dictionary:
	var origin: Vector3 = _player.ball_position() + Vector3.UP * 2.0
	return {"origin": origin, "forward": (at - origin).normalized(), "harpoon": {"state": 0}}


func _begin(id: String, p: Dictionary) -> void:
	_player.abilities.ultimate_id = id
	_ult.meter.locked = false
	_ult.meter.refund(100.0)
	_player.intent.clear()
	_ult.start(p)


func _advance(dt := DT) -> void:
	if _ult.phase() == "flight":
		_player.body().global_position = _ult._expected
	_combat._tick_cloak(dt)
	_ult.step(dt)


func _ride_out() -> void:
	for i in 420:
		if not _ult.active():
			return
		_advance()


func _simple_plan(to: Vector3, mode := "arc", beats := 6) -> Dictionary:
	var seconds: float = beats * 60.0 / 172.0
	return {"path": mode, "from": _player.ball_position(), "to": to, "target": null, "beats": beats,
		"flight": seconds, "seconds": 0.35 + seconds,
		"legs": [{"mode": mode, "to": to, "beats": beats, "seconds": seconds, "strike": true}]}


func _cases() -> void:
	_ult.beat_seconds = func() -> float: return 60.0 / 172.0
	_game.events.ultimate_peak.connect(func(_id: String, _at: Vector3): _peak_modes.append(_ult.leg_state()["mode"]))
	_game.events.cloak_broken.connect(func(reason: String): _cloak_breaks.append(reason))
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	collider.shape = box
	floor.add_child(collider)
	_game.add_child(floor)
	floor.global_position = _player.ball_position() + Vector3.DOWN * 1.5
	var home: Vector3 = _player.ball_position()
	var b := home + Vector3(30.0, -1.0, 0.0)
	await physics_frame
	await physics_frame

	for heft in [1, 5]:
		_fresh()
		_player.body().global_position = home
		_game.run.mass = 0.0 if heft == 1 else 1700.0
		var enemies: Array = []
		for i in 8:
			enemies.append(_enemy(b + Vector3(0.0, 0.5, i - 3.5)))
		var p: Dictionary = _ult.plan(home, _aim(b))
		_t.eq("Windhover modes class %d" % heft, p["legs"].map(func(l): return l["mode"]), ["arc", "hold", "line"])
		_t.near("H is 14 m over B class %d" % heft, (p["hover"] as Vector3).y - (p["to"] as Vector3).y, 14.0)
		_t.eq("two hold beats class %d" % heft, p["legs"][1]["beats"], 2)
		_t.eq("one beat stoop class %d" % heft, p["legs"][2]["beats"], 1)
		_peak_modes.clear()
		_cloak_breaks.clear()
		_ult.volley_log.clear()
		_begin("windhover", p)
		var cloaked := true
		for i in 420:
			if not _ult.active():
				break
			_advance()
			cloaked = cloaked and _player.kit.cloaked
		_t.check("cloak holds through every phase class %d" % heft, cloaked and not _cloak_breaks.has("shot"))
		_t.eq("peak occurs in hold class %d" % heft, _peak_modes, ["hold"])
		_t.check("volleys respect target cap and B class %d" % heft,
			_ult.volley_log.size() > 2 and _ult.volley_log.all(func(v): return v["targets"] <= Kest.targets_for_class(heft) and v["centre"] == p["to"]))
		_t.check("stoop hits eight enemies class %d" % heft, _ult.record()["landing_hits"] == 8)
		_t.check("cloak runs 1.5 seconds after landing class %d" % heft, _combat.cloak_left > 1.20 and _combat.cloak_left <= 1.5)
		_t.eq("satchel count matches targets class %d" % heft, _ult.kest_cage_state()["satchel_bands"], Kest.minis_per_throw(heft))
		await _flush_cards()
		for enemy in enemies:
			enemy.free()
	_t.check("eight distinct targets earn Tick, Tick, Boom", _game.ctx.codex.known("kest_tick_tick_boom"))
	_t.check("Windhover opens after the framework card", _game.ctx.codex.known("kest_windhover") and _game.ctx.codex.known("set_piece"))

	_fresh()
	_player.body().global_position = home
	var body := _enemy(home + Vector3.RIGHT * 35.0)
	_player.grapple_to(body.global_position, Vector3.UP, body)
	var standing: Dictionary = _ult.plan(home, _aim(b))
	_t.eq("standing line still launches on an arc", standing["path"], "arc")
	_t.eq("standing enemy anchor chooses B", standing["to"], body.global_position)
	body.free()
	_fresh()
	_player.body().global_position = home
	var fallback: Dictionary = _ult.plan(home, {"origin": home + Vector3.UP, "forward": Vector3.UP, "harpoon": {"state": 0}})
	_t.eq("no destination preserves the framework hop", fallback["path"], "hop")
	_peak_modes.clear()
	_begin("windhover", fallback)
	_ride_out()
	_t.eq("fallback hop still fires its peak", _peak_modes, ["hop"])

	_fresh()
	_player.body().global_position = home
	_game.run.mass = 0.0
	_player.abilities.ultimate_id = "minelayer"
	_player.grapple_to(b, Vector3.UP, null)
	var mines: Dictionary = _ult.plan(home, _aim(b))
	_t.eq("Minelayer prefers line", mines["path"], "line")
	_begin("minelayer", mines)
	_ride_out()
	var live: Array = _ult.payloads.charges
	_t.check("Minelayer never exceeds ten live mines", live.size() <= 10 and live.size() > 0)
	_t.check("mines arm at landing with six-second fuses", live.all(func(c): return c["arm"] <= 0.0 and c["fuse"] > 5.5 and c["fuse"] <= 6.0))
	var mine: Dictionary = live[0]
	body = _enemy(mine["pos"] + Vector3.RIGHT * 1.9)
	_blasts.clear()
	_ult._step_payloads(DT)
	_t.check("enemy at 1.9 m triggers a mine", _blasts.size() >= 1)
	body.free()
	_ult._step_payloads(6.0)
	_t.eq("all remaining mines expire by six seconds", _ult.payloads.charges.size(), 0)

	for heft in [1, 5]:
		_fresh()
		_player.body().global_position = home
		_game.run.mass = 0.0 if heft == 1 else 1700.0
		_player.abilities.ultimate_id = "air_raid"
		var raid: Dictionary = _ult.plan(home, _aim(b))
		_t.eq("Air Raid prefers arc class %d" % heft, raid["path"], "arc")
		_begin("air_raid", raid)
		while _ult.phase() != "flight":
			_advance()
		while _ult._total_beat < 2 and _ult.phase() == "flight":
			_advance()
		_t.eq("Air Raid group size class %d" % heft, _ult._groups[0].size(), Kest.minis_per_throw(heft))
		_t.check("raid minis cannot touch or fuse before landing class %d" % heft,
			_ult.payloads.charges.all(func(c): return is_inf(c["fuse"]) and is_inf(c["arm"]) and c["_inert"]))
		_t.eq("no raid detonation before landing class %d" % heft, _blasts.size(), 0)
		_ult.roll_log.clear()
		_ride_out()
		_ult._step_payloads(0.01)
		for i in 150:
			_ult.step(DT)
		var roll: Array = _ult.roll_log
		var eighth: float = 30.0 / 172.0
		var ordered := roll.size() >= 4
		for i in range(1, roll.size()):
			ordered = ordered and roll[i]["index"] == roll[i-1]["index"] - 1 and absf(float(roll[i]["at"]) - float(roll[i-1]["at"]) - eighth) < 0.0001
		_t.check("roll groups follow eighth notes newest first class %d" % heft, ordered, "rolls %s" % [roll])
		_t.eq("Air Raid carpet fully resolves class %d" % heft, _ult.payloads.charges.size(), 0)

	_fresh()
	_player.body().global_position = home
	_game.run.mass = 0.0
	var w := _enemy(b, "warden")
	w.global_position = b
	_begin("windhover", _simple_plan(b))
	var before: float = w.posture()
	var c: Dictionary = _ult._drop(b, 12.0, 2.5)
	c["_inert"] = false
	_ult._detonate_payload(_ult.payloads.take(c))
	_t.check("mini blast uses other posture and never shatters", w.posture() > before and w.posture() - before <= 1.501 and w.chunks_left() == 4,
		"before %.2f after %.2f" % [before, w.posture()])
	for i in 40:
		c = _ult._drop(b, 12.0, 2.5)
		c["_inert"] = false
		_ult._detonate_payload(_ult.payloads.take(c))
	_ult.landing(b, 1.0, 1.0)
	_t.check("whole set piece adds no more than the closed posture cap", w.posture() - before <= preload("res://src/combat/ultimate.gd").warden_cap(w.monster_build()) + 0.001 and w.chunks_left() == 4)
	w._apply_posture({"gain": 100.0, "contact": false})
	await physics_frame
	c = _ult._drop(b, 12.0, 2.5)
	c["_inert"] = false
	_ult._detonate_payload(_ult.payloads.take(c))
	_t.eq("mini blast cannot shatter an open core", w.chunks_left(), 4)
	_ult.landing(b, 1.0, 1.0)
	_t.eq("landing shatters an open core once", w.chunks_left(), 3)
	w.free()
	_t.eq("peak score quotes 62, 57, 53", SfxBank.kest_score("raid_kest_stinger").map(func(e): return e[1]), [62, 57, 53])
	_t.eq("boom lands on low root 50", SfxBank.kest_score("raid_kest_boom")[0][1], 50)
	_t.check("Homecoming is not granted for another pilot", not _game.ctx.codex.known("kest_homecoming"))
	_ult.homecoming(2)
	_t.check("world two does not grant Homecoming", not _game.ctx.codex.known("kest_homecoming"))
	_ult.homecoming(3)
	await _flush_cards()
	_t.check("Kest entering world three discovers Homecoming", _game.ctx.codex.known("kest_homecoming"))
	_machinery()
	floor.free()


func _machinery() -> void:
	var painter := HeroAssets.new()
	var model := (load("res://assets/models/world_one/shell_kest.glb") as PackedScene).instantiate()
	root.add_child(model)
	painter.paint(model, {"class": ClassDef.KEST_COLOR})
	var pod := model.find_child("Pod", true, false) as Node3D
	var mortar := pod.get_node("WeaponRing/Mortar") as MeshInstance3D
	var ring := pod.get_node("WeaponRing") as MeshInstance3D
	var rest := mortar.position
	var state := {"mortar_pitch": PI / 4.0, "mortar_recoil": 0.08, "lit_count": 4, "heft_class": 5,
		"fuse_glow": 1.0, "fuse_boost": true, "fuse_blink": false}
	painter.apply_kest_state(pod, state)
	_t.near("delivered Mortar pitches on the shared state", mortar.rotation.x, -PI / 4.0)
	_t.near("delivered Mortar recoils 0.08 m", mortar.position.z - rest.z, 0.08)
	_t.eq("UV2 satchel shader reads lit count", ring.get_instance_shader_parameter("lit_count"), 4)
	_t.eq("UV2 satchel shader reads heft gate", ring.get_instance_shader_parameter("heft_class"), 5)
	var before: int = painter.kest_band_material(Color.WHITE).get_instance_id()
	painter.apply_kest_state(pod, state)
	_t.eq("satchel material is cached across repeated reads", painter.kest_band_material(Color.WHITE).get_instance_id(), before)
	var forbidden := model.find_children("*", "Light3D", true, false).size()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		forbidden += 1 if mi.material_override != null else 0
	_t.eq("machinery adds no lights or per-instance material override", forbidden, 0)
	model.free()
	painter.free()
