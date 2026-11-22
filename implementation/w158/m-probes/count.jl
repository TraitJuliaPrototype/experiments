# W-158, sixth part: what the rule of compiler §7.4 costs a session, counted (a probe, nothing in the product). Loads
# an app of `../w135/apps/` (or any file with a `main`), runs `main` once, then reads every compiled instance of the
# session (every module's methods):
#   trusted      instances whose result rests on a declared result its members' own code does not check (the
#                `trusted` effect: a `Callable{A, S}`'s `S`, an operation's unchecked result)
#   checks       invokes of `Core._callable_result` in their optimized code: at a direct call of a function known only
#                by its signature (where `typeassert` was), and after a call that passes one on (new)
#   flagged      call statements that still carry the trusted IR flags (calls whose result was taken as the type alone,
#                not checked: an invoke of the instance inferred)
# per package (the module's root), and the total; with a build that has no `trusted` effect it prints zeros.
#     [LIST=1] julia --project=<env> count.jl <app.jl> [args…]        (LIST=1: the trusted instances)
app = abspath(popfirst!(ARGS))
include(app)
redirect_stdout(devnull) do
    Base.invokelatest(main, ARGS)
end
const C = Base.Compiler
const HAS = isdefined(C, :IR_FLAGS_TRUSTED)
const FLAGS = HAS ? C.IR_FLAGS_TRUSTED : UInt32(0)
trusted_bits(ci) = HAS ? C.decode_effects(ci.ipo_purity_bits).trusted : 0x00
counts = Dict{Symbol,Vector{Int}}()        # instances, trusted, direct checks, passed-on checks, flagged
function code_of(ci)
    src = isdefined(ci, :inferred) ? ci.inferred : nothing
    src isa String && (src = try Base._uncompressed_ir(ci, src) catch; nothing end)
    return src isa Core.CodeInfo ? src : nothing
end
isfunc(@nospecialize(x)) = x isa GlobalRef || x isa QuoteNode || x isa Function || x isa Core.Builtin
Base.visit(Core.methodtable) do m
    p = nameof(Base.moduleroot(m.module))
    c = get!(() -> zeros(Int, 5), counts, p)
    for mi in Base.specializations(m)
        mi === nothing && continue
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while ci !== nothing
            c[1] += 1
            if trusted_bits(ci) != 0x00
                c[2] += 1
                get(ENV, "LIST", "0") == "1" && println("trusted ", trusted_bits(ci), " ", mi.specTypes)
            end
            src = code_of(ci)
            if src !== nothing
                for (i, st) in enumerate(src.code)
                    st isa Expr && (src.ssaflags[i] & FLAGS) != 0 && (c[5] += 1)
                    Meta.isexpr(st, :invoke) || continue
                    f = st.args[2]
                    (f isa GlobalRef && f.name === :_callable_result) || continue
                    a = st.args[3]
                    prev = a isa Core.SSAValue ? src.code[a.id] : nothing
                    # a direct call: the called value is no function known by name
                    direct = Meta.isexpr(prev, :call) && !isfunc(prev.args[1])
                    direct ? (c[3] += 1) : (c[4] += 1)
                end
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
tot = zeros(Int, 5)
for (p, c) in sort!(collect(counts); by = first)
    tot .+= c
    any(!iszero, c[2:5]) && println("count $p: $(c[1]) instances, $(c[2]) trusted; checks $(c[3]) at a direct call, $(c[4]) after a call that passes one on; $(c[5]) statements flagged")
end
println("count total: $(tot[1]) instances, $(tot[2]) trusted; checks $(tot[3]) at a direct call, $(tot[4]) after a call that passes one on; $(tot[5]) statements flagged")
