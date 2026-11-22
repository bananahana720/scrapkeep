# smoke: solo (calls PackedScene.take_over_path on boss_pickup.glb, overwriting the process ResourceCache, and checks Boss._pickup_mesh cold load)
extends SceneTree

const Boss := preload("res://src/boss/boss.gd")
const T := preload("res://tests/support/t.gd")
const PICKUP := "res://assets/models/bosses/boss_pickup.glb"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("fua_boss_pickup_failure_test")
	# Replace only this process's cached scene, preserving the asset on disk. Each
	# instantiation counts a real model validation attempt in the production loader.
	var fixture_script := GDScript.new()
	fixture_script.source_code = "extends Node3D\nstatic var attempts := 0\nfunc _init():\n\tattempts += 1\n"
	t.eq("counting fixture compiles", fixture_script.reload(), OK)
	var fixture := Node3D.new()
	fixture.set_script(fixture_script)
	var packed := PackedScene.new()
	t.eq("malformed scene packs", packed.pack(fixture), OK)
	fixture.free()
	fixture_script.set("attempts", 0)
	packed.take_over_path(PICKUP)
	var arena := Node3D.new()
	root.add_child(arena)
	var boss := Boss.new()
	boss.arena = arena
	boss._spawn_pickup(Vector3.ZERO, 7, "spill")
	t.eq("first malformed pickup performs one validation attempt", fixture_script.get("attempts"), 1)
	t.check("first malformed pickup uses box fallback", boss._pickups[0].node.find_child("ScrapCore", false, false).mesh is BoxMesh)
	boss._spawn_pickup(Vector3.RIGHT, 9, "returned")
	t.eq("second malformed pickup does not retry validation", fixture_script.get("attempts"), 1)
	t.check("second malformed pickup keeps box fallback", boss._pickups[1].node.find_child("ScrapCore", false, false).mesh is BoxMesh)
	t.eq("fallback keeps pickup value", boss._pickups[1].value, 9)
	boss.free()
	arena.free()
	quit(t.verdict())
