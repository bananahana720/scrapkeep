import sys; sys.path.insert(0,'.')
from h import *
cfg={
 'default':({'feature':'river'},),
}
def w(name,ov,seed=1):
    print(rung(name,None,{'base':'terrain','seed':seed,'overrides':ov,'title':name},name,tool='compose_world'))
mode=sys.argv[1]
if mode=='a':
    w('B5a default river',{'world':{'features':[{'feature':'river'}]}})
    w('B5b default river +plants',{'world':{'features':[{'feature':'river'}]},'plants':True})
if mode=='b':
    w('B5c continent great river+coast+range',{'world':{'features':[{'feature':'river','size':'great'},{'feature':'coast','side':'S'},{'feature':'range'}]}})
    w('B5d continent +plants',{'world':{'features':[{'feature':'river','size':'great'},{'feature':'coast','side':'S'},{'feature':'range'}]},'plants':True})
if mode=='c':
    f8=[{'feature':'range','size':'cordillera','along':'NS'},{'feature':'river','size':'great'},{'feature':'lake','size':'great'},{'feature':'coast','side':'W'},{'feature':'plateau','size':'tableland'},{'feature':'volcano','size':'shield'},{'feature':'range'},{'feature':'plateau','size':'mesa'}]
    w('B5e max 8 features, continent-scale',{'world':{'features':f8,'climate':'tropical'}})
    w('B5f max 8 features +plants',{'world':{'features':f8,'climate':'tropical'},'plants':True})
if mode=='d':
    for span in (8000,50000):
        w('B5g painted from span=%d detail min0.5 relief 3'%span,{'span':span,'relief':3,'detail':{'min':0.5,'rock':8,'soil':2},'from':{'heartbeat':'rocky-irregular','splatch':'glacier-trio','landform':[{'op':'peaks','height':9,'center':[0,-12],'radius':20},{'op':'joints','rock':'granite','spacing':0.9},{'op':'talus'}],'erosion':True}})
