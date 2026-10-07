extends RefCounted

const RunState := preload("res://src/core/run_state.gd")
const Interact := preload("res://src/world/interact.gd")


func run(t) -> void:
	var chosen := Resource.new()
	# Game takes its session seed when it is created; presentation draws come after.
	seed(11)
	var plain := RunState.new(null, randi())
	plain.begin(chosen)
	seed(11)
	var session := randi()
	for i in 17:
		randf()
	var noisy := RunState.new(null, session)
	noisy.begin(chosen)
	var plain_half := plain.run_id.get_slice("-", 1)
	var noisy_half := noisy.run_id.get_slice("-", 1)
	t.eq("presentation draws cannot change the run identity's luck half", noisy_half, plain_half)
	t.eq("presentation draws cannot change a device reward seed",
		Interact.luck_seed(20260926, noisy.run_id, 4, "cache"),
		Interact.luck_seed(20260926, plain.run_id, 4, "cache"))
	seed(4242)
	var want := randi()
	seed(4242)
	plain.begin(chosen)
	t.eq("a run identity never consumes global randomness", randi(), want)
	t.check("successive runs retain distinct identities", plain.run_id.get_slice("-", 1) != plain_half)
