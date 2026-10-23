import sys,json,shutil,os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from h import call
ref,dst=sys.argv[1],sys.argv[2]
os.makedirs(dst,exist_ok=True)
e,dt,to=call('export_model',{'ref':ref,'format':'glb','lit':len(sys.argv)>3})
print(json.dumps({k:e.get(k) for k in ('ok','triangles','bytes','path','file','files','error','raw')})[:900],'%.1fs'%dt)
src=os.path.expanduser('~/.mojulo/data/outcomes/%s/model.glb'%ref)
if os.path.exists(src): shutil.copy(src,os.path.join(dst,'model.glb')); print('copied',os.path.getsize(src))
