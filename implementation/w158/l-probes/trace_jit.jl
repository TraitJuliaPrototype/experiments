# C-157, a tracing tool: lays a copy of Compiler's `add_codeinsts_to_jit!` over the session's, which prints the
# source handed to the JIT for a method whose name is in TRACE_NAMES, then activates the compiler in the latest world.
const CC = Base.Compiler
const TRACE_NAMES = Symbol[]
const TRACE_SRCS = Any[]   # (mi, copy of the source) per traced hand-over
const TRACE_PRINT = Ref(true)
let file = joinpath(Sys.BINDIR, "..", "..", "Compiler", "src", "typeinfer.jl")
    isfile(file) || (file = joinpath(ENV["TW_ROOT"], "julia-next", "Compiler", "src", "typeinfer.jl"))
    ast = Meta.parseall(read(file, String); filename = file)
    for ex in ast.args
        ex isa Expr && ex.head === :function || continue
        sig = ex.args[1]; sig.head === :call && sig.args[1] === :add_codeinsts_to_jit! || continue
        # before the ccall that hands the source to the JIT: print it
        body = ex.args[2]
        function walk!(e)
            e isa Expr || return
            for (i, a) in enumerate(e.args)
                if a isa Expr && a.head === :ccall || (a isa Expr && a.head === :call && a.args[1] === :ccall &&
                                                       a.args[2] == QuoteNode(:jl_add_codeinst_to_jit))
                    e.args[i] = quote
                        let m = get_ci_mi(callee)
                            if m.def isa Method && m.def.name in $(TRACE_NAMES)
                                Core.println("TRACE jit ", m, " world ", callee.min_world, ":", callee.max_world,
                                             " facts ", ci_policy_facts(callee))
                                $(TRACE_PRINT)[] && Core.println(src)
                                push!($(TRACE_SRCS), (m, copy(src)))
                            end
                        end
                        $a
                    end
                    return true
                end
                walk!(a) === true && return true
            end
            return nothing
        end
        walk!(body) === true || error("no ccall found")
        Core.eval(CC, ex)
        println(stderr, "trace_jit: add_codeinsts_to_jit! laid over")
    end
end
CC.activate_codegen!()
