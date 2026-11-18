try
    include(joinpath(@__DIR__, "..", "check", "edit_table.jl"))
catch e
    println("ERR TYPE ", typeof(e))
    e isa LoadError && (println("inner ", typeof(e.error)); x = e.error; println(x isa ErrorException ? x.msg : x isa TypeError ? (x.func, x.context, x.expected, typeof(x.got)) : fieldnames(typeof(x))))
    bt = catch_backtrace()
    for (k, fr) in enumerate(Base.stacktrace(bt)); k > 25 && break; println(fr); end
end
