extends SceneTree
# Systems audit probe (not committed): after paying a hull price at a trade chest, how long until
# the hull is full again with no hit taken? Uses RunState.advance at 90 ticks a second.
const RunState := preload("res://src/core/run_state.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
func _initialize() -> void:
	for share in StakeDevices.HEALTH_SHARES:
		var run = RunState.new()
		run.hp = run.max_hp * (1.0 - share)
		run.since_damage = 0.0
		var t := 0.0
		while run.hp < run.max_hp and t < 120.0:
			run.advance(1.0 / 90.0)
			t += 1.0 / 90.0
		print("regen_probe: paid %d%% hull -> full again after %.1f s with no hit (REGEN_DELAY %.1f s, REGEN_RATE %.1f hp/s)" % [int(share * 100), t, RunState.REGEN_DELAY, RunState.REGEN_RATE])
	quit(0)
