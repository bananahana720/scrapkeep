import sys; sys.path.insert(0,'.')
from h import *
def spec(c):
    return {'units':'cm','fields':[{'id':'ball','cells':c,'terms':[
      {'id':'s','op':'add','shape':{'kind':'sphere','center':[0,0,500],'radius':500}},
      {'op':'stroke','at':[300,0,700],'radius':150,'strength':1,'blend':60},
      {'op':'stroke','at':[-300,100,300],'radius':150,'strength':-1,'blend':60},
      {'op':'stroke','at':[0,-350,600],'radius':120,'strength':1,'blend':50},
      {'op':'displace','noise':{'amplitude':25,'scale':120,'octaves':3,'seed':3}}]}]}
for c in map(int,sys.argv[1:]):
    print(rung('B2 cells=%d'%c,'workbench',spec(c),'sampled sphere r500cm + 3 strokes + displace noise, cells=%d'%c))
