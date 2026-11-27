extends Node3D

const FightPhases := preload("res://src/combat/fight_phases.gd")
const Palette := preload("res://src/core/palette.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")

const FIGHT_ID := "brindle"
const MELT := [
	{"emission": 0.35, "color": Color("504028")},
	{"emission": 0.9, "color": Color("8a6024")},
	{"emission": 1.8, "color": Color("e09a2a")},
	{"emission": 3.0, "color": Color("ffd98a")},
]
const MELT_MIN_HUE := 32.0
const MELT_SECONDS := 1.6
const CHEERS := {
	"arrival": {"hop": 0.35, "seconds": 1.4},
	"phase": {"hop": 0.6, "seconds": -1.0},
	"weak_point": {"hop": 0.22, "seconds": 0.6},
	"rout": {"hop": 0.8, "seconds": 3.5},
}
const WAVE_SECONDS := 0.7
const HOP_HZ := 3.0
const LEDGER := ["SHIFT OVER", "1,200 T", "1,300 T", "ALL OF IT"]
const LEDGER_CAPTIONS := ["SUMS DO NOT BALANCE", "OWED (ROUNDED UP)", "OWED (ROUNDED UP AGAIN)", "OWED (ROUNDED)"]

var crowds: Array[MultiMeshInstance3D] = []
var melt_material: StandardMaterial3D
var ledger_line: Label3D
var ledger_caption: Label3D
var phase := 0
var seats := []
var _cheer := {}
var _melt_from := 0.0
var _melt_to := 0.0
var _melt_now := 1.0
var _melt_t := 1.0
var _clock := 0.0


func _ready() -> void:
	_weather_yard_surfaces()


func bind(events) -> void:
	set_process(false)
	_weather_yard_surfaces()
	_set_melt(MELT[1])
	_melt_from = 1.0
	_melt_to = 1.0
	if events == null:
		return
	if events.has_signal("fight_phase_changed"):
		events.fight_phase_changed.connect(_on_fight_phase)
	if events.has_signal("boss_weak_point_hit"):
		events.boss_weak_point_hit.connect(func(_id): cheer("weak_point"))
	if events.has_signal("boss_defeated"):
		events.boss_defeated.connect(_on_rout)


func seat(crowd: MultiMeshInstance3D, rests: Array) -> void:
	crowds.append(crowd)
	var row := []
	for xf: Transform3D in rests:
		var angle := fposmod(atan2(xf.origin.z, xf.origin.x), TAU)
		row.append({"rest": xf, "delay": angle / TAU * WAVE_SECONDS})
	seats.append(row)


func _on_fight_phase(fight_id: String, next: int, _phases: int) -> void:
	if fight_id != FIGHT_ID:
		return
	var first := phase == 0
	phase = clampi(next, 1, MELT.size() - 1)
	_ledger(phase)
	_heat(phase)
	cheer("arrival" if first else "phase")


func _on_rout() -> void:
	phase = 0
	_ledger(0)
	_heat(0)
	cheer("rout")


func _ledger(index: int) -> void:
	ledger_line.text = LEDGER[index]
	if ledger_caption != null:
		ledger_caption.text = LEDGER_CAPTIONS[index]


func cheer(kind: String) -> void:
	var row: Dictionary = CHEERS[kind]
	var seconds: float = row.seconds if row.seconds > 0.0 else FightPhases.boss(FIGHT_ID).transition()
	if not _cheer.is_empty() and _clock < _cheer.until and float(_cheer.hop) > float(row.hop):
		return
	_cheer = {"kind": kind, "hop": row.hop, "start": _clock, "until": _clock + seconds + WAVE_SECONDS}
	set_process(true)


func cheering() -> String:
	return String(_cheer.get("kind", "")) if not _cheer.is_empty() and _clock < float(_cheer.until) else ""


func _heat(index: int) -> void:
	_melt_from = _melt_now
	_melt_to = float(index)
	_melt_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	if _melt_t < 1.0:
		_melt_t = minf(_melt_t + delta / MELT_SECONDS, 1.0)
		var at := lerpf(_melt_from, _melt_to, smoothstep(0.0, 1.0, _melt_t))
		_melt_now = at
		var lo := clampi(floori(at), 0, MELT.size() - 1)
		var hi := clampi(lo + 1, 0, MELT.size() - 1)
		_set_melt(_mix(MELT[lo], MELT[hi], at - lo))
	var live: bool = not _cheer.is_empty() and _clock < float(_cheer.until)
	for c in crowds.size():
		var multimesh := crowds[c].multimesh
		for i in seats[c].size():
			var s: Dictionary = seats[c][i]
			var xf: Transform3D = s.rest
			if live:
				var t := _clock - float(_cheer.start) - float(s.delay)
				var span := float(_cheer.until) - float(_cheer.start) - WAVE_SECONDS
				if t > 0.0 and t < span:
					var envelope := sin(PI * t / span)
					var bounce := absf(sin(TAU * HOP_HZ * t + float(i)))
					xf = Transform3D(xf.basis.rotated(xf.basis.x.normalized(), 0.12 * envelope * sin(TAU * HOP_HZ * 0.5 * t + i)),
						xf.origin + Vector3.UP * float(_cheer.hop) * envelope * bounce)
			multimesh.set_instance_transform(i, xf)
	if not live:
		_cheer = {}
	if not live and _melt_t >= 1.0:
		set_process(false)


func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"emission": lerpf(a.emission, b.emission, t), "color": a.color.lerp(b.color, t)}


func _set_melt(row: Dictionary) -> void:
	if melt_material != null:
		melt_material.emission = row.color
		melt_material.albedo_color = row.color.darkened(0.35)
		melt_material.emission_energy_multiplier = row.emission


func _weather_yard_surfaces() -> void:
	if melt_material != null:
		Palette.surface_grain(melt_material)
		if melt_material.albedo_texture == null:
			var melt_tex := Palette.look_texture("rusted-salvaged-plate-worn", true)
			if melt_tex != null:
				melt_material.albedo_texture = melt_tex
				melt_material.uv1_triplanar = true
				melt_material.uv1_scale = Vector3.ONE / 5.5
	PropMeshes.weather_node_materials(self, 4.5)
	for crowd in crowds:
		if crowd != null and crowd.multimesh != null and crowd.multimesh.mesh != null:
			var m := crowd.multimesh.mesh
			for s in m.get_surface_count():
				var sm := m.surface_get_material(s) as StandardMaterial3D
				if sm != null:
					PropMeshes.weather_existing_material(sm, 3.0)
