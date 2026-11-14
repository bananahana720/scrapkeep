# blender -b --factory-startup -P pilot_pose_check.py -- pilot.glb [more.glb ...]
# Plays every clip of a pilot and measures how far the skin stretches: for each edge, its posed length over its rest length,
# sampled at eight frames a clip. Prints one line a pilot with the worst clip and the share of edges that more than double.
# The authored pilots measure 0.0 to 0.1 percent. The first Tripo skins (weights copied from the authored mesh) measured 5.1 to
# 7.5 percent on five pilots and 2.1 percent on Tarn (stretch_before in the refit's receipt); keep a sibling under 4 percent.
# tools/tripo/README.md has each pilot's number.
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
