"""Bounded real-launcher cancellation probe; only its own child workspace is stopped."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time

root = Path('/home/andrew/Projects/test-game-2')
output = root/'artifacts/local/agent-recovery-development/final-interruption'
state = Path.home()/'.local/state/codex-native-input/agent-desktop/workspaces/playtest-recovery-interrupt/session.json'
log_path = root/'artifacts/local/agent-recovery-development/final-interruption.log'
with log_path.open('w') as log:
    process = subprocess.Popen(['node', 'scripts/agent-playtest.mjs', '--workspace', 'playtest-recovery-interrupt',
        '--smoke-seconds', '40', '--max-seconds', '90', '--output', str(output)],
        cwd=root, stdout=log, stderr=log, start_new_session=True)
    try:
        deadline = time.monotonic() + 70
        while not (output/'trial-001/frame-00005.jpg').exists():
            if process.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError('Player did not reach captured native gameplay before interruption')
            time.sleep(.1)
        manifest = json.loads(state.read_text())
        started = time.monotonic()
        os.killpg(process.pid, signal.SIGINT)
        process.wait(timeout=20)
        result = json.loads((output/'report.json').read_text())
        receipt = {'signal': 'SIGINT to launcher process group', 'gameplay_frame_received': True,
            'completion_seconds': time.monotonic()-started, 'exit_code': process.returncode,
            'outcome': result['trials'][0]['outcome'], 'cleanup_errors': result['cleanup_errors'],
            'session_removed': not state.exists(), 'owned_processes': []}
        for kind in ('browser', 'compositor'):
            identity = manifest[kind]
            stat = Path(f'/proc/{identity["pid"]}/stat')
            live = False
            if stat.exists():
                contents = stat.read_text(); tail = contents[contents.rfind(')')+2:].split()
                live = tail[0] != 'Z' and tail[19] == str(identity['start_ticks'])
            receipt['owned_processes'].append({'kind':kind, 'same_process_still_live':live})
        receipt['passed'] = (receipt['outcome']=='interrupted' and not receipt['cleanup_errors']
            and receipt['session_removed'] and all(not p['same_process_still_live'] for p in receipt['owned_processes']))
        (output/'interruption-check.json').write_text(json.dumps(receipt,indent=2))
        print(json.dumps(receipt),flush=True)
        assert receipt['passed']
    finally:
        if process.poll() is None:
            os.killpg(process.pid,signal.SIGTERM)
            process.wait(timeout=25)
