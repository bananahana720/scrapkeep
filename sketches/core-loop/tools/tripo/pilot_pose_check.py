import bpy, sys, json
a = sys.argv[sys.argv.index("--") + 1:]
for path in a:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    sc = bpy.context.scene
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    ob = max([o for o in bpy.data.objects if o.type == "MESH" and o.vertex_groups], key=lambda o: len(o.data.vertices))
    edges = [tuple(e.vertices) for e in ob.data.edges]
    def lengths():
        dg = bpy.context.evaluated_depsgraph_get(); ev = ob.evaluated_get(dg); m = ev.to_mesh()
        co = [v.co.copy() for v in m.vertices]; ev.to_mesh_clear()
        return [(co[i] - co[j]).length for i, j in edges]
    arm.animation_data_clear()
    for pb in arm.pose.bones: pb.matrix_basis.identity()
    bpy.context.view_layer.update(); rest = lengths()
    worst = {}
    for act in sorted(bpy.data.actions, key=lambda x: x.name):
        arm.animation_data_create(); arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and getattr(act, "slots", None): arm.animation_data.action_slot = act.slots[0]
        f0, f1 = act.frame_range; share = 0.0; top = 0.0
        for k in range(8):
            sc.frame_set(int(round(f0 + (f1 - f0) * k / 7))); ln = lengths()
            r = [l / r0 for l, r0 in zip(ln, rest) if r0 > 1e-4]
            share = max(share, sum(1 for x in r if x > 2.0) / len(r)); top = max(top, sorted(r)[int(len(r) * 0.999)])
        worst[act.name] = (round(100 * share, 2), round(top, 2))
    clip = max(worst, key=lambda k: worst[k][0])
    print("STRETCH", json.dumps({"file": path.split("/")[-1], "worst_clip": clip, "edges_doubled_pct": worst[clip][0], "p999_ratio": worst[clip][1],
        "big_cheer": worst.get("big_cheer"), "heave": worst.get("heave"), "clips": len(worst)}))
