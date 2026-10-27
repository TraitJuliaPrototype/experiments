# E-168: the session of the plan (writeup/plans/2026-10-27-ttfx-sciml-makie.md §2) in Python.
# Marks "T <step> <epoch s>"; digests, PNG sizes and versions after the last mark.
#     WL_ORDER=A|B MPLCONFIGDIR=out/mpl pyenv/bin/python workload.py <outdir>
import os, sys, time
def mark(step): print("T", step, repr(time.time()), flush=True)
mark("start")
ORDER = os.environ.get("WL_ORDER", "A")
import numpy as np
from scipy.integrate import solve_ivp
def load_plots():
    global plt, matplotlib
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
if ORDER == "A": load_plots()
mark("load")
out = sys.argv[1] if len(sys.argv) > 1 else "out"
RT, AT = 1e-6, 1e-8
def lorenz(t, u, s=10.0, r=28.0, b=8.0/3.0):
    return [s*(u[1]-u[0]), u[0]*(r-u[2])-u[1], u[0]*u[1]-b*u[2]]
def robertson(t, u):
    return [-0.04*u[0] + 1e4*u[1]*u[2], 0.04*u[0] - 1e4*u[1]*u[2] - 3e7*u[1]**2, 3e7*u[1]**2]
def vanderpol(t, u, mu=1000.0):
    return [u[1], mu*((1 - u[0]**2)*u[1]) - u[0]]
TL = np.linspace(0.0, 20.0, 2001); TR = np.logspace(-5, 5, 201); TV = np.linspace(0.0, 3000.0, 3001)
def solve_two():
    a = solve_ivp(lorenz, (0.0, 20.0), [1.0, 0.0, 0.0], method="RK45", t_eval=TL, rtol=RT, atol=AT)
    b = solve_ivp(robertson, (0.0, 1e5), [1.0, 0.0, 0.0], method="Radau", t_eval=TR, rtol=RT, atol=AT)
    return a, b
def plot_two(a, b, path):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 6))
    for k in range(3): ax1.plot(a.t, a.y[k])
    for k in range(3): ax2.plot(b.t, b.y[k] * (1e4 if k == 1 else 1.0))
    ax2.set_xscale("log")
    fig.savefig(path, dpi=100); plt.close(fig)
a, b = solve_two()
mark("solve1")
if ORDER == "B": load_plots()
plot_two(a, b, f"{out}/py-1.png")
mark("plot1")
c = solve_ivp(vanderpol, (0.0, 3000.0), [2.0, 0.0], method="Radau", t_eval=TV, rtol=RT, atol=AT)
fig, ax = plt.subplots(figsize=(8, 4)); ax.plot(c.t, c.y[0]); fig.savefig(f"{out}/py-2.png", dpi=100); plt.close(fig)
mark("model2")
a2, b2 = solve_two(); plot_two(a2, b2, f"{out}/py-3.png")
mark("again")
def digest(name, t, y, ts):
    i = [int(np.argmin(abs(t - x))) for x in ts]
    print("D", name, " ".join(f"{y[k][j]:.6g}" for j in i for k in range(len(y))), flush=True)
digest("lorenz", a.t, a.y, [1.0, 2.0]); digest("robertson", b.t, b.y, [1.0, 1e3, 1e5]); digest("vanderpol", c.t, c.y, [1000.0, 3000.0])
import struct, scipy
for f in sorted(n for n in os.listdir(out) if n.startswith("py-") and n.endswith(".png")):
    d = open(os.path.join(out, f), "rb").read(); w, h = struct.unpack(">II", d[16:24])
    print("P", f, f"{w}x{h}", os.path.getsize(os.path.join(out, f)), "bytes")
print("V python", sys.version.split()[0], "numpy", np.__version__, "scipy", scipy.__version__, "matplotlib", matplotlib.__version__, "order", ORDER)
