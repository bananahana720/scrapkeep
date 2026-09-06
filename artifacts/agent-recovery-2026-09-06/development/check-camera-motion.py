import hashlib
import http.server
import json
import sys
import threading
import time
from functools import partial
from pathlib import Path

root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root/'tools/agent-player'))
from combat import play
from desktop import Desktop
from evidence import Evidence, hashes
from flow import classify, choose_action
from policy import Policy, Intent
from run import QuietHandler

class CameraProbe(Policy):
    def aim(self, frame):
        self.motion = Intent(look=(300,0))
    def step(self, dt):
        self.elapsed += max(0,dt)
        return self.motion

output=root/'artifacts/local/agent-recovery-development/camera-calibration'
output.mkdir()
build=root/'artifacts/local/agent-recovery-development/relocation-live/build'
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(build)))
threading.Thread(target=server.serve_forever,daemon=True).start()
desktop=Desktop('playtest-camera-proof',Path.home()/'.local/share/codex-native-input/agent-desktop')
evidence=Evidence(output)
receipt={'method':'Native constant positive yaw, no keys or buttons; current ordinary game build; screenshot observation only','requested_velocity':[300,0],'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'build_hashes':hashes(build.rglob('*'),build),'game_unchanged':True}
try:
 receipt['desktop']=desktop.launch(f'http://127.0.0.1:{server.server_port}/orchard.html')
 for i in range(5):
  ui=desktop.observe();state=classify(ui);evidence.save_json(f'ui-{i}-{state}.json',ui)
  if state=='playing':break
  action=choose_action(ui,['ground-loop','echo'])
  if action:desktop.activate(ui,action)
  time.sleep(1.2)
 else:raise RuntimeError('Did not reach ordinary play')
 receipt['reason']=play(desktop,CameraProbe(),12,evidence)
 receipt['active_seconds']=12
finally:
 evidence.close()
 receipt['cleanup_errors']=desktop.close()
 server.shutdown();server.server_close()
 (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'reason':receipt.get('reason'),'cleanup_errors':receipt['cleanup_errors'],'output':str(output)}))
