import bpy, math, mathutils
from mathutils import Vector
import os
M=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../assets/models"))+"/"
def reset(res=(960,540), samples=24, ink=True, ink_w=1.4):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene
    sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=samples; sc.cycles.use_denoising=True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.view_settings.view_transform='Standard'; sc.view_settings.look='None'
    sc.render.use_freestyle=ink
    if ink:
        sc.render.line_thickness_mode='ABSOLUTE'; sc.render.line_thickness=ink_w
        vl=sc.view_layers[0]; ls=vl.freestyle_settings.linesets[0] if vl.freestyle_settings.linesets else vl.freestyle_settings.linesets.new("L")
        ls.select_by_visibility=True; ls.select_by_edge_types=True
        ls.select_silhouette=True; ls.select_border=True; ls.select_crease=True
        if ls.linestyle is None: ls.linestyle=bpy.data.linestyles.new("ink")
        ls.linestyle.color=(0.06,0.05,0.07)
    w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
    return sc
def sky(top, horizon, strength=1.0):
    w=bpy.context.scene.world; nt=w.node_tree; bg=nt.nodes["Background"]
    tc=nt.nodes.new("ShaderNodeTexCoord"); sep=nt.nodes.new("ShaderNodeSeparateXYZ"); ramp=nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"] if False else tc.outputs["Window"], sep.inputs[0])
    nt.links.new(sep.outputs[1], ramp.inputs[0])
    ramp.color_ramp.elements[0].color=(*horizon,1); ramp.color_ramp.elements[1].color=(*top,1)
    lp=nt.nodes.new("ShaderNodeLightPath"); mix=nt.nodes.new("ShaderNodeMixShader"); bg2=nt.nodes.new("ShaderNodeBackground")
    bg2.inputs[0].default_value=(*[ (a+b)/2 for a,b in zip(top,horizon)],1); bg2.inputs[1].default_value=strength
    bg.inputs[1].default_value=1.0
    nt.links.new(ramp.outputs[0], bg.inputs[0])
    out=nt.nodes["World Output"]
    nt.links.new(bg2.outputs[0], mix.inputs[1]); nt.links.new(bg.outputs[0], mix.inputs[2])
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0]); nt.links.new(mix.outputs[0], out.inputs[0])
def load(path, loc=(0,0,0), rot=(0,0,0), scale=1.0, name=None):
    before=set(bpy.data.objects)
    for coll in (bpy.data.materials, bpy.data.images, bpy.data.meshes, bpy.data.textures):
        for d in coll:
            if "~" not in d.name: d.name = d.name + "~" + str(id(d) % 100000)
    bpy.ops.import_scene.gltf(filepath=M+path)
    new=[o for o in bpy.data.objects if o not in before]
    root=bpy.data.objects.new(name or path, None); bpy.context.scene.collection.objects.link(root)
    for o in new:
        if o.parent is None: o.parent=root
    root.location=loc; root.rotation_euler=[math.radians(a) for a in rot]; root.scale=(scale,)*3
    for a in bpy.data.actions: pass
    for o in new:
        if o.animation_data: o.animation_data.action=None
    return root
def ball(pilot, loc=(0,0,0), rot=(0,0,0), scale=1.0, shell=True, pose_name=None, pose_frame=0):
    r=bpy.data.objects.new("ball_"+pilot, None); bpy.context.scene.collection.objects.link(r)
    if pilot in ("sable","rivet","kest") and pose_name is None:
        s=load(f"shell_{pilot}.glb"); s.parent=r
    else:
        p=load(f"pilot_{pilot}_anim.glb"); p.parent=r; p.scale=(0.85,)*3; p.location=(0,0,-0.12)
        if pose_name:
            for o in p.children_recursive:
                if o.animation_data is None: o.animation_data_create()
                a=bpy.data.actions.get(pose_name)
                if a:
                    o.animation_data.action=a
                    if hasattr(o.animation_data,"action_slot") and a.slots: o.animation_data.action_slot=a.slots[0]
            bpy.context.scene.frame_set(pose_frame)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.98, segments=48, ring_count=24); g=bpy.context.object; g.parent=r
        gm=bpy.data.materials.new("glass"); gm.use_nodes=True; b=gm.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value=(0.9,0.95,1,1); b.inputs["Roughness"].default_value=0.05; b.inputs["Alpha"].default_value=0.12
        g.data.materials.append(gm); bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_torus_add(major_radius=0.99, minor_radius=0.03, location=(0,0,0)); t=bpy.context.object; t.parent=r
        t.data.materials.append(mat((0.12,0.22,0.22),0.5))
        bpy.ops.mesh.primitive_torus_add(major_radius=0.93, minor_radius=0.025, location=(0,0,-0.05)); t2=bpy.context.object; t2.parent=r
        t2.data.materials.append(mat((0.3,1.0,0.85),0.3,0.8))
    r.location=loc; r.rotation_euler=[math.radians(a) for a in rot]; r.scale=(scale,)*3
    return r
def mat(color, rough=0.6, emit=0.0):
    m=bpy.data.materials.new("m"); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*color,1); b.inputs["Roughness"].default_value=rough
    if emit: b.inputs["Emission Color"].default_value=(*color,1); b.inputs["Emission Strength"].default_value=emit
    return m
def plane(size, loc, color, rot=(0,0,0)):
    bpy.ops.mesh.primitive_plane_add(size=size, location=loc, rotation=[math.radians(a) for a in rot]); o=bpy.context.object; o.data.materials.append(mat(color,0.9)); return o
def cam(loc, look, lens=35, roll=0.0):
    sc=bpy.context.scene; c=bpy.data.objects.new("cam",bpy.data.cameras.new("cam")); sc.collection.objects.link(c); sc.camera=c
    c.location=loc; d=Vector(look)-Vector(loc); q=d.to_track_quat('-Z','Y')
    q=q @ mathutils.Quaternion((0,0,1), math.radians(roll))
    c.rotation_mode='QUATERNION'; c.rotation_quaternion=q
    c.data.lens=lens; c.data.clip_end=5000; return c
def sun(rot, energy=3.5, color=(1,0.95,0.88)):
    l=bpy.data.objects.new("sun",bpy.data.lights.new("sun","SUN")); l.data.energy=energy; l.data.color=color; l.data.angle=math.radians(2)
    l.rotation_euler=[math.radians(a) for a in rot]; bpy.context.scene.collection.objects.link(l); return l
def point(loc, energy, color=(1,1,1), size=0.5):
    l=bpy.data.objects.new("pt",bpy.data.lights.new("pt","POINT")); l.data.energy=energy; l.data.color=color; l.data.shadow_soft_size=size
    l.location=loc; bpy.context.scene.collection.objects.link(l); return l
def render(path):
    bpy.context.scene.render.filepath=path; bpy.ops.render.render(write_still=True)
