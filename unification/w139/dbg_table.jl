# W-139: the closed build's rule for a cast to `Compiled` on a value known by its trait, seen from a
# session (as dbg_closed.jl): TraitTables' `floats`, `describe` and TraitCSV's `readtable`.
using TraitWorld, TraitCSV, TraitTables
let i = findfirst(==(:trim), fieldnames(Base.JLOptions))
    unsafe_store!(Ptr{Int8}(cglobal(:jl_options)) + fieldoffset(Base.JLOptions, i), Int8(1))
end
push!(LOAD_PATH, joinpath(ENV["TW_ROOT"], "julia-unified", "Compiler"))
using Compiler
const CC = Compiler
const TC = TraitTables.TableCore
dyn(ci) = [st for st in ci.code if Meta.isexpr(st, :call) && st.args[1] == GlobalRef(Core, :attributed_call)]
for (f, tt) in ((TC.describe, (TC.Table,)), (TraitCSV.CSVCore.readtable, (String, UInt8, Vector{TraitCSV.CSVCore.CSVColumn})),
                ((t, n) -> TC.floats(t, n), (TC.Table, String)))
    ci, rt = Base.code_typed(f, tt; interp = CC.NativeInterpreter())[1]
    println(f, " => ", rt, " | statements ", length(ci.code), " | attributed calls left: ", length(dyn(ci)))
    foreach(st -> println("    ", st), dyn(ci))
end

println("members of Column a closed build lists: ", length(CC.closed_candidates(TC.Column)), "; of CSVColumn: ", CC.closed_candidates(TraitCSV.CSVCore.CSVColumn))
println("emptylike at CSVColumn infers: ", Base.return_types(TraitCSV.CSVCore.emptylike, (TraitCSV.CSVCore.CSVColumn,); interp = CC.NativeInterpreter()))
