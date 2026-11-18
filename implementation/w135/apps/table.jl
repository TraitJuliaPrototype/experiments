# E-361 (4): a CSV read, summarized and sorted. TABLE_PLAIN=1 builds the plain twin (PlainTables).
const PLAIN = get(ENV, "TABLE_PLAIN", "0") == "1"
@static if PLAIN
    using PlainTables; const TB = PlainTables; const RD = PlainTables.readcsv
else
    using TraitWorld, TraitCSV, TraitTables; const TB = TraitTables; const RD = TraitCSV.read
end
function (@main)(args::Vector{String})::Cint
    t = RD(args[1])
    println(Core.stdout, TB.summary_text(t))
    x = TB.floats(t, TB.colnames(t)[1])
    println(Core.stdout, "sum ", round(sum(x); sigdigits = 8))
    return 0
end
PLAIN || include("verify.jl")
