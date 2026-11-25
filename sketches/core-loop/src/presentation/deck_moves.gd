extends RefCounted

const DeckFx := preload("res://src/presentation/deck_fx.gd")


const PUMP := {"build": 0.45, "telegraph": 0.6, "drop": 0.55}
const PUMP_VIKING := {"build": 0.58, "telegraph": 0.72, "drop": 0.68}
const PRESETS := ["festival", "viking"]
const PUMP_STEMS := ["bass", "other"]
const PUMP_ATTACK_FRAMES := 220
const PUMP_SHAPE := [
	[0.07, 1.0],
	[0.2, 0.86],
	[0.345, 0.5],
	[0.49, 0.14],
	[0.62, 0.0],
]

const BUILD_TIERS := [
	{"posture": 75.0},
	{"posture": 85.0},
	{"posture": 95.0},
]

const TAG_BUILD := "deck_build"
const TAG_BREATH := "deck_breath"
const TAG_DROP := "deck_drop"

var _seq_id := 0
var _build_bar_at := -1
var _open_downlifter_done := false
var _allowed := false
var _drop_active := false
var _style := "off"


static func pump_for(style: String) -> Dictionary:
	if style == "viking":
		return PUMP_VIKING
	if style == "festival":
		return PUMP
	return {}


static func _resolve_style(room: Dictionary) -> String:
	if room.has("style"):
		var s := String(room.get("style", "off"))
		return s if s in PRESETS else "off"
	return "festival" if bool(room.get("on", false)) else "off"


static func tier_for_posture(posture: float) -> int:
	var tier := 0
	for i in BUILD_TIERS.size():
		if posture >= float(BUILD_TIERS[i]["posture"]):
			tier = i
	return tier


static func pump_share(frame_in_beat: int, beat_frames: int) -> float:
	if beat_frames <= 0 or frame_in_beat <= 0 or frame_in_beat >= beat_frames:
		return 0.0
	var hold_k := int(round(float(PUMP_SHAPE[0][0]) * float(beat_frames)))
	var atk := mini(PUMP_ATTACK_FRAMES, maxi(hold_k, 1))
	if frame_in_beat < atk:
		return float(frame_in_beat) / float(atk)
	var prev_k := atk
	var prev_s := 1.0
	for row in PUMP_SHAPE:
		var bp_k := maxi(prev_k, int(round(float(row[0]) * float(beat_frames))))
		var bp_s := float(row[1])
		if frame_in_beat <= bp_k:
			if bp_k == prev_k:
				return bp_s
			return lerpf(prev_s, bp_s, float(frame_in_beat - prev_k) / float(bp_k - prev_k))
		prev_k = bp_k
		prev_s = bp_s
	return 0.0


static func next_pump_breakpoint(frame_in_beat: int, beat_frames: int) -> int:
	if beat_frames <= 0:
		return 1
	var hold_k := int(round(float(PUMP_SHAPE[0][0]) * float(beat_frames)))
	var atk := mini(PUMP_ATTACK_FRAMES, maxi(hold_k, 1))
	if frame_in_beat < atk:
		return atk
	for row in PUMP_SHAPE:
		var bp_k := int(round(float(row[0]) * float(beat_frames)))
		if frame_in_beat < bp_k:
			return bp_k
	return beat_frames


func reset() -> void:
	_seq_id = 0
	_build_bar_at = -1
	_open_downlifter_done = false
	_allowed = false
	_drop_active = false
	_style = "off"


func tend(seq, room: Dictionary) -> void:
	if seq == null:
		reset()
		return
	var id: int = seq.get_instance_id()
	if id != _seq_id:
		_seq_id = id
		_build_bar_at = -1
		_open_downlifter_done = false
		_drop_active = false
	var style := _resolve_style(room)
	var active := style != "off" and bool(room.get("allow", false)) and not bool(seq.flat) and String(seq.mode) != "off"
	if not active:
		seq.set_pump({})
		if _allowed or _build_bar_at >= 0 or _open_downlifter_done or _drop_active:
			seq.cancel_shots("", seq.GAP_RAMP)
		_allowed = false
		_build_bar_at = -1
		_open_downlifter_done = false
		_drop_active = false
		_style = "off"
		return
	_allowed = true
	_style = style
	seq.set_pump(pump_for(style))
	var mode := String(seq.mode)
	var sec := String(seq.section)
	var pending_sec := String(seq.pending.get("section", ""))
	var pending_at := int(seq.pending.get("at", -1))
	var in_telegraph := mode == "warden" and (
		(sec == "telegraph" and (pending_sec == "" or pending_sec == "telegraph"))
		or pending_sec == "telegraph"
	)
	if in_telegraph:
		var at: int = seq.next_bar()
		var starts_in_tele := sec == "telegraph" or (pending_at >= 0 and pending_at <= at)
		if starts_in_tele and at != _build_bar_at and at >= seq.clock and at - seq.clock <= seq.grid_bar / 2:
			var tier := tier_for_posture(float(room.get("posture", 75.0)))
			var build_pcm := DeckFx.viking_build(tier, seq.grid_bar, seq.grid_beat) if style == "viking" else DeckFx.build(tier, seq.grid_bar, seq.grid_beat)
			seq.shot_at(at, build_pcm, TAG_BUILD, 1.0)
			_build_bar_at = at
	elif _build_bar_at >= 0:
		seq.cancel_shots(TAG_BUILD, seq.GAP_RAMP)
		_build_bar_at = -1
	var in_open := mode == "warden" and sec == "open" and (pending_sec == "" or pending_sec == "open")
	if in_open:
		if not _open_downlifter_done:
			seq.shot_at(seq.clock, DeckFx.downlifter(seq.grid_bar), TAG_BREATH, 1.0)
			_open_downlifter_done = true
	elif _open_downlifter_done:
		seq.cancel_shots(TAG_BREATH, seq.GAP_RAMP)
		_open_downlifter_done = false
	if _drop_active and sec != "drop" and pending_sec != "drop":
		seq.cancel_shots(TAG_DROP, seq.GAP_RAMP)
		_drop_active = false


func on_drop(seq, at: int, style := "") -> void:
	var use_style := style if style != "" else _style
	if not _allowed or not use_style in PRESETS or seq == null or at < 0 or bool(seq.flat) or String(seq.mode) == "off":
		return
	if _drop_active:
		seq.cancel_shots(TAG_DROP, seq.GAP_RAMP)
		_drop_active = false
	if _build_bar_at >= 0:
		seq.cancel_shots(TAG_BUILD, seq.GAP_RAMP)
		_build_bar_at = -1
	if _open_downlifter_done:
		seq.cancel_shots(TAG_BREATH, seq.GAP_RAMP)
		_open_downlifter_done = false
	var swell_len := mini(int(seq.grid_beat), maxi(at - int(seq.clock), 0))
	if swell_len > 0:
		seq.shot_at(at - swell_len, DeckFx.swell(swell_len), TAG_DROP, 1.0)
	var impact_pcm := DeckFx.viking_impact() if use_style == "viking" else DeckFx.impact()
	seq.shot_at(at, impact_pcm, TAG_DROP, 1.0)
	_drop_active = true
