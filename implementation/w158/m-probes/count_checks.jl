# W-158, sixth part: the checks the rule of compiler §7.4 inserts while a session compiles (a probe: a counter laid
# over the session's compiler, nothing in the product). `trusted_result_check` is wrapped to count each check it
# makes, by where it is made (from the call stack): at a direct call of a function known only by its signature
# (`handle_callable_call!`), after a call that passed one on (`check_trusted_result!`), in a split
# (`ir_inline_unionsplit!`: a fallback or case, and an operation's or a closed build's branches), and by its kind
# (`Callable`: the box's check; `typeassert`: an operation's). Run with `--compiled-modules=no`, so that every package
# is inferred in the session and counted (an image's code, and a cache's inferred code under `--pkgimages=no`, were
# inferred in the precompile process).
#     julia --compiled-modules=no --project=<env> count_checks.jl <app.jl> [args…]
const CC = Base.Compiler
const COUNTS = Dict{Tuple{Symbol,Symbol},Int}()
const ORIG = which(CC.trusted_result_check, (Any, Any, UInt32, UInt))
Core.eval(CC, quote
    function trusted_result_check(@nospecialize(val), @nospecialize(T), trusted::UInt32, world::UInt)
        where_ = :other
        for fr in stacktrace()
            n = fr.func
            if n === :handle_callable_call!
                where_ = :direct; break
            elseif n === :check_trusted_result!
                where_ = :passed_on; break
            elseif n === :ir_inline_unionsplit! || n === :handle_call!
                where_ = :split; break
            end
        end
        kind = trusted & IR_FLAG_TRUSTED_CALLABLE != 0 ? :Callable : :typeassert
        c = $(COUNTS)
        c[(where_, kind)] = get(c, (where_, kind), 0) + 1
        if trusted & IR_FLAG_TRUSTED_CALLABLE != 0
            mi = callable_result_instance(world)
            mi === nothing || return Expr(:invoke, mi, GlobalRef(Core, :_callable_result), val, T)
            return Expr(:call, GlobalRef(Core, :_callable_result), val, T)
        end
        return Expr(:call, GlobalRef(Core, :typeassert), val, T)
    end
end)
CC.activate_codegen!()
app = abspath(popfirst!(ARGS))
include(app)
redirect_stdout(devnull) do
    Base.invokelatest(main, ARGS)
end
for (k, v) in sort!(collect(COUNTS); by = first)
    println("checks $(k[1]) $(k[2]): $v")
end
println("checks total: ", sum(values(COUNTS); init = 0), " (", sum((v for (k, v) in COUNTS if k[2] === :Callable); init = 0), " of a Callable's result)")
