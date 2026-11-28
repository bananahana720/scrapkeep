extends SceneTree

const Game := preload("res://src/game.gd")
const Roster := preload("res://src/combat/roster.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const AreaField := preload("res://src/combat/area_field.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const WavIo := preload("res://src/presentation/wav_io.gd")
const T := preload("res://tests/support/t.gd")
const Intent := preload("res://src/movement/intent.gd")

# Fields and casts, first slice (design-v3/FIELDS-AND-CASTS.md sections 2 to 4).
# - Cast time: a slot with a cast starts it with nothing spent, reads ACTIVE while it runs,
#   finishes once, and an interrupt drops it with nothing spent. Andrew's "Big ones only"
#   (2026-10-17 19:56:59Z): Gather Plate and the depth-3 Q variants carry a cast, nothing else;
#   a variant's Q wind-up is its cast, a base Q keeps 0.35 s.
# - The jam shuts only the specials and the line skill, answers "jammed" and wears off.
# - AreaField: a laid field stays put, an emitter follows its source, the lead climbs before
#   each pulse and a 3.6 s run pulses three times.
# - The jolt layer in a live game: it warns before it pulses; a pulse on a slow grounded ball
#   drops Sable's charging gauge, jams the special and leaves the ball unheld; a pulse on a
#   ball in the air passes it by; a pulse during Q's wind-up recalls Q with a full refund; a
#   ball with a line attached reads as slipping.
# - Its voice loads only if present: a raw RIFF reads as 16-bit mono, and the body carries a
#   presence loop exactly when the presence file exists.

const EXPECTED_CHECKS := 28
const OFFSET := Vector3(8.0, 0.0, 3.0)
const LIMIT := 9.0
const DT := 1.0 / 60.0

var _t := T.new("jolt_layer_test")
var _game
var _unit: Node3D
var _ball_at := Vector3.ZERO
var _clock := 0.0
var _warn_at := -1.0
var _first_jolt_at := -1.0
var _cancelled: Array = []
var _held_on_jolt := true
var _jammed_on_jolt := false
var _lifted := false
var _done := false
var _pressed := false
var _q_pressed := false
var _q_refusal := "unset"
var _q_winding := false
var _source


func _initialize() -> void:
	_cast_time()
	_jam()
	_field()
	_voice()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _cast_time() -> void:
	var with_cast := []
	for id in AbilityState.ABILITIES:
		if float(AbilityState.ABILITIES[id].get("cast", 0.0)) > 0.0:
			with_cast.append(id)
	var want := ["gather_plate"]
	for id in AbilityState.ABILITIES:
		if AbilityState.ABILITIES[id].has("variant_of"):
			want.append(id)
	with_cast.sort()
	want.sort()
	_t.eq("only Gather Plate and the Q variants have a cast time", with_cast, want)
	var ab := AbilityState.new()
	ab.swap(AbilityState.SPECIAL, "gather_plate")
	ab.slot(AbilityState.SPECIAL).cast = 0.4
	var charges: int = ab.slot(AbilityState.SPECIAL).charges
	_t.check("a cast starts on a ready slot", ab.begin_cast(AbilityState.SPECIAL), "begin_cast")
	_t.check("a second cast cannot start over it", not ab.begin_cast(AbilityState.SPECIAL), "begin_cast again")
	_step(ab, 0.2)
	_t.eq("the slot reads active mid-cast and nothing is spent",
		[ab.state_of(AbilityState.SPECIAL), ab.slot(AbilityState.SPECIAL).charges, ab.charging()], ["active", charges, true])
	_t.near("the cast fraction is half way", ab.cast_fraction(), 0.5, 0.05)
	_t.eq("an interrupt drops the cast with nothing spent",
		[ab.cancel_gauges(), ab.casting, ab.slot(AbilityState.SPECIAL).charges, ab.take_cast_done()],
		[["gather_plate"], "", charges, ""])
	ab.begin_cast(AbilityState.SPECIAL)
	_step(ab, 0.45)
	_t.eq("a cast that runs its time finishes once", [ab.take_cast_done(), ab.take_cast_done(), ab.casting],
		[AbilityState.SPECIAL, "", ""])


func _jam() -> void:
	var ab := AbilityState.new()
	ab.swap(AbilityState.WEAPON, "rapid_laser")
	ab.swap(AbilityState.SPECIAL, "overdrive_blast")
	ab.swap(AbilityState.LINE, "line_drive")
	ab.swap(AbilityState.MOVEMENT, "overdrive_sprint")
	ab.jam(0.5)
	ab.jam(0.3)
	_t.eq("a jam shuts the special and the line skill only",
		[ab.ready(AbilityState.SPECIAL), ab.ready(AbilityState.LINE), ab.ready(AbilityState.WEAPON), ab.ready(AbilityState.MOVEMENT)],
		[false, false, true, true])
	_t.eq("a jammed slot reads unavailable and answers jammed",
		[ab.state_of(AbilityState.SPECIAL), ab.select(AbilityState.SPECIAL)], ["unavailable", "jammed"])
	_step(ab, 0.35)
	_t.check("a second jam refreshes, never stacks", ab.jammed() and ab.jam_left < 0.2, "jam_left %.2f" % ab.jam_left)
	_step(ab, 0.2)
	_t.eq("the jam wears off", [ab.jammed(), ab.ready(AbilityState.SPECIAL)], [false, true])


func _field() -> void:
	var source := Node3D.new()
	var laid := AreaField.new("static_jam", Vector3(1.0, 0.0, 1.0), source)
	var emitter := AreaField.new("static_jam", Vector3.ZERO, source)
	emitter.row = emitter.row.duplicate()
	emitter.row["anchor"] = AreaField.EMITTER
	source.position = Vector3(20.0, 0.0, 0.0)
	_t.eq("a laid field stays put and an emitter follows its source",
		[laid.centre_now(), emitter.centre_now()], [Vector3(1.0, 0.0, 1.0), Vector3(20.0, 0.0, 0.0)])
	_t.eq("contains reads the radius and the height",
		[laid.contains(Vector3(6.5, 0.0, 1.0)), laid.contains(Vector3(7.5, 0.0, 1.0)), laid.contains(Vector3(1.0, 4.0, 1.0))],
		[true, false, false])
	var pulses := 0
	var lead_seen := 0.0
	var lead_before_first := 0.0
	for i in int(round(3.65 / DT)):
		if laid.step(DT):
			pulses += 1
		elif pulses == 0:
			lead_before_first = maxf(lead_before_first, laid.lead_fraction())
		lead_seen = maxf(lead_seen, laid.lead_fraction())
	_t.eq("a 3.6 s run pulses three times", pulses, 3)
	_t.check("the lead climbs to full before the first pulse", lead_before_first > 0.95 and lead_seen <= 1.0,
		"lead before the first pulse %.2f" % lead_before_first)
	source.free()


func _voice() -> void:
	var riff := PackedByteArray()
	riff.append_array("RIFF".to_ascii_buffer())
	riff.resize(riff.size() + 4)
	riff.append_array("WAVEfmt ".to_ascii_buffer())
	var fmt := PackedByteArray()
	fmt.resize(20)
	fmt.encode_u32(0, 16)
	fmt.encode_u16(4, 1)
	fmt.encode_u16(6, 1)
	fmt.encode_u32(8, 44100)
	fmt.encode_u32(12, 88200)
	fmt.encode_u16(16, 2)
	fmt.encode_u16(18, 16)
	fmt.append_array("data".to_ascii_buffer())
	riff.append_array(fmt)
	var data := PackedByteArray()
	data.resize(4 + 8)
	data.encode_u32(0, 8)
	riff.append_array(data)
	var wav: AudioStreamWAV = WavIo.from_riff(riff)
	_t.eq("a raw RIFF reads as 16-bit mono at its rate", [wav != null, wav.stereo if wav else true,
		wav.mix_rate if wav else 0, wav.data.size() if wav else 0], [true, false, 44100, 8])


func _step(ab, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		ab.tick(DT)


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _unit == null:
		_setup()
		return false
	_clock += delta
	var player = _game.player
	if _warn_at < 0.0 and _unit.telegraph() != null:
		_warn_at = _clock
	var live: bool = _unit.phase == _unit.Phase.LIVE
	var field = _unit.field
	# Sable's special gauge starts charging as the field goes live and is held through the
	# first pulse (a 1 s gauge fires 0.5 s after full, past the 1.2 s pulse).
	if live and not _pressed:
		_pressed = true
		_source.press["special_pressed"] = true
		_source.hold["special_held"] = true
	if _unit.jolts >= 1:
		_source.hold.erase("special_held")
	if _unit.jolts == 1 and _first_jolt_at < 0.0:
		_first_jolt_at = _clock
		_held_on_jolt = _game.ctx.spawner.fleet.holds.holding()
		_jammed_on_jolt = player.abilities.jammed()
	# Second pulse: lift the ball just before it. Third: start Q 0.2 s before it, inside the wind-up.
	if live and field != null and field.pulses == 1 and not _lifted and field.lead_fraction() > 0.6:
		_lifted = true
		player.reset_to(player.ball_position() + Vector3.UP * 1.6)
	if live and field != null and field.pulses == 2 and not _q_pressed and player.state.grounded \
			and field.lead_fraction() > 0.6:
		_q_pressed = true
		var ult = _game.combat.ultimate
		ult.meter.refund(ult.meter.CAP)
		_q_refusal = ult.press()
		_q_winding = ult.winding_up()
	if field != null and field.pulses >= 3 or _clock > LIMIT:
		return _finish(field)
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_ball_at = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.player.reset_to(_ball_at)
	_source = Intent.Scripted.new()
	_game.player.source = _source
	_game.events.gauge_cancelled.connect(func(id: String, reason: String): _cancelled.append([id, reason]))
	var at: Vector3 = _ball_at + OFFSET
	_unit = ctx.spawner.spawn_enemy("jolt_layer", ctx.terrain.drop_point(at.x, at.z, 1.8))
	_unit._rest = 0.3


func _finish(field) -> bool:
	_done = true
	var row: Dictionary = Roster.row("jolt_layer")
	var outcomes: Array = field.outcomes if field != null else []
	_t.check("the jolt layer is a built world 1 kind", Roster.built("jolt_layer") and int(row.get("world", 0)) == 1
		and _unit.get_script().resource_path.ends_with("jolt_layer.gd"), "row %s" % row.get("mechanic", ""))
	_t.check("it warns before it jolts", _warn_at >= 0.0 and _first_jolt_at - _warn_at >= _unit.warn_seconds + 1.0,
		"warned at %.2f, first jolt at %.2f" % [_warn_at, _first_jolt_at])
	_t.check("the first pulse lands on the slow grounded ball", outcomes.size() >= 1 and outcomes[0] == "landed",
		"outcomes %s" % [outcomes])
	_t.check("it drops the charging gauge, by the field's name", _cancelled.has(["detonation_gauge", "static_jam"]),
		"cancelled %s" % [_cancelled])
	_t.check("it jams the special and never holds the ball", _jammed_on_jolt and not _held_on_jolt,
		"jammed %s, held %s" % [_jammed_on_jolt, _held_on_jolt])
	_t.check("a ball in the air slips the second pulse", outcomes.size() >= 2 and outcomes[1] == "air",
		"outcomes %s" % [outcomes])
	var ult = _game.combat.ultimate
	_t.check("a jolt in Q's wind-up recalls Q with a full refund", _q_refusal == "" and _q_winding
		and outcomes.size() >= 3 and outcomes[2] == "landed" and _unit.recalls == 1 and not ult.active() and ult.meter.full(),
		"press %s, winding %s, outcomes %s, recalls %d, meter full %s" % [_q_refusal, _q_winding, outcomes, _unit.recalls, ult.meter.full()])
	_t.eq("the unit counts two jolts and one slip", [_unit.jolts, _unit.slipped], [2, 1])
	var player = _game.player
	player.grapple_to(player.ball_position() + Vector3(0.0, 6.0, 1.0))
	var hooked_break: String = field.broken_by(player) if field != null else ""
	player.release_grapple()
	_t.eq("a ball with a line attached slips a pulse", hooked_break, "line")
	var base_id: String = player.abilities.ultimate_id
	var windups := [ult.windup_seconds()]
	player.abilities.ultimate_id = "ball_lightning"
	windups.append(ult.windup_seconds())
	player.abilities.ultimate_id = base_id
	_t.eq("a base Q winds up 0.35 s and a variant casts 0.5 s", windups, [0.35, AbilityState.VARIANT_CAST])
	var has_file := ResourceLoader.exists(SfxBank.file_path("jolt_layer_presence")) or FileAccess.file_exists(SfxBank.file_path("jolt_layer_presence"))
	_t.eq("the body carries a presence loop exactly when its file is present",
		_unit.get_node_or_null("Foley_jolt_layer_presence") != null, has_file)
	_t.eq("the check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	quit(_t.verdict())
	return true
