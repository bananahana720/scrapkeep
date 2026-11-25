import sys, numpy as np, soundfile as sf
y, sr = sf.read(sys.argv[1]); y = y.mean(axis=1) if y.ndim > 1 else y
n, hop = 2048, 256
frames = np.lib.stride_tricks.sliding_window_view(y, n)[::hop] * np.hanning(n)
mag = np.abs(np.fft.rfft(frames, axis=1))
env = np.maximum(np.diff(np.log1p(mag), axis=0), 0).sum(axis=1)
env -= env.mean()
t = np.arange(len(env)) * hop / sr
score = lambda b: abs((env * np.exp(2j * np.pi * t * b / 60)).sum()) / np.abs(env).sum()
for b in [float(x) for x in sys.argv[2:]]:
    print(f"{b:7.2f}  {score(b):.3f}")
grid = np.arange(140, 185, 0.05)
print(f"best {grid[np.argmax([score(b) for b in grid])]:.2f}")
