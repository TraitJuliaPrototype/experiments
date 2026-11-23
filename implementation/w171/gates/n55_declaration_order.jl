# Gate (compiler §4.3; E-544): a declaration's walk ends the code the membership changes before the world counter
# advances to the entry, as a method's insertion does: two threads that read the counter and ask a call compiled for
# the member never run code compiled before the membership in its world. Runs `../probes/thread_race.jl` with three
# threads for 2000 declarations and takings back. A candidate for `gates/`; fails on `w171c` 20730dea1c (22 to 3,844
# wrong answers a run).
#     julia --project=experiments/implementation n55_declaration_order.jl
up(f) = (d = @__DIR__; while !ispath(joinpath(d, f)) && dirname(d) != d; d = dirname(d); end; joinpath(d, f))
probe = up(joinpath("w171", "probes", "thread_race.jl"))
proj = dirname(dirname(dirname(probe)))
out = read(`$(Base.julia_cmd()) -t 3 --startup-file=no --project=$proj $probe member 2000`, String)
println(strip(out))
m = match(r"(\d+) checks, (\d+) wrong", out)
@assert m !== nothing && parse(Int, m.captures[1]) > 1000 && m.captures[2] == "0" "wrong answers under threads: $out"
println("n55_declaration_order: OK")
