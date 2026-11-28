extends SceneTree

const Bank := preload("res://src/presentation/experimental_audio_bank.gd")
const T := preload("res://tests/support/t.gd")

const EXPECTED_EVENTS := [
	"smelter_ambience",
	"hazard_squall_alarm",
	"apex_lockdown",
	"pa_salvage_press_lockdown",
	"pa_foreman_rig_deployed",
	"pa_hazard_squall_incoming",
	"pa_airdrop_pod_inbound",
]

const EXPECTED_MASKS := [
	"pitted_iron",
	"slag_crust",
	"corrosive_brine",
]

const MAX_SEAM_MEAN_DELTA := 0.065
const MAX_SEAM_TO_INTERIOR_RATIO := 1.35
const MIN_CHANNEL_STDDEV := 0.12

var _t := T.new("experimental_audio_bank_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Bank._reset()
	_verify_audio_events()
	_verify_player_configuration_and_cooldown()
	_verify_pbr_masks()
	Bank._reset()
	quit(_t.verdict())


func _verify_audio_events() -> void:
	var ids := Bank.event_ids()
	_t.eq("event count", ids.size(), EXPECTED_EVENTS.size())
	for event_id in EXPECTED_EVENTS:
		_t.check("%s registered" % event_id, Bank.has_event(event_id), event_id)
		var entry := Bank.spec(event_id)
		var bus := Bank.bus_for(event_id)
		_t.check("%s bus valid" % event_id, bus in Bank.VALID_BUSES, bus)
		var cooldown := Bank.cooldown_for(event_id)
		_t.check("%s cooldown non-negative" % event_id, cooldown >= 0.0, str(cooldown))
		var duck := Bank.ducking_for(event_id)
		var duck_db := float(duck["duck_db"])
		var duck_bus := String(duck["duck_bus"])
		_t.check("%s duck_db <= 0" % event_id, duck_db <= 0.0, str(duck_db))
		_t.check(
			"%s duck_bus valid" % event_id,
			duck_bus == "" or duck_bus in Bank.VALID_BUSES,
			duck_bus,
		)
		var stream := Bank.stream_for(event_id)
		var is_vorbis := stream is AudioStreamOggVorbis
		_t.check("%s loads AudioStreamOggVorbis" % event_id, is_vorbis, String(entry["path"]))
		if is_vorbis:
			var length_s := stream.get_length()
			_t.check("%s duration > 0" % event_id, length_s > 0.25, "%.2fs" % length_s)
			_t.eq("%s loop matches spec" % event_id, stream.loop, bool(entry["loop"]))


func _verify_player_configuration_and_cooldown() -> void:
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	var configured := Bank.configure_player(player, "pa_salvage_press_lockdown")
	_t.check("configure_player returns true", configured, "pa_salvage_press_lockdown")
	_t.check("player stream attached", player.stream is AudioStreamOggVorbis, str(player.stream))
	_t.check("can trigger before mark", Bank.can_trigger("pa_salvage_press_lockdown", 10.0), "t=10.0")
	Bank.mark_triggered("pa_salvage_press_lockdown", 10.0)
	_t.check("blocked inside cooldown", not Bank.can_trigger("pa_salvage_press_lockdown", 12.0), "t=12.0")
	_t.check("allowed after cooldown", Bank.can_trigger("pa_salvage_press_lockdown", 14.5), "t=14.5")
	_t.check("unknown event rejected", not Bank.configure_player(player, "missing_event"), "missing_event")
	player.queue_free()


func _verify_pbr_masks() -> void:
	var getters := {
		"pitted_iron": Bank.load_pbr_mask("pitted_iron"),
		"slag_crust": Bank.load_pbr_mask("slag_crust"),
		"corrosive_brine": Bank.load_pbr_mask("corrosive_brine"),
	}
	_t.eq("mask id count", Bank.pbr_mask_ids().size(), EXPECTED_MASKS.size())
	for mask_id in EXPECTED_MASKS:
		var tex := getters[mask_id] as Texture2D
		var entry := Bank.pbr_mask_spec(mask_id)
		_t.check("%s loads Texture2D" % mask_id, tex != null, String(entry["path"]))
		if tex == null:
			continue
		var width := tex.get_width()
		var height := tex.get_height()
		_t.check("%s dimensions >= 512" % mask_id, width >= 512 and height >= 512, "%dx%d" % [width, height])
		var img := tex.get_image()
		_t.check("%s image readable" % mask_id, img != null and not img.is_empty(), mask_id)
		if img == null or img.is_empty():
			continue
		var metrics := _measure_seam_and_variance(img)
		var lr_mean := float(metrics["lr_mean"])
		var tb_mean := float(metrics["tb_mean"])
		var interior_mean := float(metrics["interior_mean"])
		var lr_ratio := lr_mean / maxf(interior_mean, 0.0001)
		var tb_ratio := tb_mean / maxf(interior_mean, 0.0001)
		var min_std := float(metrics["min_std"])
		_t.check(
			"%s left-right seam smooth" % mask_id,
			lr_mean <= MAX_SEAM_MEAN_DELTA and lr_ratio <= MAX_SEAM_TO_INTERIOR_RATIO,
			"lr=%.5f interior=%.5f ratio=%.2f" % [lr_mean, interior_mean, lr_ratio],
		)
		_t.check(
			"%s top-bottom seam smooth" % mask_id,
			tb_mean <= MAX_SEAM_MEAN_DELTA and tb_ratio <= MAX_SEAM_TO_INTERIOR_RATIO,
			"tb=%.5f interior=%.5f ratio=%.2f" % [tb_mean, interior_mean, tb_ratio],
		)
		_t.check(
			"%s RGB channels carry detail" % mask_id,
			min_std >= MIN_CHANNEL_STDDEV,
			"min_std=%.4f" % min_std,
		)


func _measure_seam_and_variance(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var lr_sum := 0.0
	for y in range(h):
		var c_left := img.get_pixel(0, y)
		var c_right := img.get_pixel(w - 1, y)
		lr_sum += absf(c_left.r - c_right.r) + absf(c_left.g - c_right.g) + absf(c_left.b - c_right.b)
	var tb_sum := 0.0
	for x in range(w):
		var c_top := img.get_pixel(x, 0)
		var c_bot := img.get_pixel(x, h - 1)
		tb_sum += absf(c_top.r - c_bot.r) + absf(c_top.g - c_bot.g) + absf(c_top.b - c_bot.b)
	var interior_sum := 0.0
	var interior_pairs := 0
	for y in range(0, h, 2):
		for x in range(0, w - 1, 2):
			var c_a := img.get_pixel(x, y)
			var c_b := img.get_pixel(x + 1, y)
			interior_sum += absf(c_a.r - c_b.r) + absf(c_a.g - c_b.g) + absf(c_a.b - c_b.b)
			interior_pairs += 1
	var sum_r := 0.0
	var sum_g := 0.0
	var sum_b := 0.0
	var sq_r := 0.0
	var sq_g := 0.0
	var sq_b := 0.0
	var samples := 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			sum_r += c.r
			sum_g += c.g
			sum_b += c.b
			sq_r += c.r * c.r
			sq_g += c.g * c.g
			sq_b += c.b * c.b
			samples += 1
	var inv := 1.0 / float(maxi(samples, 1))
	var std_r := sqrt(maxf(0.0, sq_r * inv - pow(sum_r * inv, 2.0)))
	var std_g := sqrt(maxf(0.0, sq_g * inv - pow(sum_g * inv, 2.0)))
	var std_b := sqrt(maxf(0.0, sq_b * inv - pow(sum_b * inv, 2.0)))
	return {
		"lr_mean": lr_sum / float(h * 3),
		"tb_mean": tb_sum / float(w * 3),
		"interior_mean": interior_sum / float(maxi(interior_pairs, 1) * 3),
		"min_std": minf(std_r, minf(std_g, std_b)),
	}
