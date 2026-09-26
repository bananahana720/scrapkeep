extends SceneTree

const Director := preload("res://src/world/director.gd")

# The spawn director's honesty rules, stepped headless at a fixed h: the clock never
# toughens an enemy, its tier is clamped, every rise is announced and none is silent,
# 60% of spawns land ahead of a rolling ball and none near it, every body is preceded
# by its arrival ring for a full second, and a heavier ball earns a bigger crowd up to
# a hard cap without tougher enemies.

const H := 1.0 / 90.0
const SPEED := 20.0
const SPAWNS := 200
const AHEAD_SHARE := 0.55
const MIN_GAP := 25.0

var _failures := 0


func _initialize() -> void:
	_check_hp()
	_check_tiers()
	_check_spots()
	_check_arrivals()
	_check_cap()
	print("world_director_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_hp() -> void:
	var d := Director.new(1)
	d.threat = 1.5
	var at_start: float = d.hp_scale()
	for i in int(300.0 / H):
		d.advance(H, 0)
	var at_end: float = d.hp_scale()
	_report("hp from threat only", at_start == at_end and at_start == 1.5 and not d.has_method("chaser_hp") and not d.has_method("lobber_hp"),
		"HP scale %.2f at 0 s and %.2f at 300 s on a threat-1.5 stage; no clock-driven HP functions remain" % [at_start, at_end])


func _check_tiers() -> void:
	var d := Director.new(2)
	var highest := 0
	var rises_expected := 0
	var rises_seen: Array[int] = []
	var wrong: Array[String] = []
	var last := 0
	var t := 0.0
	while t < 600.0:
		d.spike = fmod(t, 150.0) > 100.0
		d.advance(H, 0)
		var now: int = d.effective_tier()
		highest = maxi(highest, now)
		var rises := d.take_threat_rises()
		if now > last:
			rises_expected += now - last
			for step in range(last + 1, now + 1):
				if not step in rises:
					wrong.append("rise to %d at %.1f s unannounced" % [step, t])
		elif not rises.is_empty():
			wrong.append("threat_rose %s at %.1f s with no rise" % [rises, t])
		rises_seen.append_array(rises)
		last = now
		t += H
	_report("time tier clamped", highest <= Director.MAX_TIME_TIERS + Director.SPIKE_TIERS and d.tier() == Director.MAX_TIME_TIERS,
		"after 600 s the clock's tier is %d and the effective tier never passed %d (limit %d)"
			% [d.tier(), highest, Director.MAX_TIME_TIERS + Director.SPIKE_TIERS])
	_report("threat_rose honest", wrong.is_empty() and rises_seen.size() == rises_expected and rises_expected > 0,
		"%d rises, beacon spikes included, and %d announced %s; mismatches %s"
			% [rises_expected, rises_seen.size(), rises_seen, wrong])


func _check_spots() -> void:
	var d := Director.new(3)
	var velocity := Vector2(0.0, SPEED)
	var ahead := 0
	var near := 0
	var closest := INF
	for i in SPAWNS:
		var spot := d.spawn_spot(Vector2.ZERO, velocity, Vector2(1.0, 0.0))
		var rel := spot
		closest = minf(closest, rel.length())
		if rel.length() < MIN_GAP:
			near += 1
		if absf(rel.angle_to(velocity)) <= Director.AHEAD_CONE + 0.001:
			ahead += 1
	var share := float(ahead) / SPAWNS
	_report("spawns ahead", share >= AHEAD_SHARE and near == 0,
		"%d of %d seeded spawns at %d m/s land within 35 degrees ahead (%.0f%%); closest %.1f m, %d within 25 m"
			% [ahead, SPAWNS, int(SPEED), share * 100.0, closest, near])


# A ball weaving across the stage at 20 m/s: every spawn must show its ring for at
# least a second before its body, and never land within 25 m of the ball.
func _check_arrivals() -> void:
	var d := Director.new(4)
	d.threat = 2.1
	var seen := {}
	var gaps: Array[float] = []
	var too_close := 0
	var t := 0.0
	var alive := 0
	while t < 240.0:
		var ball := Vector2(sin(t * 0.07) * 100.0, cos(t * 0.05) * 100.0)
		var velocity := Vector2(cos(t * 0.07) * 7.0, -sin(t * 0.05) * 5.0).normalized() * SPEED
		var due := d.advance(H, alive, ball, velocity, Vector2(0.0, 1.0))
		t += H
		for a in d.arrivals:
			var key: String = str(a["at"])
			if not seen.has(key):
				seen[key] = t
		for spawn in due:
			var key: String = str(spawn["at"])
			gaps.append(t - float(seen.get(key, t)))
			if (spawn["at"] as Vector2).distance_to(ball) < MIN_GAP:
				too_close += 1
			alive = (alive + 1) % 6
	var shortest := INF
	for g in gaps:
		shortest = minf(shortest, g)
	_report("arrival rings", not gaps.is_empty() and shortest >= Director.ARRIVAL - H * 0.5 and too_close == 0,
		"%d bodies each arrived %.3f s or more after their ring; %d within 25 m of the ball" % [gaps.size(), shortest, too_close])


func _check_cap() -> void:
	var d := Director.new(5)
	d.threat = 1.0
	d.heft_class = 1
	var base: int = d.cap()
	var hp_base: float = d.hp_scale()
	d.heft_class = 5
	var heavy: int = d.cap()
	var hp_heavy: float = d.hp_scale()
	var ceiling := 0
	for threat in [1.0, 1.5, 2.1]:
		for spike in [false, true]:
			for heft in [1, 3, 5]:
				var e := Director.new(6)
				e.threat = threat
				e.spike = spike
				e.heft_class = heft
				e.stage_time = 600.0
				ceiling = maxi(ceiling, e.cap())
	_report("heft raises the crowd", heavy == base + 8 and ceiling <= Director.HARD_CAP and hp_heavy == hp_base,
		"cap %d at heft class I, %d at class V; highest cap across threat, spike and heft %d (hard cap %d); HP scale %.2f and %.2f"
			% [base, heavy, ceiling, Director.HARD_CAP, hp_base, hp_heavy])


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
