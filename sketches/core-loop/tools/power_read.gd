extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# POWER-READ (alpha-status/ambition-map.md, unit 5): how much mightier one pilot's
# signature hit reads on a grown build than on the first fight. Every pilot slams the
# same way and the landing then takes the pilot's flavour (player_ball.gd _on_slammed),
# so the signature hit here is one scripted slam at 30 m/s (full flatness, in open air) with one
# standard chaser 3 m in front of the ball. The hit is identical at both depths; only
# the build differs:
#   depth 0  the pilot as chosen: no tree picks, no parts, no mass (heft class I)
#   depth 4  four tree picks (the left card each time), the first four catalogue parts the
#            pilot may be offered, and start mass to heft 3.2 (heft class IV)
# Readings, one JSON line per run ("power_read row: {...}"):
#   pixels   against the frame before the hit, each a peak over WINDOW frames, as a share of
#            the screen: area (pixels changed), energy (how far they changed), heat (colour
#            in what changed: max minus min channel), ink (changed pixels now dark: outlines
#            and words), centre (changed share of the middle ninth). The runner reads
#            presence from energy, heat and ink (Andrew's card "Presence, centre clear",
#            17 Oct 17:28Z). The same window without a hit is reported as noise. Needs a
#            display (xvfb-run is fine); --render=0 skips it. Peaks come from the first
#            HIT_FRAMES, and telegraphs and committed hazards are hidden while pixels are
#            read: combat geometry (Cannon's rush ring) is not the hit's look.
#   knock    metres the chaser actually travels while knockback outranks its own steering
#            (enemy.gd _move), plus the code's own v^2 / 2a reading of the push it got.
#   sound    cues the hit fired "now" in audio.cue_log, as entries and distinct sounds.
#   fx       vfx glyphs and fx_ effects spawned by the hit.
# The chaser's health is raised so neither depth kills it; a kill would add its death
# effects at one depth only. One warm-up slam lands on a throwaway chaser before the quiet
# wait, so a part's first-fire accent (reward_payoff's bell and ring) never counts as part of
# the grown hit. Camera shake is set to zero so a shake never counts as
# effect area; the shake itself is not read. It measures and changes nothing.
#   xvfb-run -a -s "-screen 0 960x540x24" godot --path sketches/core-loop --rendering-driver opengl3 \
#     --resolution 960x540 --fixed-fps 60 --script res://tools/power_read.gd -- --pilot=tally --depth=4 [--out=dir]
# scripts/power-read.mjs runs every pilot at both depths and writes the phone page.

const BALL := Vector3(0.0, 500.0, 0.0)
const TARGET := Vector3(0.0, 0.0, -3.0)
const SLAM_SPEED := 30.0
const GROWN_DEPTH := 4
const GROWN_PARTS := 4
const GROWN_HEFT := 3.2
const SETTLE_FRAMES := 30
# Long enough for the stage banner and any part-gained card and bell to clear.
const QUIET_FRAMES := 360
const WINDOW := 45
# Pixel peaks come from the hit's own first frames: its bursts, words and ink live about three
# frames, and the peak lands by frame 8 for every pilot on main. Later frames hold what the hit
# leaves behind, such as Cannon's rush zone growing to fill the screen.
const HIT_FRAMES := 15
const KNOCK_FRAMES := 240
const SOUND_WAIT_FRAMES := 600
# A channel moved by more than this (0 to 1) counts the pixel as changed.
const PIXEL_DELTA := 0.1
# A changed pixel whose mean channel ends under this (0 to 1) counts as ink.
const INK_LEVEL := 0.25
const METRICS := ["area", "energy", "heat", "ink", "centre"]
const STURDY_HP := 100000.0

var _game
var _args := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _run() -> void:
	var row := {}
	var code := 0
	var problem := await _measure(row)
	if problem != "":
		row["error"] = problem
		code = 1
	print("power_read row: " + JSON.stringify(row))
	if _args.has("out"):
		DirAccess.make_dir_recursive_absolute(_args["out"])
		var file := FileAccess.open(_args["out"].path_join("%s-d%d.json" % [row.get("pilot", "x"), row.get("depth", -1)]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(row, "  "))
	quit(code)


func _measure(row: Dictionary) -> String:
	var pilot: String = _args.get("pilot", "pylon_engineer")
	var depth := int(_args.get("depth", "0"))
	var render: bool = _args.get("render", "1") != "0" and DisplayServer.get_name() != "headless"
	row["pilot"] = pilot
	row["depth"] = depth
	row["slam_speed"] = SLAM_SPEED
	row["renderer"] = "%s/%s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()]
	while _game.flow == null:
		await process_frame
	var index := -1
	for i in _game.flow.classes.size():
		if _game.flow.classes[i].id == pilot:
			index = i
	if index < 0:
		return "unknown pilot %s" % pilot
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(index)
	await _frames(SETTLE_FRAMES)
	var problem := _grow(row, depth)
	if problem != "":
		return problem
	_park()
	var juice = _game.presentation.juice
	juice.set_comfort("shake", 0.0)
	var audio = _game.presentation.audio
	for i in SOUND_WAIT_FRAMES:
		if audio.sound_ready:
			break
		await process_frame
	row["sound_ready"] = audio.sound_ready
	await _frames(QUIET_FRAMES)
	# After the part cards close: a payoff waits while any reward ceremony is still showing.
	var warm := _spawn_target()
	await _frames(2)
	_game.player._on_slammed(_game.player.body().global_position, SLAM_SPEED, 1.0)
	await _frames(SETTLE_FRAMES)
	if is_instance_valid(warm):
		warm.queue_free()
	_park()
	await _frames(QUIET_FRAMES)
	row["payoffs_before_hit"] = _game.presentation.ceremony.payoffs.size()

	# The same window with no hit: what the scene changes on its own.
	var still := _spawn_target()
	await _frames(2)
	var before: Image = await _grab(render)
	var quiet := await _window(render, before)
	for k in METRICS:
		row["noise_" + k] = quiet[k]
	still.queue_free()
	_park()
	await _frames(2)

	var target := _spawn_target()
	await _frames(2)
	_park()
	before = await _grab(render)
	var cues_before: int = audio.cue_log_total
	var spawned_before := _spawned_total()
	var hp_before: float = target.hp
	var start: Vector3 = target.global_position
	_game.player._on_slammed(_game.player.body().global_position, SLAM_SPEED, 1.0)
	var push: Vector3 = target._knock
	var flat := Vector3(push.x, 0.0, push.z)
	row["knock_push_mps"] = flat.length()
	row["knock_code_m"] = maxf(0.0, (flat.length_squared() - 1.0) / (2.0 * target.KNOCK_DECAY))
	var direction := flat.normalized() if flat.length() > 0.0 else Vector3.ZERO
	var travelled := 0.0
	var shots: Array = []
	var peak := {}
	for k in METRICS:
		peak[k] = 0.0
	var area_sum := 0.0
	var peak_frame := -1
	for f in WINDOW:
		await process_frame
		if is_instance_valid(target) and target._knocked_speed() >= 1.0:
			travelled = maxf(travelled, (target.global_position - start).dot(direction))
		if render and f < HIT_FRAMES:
			row["telegraphs_hidden"] = maxi(int(row.get("telegraphs_hidden", 0)), _hide_telegraphs())
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var read := _changed(before, image)
			area_sum += read["area"]
			if read["energy"] > peak["energy"]:
				peak_frame = f
				shots = [image]
			for k in METRICS:
				peak[k] = maxf(peak[k], read[k])
	for f in KNOCK_FRAMES:
		if not is_instance_valid(target) or target._knocked_speed() < 1.0:
			break
		await process_frame
		travelled = maxf(travelled, (target.global_position - start).dot(direction))
	if is_instance_valid(target) and target._knocked_speed() >= 1.0:
		row["knock_unfinished"] = true
	row["knock_m"] = travelled
	row["damage"] = hp_before - (target.hp if is_instance_valid(target) else 0.0)
	for k in METRICS:
		row[k] = peak[k]
	row["area_sum"] = area_sum
	row["peak_frame"] = peak_frame
	row["rendered"] = render
	var fired: Array = audio.cues_since(cues_before)
	var now := fired.filter(func(c: Array) -> bool: return c[2] == "now")
	var sounds := {}
	for c in now:
		sounds[str(c[1])] = true
	row["sound_cues"] = now.size()
	row["sound_layers"] = sounds.size()
	row["sounds"] = sounds.keys()
	row["sound_skipped"] = fired.size() - now.size()
	row["fx_spawned"] = _spawned_total() - spawned_before
	row["payoffs_in_hit"] = _game.presentation.ceremony.payoffs.size() - int(row["payoffs_before_hit"])
	if render and _args.has("out"):
		DirAccess.make_dir_recursive_absolute(_args["out"])
		before.save_png(_args["out"].path_join("%s-d%d-before.png" % [pilot, depth]))
		if not shots.is_empty():
			shots[0].save_png(_args["out"].path_join("%s-d%d-peak.png" % [pilot, depth]))
	return ""


# The depth-4 build: the left card at each of four picks, four catalogue parts, heft IV.
func _grow(row: Dictionary, depth: int) -> String:
	var run = _game.ctx.run
	var tree = _game.player.tree
	if depth > 0:
		tree.world_one = false
		tree.max_depth = UpgradeTree.DEPTHS
		tree.reset(run.class_id())
		for d in range(1, depth + 1):
			if not tree.pending():
				tree.open_checkpoint()
			var offer: Array = tree.offered(run.class_id(), d)
			if offer.is_empty() or not tree.pick(offer[0]["id"]):
				return "tree pick at depth %d failed (offer %s)" % [d, offer]
		var pool := Parts.offer_pool(run.class_id(), ["common", "uncommon", "rare"])
		for id in Parts.CATALOGUE:
			if run.parts.size() >= GROWN_PARTS:
				break
			if id in pool:
				run.add_part(id, "power_read")
		run.grant_start_mass((GROWN_HEFT - run.heft() + run.mass * run.HEFT_PER_MASS) / run.HEFT_PER_MASS)
	row["picks"] = Array(tree.path())
	row["parts"] = Array(run.parts)
	row["heft"] = run.heft()
	row["heft_class"] = run.raw_heft_class(run.heft())
	return ""


# The ball held still in open air, so the backdrop and camera never move between frames.
func _park() -> void:
	_game.player.reset_to(BALL)
	_game.player.body().global_position = BALL
	_game.player.active_body().freeze = true


# A standard chaser in front of the ball, too sturdy to die, its own body hidden so only
# what the hit draws counts as changed pixels.
func _spawn_target() -> Node3D:
	var enemy: Node3D = _game.ctx.spawner.spawn_enemy("chaser", BALL + TARGET)
	enemy._set_health(STURDY_HP)
	enemy.visible = false
	return enemy


func _window(render: bool, before) -> Dictionary:
	var peak := {}
	for k in METRICS:
		peak[k] = 0.0
	for f in WINDOW:
		await process_frame
		if render and f < HIT_FRAMES:
			_hide_telegraphs()
			await RenderingServer.frame_post_draw
			var read := _changed(before, root.get_texture().get_image())
			for k in METRICS:
				peak[k] = maxf(peak[k], read[k])
	return peak


# Telegraphs, hostile threats and every committed hazard, the player's own included (Cannon's
# rush ring is a hazard the slam commits): combat geometry, not the hit's look.
func _hide_telegraphs() -> int:
	var hidden := 0
	var nodes: Array = get_nodes_in_group("telegraph") + get_nodes_in_group(Threat.GROUP)
	nodes.append_array(_hazards(_game))
	for node in nodes:
		if node is Node3D and node.visible:
			node.visible = false
			hidden += 1
	return hidden


func _hazards(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Hazard:
			out.append(child)
		else:
			out.append_array(_hazards(child))
	return out


func _grab(render: bool):
	if not render:
		return null
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _spawned_total() -> int:
	var total := 0
	var spawned: Dictionary = _game.presentation.vfx.spawned
	for k in spawned:
		total += int(spawned[k])
	return total


# Each reading as a share of the screen. A pixel counts as changed when any channel moved by
# more than PIXEL_DELTA; energy adds how far it moved, heat its colour (max minus min channel,
# saturation times value), ink whether it ended dark. Centre is the changed share of the
# middle third by width and height.
static func _changed(a: Image, b: Image) -> Dictionary:
	var out := {"area": 0.0, "energy": 0.0, "heat": 0.0, "ink": 0.0, "centre": 0.0}
	if a == null or b == null or a.get_size() != b.get_size():
		return out
	var da := a.get_data()
	var db := b.get_data()
	var step := 4 if a.get_format() == Image.FORMAT_RGBA8 else 3
	var width := a.get_width()
	var height := a.get_height()
	var box := Rect2i(width / 3, height / 3, width / 3, height / 3)
	var limit := int(PIXEL_DELTA * 255.0)
	var ink_level := int(INK_LEVEL * 255.0 * 3.0)
	var changed := 0
	var energy := 0
	var heat := 0
	var ink := 0
	var centre := 0
	var i := 0
	for y in height:
		var middle_row := y >= box.position.y and y < box.end.y
		for x in width:
			var r := absi(da[i] - db[i])
			var g := absi(da[i + 1] - db[i + 1])
			var bl := absi(da[i + 2] - db[i + 2])
			if r > limit or g > limit or bl > limit:
				changed += 1
				energy += r + g + bl
				var hi := maxi(db[i], maxi(db[i + 1], db[i + 2]))
				var lo := mini(db[i], mini(db[i + 1], db[i + 2]))
				heat += hi - lo
				if db[i] + db[i + 1] + db[i + 2] < ink_level:
					ink += 1
				if middle_row and x >= box.position.x and x < box.end.x:
					centre += 1
			i += step
	var count := float(maxi(width * height, 1))
	out["area"] = changed / count
	out["energy"] = energy / (765.0 * count)
	out["heat"] = heat / (255.0 * count)
	out["ink"] = ink / count
	out["centre"] = centre / float(maxi(box.size.x * box.size.y, 1))
	return out
