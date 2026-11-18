#@ load
using TraitCSV, TraitTables, TraitMakie
#@ read
t = TraitCSV.read(ARGS[1])
#@ summary
print(summary_text(t))
#@ plot
name = numericnames(t)[1]
x = floats(t, name; skipmissing = true)
f = hist(x; bins = 24, title = basename(ARGS[1]), size = (1200, 800))
vlines!(f, sum(x) / length(x); color = :red)
save(ARGS[2], f)
#@ _find the edit
const TC = TraitTables.TableCore
tcfile = joinpath(dirname(pathof(TraitTables)), "TableCore.jl")
function finddef(ex, name)
    ex isa Expr || return nothing
    if ex.head in (:toplevel, :block, :module, :macrocall)
        for a in ex.args; r = finddef(a, name); r === nothing || return r; end
    elseif ex.head === :function && ex.args[1] isa Expr && ex.args[1].head === :call && ex.args[1].args[1] === name
        return ex
    end
    nothing
end
editex = finddef(Meta.parseall(read(tcfile, String); filename = tcfile), :summarize)
#@ edit of summarize, first
Core.eval(TC, editex)
#@ edit of summarize, second
Core.eval(TC, editex)
#@ summary after the edit
print(summary_text(t))
