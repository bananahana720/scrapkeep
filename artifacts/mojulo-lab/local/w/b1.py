import sys; sys.path.insert(0,'.')
from h import *
def spec(n,seg):
    nx,ny=n; sp=900/ max(nx,ny)
    return {'units':'cm','fields':[{'id':'ball','exact':True,'segments':seg,'terms':[
      {'id':'s','op':'add','shape':{'kind':'sphere','center':[0,0,500],'radius':500}},
      {'op':'repeat','spacing':[sp,sp,0],'count':[nx,ny,1],'combine':'subtract','terms':[
        {'id':'bore','op':'add','shape':{'kind':'capsule','a':[0,0,-10],'b':[0,0,1010],'radius':min(12,sp*0.3)}}]}]}]}
n=eval(sys.argv[1]); seg=int(sys.argv[2])
print(rung('B1 bores=%d seg=%d'%(n[0]*n[1],seg),'workbench',spec(n,seg),'exact sphere r500cm minus %dx%d bores, segments=%d'%(n[0],n[1],seg)))
