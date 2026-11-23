# The set-folds report's closed-build mode (W-171, E-544): are the answers about a set that a trimmed program compiles
# the answers a session gives? A closed build has one world: what is final there is every set's members (compiler
# §7.6). For each shape of `set_folds.jl` that a program can hold, in three final states (the pair declared; declared
# and taken back while the program loads; never declared), the program computes every question at the shape's value,
# compiled for the value's type and, where the shape has one, once at a set; the session runs the same source. The
# two outputs are compared line by line.
#
#     julia --project=experiments/implementation experiments/implementation/audit/set_folds_closed.jl [--keep] [--shapes=a,b]
#
# It writes the program to a temporary directory, runs it in a session, builds it with `--trim=safe` by the tree's
# juliac build script (as ../w139/build.sh does; memory guard 4 GB) and runs the binary. The last line is the tally.

const KEEP = "--keep" in ARGS
const SHAPESEL = let a = filter(x -> startswith(x, "--shapes="), ARGS); isempty(a) ? nothing : split(a[1][10:end], ',') end

# the shapes of set_folds.jl that a program holds: (name, defs, member, set, setup, A, B, val, W)
nest(s, n) = n == 0 ? s : "Tuple{" * nest(s, n - 1) * "}"
nestv(s, n) = n == 0 ? s : "(" * nestv(s, n - 1) * ",)"
const INP = "@trait X2{I}\nccall(:jl_set_input_params, Cvoid, (Any, UInt8), X2, 0x01)\nstruct S end"
const CLOSED_SHAPES = [
    ("type", "struct S end", "S", "X", "", "S", "X", "S()", ""),
    ("tuple", "struct S end", "S", "X", "", "Tuple{S}", "Tuple{X}", "(S(),)", ""),
    ("tuple2", "struct S end", "S", "X", "", "Tuple{Int, S}", "Tuple{Integer, X}", "(1, S())", ""),
    ("invariant", "struct S end", "S", "X", "", "Ph{S}", "Ph{X}", "Ph{S}()", ""),
    ("union", "struct S end", "S", "X", "", "S", "Union{X, Int}", "S()", ""),
    ("intersection", "struct S end\n@trait Yb", "S", "X", "SFLIB_DECLARE(S, Yb)", "S", "Core.All{Tuple{X, Yb}}", "S()", ""),
    ("all3", "struct S end\n@trait Yb\n@trait Yd", "S", "X", "SFLIB_DECLARE(S, Yb)\nSFLIB_DECLARE(S, Yd)", "S",
     "Core.All{Tuple{X, Yb, Yd}}", "S()", ""),
    ("upper_bound", "struct S end", "S", "X", "", "Ph{S}", "Ph{<:X}", "Ph{S}()", ""),
    ("lower_bound", "struct S end", "S", "X", "", "Ph{X}", "Ph{T} where T>:S", "Ph{X}()", ""),
    ("lb_tuple", "struct S end", "S", "X", "", "Tuple{Ph{X}}", "Tuple{Ph{T}} where T>:S", "(Ph{X}(),)", ""),
    ("super_param", "struct S end\nabstract type AP{T} end\nstruct P2{T} <: AP{T} end", "S", "X", "", "P2{S}", "AP{<:X}",
     "P2{S}()", ""),
    ("type_type", "struct S end", "S", "X", "", "Type{S}", "Type{<:X}", "S", ""),
    ("type_value", "struct S end", "Type{S}", "X", "", "Type{S}", "X", "S", ""),
    ("vararg", "struct S end", "S", "X", "", "Tuple{Int, S, S}", "Tuple{Int, Vararg{X}}", "(1, S(), S())", ""),
    ("family", "struct F{T} end", "F{T} where T", "X", "", "F{Int}", "X", "F{Int}()", ""),
    ("family_bounded", "struct F{T} end\n@trait Yb\nstruct S end", "F{T} where T<:Yb", "X", "SFLIB_DECLARE(S, Yb)", "F{S}",
     "X", "F{S}()", ""),
    ("input", INP, "S", "X2{Int}", "", "S", "X2{Int}", "S()", ""),
    ("inputs2", INP, "S", "X2{Int}", "SFLIB_DECLARE(S, X2{String})", "S", "Core.All{Tuple{X2{Int}, X2{String}}}", "S()", ""),
    ("abstract_member", "abstract type AM end\nstruct SA <: AM end", "AM", "X", "", "AM", "X", "SA()", "AM"),
    ("set_member", "@trait Y0\nstruct S0 end", "Y0", "X", "SFLIB_DECLARE(S0, Y0)", "Y0", "X", "S0()", "Y0"),
    ("member_method", "struct S end\nstruct T1 end\ng(::S) = :A", "S", "X", "SFLIB_DECLARE(T1, X)", "S", "X", "S()", "X"),
    ("deep9", "struct S end", "S", "X", "", nest("S", 9), nest("X", 9), nestv("S()", 9), ""),
]

const VARIANTS = [("D", [:add]), ("T", [:add, :del]), ("N", Symbol[])]
const QV = [:isa, :tassert, :new, :stf, :mrs, :disp, :app]
const QN = [:sub, :int, :eq]
qbody(q) = q === :sub ? "A <: B" : q === :int ? "typeintersect(A, B) === Union{}" : q === :eq ? "A == B" :
           q === :isa ? "x isa B" : q === :tassert ? "(x::B; true)" : q === :new ? "(@newHB(x); true)" :
           q === :stf ? "(m = MB(); setfield!(m, :v, x); true)" :
           q === :mrs ? "(Core.memoryrefset!(Core.memoryrefnew(Memory{B}(undef, 1)), x, :not_atomic, true); true)" :
           q === :disp ? "g(x)" : q === :app ? "applicable(h, x)" : error(q)

function program()
    io = IOBuffer()
    println(io, "using Traits")
    mods = String[]
    for sh in CLOSED_SHAPES, (vn, chs) in VARIANTS
        name, defs, member, set, setup, A, B, val, W = sh
        SHAPESEL === nothing || name in SHAPESEL || continue
        m = "SFC_$(name)_$(vn)"
        push!(mods, m)
        println(io, "module $m\nusing Traits\nSFLIB_DECLARE(mem, set) = Traits.declare_membership(mem, set, @__MODULE__)")
        println(io, "@trait X\nstruct Ph{T} end\n", defs)
        println(io, "const A = $A\nconst B = $B")
        println(io, "g(::Any) = :Any\ng(::B) = :B\nh(::B) = :hB")
        println(io, "struct HB; v::B; end\nmacro newHB(x) esc(Expr(:new, :HB, x)) end\nmutable struct MB; v::B; MB() = new(); end")
        isempty(setup) || println(io, setup)
        for c in chs
            c === :add && println(io, "SFLIB_DECLARE($member, $set)")
            c === :del && println(io, "ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), $member, $set, @__MODULE__)")
        end
        for q in QN
            println(io, "q_$(q)() = ", qbody(q))
        end
        for q in QV
            println(io, "q_$(q)(x) = ", qbody(q))
            isempty(W) || println(io, "Base.@nospecializeinfer o_$(q)(@nospecialize(x::$W)) = ", qbody(q))
        end
        println(io, "ans(f) = try string(f()) catch e; e isa TypeError ? \"TypeError\" : e isa MethodError ? \"MethodError\" : \"error\" end")
        println(io, "ans(f, x) = try string(f(x)) catch e; e isa TypeError ? \"TypeError\" : e isa MethodError ? \"MethodError\" : \"error\" end")
        println(io, "function answers(out)")
        println(io, "    x = $val")
        for q in QN
            println(io, "    push!(out, \"$m $q q \" * ans(q_$q))")
        end
        for q in QV
            println(io, "    push!(out, \"$m $q q \" * ans(q_$q, x))")
            isempty(W) || println(io, "    x isa $W && push!(out, \"$m $q o \" * ans(o_$q, x))")
        end
        println(io, "end\nend")
    end
    println(io, "function (@main)(args::Vector{String})::Cint\n    out = String[]")
    for m in mods
        println(io, "    $m.answers(out)")
    end
    println(io, "    for l in out\n        println(Core.stdout, l)\n    end\n    return 0\nend")
    return String(take!(io))
end

function main()
    R = normpath(joinpath(@__DIR__, "..", "..", ".."))
    root = mktempdir(; cleanup = !KEEP)
    app = joinpath(root, "sfclosed.jl")
    write(app, program())
    J = joinpath(Sys.BINDIR, "julia")
    proj = normpath(joinpath(@__DIR__, ".."))
    t0 = time()
    ses = read(ignorestatus(`$J -t 1 --startup-file=no --project=$proj -e 'include(ARGS[1]); exit(main(String[]))' $app`), String)
    lib = normpath(joinpath(Sys.BINDIR, "..", "lib"))
    tr = normpath(joinpath(Sys.BINDIR, "..", "..", "test", "trimming"))
    log = joinpath(root, "build.log")
    obj = joinpath(root, "sfclosed-o.a"); exe = joinpath(root, "sfclosed")
    cmd = `nice -n 10 $J -t 1 -J $lib/julia/sys.so --startup-file=no --history-file=no --project=$proj --output-o $obj
           --output-incremental=no --strip-ir --strip-metadata --experimental --trim=safe $tr/juliac-buildscript.jl $app --output-exe true`
    ok = success(pipeline(ignorestatus(cmd); stdout = log, stderr = log))
    tb = time() - t0
    bin = ""
    if ok
        cfg = read(`$J --startup-file=no -e 'include(joinpath(Sys.BINDIR,Base.DATAROOTDIR,"julia","julia-config.jl"))' -- --ldflags --ldlibs`, String)
        cc = `cc -o $exe -Wl,--whole-archive $obj -Wl,--no-whole-archive -lm -L$lib -L$lib/julia -Wl,-rpath,$lib -Wl,-rpath,$lib/julia $(split(cfg)) -ljulia-internal`
        ok = success(pipeline(ignorestatus(cc); stdout = log, stderr = log, append = true))
        ok && (bin = read(ignorestatus(`timeout 120 $exe`), String))
    end
    sl = filter(!isempty, split(ses, '\n')); bl = filter(!isempty, split(bin, '\n'))
    println("set_folds_closed: Julia ", VERSION, " ", Base.GIT_VERSION_INFO.commit_short, "; build ", ok ? "ok" : "failed",
            " after ", round(tb; digits = 1), " s")
    if !ok
        println(join(last(readlines(log), 30), '\n'))
    end
    bd = Dict(split(l, ' ')[1:3] => l for l in bl if count(' ', l) >= 3)
    mism = String[]
    for l in sl
        k = split(l, ' ')[1:3]
        b = get(bd, k, "(missing)")
        b == l || push!(mism, "  session: $l | program: $(b == "(missing)" ? b : split(b, ' ')[4])")
    end
    for m in mism; println(m); end
    println("set_folds_closed: $(length(sl)) answers in the session, $(length(bl)) in the program, $(length(mism)) differ",
            KEEP ? "; kept $root" : "")
    KEEP || rm(root; recursive = true, force = true)
end
main()
