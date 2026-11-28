extends RefCounted

const Density := preload("res://src/presentation/density.gd")

var fill_scale := 1.0
var target := 0.0
var wait := 0.0


func step(delta: float, sample: Callable) -> void:
	wait -= delta
	if wait <= 0.0:
		wait = 1.0 / Density.SAMPLE_HZ
		target = sample.call()
	publish(Density.fill_scale(Density.live().update(delta, target)))


func reset() -> void:
	target = 0.0
	wait = 0.0
	publish(1.0)


func publish(value: float) -> void:
	if value != fill_scale:
		fill_scale = value
		Density.publish_fill_scale(value)
