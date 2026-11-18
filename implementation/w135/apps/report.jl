# E-361 (6): TraitReport's task, form (t): a CSV read, its summary printed, a histogram of the first
# numeric column with its mean, to a PNG (TraitCSV, TraitTables, TraitMakie).
# REPORT_PLAIN=1 builds the plain twin (PlainTables and PlainPlots).
const PLAIN = get(ENV, "REPORT_PLAIN", "0") == "1"
@static if PLAIN
    using PlainTables, PlainPlots; const TB = PlainTables; const PL = PlainPlots; const RD = PlainTables.readcsv
else
    using TraitWorld, TraitCSV, TraitTables, TraitMakie; const TB = TraitTables; const PL = TraitMakie; const RD = TraitCSV.read
end
function (@main)(args::Vector{String})::Cint
    t = RD(args[1])
    print(Core.stdout, TB.summary_text(t))
    name = TB.numericnames(t)[1]
    x = TB.floats(t, name; skipmissing = true)
    f = PL.hist(x; bins = 24, title = "report", size = (1200, 800))
    PL.vlines!(f, sum(x) / length(x); color = :red)
    PL.save(args[2], f)
    println(Core.stdout, "wrote ", args[2])
    return 0
end
PLAIN || include("verify.jl")
include("jllhole.jl")
