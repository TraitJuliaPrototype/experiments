# The set-folds report's image mode (W-171, E-543): does compiled code that lives in a package image, or that a
# package image's memberships change, keep an answer about a set outside the worlds where it holds? The same
# questions as `set_folds.jl`, asked of copies compiled in a session or in a package's image, before and after a
# change, against the runtime's own answer asked afresh by `ccall` in each world.
#
#     julia --project=experiments/implementation experiments/implementation/audit/set_folds_images.jl [--keep]
#
# Directions (each a child process on a fresh depot; the packages are written to a temporary directory):
#   loaded_after    the functions compiled in the session (`PkgF1`), then a precompiled package's memberships loaded
#                   (`PkgM1`)
#   image_code      the functions compiled in a package's image (`PkgF2`'s workload), the memberships declared in the
#                   session
#   image_positive  a package that declares the memberships and compiles the functions in its image (`PkgFM`), the
#                   memberships taken back in the session
#   refused         an image's membership refused at activation (a second instance of a set), with code in that
#                   image that folded it (`PkgR` after `PkgM3`)
# It asserts nothing; the last line is the tally. See README.md, "The set-folds report".

const KEEP = "--keep" in ARGS

# the shapes (a subset of set_folds.jl's that a package can hold), as (name, defs, member, set, A, B, val, setup)
const SHAPES = [
    ("type", "struct S end", "S", "X", "S", "X", "S()", ""),
    ("tuple", "struct S end", "S", "X", "Tuple{S}", "Tuple{X}", "(S(),)", ""),
    ("union", "struct S end", "S", "X", "S", "Union{X, Int}", "S()", ""),
    ("upper_bound", "struct S end", "S", "X", "Ph{S}", "Ph{<:X}", "Ph{S}()", ""),
    ("lower_bound", "struct S end", "S", "X", "Ph{X}", "Ph{T} where T>:S", "Ph{X}()", ""),
    ("type_type", "struct S end", "S", "X", "Type{S}", "Type{<:X}", "S", ""),
    ("type_value", "struct S end", "Type{S}", "X", "Type{S}", "X", "S", ""),
    ("vararg", "struct S end", "S", "X", "Tuple{Int, S, S}", "Tuple{Int, Vararg{X}}", "(1, S(), S())", ""),
    ("family", "struct F{T} end", "F{T} where T", "X", "F{Int}", "X", "F{Int}()", ""),
    ("super_param", "struct S end\nabstract type AP{T} end\nstruct P2{T} <: AP{T} end", "S", "X", "P2{S}", "AP{<:X}", "P2{S}()", ""),
    ("input", "@trait X2{I}\nccall(:jl_set_input_params, Cvoid, (Any, UInt8), X2, 0x01)\nstruct S end", "S", "X2{Int}", "S", "X2{Int}", "S()", ""),
    ("abstract_member", "abstract type AM end\nstruct SA <: AM end", "AM", "X", "AM", "X", "SA()", ""),
    ("set_member", "@trait Y0\nstruct S0 end", "Y0", "X", "Y0", "X", "S0()", "Traits.declare_membership(S0, Y0, @__MODULE__)"),
]
const NOARG_Q = [:sub, :int, :eq, :hasm]
const VAL_Q = [:isa, :tassert, :new, :disp, :app]
qbody(q) = q === :sub ? "A <: B" : q === :int ? "typeintersect(A, B) === Union{}" : q === :eq ? "A == B" :
           q === :hasm ? "hasmethod(h, Tuple{A})" : q === :isa ? "x isa B" : q === :tassert ? "(x::B; true)" :
           q === :new ? "(@newHB(x); true)" : q === :disp ? "g(x)" : q === :app ? "applicable(h, x)" : error(q)
fbody(q) = q === :sub ? "ccall(:jl_subtype, Cint, (Any, Any), A, B) != 0" :
           q === :int ? "ccall(:jl_type_intersection, Any, (Any, Any), A, B) === Union{}" :
           q === :eq ? "ccall(:jl_types_equal, Cint, (Any, Any), A, B) != 0" :
           q === :hasm ? "SF_hasmethod(h, A)" :
           q === :isa ? "ccall(:jl_isa, Cint, (Any, Any), x, B) != 0" :
           q === :tassert ? "ccall(:jl_isa, Cint, (Any, Any), x, B) != 0 ? true : :TypeError" :
           q === :new ? "(ccall(:jl_new_structv, Any, (Any, Ptr{Any}, UInt32), HB, Any[x], 1); true)" :
           q === :disp ? "SF_dispatch(g, x)" : q === :app ? "SF_dispatch(h, x) !== :nomethod" : error(q)

const REF_SRC = raw"""
SF_methods(f) = (ms = Base._methods_by_ftype(Tuple{typeof(f), Vararg{Any}}, -1, Base.tls_world_age());
                 ms === nothing ? Method[] : Method[m.method for m in ms])
function SF_select(f, tt)
    sig = Tuple{typeof(f), tt.parameters...}
    app = [m for m in SF_methods(f) if ccall(:jl_subtype, Cint, (Any, Any), sig, m.sig) != 0]
    isempty(app) && return nothing
    best = [m for m in app if all(o -> o === m || Base.morespecific(m.sig, o.sig), app)]
    return length(best) == 1 ? best[1] : :ambiguous
end
SF_dispatch(f, x) = (m = SF_select(f, Tuple{Core.Typeof(x)}); m isa Method ? Core.invoke(f, Base.tuple_type_tail(m.sig), x) :
                     m === nothing ? :nomethod : m)
SF_hasmethod(f, A) = SF_select(f, Tuple{A}) isa Method
"""

# one case's module: the definitions, the pair (MEMBER, SET), two copies of each question, the fresh answers
function case_module(i, sh; workload = false, declare = false)
    name, defs, member, set, A, B, val, setup = sh
    io = IOBuffer()
    println(io, "module C$i\nusing Traits\nimport ..SF_dispatch, ..SF_hasmethod\n@trait X\nstruct Ph{T} end\n", defs)
    println(io, "const A = $A\nconst B = $B\nconst MEMBER = $member\nconst SET = $set\nval() = $val")
    println(io, "g(::Any) = :Any\ng(::B) = :B\nh(::B) = :hB\nfunction g end\nfunction h end")
    println(io, "struct HB; v::B; end\nmacro newHB(x) esc(Expr(:new, :HB, x)) end")
    isempty(setup) || println(io, setup)
    for k in 0:1, q in vcat(NOARG_Q, VAL_Q)
        a = q in NOARG_Q ? "" : "x"
        println(io, "q_$(q)_$(k)($a) = ", qbody(q))
    end
    for q in vcat(NOARG_Q, VAL_Q)
        println(io, "f_$(q)($(q in NOARG_Q ? "" : "x")) = ", fbody(q))
    end
    declare && println(io, "Traits.declare_membership(MEMBER, SET, @__MODULE__)")
    if workload
        println(io, "let x = val()")
        for q in vcat(NOARG_Q, VAL_Q)
            println(io, "    try; q_$(q)_0($(q in NOARG_Q ? "" : "x")); catch; end")
        end
        println(io, "end")
    end
    println(io, "end")
    return String(take!(io))
end

function write_pkg(dir, name, body)
    mkpath(joinpath(dir, name, "src"))
    write(joinpath(dir, name, "src", "$name.jl"), body)
end
function funcs_pkg(name; workload = false, declare = false)
    io = IOBuffer()
    println(io, "module $name\nusing Traits\n", REF_SRC)
    for (i, sh) in enumerate(SHAPES)
        print(io, case_module(i, sh; workload = workload, declare = declare))
    end
    println(io, "end")
    return String(take!(io))
end
function members_pkg(name, of)
    io = IOBuffer()
    println(io, "module $name\nusing Traits, $of")
    for i in eachindex(SHAPES)
        println(io, "Traits.declare_membership($of.C$i.MEMBER, $of.C$i.SET, @__MODULE__)")
    end
    println(io, "end")
    return String(take!(io))
end

# the child's driver: asks every copy in every world and prints one line per check
const DRIVER = raw"""
const NOARG_Q = [:sub, :int, :eq, :hasm]
const VAL_Q = [:isa, :tassert, :new, :disp, :app]
r1(x) = replace(repr(x isa Method ? (x.name, x.sig) : x), '\t' => ' ', '\n' => ' ')
callv(f, args...) = try f(args...) catch e; e isa TypeError ? :TypeError : e isa MethodError ? :MethodError : Symbol(nameof(typeof(e))) end
function ask(dir, P, worlds, copies_first)
    for (i, M) in enumerate([getglobal(P, Symbol(:C, i)) for i in 1:NSHAPES])
        x = Base.invokelatest(getglobal(M, :val))
        for q in vcat(NOARG_Q, VAL_Q), k in 0:1, (j, w) in enumerate(worlds)
            args = q in NOARG_Q ? () : (x,)
            f = Base.invokelatest(getglobal, M, Symbol("q_", q, "_", k))
            fr = Base.invokelatest(getglobal, M, Symbol("f_", q))
            c = callv(Base.invoke_in_world, w, f, args...)
            r = callv(Base.invoke_in_world, w, fr, args...)
            println("ROW\t", dir, "\t", SHAPENAMES[i], "\t", q, "\t", k, "\t", copies_first[k+1], "\t", j - 1, "\t", r1(c), "\t", r1(r))
        end
    end
end
# ask copy k of every question in the latest world (its first compile there)
function warm(P, k)
    for i in 1:NSHAPES
        M = getglobal(P, Symbol(:C, i))
        x = Base.invokelatest(getglobal(M, :val))
        for q in vcat(NOARG_Q, VAL_Q)
            callv(Base.invokelatest, getglobal(M, Symbol("q_", q, "_", k)), (q in NOARG_Q ? () : (x,))...)
        end
    end
end
"""

function main()
    root = mktempdir(; cleanup = !KEEP)
    pk = joinpath(root, "pkgs"); depot = joinpath(root, "depot"); mkpath(depot)
    write_pkg(pk, "PkgF1", funcs_pkg("PkgF1"))
    write_pkg(pk, "PkgM1", members_pkg("PkgM1", "PkgF1"))
    write_pkg(pk, "PkgF2", funcs_pkg("PkgF2"; workload = true))
    write_pkg(pk, "PkgFM", funcs_pkg("PkgFM"; workload = true, declare = true))
    # refused at activation: S in XP{Int} by PkgM3, S in XP{Float64} by PkgR, which folds it in its image
    write_pkg(pk, "PkgP", """
    module PkgP
    using Traits
    @trait XP{T}
    struct S end
    gp(::Any) = :Any
    gp(::XP{Float64}) = :XPF
    rq_sub() = S <: XP{Float64}
    rq_isa(x) = x isa XP{Float64}
    rq_disp(x) = gp(x)
    end""")
    write_pkg(pk, "PkgM3", "module PkgM3\nusing Traits, PkgP\nTraits.declare_membership(PkgP.S, PkgP.XP{Int}, @__MODULE__)\nend")
    write_pkg(pk, "PkgR", """
    module PkgR
    using Traits, PkgP
    Traits.declare_membership(PkgP.S, PkgP.XP{Float64}, @__MODULE__)
    r_sub() = PkgP.S <: PkgP.XP{Float64}
    r_isa(x) = x isa PkgP.XP{Float64}
    r_disp(x) = PkgP.gp(x)
    r_sub(); r_isa(PkgP.S()); r_disp(PkgP.S())
    end""")
    unif = dirname(@__DIR__)
    env = copy(ENV)
    env["JULIA_DEPOT_PATH"] = depot * ":" * join(DEPOT_PATH[2:end], ":")
    env["JULIA_LOAD_PATH"] = join([pk, unif, "@stdlib"], ":")
    env["JULIA_PKG_PRECOMPILE_AUTO"] = "0"
    hdr = "const NSHAPES = $(length(SHAPES)); const SHAPENAMES = $(repr([s[1] for s in SHAPES]))\n" * DRIVER
    function child(code)
        cmd = setenv(`$(Base.julia_cmd()) --startup-file=no -e $(hdr * code)`, env)
        out = IOBuffer(); err = IOBuffer()
        ok = success(pipeline(ignorestatus(cmd); stdout = out, stderr = err))
        return ok, String(take!(out)), String(take!(err))
    end
    # precompile each package in a session of its own
    t0 = time()
    for p in ("PkgF1", "PkgM1", "PkgF2", "PkgFM", "PkgP", "PkgM3", "PkgR")
        ok, out, err = child("using $p")
        ok || println("precompiling $p failed: ", first(err, 2000))
    end
    runs = [
        ("loaded_after", """
            using PkgF1
            warm(PkgF1, 0); w0 = Base.get_world_counter()
            using PkgM1
            w1 = Base.get_world_counter(); warm(PkgF1, 1)
            ask("loaded_after", PkgF1, [w0, w1], (0, 1))"""),
        ("image_code", """
            using Traits, PkgF2
            w0 = Base.get_world_counter()
            for i in 1:NSHAPES
                M = getglobal(PkgF2, Symbol(:C, i))
                Traits.declare_membership(M.MEMBER, M.SET, Main)
            end
            w1 = Base.get_world_counter(); warm(PkgF2, 1)
            ask("image_code", PkgF2, [w0, w1], (0, 1))"""),
        ("image_positive", """
            using PkgFM
            w0 = Base.get_world_counter()
            for i in 1:NSHAPES
                M = getglobal(PkgFM, Symbol(:C, i))
                ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), M.MEMBER, M.SET, PkgFM)
            end
            w1 = Base.get_world_counter(); warm(PkgFM, 1)
            ask("image_positive", PkgFM, [w0, w1], (0, 1))"""),
        ("refused", """
            using PkgP, PkgM3
            a0 = (PkgP.rq_sub(), PkgP.rq_isa(PkgP.S()), PkgP.rq_disp(PkgP.S()))
            using PkgR
            for (n, c, f) in (("sub", PkgR.r_sub(), PkgP.S <: PkgP.XP{Float64}), ("isa", PkgR.r_isa(PkgP.S()), PkgP.S() isa PkgP.XP{Float64}),
                              ("disp", PkgR.r_disp(PkgP.S()), PkgP.gp(Base.inferencebarrier(PkgP.S()))),
                              ("sub_before", PkgP.rq_sub(), ccall(:jl_subtype, Cint, (Any, Any), PkgP.S, PkgP.XP{Float64}) != 0),
                              ("isa_before", PkgP.rq_isa(PkgP.S()), ccall(:jl_isa, Cint, (Any, Any), PkgP.S(), PkgP.XP{Float64}) != 0))
                println("ROW\\trefused\\tsecond_instance\\t", n, "\\t0\\t0\\t1\\t", repr(c), "\\t", repr(f))
            end"""),
    ]
    rows = Vector{Vector{SubString{String}}}()
    for (name, code) in runs
        ok, out, err = child(code)
        ok || println("child $name failed: ", first(err, 3000))
        for l in split(out, '\n')
            startswith(l, "ROW\t") && push!(rows, split(l, '\t')[2:end])
        end
        occursin("WARNING", err) && println("child $name warned: ", first(join(filter(l -> occursin("WARNING", l), split(err, '\n')), " | "), 600))
    end
    dt = time() - t0
    # dir shape question copy first world compiled fresh
    mism = filter(r -> r[7] != r[8], rows)
    println("set_folds_images: Julia ", VERSION, " ", Base.GIT_VERSION_INFO.commit_short, ", ", length(SHAPES), " shapes")
    println("\n== compiled against fresh: ", length(mism), " mismatches (direction, shape, question: copy/world compiled/fresh)")
    groups = Dict{Any,Vector{Any}}()
    for r in mism; push!(get!(groups, (r[1], r[2], r[3]), Any[]), r); end
    for (k, v) in sort!(collect(groups); by = p -> string(p[1]))
        println("  ", rpad(k[1], 15), rpad(k[2], 16), rpad(k[3], 8), join(["copy $(r[4]) world $(r[6]): $(r[7])/$(r[8])" for r in v], "; "))
    end
    for d in unique(r[1] for r in rows)
        n = count(r -> r[1] == d, rows); m = count(r -> r[1] == d, mism)
        println("== ", d, ": ", n, " checks, ", m, " mismatches")
    end
    println("\nset_folds_images: $(length(rows)) checks, $(length(mism)) mismatches in $(length(groups)) groups, $(round(dt; digits = 1)) s")
    KEEP ? println("kept: ", root) : rm(root; recursive = true, force = true)
end
main()
