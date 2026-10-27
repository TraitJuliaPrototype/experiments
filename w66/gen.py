# E-193: the toy packages. Each case: a trait package P<i> whose facts code depends on something that changes between
# two sessions while P<i>'s own source and version stay the same. Variants a and b of a changed dependency share
# its name, UUID and version and differ in source.
import os, uuid
def U(n): return str(uuid.uuid5(uuid.NAMESPACE_DNS, 'w66.' + n))
TW = '7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14'
def pkg(dirname, name, deps, src, ext=None, weak=None):
    d = f'pkgs/{dirname}'; os.makedirs(d + '/src', exist_ok=True)
    with open(d + '/Project.toml', 'w') as f:
        f.write(f'name = "{name}"\nuuid = "{U(name)}"\nversion = "0.1.0"\n\n[deps]\n')
        for k in deps: f.write(f'{k} = "{TW if k == "TraitWorld" else U(k)}"\n')
        if weak:
            f.write('\n[weakdeps]\n')
            for k in weak: f.write(f'{k} = "{U(k)}"\n')
            f.write('\n[extensions]\n')
            for e, trig in ext.items(): f.write(f'{e} = "{trig}"\n')
    open(f'{d}/src/{name}.jl', 'w').write(src)
    return d
def ext(dirname, extname, src):
    os.makedirs(f'pkgs/{dirname}/ext', exist_ok=True)
    open(f'pkgs/{dirname}/ext/{extname}.jl', 'w').write(src)
def trait(name, deps, body):
    return pkg(name, name, ['TraitWorld'] + deps, f'''module {name}
using TraitWorld
{''.join(f"import {d}" + chr(10) for d in deps)}@trait_module module Impl
using TraitWorld
{''.join(f"import {d}" + chr(10) for d in deps)}{body}
end
go() = Impl.go()
end
''')
# case 1: a dependency's macro changes its expansion
for v, val in (('a', 1), ('b', 2)):
    pkg(f'M1{v}', 'M1', [], f'module M1\nmacro val() return {val} end\nend\n')
trait('P1', ['M1'], 'go() = M1.@val() + 0')
# case 2: a dependency's struct gains a field; the trait code reads its size
pkg('L2a', 'L2', [], 'module L2\nstruct S; a::Int; end\nend\n')
pkg('L2b', 'L2', [], 'module L2\nstruct S; z::Int; a::Int; end\nS(a::Int) = S(0, a)\nend\n')
trait('P2', ['L2'], 'go() = sizeof(L2.S)')
# case 3: a supertype's owner adds a method for its abstract type
pkg('A3a', 'A3', [], 'module A3\nabstract type AbsT end\nf3(x) = 1\nend\n')
pkg('A3b', 'A3', [], 'module A3\nabstract type AbsT end\nf3(x) = 1\nf3(x::AbsT) = 2\nend\n')
pkg('B3', 'B3', ['A3'], 'module B3\nimport A3\nstruct C <: A3.AbsT end\nend\n')
trait('P3', ['A3', 'B3'], 'go() = A3.f3(B3.C())')
# case 4: a callee two levels down changes (the middle callee not inlined)
for v, val in (('a', 1), ('b', 2)):
    pkg(f'R4{v}', 'R4', [], f'module R4\nk() = {val}\nend\n')
pkg('Q4', 'Q4', ['R4'], 'module Q4\nimport R4\n@noinline h() = R4.k() + 0\nend\n')
trait('P4', ['Q4'], 'go() = Q4.h()')
# case 5: the parent's extension, activated by an unrelated package
pkg('X5', 'X5', [], 'module X5\nstruct T5 end\ng5(x) = 1\nend\n', ext={'X5Ext': 'Y5'}, weak=['Y5'])
ext('X5', 'X5Ext', 'module X5Ext\nimport X5, Y5\nX5.g5(x::X5.T5) = 2\nend\n')
pkg('Y5', 'Y5', [], 'module Y5\nend\n')
trait('P5', ['X5'], 'go() = X5.g5(X5.T5())')
# case 6: SparseArrays loaded in the second session only
trait('P6', [], 'go() = vcat(1, [2, 3])')
print('ok')
