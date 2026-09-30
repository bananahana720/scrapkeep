extends SceneTree

const Presentation := preload("res://src/presentation/presentation.gd")
const CodexBanner := preload("res://src/presentation/codex_banner.gd")
const Codex := preload("res://src/core/codex.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")

# A first-find part card shows the part's own row: its name and its text, including for
# a generated part. Synergy cards keep reading the codex.


func _initialize() -> void:
	var fails := 0
	var banner = CodexBanner.new()
	root.add_child(banner)
	banner.cards = true
	var p = Presentation.new()
	var codex = Codex.new()
	p.ctx = {"codex": codex}
	p.banner = banner
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var generated := ItemGen.roll_id(rng, "rare")
	for id in ["slag_rounds", generated]:
		banner.dismiss(true)
		p._on_part(id, "gate")
		var row := Parts.row(id)
		var want_name := String(row.get("name", ""))
		var want_text := String(row.get("text", ""))
		if want_name == "" or want_text == "":
			print("FAIL %s: Parts row has no name or text" % id)
			fails += 1
		elif banner._title.text != want_name:
			print("FAIL %s: title \"%s\", want \"%s\"" % [id, banner._title.text, want_name])
			fails += 1
		elif banner._body.text != want_text or not banner._body.visible:
			print("FAIL %s: body \"%s\" visible=%s, want \"%s\"" % [id, banner._body.text, banner._body.visible, want_text])
			fails += 1
		else:
			print("ok %s: \"%s\" / \"%s\"" % [id, want_name, want_text])
	p.free()
	codex.free()
	banner.free()
	print("discovery_part_card_test: %s" % ("FAIL" if fails > 0 else "PASS"))
	quit(1 if fails > 0 else 0)
