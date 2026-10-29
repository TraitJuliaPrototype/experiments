#!/usr/bin/env python3
"""U6 (E-252): generate the scratch packages of each arrangement under arr/<R>/.

Model. `Xs` owns the set's registry `ismember(x) = false`; `Fo` owns `f`, with the bounded method's
body `f(x) = Xs.ismember(x) ? :won : :fallback` (f's owner depends on Xs, as in exploration §11.1);
`Sp` owns the type `Ty`. A membership `Ty ∈ X` is the plain method `Xs.ismember(::Sp.Ty) = true`;
the arrangement decides where it lives (a package or an extension). Today's Julia has no late
subtyping, so a plain method stands in for the membership: what is measured is *when* it becomes
visible relative to the compile of the probing code. R9 models the excluded combination instead:
the set is `Xs.Members = Union{Sp.Ty}` (members by the set's owner) and the bounded method
`Fo.f(::Xs.Members)` lives in Fo's extension triggered by Xs.

Every probing module records at the time its body runs (in precompilation: in the child process
that writes its image):
  SEEN        what `g() = Fo.f(<a Ty>)` returned then (`:won` iff the membership was visible)
  AT_COMPILE  which of the arrangement's modules were loaded then (Base.loaded_modules_order)
  GENERATING  whether that was while writing an image
"""
import json, os, sys, uuid

NS = uuid.UUID("5d1c2b0e-52a0-4c8e-9f6b-0e0c0f0e0252")
HERE = os.path.dirname(os.path.abspath(__file__))

def U(r, name):
    return str(uuid.uuid5(NS, f"{r}/{name}"))

def probe(call, ours, imports=""):
    names = ", ".join(f'"{n}"' for n in sorted(ours))
    return f"""{imports}
# --- probe (U6) ---
g() = {call}
const SEEN = g()
const AT_COMPILE = filter(in(Set([{names}])), [String(nameof(m)) for m in Base.loaded_modules_order])
const GENERATING = ccall(:jl_generating_output, Cint, ()) == 1
"""

XS = "ismember(x) = false\n"
FO = "import Xs\nf(x) = Xs.ismember(x) ? :won : :fallback\n"
SP = "struct Ty end\n"
MEM = "import Xs, Sp\nXs.ismember(::Sp.Ty) = true\n"

def pkg(deps=(), weak=(), exts=None, src="", extsrc=None):
    return dict(deps=list(deps), weak=list(weak), exts=exts or {}, src=src, extsrc=extsrc or {})

def arrangements():
    A = {}
    # R1: membership by the set's owner, in Xs's extension triggered by S's package; P names Fo and Sp.
    A["R1"] = dict(
        doc="membership by X's owner in ext XsSpExt (parent Xs, trigger Sp); P deps Fo, Sp (Xs via Fo)",
        pkgs=dict(
            Xs=pkg(weak=["Sp"], exts={"XsSpExt": ["Sp"]}, src=XS, extsrc={"XsSpExt": MEM}),
            Fo=pkg(deps=["Xs"], src=FO), Sp=pkg(src=SP),
            P=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["P"], probes={"P": "P"}, ext="XsSpExt")
    # R2: membership by the member's owner, in Sp's extension triggered by Xs.
    A["R2"] = dict(
        doc="membership by S's owner in ext SpXsExt (parent Sp, trigger Xs); P deps Fo, Sp",
        pkgs=dict(
            Xs=pkg(src=XS), Fo=pkg(deps=["Xs"], src=FO),
            Sp=pkg(weak=["Xs"], exts={"SpXsExt": ["Xs"]}, src=SP, extsrc={"SpXsExt": MEM}),
            P=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["P"], probes={"P": "P"}, ext="SpXsExt")
    # R3: an extension with two triggers (parent Sp, triggers Xs and Fo).
    A["R3"] = dict(
        doc="membership in ext SpXsFoExt (parent Sp, triggers Xs and Fo); P deps Fo, Sp",
        pkgs=dict(
            Xs=pkg(src=XS), Fo=pkg(deps=["Xs"], src=FO),
            Sp=pkg(weak=["Xs", "Fo"], exts={"SpXsFoExt": ["Xs", "Fo"]}, src=SP, extsrc={"SpXsFoExt": MEM}),
            P=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["P"], probes={"P": "P"}, ext="SpXsFoExt")
    # R4: P depends on the trigger Sp only indirectly (through Q), and on Fo.
    A["R4"] = dict(
        doc="as R1, but P deps Fo and Q; Q deps Sp (P reaches Sp's type only through Q)",
        pkgs=dict(
            Xs=pkg(weak=["Sp"], exts={"XsSpExt": ["Sp"]}, src=XS, extsrc={"XsSpExt": MEM}),
            Fo=pkg(deps=["Xs"], src=FO), Sp=pkg(src=SP),
            Q=pkg(deps=["Sp"], src="import Sp\nmake() = Sp.Ty()\n"),
            P=pkg(deps=["Fo", "Q"], src="import Fo, Q\n" + "@@probe:Fo.f(Q.make())")),
        top=["P"], probes={"P": "P"}, ext="XsSpExt")
    # R5: a third package's precompilation: Z depends on P only and compiles its own call at Ty.
    A["R5"] = dict(
        doc="as R4; Z deps P only, Z's workload compiles Fo.f at Ty through P",
        pkgs=dict(
            Xs=pkg(weak=["Sp"], exts={"XsSpExt": ["Sp"]}, src=XS, extsrc={"XsSpExt": MEM}),
            Fo=pkg(deps=["Xs"], src=FO), Sp=pkg(src=SP),
            Q=pkg(deps=["Sp"], src="import Sp\nmake() = Sp.Ty()\n"),
            P=pkg(deps=["Fo", "Q"], src="import Fo, Q\nh(x) = Fo.f(x)\nmk() = Q.make()\n"),
            Z=pkg(deps=["P"], src="import P\n" + "@@probe:P.h(P.mk())")),
        top=["Z"], probes={"Z": "Z"}, ext="XsSpExt")
    # R6: the member's own package is the probing code; the membership is in Xs's extension triggered by it.
    A["R6"] = dict(
        doc="self-trigger: P = Sp (deps Fo); membership by X's owner in ext XsSpExt (parent Xs, trigger Sp)",
        pkgs=dict(
            Xs=pkg(weak=["Sp"], exts={"XsSpExt": ["Sp"]}, src=XS, extsrc={"XsSpExt": MEM}),
            Fo=pkg(deps=["Xs"], src=FO),
            Sp=pkg(deps=["Fo"], src="import Fo\n" + SP + "@@probe:Fo.f(Ty())")),
        top=["Sp"], probes={"Sp": "Sp"}, ext="XsSpExt")
    # R7: the member's own package, its own extension (trigger Xs, which is in Sp's tree through Fo).
    A["R7"] = dict(
        doc="self-parent: P = Sp (deps Fo; Fo deps Xs); membership by S's owner in its own ext SpXsExt (trigger Xs)",
        pkgs=dict(
            Xs=pkg(src=XS), Fo=pkg(deps=["Xs"], src=FO),
            Sp=pkg(deps=["Fo"], weak=["Xs"], exts={"SpXsExt": ["Xs"]}, src="import Fo\n" + SP + "@@probe:Fo.f(Ty())",
                   extsrc={"SpXsExt": MEM})),
        top=["Sp"], probes={"Sp": "Sp"}, ext="SpXsExt")
    # R8: the probing code is an extension (Fo's, triggered by Sp); the membership is Sp's extension triggered by Xs.
    A["R8"] = dict(
        doc="P = extension FoSpExt (parent Fo, trigger Sp; Xs in its tree via Fo); membership by S's owner in ext SpXsExt (parent Sp, trigger Xs); top Pt deps Fo, Sp",
        pkgs=dict(
            Xs=pkg(src=XS),
            Fo=pkg(deps=["Xs"], weak=["Sp"], exts={"FoSpExt": ["Sp"]}, src=FO,
                   extsrc={"FoSpExt": "@@probe:Fo.f(Sp.Ty())|import Fo, Sp"}),
            Sp=pkg(weak=["Xs"], exts={"SpXsExt": ["Xs"]}, src=SP, extsrc={"SpXsExt": MEM}),
            Pt=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["Pt"], probes={"FoSpExt": "ext:Fo:FoSpExt", "Pt": "Pt"}, ext="SpXsExt")
    # R8b: as R8, but FoSpExt lists Xs (a regular dep of Fo) among its triggers too: its trigger set
    # {Fo, Sp, Xs} is then a strict superset of SpXsExt's {Sp, Xs}.
    A["R8b"] = dict(
        doc="as R8, but FoSpExt is triggered by Sp and Xs (Xs a regular dep of Fo)",
        pkgs=dict(
            Xs=pkg(src=XS),
            Fo=pkg(deps=["Xs"], weak=["Sp"], exts={"FoSpExt": ["Sp", "Xs"]}, src=FO,
                   extsrc={"FoSpExt": "@@probe:Fo.f(Sp.Ty())|import Fo, Sp"}),
            Sp=pkg(weak=["Xs"], exts={"SpXsExt": ["Xs"]}, src=SP, extsrc={"SpXsExt": MEM}),
            Pt=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["Pt"], probes={"FoSpExt": "ext:Fo:FoSpExt", "Pt": "Pt"}, ext="SpXsExt")
    # R9: the excluded combination (control for the "only if" direction): members by the set's owner,
    # the bounded method in f's owner's extension triggered by Xs; P does not depend on Xs.
    XS9 = "import Sp\nconst Members = Union{Sp.Ty}\n"
    FO9 = "f(x) = :fallback\n"
    A["R9"] = dict(
        doc="excluded combination: Xs.Members = Union{Sp.Ty} (members by X's owner); Fo.f(::Xs.Members) in ext FoXsExt (parent Fo, trigger Xs); P deps Fo, Sp only",
        pkgs=dict(
            Sp=pkg(src=SP), Xs=pkg(deps=["Sp"], src=XS9),
            Fo=pkg(weak=["Xs"], exts={"FoXsExt": ["Xs"]}, src=FO9,
                   extsrc={"FoXsExt": "import Fo, Xs\nFo.f(::Xs.Members) = :won\n"}),
            P=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["P", "Xs"], probes={"P": "P"}, ext="FoXsExt")
    # R9b: the same, but P depends on Xs too.
    A["R9b"] = dict(
        doc="as R9, but P deps Fo, Sp and Xs",
        pkgs=dict(
            Sp=pkg(src=SP), Xs=pkg(deps=["Sp"], src=XS9),
            Fo=pkg(weak=["Xs"], exts={"FoXsExt": ["Xs"]}, src=FO9,
                   extsrc={"FoXsExt": "import Fo, Xs\nFo.f(::Xs.Members) = :won\n"}),
            P=pkg(deps=["Fo", "Sp", "Xs"], src="import Fo, Sp, Xs\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["P"], probes={"P": "P"}, ext="FoXsExt")
    # R10: a trigger that is a regular dependency of the parent (deps, not weakdeps).
    A["R10"] = dict(
        doc="as R2, but Xs is a regular dep of Sp (trigger in [deps], not [weakdeps]); P deps Fo, Sp",
        pkgs=dict(
            Xs=pkg(src=XS), Fo=pkg(deps=["Xs"], src=FO),
            Sp=pkg(deps=["Xs"], exts={"SpXsExt": ["Xs"]}, src=SP, extsrc={"SpXsExt": MEM}),
            P=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["P"], probes={"P": "P"}, ext="SpXsExt")
    # R12: R1 without the extension at first (added later by the driver: ext12.sh).
    A["R12"] = dict(
        doc="as R1, but XsSpExt is added to Xs (Project.toml, ext file, resolve) after P's image was written",
        pkgs=dict(
            Xs=pkg(src=XS), Fo=pkg(deps=["Xs"], src=FO), Sp=pkg(src=SP),
            P=pkg(deps=["Fo", "Sp"], src="import Fo, Sp\n" + "@@probe:Fo.f(Sp.Ty())")),
        top=["P"], probes={"P": "P"}, ext="XsSpExt")
    return A

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as io:
        io.write(text)

def expand(code, ours):
    if "@@probe:" not in code:
        return code
    head, rest = code.split("@@probe:", 1)
    if "|" in rest:
        call, imports = rest.split("|", 1)
    else:
        call, imports = rest, ""
    return head + probe(call.strip(), ours, imports)

def gen(r, a):
    root = os.path.join(HERE, "arr", r)
    names = list(a["pkgs"])
    ours = set(names) | {e for p in a["pkgs"].values() for e in p["exts"]} | {a["ext"]}
    for name, p in a["pkgs"].items():
        d = os.path.join(root, "pkgs", name)
        toml = [f'name = "{name}"', f'uuid = "{U(r, name)}"', 'version = "0.1.0"', ""]
        if p["deps"]:
            toml += ["[deps]"] + [f'{x} = "{U(r, x)}"' for x in p["deps"]] + [""]
        if p["weak"]:
            toml += ["[weakdeps]"] + [f'{x} = "{U(r, x)}"' for x in p["weak"]] + [""]
        if p["exts"]:
            toml += ["[extensions]"] + [f'{e} = {json.dumps(t)}' for e, t in p["exts"].items()] + [""]
        write(os.path.join(d, "Project.toml"), "\n".join(toml))
        write(os.path.join(d, "src", name + ".jl"), f"module {name}\n{expand(p['src'], ours)}\nend\n")
        for e, code in p["extsrc"].items():
            write(os.path.join(d, "ext", e + ".jl"), f"module {e}\n{expand(code, ours)}\nend\n")
    q = json.dumps  # a JSON string is a TOML basic string here (ASCII, no control characters)
    meta = [f"doc = {q(a['doc'])}", f"ext = {q(a['ext'])}",
            "pkgs = [" + ", ".join(q(n) for n in names) + "]",
            "top = [" + ", ".join(q(n) for n in a["top"]) + "]",
            "exts = [" + ", ".join(q(e) for e in sorted(ours - set(names))) + "]", "[probes]"] + \
           [f"{k} = {q(v)}" for k, v in a["probes"].items()]
    write(os.path.join(root, "meta.toml"), "\n".join(meta) + "\n")

if __name__ == "__main__":
    A = arrangements()
    for r in (sys.argv[1:] or A):
        gen(r, A[r])
        print("generated", r)
