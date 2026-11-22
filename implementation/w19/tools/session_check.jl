# W-19: a patch that changes only method bodies of base/*.jl, evaluated in a session of vanilla v1.13.2:
#   julia --startup-file=no tools/session_check.jl <defs.jl> <test name>...
# <defs.jl> is defs_of_patch.py's output (the changed definitions as in the patch's branch); each is
# evaluated into Base, then each test file of Julia's suite (test/<name>.jl) is included in a module of its own.
using Test
defs = read(ARGS[1], String)
n = 0
for ex in Meta.parseall(defs).args
    ex isa LineNumberNode && continue
    Core.eval(Base, ex); global n += 1
end
println("evaluated $n definitions of $(basename(ARGS[1])) into Base")
testdir = joinpath(Sys.BINDIR, Base.DATAROOTDIR, "julia", "test")
cd(testdir)
for t in ARGS[2:end]
    m = Module(Symbol("Test_", replace(t, "/" => "_")))
    Core.eval(m, :(using Test, Random))
    Core.eval(m, :(include(p) = Base.include($m, p)))
    t0 = time()
    ts = @testset "$t" begin
        Base.include(m, joinpath(testdir, t * ".jl"))
    end
    println("test $t: done in $(round(time() - t0; digits = 1)) s")
end
