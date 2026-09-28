"""Verify the actual GLB structure and pose geometry after Blender reimport."""
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector, kdtree

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import rig_pilot as rig

PILOT=sys.argv[sys.argv.index('--')+1]
assert PILOT in ('rivet','sable','kest')
OUT=rig.ROOT/'artifacts/anim-pilot'/(PILOT if PILOT!='rivet' else '')
GLB=HERE.parents[1]/f'assets/models/pilot_{PILOT}_anim.glb'
MANIFEST=json.loads((OUT/'rig-manifest.json').read_text())


def points(objects):
    deps=bpy.context.evaluated_depsgraph_get()
    result=[]
    for obj in objects:
        evaluated=obj.evaluated_get(deps)
        mesh=evaluated.to_mesh()
        result.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
        evaluated.to_mesh_clear()
    return result


def distance(a,b):
    tree=kdtree.KDTree(len(b))
    for i,p in enumerate(b):tree.insert(p,i)
    tree.balance()
    return max(tree.find(p)[2] for p in a)


def main():
    blob=GLB.read_bytes()
    assert blob[:4]==b'glTF'
    length=struct.unpack_from('<I',blob,12)[0]
    doc=json.loads(blob[20:20+length])
    assert [a['name'] for a in doc['animations']]==['drop_land']
    assert len(doc['skins'])==1 and len(doc['skins'][0]['joints'])==25
    tris=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
    assert tris==MANIFEST['export_pilot_triangles']
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert {'JOINTS_0','WEIGHTS_0'} <= primitive['attributes'].keys()
    times=[doc['accessors'][s['input']] for s in doc['animations'][0]['samplers']]
    start=min(a['min'][0] for a in times)
    end=max(a['max'][0] for a in times)
    assert abs(start)<1e-6 and abs(end-1.1)<1e-5,(start,end)
    rows=json.loads((HERE/f'{PILOT}-drop-poses.json').read_text())['rows']
    bpy.ops.wm.open_mainfile(filepath=str(OUT/f'{PILOT}-drop.blend'))
    original=[bpy.data.objects[n] for n in MANIFEST['mesh_nodes']]
    source={}
    for row in rows:
        bpy.context.scene.frame_set(row['frame'])
        source[row['key']]=points(original)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps=30
    bpy.ops.import_scene.gltf(filepath=str(GLB))
    imported=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
    assert len(imported)==len(MANIFEST['mesh_nodes']), [(o.name,o.type) for o in bpy.context.scene.objects]
    errors=[]
    for row in rows:
        bpy.context.scene.frame_set(row['frame']-1)
        actual=points(imported)
        error=max(distance(source[row['key']],actual),distance(actual,source[row['key']]))
        errors.append({'key':row['key'],'frame':row['frame'],'hausdorff_distance':error})
    worst=max(e['hausdorff_distance'] for e in errors)
    skeleton=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    radius=0;drift=0
    for half in range(67):
        frame=half/2
        bpy.context.scene.frame_set(int(frame),subframe=frame%1)
        bpy.context.view_layer.update()
        radius=max(radius,max(p.length for p in points(imported)))
        anchor=skeleton.matrix_world@skeleton.pose.bones['pelvis'].head
        drift=max(drift,(anchor-Vector((0,0,-.3))).length)
    assert radius<.98 and drift<1e-6,(radius,drift)
    hierarchy={b.name:b.parent.name if b.parent else None for b in skeleton.data.bones}
    assert hierarchy==MANIFEST['bone_hierarchy'],hierarchy
    receipt={'glb_sha256':hashlib.sha256(blob).hexdigest(),'glb_bytes':len(blob),
             'pilot':PILOT,'animation':'drop_land','start_seconds':start,'end_seconds':end,
             'skins':1,'joints':25,'triangles':tris,'channels':len(doc['animations'][0]['channels']),
             'reimport_meshes':len(imported),'pose_geometry_errors':errors,
             'reimport_max_radius_67_samples':radius,'reimport_pelvis_max_drift':drift,'bone_hierarchy_matches':True,
             'max_pose_error':worst,'tolerance':.0001,'pass':worst<.0001}
    (OUT/'glb-verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
    assert worst<.0001,receipt
    print(json.dumps(receipt))


if __name__=='__main__':main()
