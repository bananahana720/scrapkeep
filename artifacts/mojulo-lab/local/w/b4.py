import sys; sys.path.insert(0,'.')
from h import *
for a in sys.argv[1:]:
    H,fn=map(int,a.split(','))
    src="$fn=%d;\ndifference(){ cube([2000,2000,20]);\n for(i=[0:%d-1]) for(j=[0:%d-1]) translate([(i+0.5)*2000/%d,(j+0.5)*2000/%d,-1]) cylinder(d=0.6*2000/%d,h=22);\n}"%(fn,H,H,H,H,H)
    print(rung('B4 H=%d fn=%d'%(H,fn),'scad',{'source':src,'units':'mm'},'2000x2000x20mm plate, %dx%d=%d holes, $fn=%d'%(H,H,H*H,fn)))
