# W-19, fourth part: why `test/precompile.jl`'s branch for an instance's internal callers (its line 977,
# `(be.def::Method).def`) runs on `w19-g-facts` and not on v1.13.2. The test's packages Root, RootA, RootB,
# written to a fresh directory; after the loads, the `Int16` instance of `Root.f`: its backedges, and the
# CodeInstance flags of `Root.g1` (G2 0x10, facts 0x20) and of `f(::Int16)`. A variant `BARRIER=1` puts a
# call at an abstract signature into `f` (`Base.inferencebarrier`), so that no code of `g1` is deep G2.
#     julia --startup-file=no h-precompile-root.jl        (a fresh depot is made in a temporary directory)
barrier = get(ENV, "BARRIER", "0") == "1"
dir = mktempdir(); depot = mktempdir()
pushfirst!(DEPOT_PATH, depot); pushfirst!(LOAD_PATH, dir)
R = :Root_h19; A = :RootA_h19; B = :RootB_h19
body = barrier ? "x += oftype(x, Base.inferencebarrier(1))::typeof(x)" : "x += oftype(x, 1)"
write(joinpath(dir, "$R.jl"), """
module $R
function f(x)
    while x < 10
        $body
    end
    return x
end
g1() = f(Int16(9))
g2() = f(Int16(9))
end
""")
for (M, g) in ((A, :g1), (B, :g2))
    write(joinpath(dir, "$M.jl"), """
    module $M
    using $R
    f$M() = $R.f(Int8(4))
    f$M()
    $R.$g()
    end
    """)
end
Base.compilecache(Base.PkgId(string(A))); Base.compilecache(Base.PkgId(string(B)))
@eval using $A, $B
invokelatest() do
    M = getfield(getfield(Main, A), R)
    m = which(M.f, (Any,))
    flags(f, T) = (mi = Base.method_instance(f, T); isdefined(mi, :cache) ? string(mi.cache.flags, base = 16) : "none")
    println("build ", Base.GIT_VERSION_INFO.commit_short, " barrier=", barrier)
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        T = mi.specTypes.parameters[2]
        nb = isdefined(mi, :backedges) ? length(mi.backedges) : 0
        kinds = isdefined(mi, :backedges) ? unique(map(be -> typeof(be isa Core.CodeInstance ? be.def : be), mi.backedges)) : []
        println("  f(::", T, "): backedges ", nb, " ", kinds)
    end
    # the code of g1 as loaded (before any call in this session)
    mi = Base.method_instance(M.g1, ())
    println("  g1's MethodInstance has code: ", isdefined(mi, :cache), "  flags ", flags(M.g1, ()))
end
