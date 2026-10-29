# E-228 (W-70): the plotting part of E-168's session in Python (matplotlib), with the same solutions (data/, read with
# numpy, not timed as plotting): marks "T <step> <epoch s>" as E-168's.
#     MPLCONFIGDIR=experiments/ttfx/out/mpl experiments/ttfx/pyenv/bin/python experiments/x3/session5.py <out dir>
import os, sys, time
def mark(step): print("T", step, repr(time.time()), flush=True)
mark("start")
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
mark("load")
out = sys.argv[1]
def read(f):
    n, m = np.fromfile(f, dtype=np.int64, count=2)
    t = np.fromfile(f, dtype=np.float64, count=n)
    u = np.fromfile(f, dtype=np.float64, count=n * m).reshape(n, m)
    return t, u.T
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "solutions.bin"), "rb") as f:
    a, b, c = read(f), read(f), read(f)
mark("data")
def plot_two(a, b, path):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 6))
    for k in range(3): ax1.plot(a[0], a[1][k])
    for k in range(3): ax2.plot(b[0], b[1][k] * (1e4 if k == 1 else 1.0))
    ax2.set_xscale("log")
    fig.savefig(path, dpi=100); plt.close(fig)
plot_two(a, b, f"{out}/py-1.png")
mark("plot1")
fig, ax = plt.subplots(figsize=(8, 4)); ax.plot(c[0], c[1][0]); fig.savefig(f"{out}/py-2.png", dpi=100); plt.close(fig)
mark("plot2")
plot_two(a, b, f"{out}/py-3.png")
mark("again")
