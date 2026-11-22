extends RefCounted

# Dynamic Music bus DSP chain and StingerMusic room cohesion bus (Sound V4).
# Owns:
#   - Music bus: AudioEffectEQ6 (dynamic 2-4 kHz warning carving),
#     AudioEffectLowPassFilter (low-hull / slow-motion),
#     AudioEffectHighPassFilter (build tension and drop release).
#   - StingerMusic bus -> SFX: studio room reverb so stingers and June's answers sit inside
#     the same acoustic space as the recorded band while obeying SFX volume and mute.

const MUSIC_BUS := "Music"
const STINGER_BUS := "StingerMusic"
const SFX_BUS := "SFX"

const EQ_BAND_1K := 3
const EQ_BAND_3K2 := 4
const EQ_1K_WARNING_DB := -2.5
const EQ_3K2_WARNING_DB := -4.0

const LPF_REST_HZ := 20500.0
const LPF_SLOW_HZ := 2500.0
const LPF_LOW_HULL_HZ := 700.0

const HPF_REST_HZ := 20.0
const HPF_BUILD_MAX_HZ := 320.0

const GLIDE_DOWN_S := 0.08
const GLIDE_UP_S := 0.45

const REVERB_ROOM_SIZE := 0.35
const REVERB_DAMPING := 0.6
const REVERB_WET := 0.14
const REVERB_DRY := 0.92

var _music_idx := -1
var _eq_idx := -1
var _lpf_idx := -1
var _hpf_idx := -1
var _eq: AudioEffectEQ6
var _lpf: AudioEffectLowPassFilter
var _hpf: AudioEffectHighPassFilter

var _stinger_idx := -1
var _reverb: AudioEffectReverb

var eq_amount := 0.0
var lpf_hz := LPF_REST_HZ
var hpf_hz := HPF_REST_HZ
var _dirty := true


func setup() -> void:
	_music_idx = AudioServer.get_bus_index(MUSIC_BUS)
	if _music_idx >= 0:
		_eq_idx = _ensure_effect(_music_idx, func(e): return e is AudioEffectEQ6, func(): return AudioEffectEQ6.new())
		_lpf_idx = _ensure_effect(_music_idx, func(e): return e is AudioEffectLowPassFilter, func(): return AudioEffectLowPassFilter.new())
		_hpf_idx = _ensure_effect(_music_idx, func(e): return e is AudioEffectHighPassFilter, func(): return AudioEffectHighPassFilter.new())
		_eq = AudioServer.get_bus_effect(_music_idx, _eq_idx) as AudioEffectEQ6
		_lpf = AudioServer.get_bus_effect(_music_idx, _lpf_idx) as AudioEffectLowPassFilter
		_hpf = AudioServer.get_bus_effect(_music_idx, _hpf_idx) as AudioEffectHighPassFilter
	_ensure_stinger_bus()
	reset()


func _ensure_stinger_bus() -> void:
	_stinger_idx = AudioServer.get_bus_index(STINGER_BUS)
	if _stinger_idx < 0:
		AudioServer.add_bus()
		_stinger_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_stinger_idx, STINGER_BUS)
	var send_target := SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else "Master"
	AudioServer.set_bus_send(_stinger_idx, send_target)
	AudioServer.set_bus_volume_db(_stinger_idx, 0.0)
	var rev_idx := _ensure_effect(_stinger_idx, func(e): return e is AudioEffectReverb, func(): return AudioEffectReverb.new())
	_reverb = AudioServer.get_bus_effect(_stinger_idx, rev_idx) as AudioEffectReverb
	_reverb.room_size = REVERB_ROOM_SIZE
	_reverb.damping = REVERB_DAMPING
	_reverb.wet = REVERB_WET
	_reverb.dry = REVERB_DRY


static func _ensure_effect(bus_idx: int, match_fn: Callable, factory: Callable) -> int:
	for i in AudioServer.get_bus_effect_count(bus_idx):
		if match_fn.call(AudioServer.get_bus_effect(bus_idx, i)):
			return i
	var idx := AudioServer.get_bus_effect_count(bus_idx)
	AudioServer.add_bus_effect(bus_idx, factory.call())
	return idx


func reset() -> void:
	eq_amount = 0.0
	lpf_hz = LPF_REST_HZ
	hpf_hz = HPF_REST_HZ
	_dirty = true
	_apply()


func step(delta: float, state: Dictionary) -> void:
	if _music_idx < 0 or _eq == null or _lpf == null or _hpf == null:
		return
	var dt := maxf(delta, 0.0)
	var prev_eq := eq_amount
	var prev_lpf := lpf_hz
	var prev_hpf := hpf_hz

	var want_eq := 1.0 if bool(state.get("focus", false)) else 0.0
	var eq_rate := (1.0 / GLIDE_DOWN_S) if want_eq > eq_amount else (1.0 / GLIDE_UP_S)
	eq_amount = move_toward(eq_amount, want_eq, dt * eq_rate)

	var want_lpf := LPF_REST_HZ
	if bool(state.get("low_hull", false)):
		want_lpf = minf(want_lpf, LPF_LOW_HULL_HZ)
	if bool(state.get("slowed", false)):
		want_lpf = minf(want_lpf, LPF_SLOW_HZ)
	var lpf_time := GLIDE_DOWN_S if want_lpf < lpf_hz else GLIDE_UP_S
	lpf_hz = _glide_hz(lpf_hz, want_lpf, dt, lpf_time)

	var tension := clampf(float(state.get("build_tension", 0.0)), 0.0, 1.0)
	var want_hpf := lerpf(HPF_REST_HZ, HPF_BUILD_MAX_HZ, tension)
	var hpf_time := GLIDE_UP_S if want_hpf > hpf_hz else GLIDE_DOWN_S
	hpf_hz = _glide_hz(hpf_hz, want_hpf, dt, hpf_time)

	if _dirty or not is_equal_approx(eq_amount, prev_eq) or not is_equal_approx(lpf_hz, prev_lpf) or not is_equal_approx(hpf_hz, prev_hpf):
		_apply()


static func _glide_hz(now: float, want: float, dt: float, duration: float) -> float:
	if dt <= 0.0 or is_equal_approx(now, want):
		return now
	var log_span := log(LPF_REST_HZ) - log(HPF_REST_HZ)
	var step_log := (log_span / maxf(duration, 0.001)) * dt
	var target_log := log(maxf(want, 1.0))
	var next_log := move_toward(log(maxf(now, 1.0)), target_log, step_log)
	if is_equal_approx(next_log, target_log):
		return want
	return exp(next_log)


func _apply() -> void:
	_dirty = false
	if _music_idx < 0:
		return
	if _eq != null:
		for band in 6:
			_eq.set_band_gain_db(band, 0.0)
		_eq.set_band_gain_db(EQ_BAND_1K, EQ_1K_WARNING_DB * eq_amount)
		_eq.set_band_gain_db(EQ_BAND_3K2, EQ_3K2_WARNING_DB * eq_amount)
		AudioServer.set_bus_effect_enabled(_music_idx, _eq_idx, eq_amount > 0.005)
	if _lpf != null:
		_lpf.cutoff_hz = clampf(lpf_hz, 20.0, LPF_REST_HZ)
		AudioServer.set_bus_effect_enabled(_music_idx, _lpf_idx, lpf_hz < LPF_REST_HZ - 100.0)
	if _hpf != null:
		_hpf.cutoff_hz = clampf(hpf_hz, HPF_REST_HZ, 2000.0)
		AudioServer.set_bus_effect_enabled(_music_idx, _hpf_idx, hpf_hz > HPF_REST_HZ + 5.0)


func snapshot() -> Dictionary:
	return {
		"eq_amount": eq_amount,
		"eq_1k_db": _eq.get_band_gain_db(EQ_BAND_1K) if _eq != null else 0.0,
		"eq_3k2_db": _eq.get_band_gain_db(EQ_BAND_3K2) if _eq != null else 0.0,
		"eq_enabled": _music_idx >= 0 and _eq_idx >= 0 and AudioServer.is_bus_effect_enabled(_music_idx, _eq_idx),
		"lpf_hz": _lpf.cutoff_hz if _lpf != null else LPF_REST_HZ,
		"lpf_enabled": _music_idx >= 0 and _lpf_idx >= 0 and AudioServer.is_bus_effect_enabled(_music_idx, _lpf_idx),
		"hpf_hz": _hpf.cutoff_hz if _hpf != null else HPF_REST_HZ,
		"hpf_enabled": _music_idx >= 0 and _hpf_idx >= 0 and AudioServer.is_bus_effect_enabled(_music_idx, _hpf_idx),
		"stinger_bus": STINGER_BUS,
		"stinger_send": AudioServer.get_bus_send(_stinger_idx) if _stinger_idx >= 0 else "",
		"stinger_reverb": _reverb != null,
	}
