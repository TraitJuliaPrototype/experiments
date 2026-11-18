using TraitCSV, TraitTables, TraitMakie, Profile
const TC = TraitTables.TableCore
t = TraitCSV.read(ARGS[1]); TraitTables.summary_text(t)
file = joinpath(dirname(pathof(TraitTables)), "TableCore.jl")
function finddef(ex, name)
    ex isa Expr || return nothing
    if ex.head in (:toplevel, :block, :module, :macrocall)
        for a in ex.args; r = finddef(a, name); r === nothing || return r; end
    elseif ex.head === :function && ex.args[1] isa Expr && ex.args[1].head === :call && ex.args[1].args[1] === name
        return ex
    end
    nothing
end
ex = finddef(Meta.parseall(read(file, String); filename = file), :summarize)
Base.cumulative_compile_timing(true)
Profile.init(n = 10^7, delay = 0.001)
c0 = Base.cumulative_compile_time_ns(); tt = @elapsed @profile Core.eval(TC, ex); c1 = Base.cumulative_compile_time_ns()
println("edit 1: ", round(1000tt; digits=1), " ms (compile ", round((c1[1]-c0[1])/1e6; digits=1), ")")
tt = @elapsed Core.eval(TC, ex); println("edit 2: ", round(1000tt; digits=1), " ms")
Profile.print(IOContext(stdout, :displaysize => (200, 250)); format = :flat, sortedby = :count, mincount = 400, noisefloor = 0)
