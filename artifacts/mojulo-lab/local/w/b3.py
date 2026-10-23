import sys; sys.path.insert(0,'.')
from h import *
SRC="""const n=params.n; const boxes=[];
for(let i=0;i<n;i++){ boxes.push({id:'b',op:'add',shape:{kind:'box',center:[i*12,0,i*6],size:[10,60,5]}}); }
return {fields:[{exact:true,segments:8,terms:boxes}]};"""
SRC2="""const n=params.n; const treads=[];
for(let i=0;i<n;i++){ treads.push({profile:{rect:{w:28,h:90}},axisFrom:{x:i*28+14,y:0,z:(i+1)*17-4},axisTo:{x:i*28+14,y:0,z:(i+1)*17},material:'wood'}); }
return {extrudes:treads};"""
mode=sys.argv[1]
for n in map(int,sys.argv[2:]):
    if mode=='ext':
        sp={'units':'cm','params':{'n':n},'budgetMs':60000,'source':SRC2}
        print(rung('B3 N=%d'%n,'code',sp,'code program returns %d extrude treads (stair), budgetMs=60000'%n))
    else:
        sp={'units':'cm','params':{'n':n},'budgetMs':60000,'source':SRC}
        print(rung('B3f N=%d'%n,'code',sp,'code program returns %d field box terms exact, budgetMs=60000'%n))
