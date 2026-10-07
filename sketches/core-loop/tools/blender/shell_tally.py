"""Tally's three-bay card reader, internal flywheels and battered rolling shell.

blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/shell_tally.py

The common spherical assembly's seat, grips, 0.98 m glass and gyro are reproduced
locally because its built-in pilot and emissive field would violate this unit's
separate-pilot and five-material contracts. Shared scripts remain untouched.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import common
from common import Part
from pilot_tally import punched_panel,glb_counts,PREVIEW

OUT=HERE.parents[1]/"assets/models/world_one/shell_tally.glb"


def plates(p):
    """Inset spherical plate sectors, broad rubbed patches and sheltered dark seams."""
    bands=[(-.30,-.59,14,.13),(-.59,-.84,12,.29),(-.84,-.96,8,.04)]
    colours=["f7f1e3","petrol","f7f1e3","charcoal","petrol","f7f1e3","petrol"]
    for band,(z0,z1,n,offset) in enumerate(bands):
        for k in range(n):
            start=math.tau*k/n+offset+.014
            end=math.tau*(k+1)/n+offset-.014
            top=z0-.008
            bottom=z1+.008
            if band==0 and math.cos((start+end)/2)>.80:
                top=-.452
            # Broad polygonal patches follow the ball; nothing becomes a ground foot.
            cols=3
            rows=[]
            for radius in (.925,.947):
                layer=[]
                for z in (top,(top+bottom)/2,bottom):
                    ring=[]
                    r=math.sqrt(max(.001,radius*radius-z*z))
                    for j in range(cols+1):
                        a=start+(end-start)*j/cols
                        ring.append(p.bm.verts.new((r*math.sin(a),r*math.cos(a),z)))
                    layer.append(ring)
                rows.append(layer)
            fs=[]
            colour=colours[(k+band*3)%len(colours)]
            for i in range(2):
                for j in range(cols):
                    outer=p.bm.faces.new((rows[1][i][j],rows[1][i+1][j],rows[1][i+1][j+1],rows[1][i][j+1]))
                    inner=p.bm.faces.new((rows[0][i][j],rows[0][i][j+1],rows[0][i+1][j+1],rows[0][i+1][j]))
                    p.paint([outer],"paint",colour)
                    p.paint([inner],"rubber")
                    # A few unequal wear patches sit at exposed corners, not a bolt grid.
                    if (k+band*4)%7==2 and i==0 and j in (0,1):
                        p.paint([outer],"paint","f7f1e3" if colour!="f7f1e3" else "706a5d")
                    fs += [outer,inner]
            boundary=[(0,j) for j in range(cols+1)]+[(1,cols),(2,cols)]+[(2,j) for j in range(cols-1,-1,-1)]+[(1,0)]
            for j,(r,c) in enumerate(boundary):
                rr,cc=boundary[(j+1)%len(boundary)]
                f=p.bm.faces.new((rows[0][r][c],rows[0][rr][cc],rows[1][rr][cc],rows[1][r][c]))
                p.paint([f],"paint","charcoal" if j%3 else "f7f1e3")
            # One repair fastener on selected panels, sunk inside the rolling boundary.
            if k%3==0 and band<2:
                a=(start+end)/2
                z=top-.04
                r=math.sqrt(.949**2-z*z)
                loc=Vector((r*math.sin(a),r*math.cos(a),z))
                p.bolt(loc,loc.normalized(),r=.014,h=.010,segs=6)


def common_cockpit(p):
    # Dimensions copied from shell_base.spherical, without its duplicate animal.
    # The reader interrupts the front rim so all three bays remain visible.
    p.ring("paint",.86,.92,.12,42,loc=(0,0,-.29),color="petrol",
           arc=(math.pi/2+.50,math.pi/2+math.tau-.50))
    for k in range(12):
        a=k*math.tau/12
        if abs(a-math.pi/2)<.50:
            continue
        normal=Vector((math.cos(a),math.sin(a),0))
        p.bolt(normal*.919+Vector((0,0,-.29)),normal,r=.015,h=.010)
    for start,span,z,depth in ((.35,.63,-.30,.073),(2.5,.43,-.305,.055),(4.9,.26,-.28,.045)):
        p.ring("paint",.916,.924,depth,4,loc=(0,0,z),color="f7f1e3",arc=(start,start+span))
    p.cyl("rubber",.36,.28,.16,20,loc=(0,0,-.6))
    for z in (-.62,-.69,-.76):
        p.ring("paint",.18,.25,.027,24,loc=(0,0,z),color="f7f1e3")
    seat=[(-.22,-.27),(.22,-.27),(.27,-.20),(.24,.14),(.16,.20),(-.16,.20),(-.24,.14),(-.27,-.20)]
    p.prism("paint",seat,.09,matrix=common.mtx((0,-.27,-.1),(math.pi/2,0,0)),color="petrol")
    p.uv("rubber",.22,12,8,loc=(0,-.22,-.12),scale=(1,.35,1.15))
    p.box("rubber",(.48,.42,.09),loc=(0,0,-.34))
    for s in (-1,1):
        p.rod("bare_metal",(s*.34,.28,-.32),(s*.32,.4,0),.025,8)
        p.rod("rubber",(s*.32,.4,0),(s*.32,.4,.10),.045,8)


def build():
    common.SLOTS["class_accent"] = {"color": "brass", "rough": .75}
    root=common.empty("ShellTally")
    glass=Part("Core")
    glass.uv("glass",.98,40,24)
    core=glass.to_object(parent=root)
    for f in core.data.polygons:
        f.use_smooth=True
    p=Part("Pod")
    common_cockpit(p)
    plates(p)
    p.box("rubber",(.40,.42,.05),loc=(0,.12,-.79))
    p.box("paint",(.46,.12,.08),loc=(0,.64,-.48),color="petrol")
    p.box("class_accent",(.40,.026,.017),loc=(0,.707,-.474))
    # Reader support and flywheel bearings explain how the kit joins the cockpit.
    for s in (-1,1):
        p.beam("paint",(s*.28,.52,-.37),(s*.29,.69,-.33),.07,.10,color="petrol")
        p.beam("bare_metal",(s*.30,-.35,-.28),(s*.50,-.35,-.28),.042,.042)
        p.box("rubber",(.095,.115,.105),loc=(s*.43,-.35,-.28))
    bmesh.ops.recalc_face_normals(p.bm,faces=list(p.bm.faces))
    pod=p.to_object(parent=root)
    common.empty("Dome",parent=pod)
    gyro=Part("Gyro")
    gyro.ring("bare_metal",.938,.965,.055,56,rot=(math.pi/2,0,0))
    gyro.ring("bare_metal",.946,.972,.028,56,rot=(math.pi/2,0,0))
    for s in (-1,1):
        gyro.cyl("bare_metal",.065,.065,.024,12,loc=(s*.94,0,0),rot=(0,math.pi/2,0))
    gyro.to_object(parent=pod)
    for side,s in (("R",1),("L",-1)):
        centre=(s*.50,-.35,-.28)
        wheel=Part("Flywheel."+side)
        wheel.ring("paint",.13,.17,.07,20,loc=centre,rot=(0,math.pi/2,0),color="f7f1e3")
        wheel.cyl("paint",.13,.13,.045,20,loc=centre,rot=(0,math.pi/2,0),color="petrol")
        wheel.cyl("paint",.035,.035,.07,10,loc=centre,rot=(0,math.pi/2,0),color="f7f1e3")
        for k in range(4):
            a=k*math.tau/4+.27
            wheel.box("paint",(.070,.016,.040),loc=(s*.50,-.35+.112*math.sin(a),-.28+.112*math.cos(a)),
                      rot=(a,0,0),color="charcoal")
        wheel.to_object(origin=centre,parent=pod)
        socket=common.empty("FlywheelAxis."+side,centre,pod)
        socket.rotation_euler=(0,math.pi/2,0)
    reader=Part("ReaderCarriage")
    reader.box("paint",(.70,.16,.23),loc=(0,.72,-.32),color="petrol")
    reader.box("paint",(.67,.008,.204),loc=(0,.804,-.32),color="charcoal")
    for i,x in enumerate((-.23,0,.23)):
        punched_panel(reader,(x,.80,-.32),.20,.19,.035,colour="f7f1e3")
        reader.box("paint",(.035,.04,.09),loc=(x,.72,-.17),color="oxide")
        reader.box("paint",(.040,.045,.017),loc=(x,.72,-.215),color="charcoal")
        for dx in (-.084,.084):
            reader.box("paint",(.008,.039,.174),loc=(x+dx,.80,-.32),color="charcoal")
    bmesh.ops.recalc_face_normals(reader.bm,faces=list(reader.bm.faces))
    carriage=reader.to_object(origin=(0,.72,-.32),parent=pod)
    for i,x in enumerate((-.23,0,.23)):
        common.empty("CardBay."+str(i),(x,.80,-.32),carriage)
    for name,pos,parent in [("ReaderExit",(0,.81,-.32),carriage),
        ("ReturnExit",(0,.72,-.48),pod),("StampContact",(0,.12,-.82),pod),
        ("LedgerMount",(-.255,.045,-.20),pod),
        ("Grip.R",(.32,.4,.05),pod),("Grip.L",(-.32,.4,.05),pod)]:
        obj=common.empty(name,pos,parent)
        # Socket local -Z is the outgoing axis after glTF/Godot conversion.
        obj.rotation_euler=(0,0,0) if name=="StampContact" else (math.pi/2,0,0)
    bpy.context.view_layer.update()
    radii={o.name:common.max_radius(o) for o in common.tree(root) if o.type=="MESH"}
    assert max(radii.values())<=.9850001,radii
    return root,radii


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,default=OUT)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    common.reset()
    root,radii=build()
    common.export(root,str(args.out))
    counts=glb_counts(args.out)
    assert counts["triangles"]<=11000 and counts["vertices"]<=11600 and counts["draws"]<=10 and counts["materials"]<=5,counts
    PREVIEW.mkdir(parents=True,exist_ok=True)
    (PREVIEW/"shell-receipt.json").write_text(json.dumps({"export":counts,"maximum_rest_radius":radii},indent=2)+"\n")
    print("TALLY_SHELL",json.dumps(counts,sort_keys=True))


if __name__=="__main__":
    main()
