"""Compare all original vertex positions in the saved Rivet baseline to a rebuilt shared rig."""
import json
import sys
from pathlib import Path
import bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import rig_pilot as rig
import anim_rivet_drop as anim
from verify_rivet_drop import points
OUT=rig.ROOT/'artifacts/anim-pilot/shared'
rows=json.loads(anim.TABLE.read_text())['rows']
bpy.ops.wm.open_mainfile(filepath=str(OUT/'baseline/rivet-drop.blend'))
names=['Pilot','Claws.R','Claws.L']
old={}
for row in rows:
    bpy.context.scene.frame_set(row['frame'])
    old[row['key']]=points([bpy.data.objects[n] for n in names])
arm,meshes,root=rig.build(polished=False)
errors=[]
for row in rows:
    rig.clear_pose(arm)
    anim.apply_row(arm,row)
    bpy.context.view_layer.update()
    new=points([bpy.data.objects[n] for n in names])
    assert len(new)==len(old[row['key']])
    error=max((a-b).length for a,b in zip(old[row['key']],new))
    errors.append({'key':row['key'],'max_vertex_error':error})
report={'poses':errors,'max_error':max(e['max_vertex_error'] for e in errors),'bones':len(arm.data.bones),'triangles':sum(rig.common.tris(o) for o in meshes),'baseline':'shared/baseline/rivet-drop.blend'}
report['pass']=report['max_error']<1e-6
(OUT/'rivet-regression.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['pass'],report
print(json.dumps(report))
