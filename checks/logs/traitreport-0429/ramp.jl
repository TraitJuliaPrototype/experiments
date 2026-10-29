using TraitCSV, TraitTables, TraitWorld
R = "/home/hellmann/Repos/julia-trait-bound/TraitReport"
s = TraitCSV.read(joinpath(R, "data", "sensors.csv"))
struct Ramp; n::Int; end
TraitTables.nrows(r::Ramp) = r.n
TraitTables.cell(r::Ramp, i::Int) = 0.5 * i
@implement Column Ramp
addcolumn!(s, "ramp", Ramp(nrow(s)))
d = try describe(s) catch e; showerror(stdout, e, catch_backtrace()); println(); nothing end
d === nothing || println("describe mean: ", d[end].mean, " expected ", 0.5 * (nrow(s) + 1) / 2)
r = try sortby(s, "ramp")["ramp"] catch e; showerror(stdout, e, catch_backtrace()); println(); nothing end
println("sortby: ", typeof(r), " ", r isa Dynamic{Column})
