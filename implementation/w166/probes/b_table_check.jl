# W-166b: the build's check of the table program's `main` run in a session (`fully_typed`), with the
# compiler's change of `wt/w166-julia` laid over the session's compiler where PATCH=1.
if get(ENV, "PATCH", "0") == "1"
    include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
    cc_patch(joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w166-julia", "Compiler", "src", "abstractinterpretation.jl"),
             [:closed_wrapper_set, :closed_wrapper_of, :closed_wrapper_bits, :closed_member_types,
              :closed_has_set_argument, :closed_member_split, :abstract_call_gf_by_type])
end
using TraitWorld, TraitCSV, TraitTables
const TB = TraitTables; const RD = TraitCSV.read
function tablemain(args::Vector{String})::Cint
    t = RD(args[1])
    println(Core.stdout, TB.summary_text(t))
    x = TB.floats(t, TB.colnames(t)[1])
    println(Core.stdout, "sum ", round(sum(x); sigdigits = 8))
    return 0
end
t0 = time()
ft = fully_typed(tablemain, (Vector{String},))
println("fully_typed: ", isfullytyped(ft), ", ", length(ft.sites), " sites, ", round(time() - t0; digits = 1), " s")
display(ft)
