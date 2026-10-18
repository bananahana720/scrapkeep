import sys, re, collections
path = sys.argv[1]; last = int(sys.argv[2]) if len(sys.argv) > 2 else 600
tok = re.compile(r'&"([^"]*)"|"([^"]*)"|(-?[0-9.e+-]+)')
sigs = {}; frames = []
for line in open(path):
    if line.startswith('["servers:function_signature"'):
        m = re.search(r'&"([^"]*)", (\d+)\]', line); sigs[int(m.group(2))] = m.group(1)
    elif line.startswith('["servers:profile_frame"'):
        frames.append(line)
frames = frames[-last-5:-5]
selfs = collections.Counter(); tots = collections.Counter(); calls = collections.Counter()
hdr = collections.Counter()
for line in frames:
    body = line[line.index('[', 2) + 1:]
    t = []
    for m in tok.finditer(body):
        t.append(m.group(1) if m.group(1) is not None else (m.group(2) if m.group(2) is not None else float(m.group(3))))
    # header: frame, frame_time, process_time, physics_time, physics_frame_time, script_time
    hdr['frame'] += t[1]; hdr['proc'] += t[2]; hdr['phys'] += t[3]; hdr['script'] += t[5]
    i = 6; nserv = int(t[i]); i += 1
    for _ in range(nserv):
        i += 1; n = int(t[i]); i += 1 + n  # name, count, then n/2 pairs? n counts items
    nf = int(t[i]); i += 1
    while i + 5 <= len(t):
        sid, c, st, tt, _int = t[i:i+5]; i += 5
        selfs[int(sid)] += st; tots[int(sid)] += tt; calls[int(sid)] += c
n = len(frames)
print(f"frames={n} mean frame={hdr['frame']/n*1000:.2f} proc={hdr['proc']/n*1000:.2f} phys={hdr['phys']/n*1000:.2f} script={hdr['script']/n*1000:.2f} ms")
print("--- top self (ms/frame, calls/frame)")
for sid, v in selfs.most_common(int(sys.argv[3]) if len(sys.argv) > 3 else 45):
    print(f"{v/n*1000:7.3f}  tot {tots[sid]/n*1000:7.3f}  calls {calls[sid]/n:7.1f}  {sigs.get(sid, sid)}")
print("--- by file (self ms/frame)")
byf = collections.Counter()
for sid, v in selfs.items():
    byf[sigs.get(sid, str(sid)).split('::')[0]] += v
for f, v in byf.most_common(30):
    print(f"{v/n*1000:7.3f}  {f}")
