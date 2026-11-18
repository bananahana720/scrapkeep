extends SceneTree

const Game := preload("res://src/game.gd")
const Classes := preload("res://src/core/class_def.gd")
var peak := {}
var landed := false

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var game := Game.new()
    game.test_mode = true
    root.add_child(game)
    while game.flow == null:
        await physics_frame
    game.ctx.calm = true
    game.flow.press_start()
    game.flow.choose_class(0)
    for step in 12:
        await physics_frame
    game.player.fit_class(Classes.by_id("runner_gunner"))
    var hero = game.presentation.hero_assets
    await process_frame
    var ult = game.combat.ultimate
    var rec:Dictionary=hero.shell_of(game.player)
    var bones := []
    for rig in rec.core.find_children("*","Skeleton3D",true,false):
        for i in rig.get_bone_count():
            bones.append(rig.get_bone_name(i))
    game.events.ultimate_peak.connect(func(id:String,_at:Vector3):
        peak={"piece":id,"phase":ult.phase(),"reaction":rec.get("reaction",""),"fin_bones":bones})
    game.events.ultimate_landed.connect(func(_id:String,_at:Vector3,_hits:int,_damage:float):
        landed=true)
    ult.meter.locked = false
    ult.meter.refund(ult.meter.CAP)
    var origin:Vector3=game.player.ball_position()+Vector3.UP*2.0
    var refused:String=ult.press({"origin":origin,"forward":Vector3(1.0,-0.25,0).normalized()})
    for tick in 420:
        await physics_frame
        if landed:
            break
    print("RIVET_RIDE ",JSON.stringify({"press":refused,"peak":peak,"landed":landed}))
    game.free()
    quit(0 if refused == "" and peak.get("piece","") == "foundry_cutter" and landed else 1)
