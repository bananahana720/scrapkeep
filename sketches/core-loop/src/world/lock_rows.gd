extends RefCounted

const ROWS := {
	"park_dam": {
		"gate": {"packs": 5, "also": ["enemy_camp"], "max_s": 75.0},
		"lock": {"id": "apron_crew", "within_m": 200.0, "sentry": {"kind": "lobber", "within_m": 330.0, "ahead_m": 60.0, "side_m": 20.0}, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 60.0, "wave_gap_s": 3.5,
			"waves": [["chaser", "chaser", "lobber"], ["lobber", "lobber", "chaser"], ["chaser", "chaser", "chaser", "lobber"], ["lobber", "chaser", "chaser", "jolt_layer"], ["chaser", "chaser", "lobber", "lobber", "ramp_flipper"]],
			"overtime": {"flow": [0.0, 0.0, 1.0]}},
	},
	"park_flume": {
		"gate": {"packs": 1, "also": ["enemy_camp"], "max_s": 75.0},
		"lock": {"id": "forecourt_crew", "within_m": 210.0, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 70.0, "wave_gap_s": 3.5,
			"waves": [["chaser", "chaser", "lobber"], ["chaser", "lobber", "lobber"], ["chaser", "chaser", "lobber", "lobber"], ["lobber", "chaser", "chaser"], ["chaser", "lobber", "lobber"], ["chaser", "chaser", "lobber", "jolt_layer"], ["chaser", "chaser", "chaser", "lobber", "ramp_flipper"]]},
	},
	"park_pit": {
		"lock": {"id": "bench_crew", "within_m": 190.0, "sentry": {"kind": "burrower", "within_m": 310.0, "ahead_m": 55.0, "side_m": 18.0}, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 65.0, "wave_gap_s": 3.5,
			"waves": [["burrower", "burrower", "lamp_swarm"], ["chaser", "burrower", "lobber"], ["burrower", "lamp_swarm", "lamp_swarm"], ["burrower", "chaser", "prop_crew"], ["burrower", "burrower", "lamp_swarm", "prop_crew"]]},
	},
	"park_sinkhole": {
		"lock": {"id": "cenote_crew", "within_m": 200.0, "sentry": {"kind": "lobber", "within_m": 320.0, "ahead_m": 60.0, "side_m": 20.0}, "radius_m": 28.0, "ahead_m": 10.0, "max_s": 70.0, "wave_gap_s": 3.5,
			"waves": [["burrower", "burrower", "lamp_swarm"], ["lamp_swarm", "lobber", "burrower"], ["burrower", "prop_crew", "chaser", "lobber"], ["burrower", "lamp_swarm", "splitter"], ["burrower", "burrower", "prop_crew", "lamp_swarm"], ["burrower", "lamp_swarm", "prop_crew", "splitter"]]},
	},
	"park_islands": {
		"lock": {"id": "mooring_crew", "within_m": 200.0, "sentry": {"kind": "line_cutter", "within_m": 320.0, "ahead_m": 60.0, "side_m": 18.0}, "radius_m": 28.0, "ahead_m": 10.0, "max_s": 70.0, "wave_gap_s": 3.5,
			"waves": [["line_cutter", "line_cutter", "kite_drone"], ["kite_drone", "chaser", "lobber"], ["line_cutter", "kite_drone", "gap_net"], ["line_cutter", "line_cutter", "kite_drone", "lobber"], ["kite_drone", "kite_drone", "gap_net", "chaser"], ["line_cutter", "line_cutter", "kite_drone", "gap_net"]]},
	},
	"park_crown": {
		"lock": {"id": "summit_crew", "within_m": 210.0, "sentry": {"kind": "kite_drone", "within_m": 330.0, "ahead_m": 60.0, "side_m": 20.0}, "radius_m": 28.0, "ahead_m": 10.0, "max_s": 75.0, "wave_gap_s": 3.5,
			"waves": [["line_cutter", "kite_drone", "kite_drone"], ["line_cutter", "line_cutter", "gap_net"], ["kite_drone", "lobber", "chaser", "gap_net"], ["line_cutter", "kite_drone", "dispatcher"], ["line_cutter", "line_cutter", "kite_drone", "gap_net"], ["kite_drone", "kite_drone", "gap_net", "dispatcher"], ["line_cutter", "line_cutter", "kite_drone", "kite_drone", "gap_net"]]},
	},
}


static func row(map_id: String) -> Dictionary:
	return ROWS.get(map_id, {})
