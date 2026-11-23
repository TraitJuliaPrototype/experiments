# Gate (compiler §4, §5; E-542 to E-544): the set-folds report on a fixed slice, chosen to hold a case of every pattern
# the report found (W-171's fifteen fixes, rows 181 to 195 of the inventory, and C-166, C-167): compiled code asked in
# every world a sequence makes answers as the runtime asked afresh there. Three runs, each in processes of its own:
# - the stub mode: the type, a tuple with a `Vararg`, a declared supertype's parameter, `Type{<:X}`, a type value,
#   lower bounds (at the top, against a set, compared for equality at the top and inside an invariant parameter, a
#   member inside one), a set as member, an abstract member, a union of both sides, code compiled once at the set with
#   a method at the member's own type, a set nine tuples deep; every question, the stores into storage typed by a set
#   among them; declared, taken back, declared again, a method at the member before it;
# - the library mode: the kept forms `Compiled{S}` and `Dynamic{Y}`, `Callable`; declared and taken back;
# - the image mode (memberships and code in package images; all of it, 15 s).
# The full report stays the playbook's step after a change to sets or folds (playbook §3).
# A candidate for `gates/`; fails on `w143-julia` d1e64d8b56, `absence-worlds` 8884715703 and `w159-bisect` 3037289af6.
#     julia --project=experiments/implementation n49_set_folds.jl
up(f) = (d = @__DIR__; while !ispath(joinpath(d, f)) && dirname(d) != d; d = dirname(d); end; joinpath(d, f))
const AUDIT = up(joinpath("audit", "set_folds.jl")) |> dirname
const STUB = dirname(AUDIT)
const TW = up(joinpath("TraitWorld", "Project.toml")) |> dirname
const J = Base.julia_cmd()
const SHAPES = "type,vararg,super_param,type_type,type_value,lower_bound,lower_bound_rev,lower_bound_eq,lower_bound_inv," *
               "both_bounds,set_member,abstract_member,union_both,member_method,deep9,lb_in_tuple"
const SEQS = "^[a-z_]+/(declared|taken_back|redeclared|method_at_member)\$"
function run_tool(args...; project)
    out = read(ignorestatus(`$J --startup-file=no --project=$project $args`), String)
    lines = split(strip(out), '\n')
    return out, String(lines[end])
end
# the tally's counts, which must all be 0: mismatches, crashes, case errors, dynamic, fresh against expected
function zero_tally(t)
    m = match(r"(\d+) mismatches in \d+ groups, (\d+) crashes, (\d+) case errors, (\d+) dynamic, (\d+) fresh-vs-expected", t)
    m === nothing && return false
    return all(c -> c == "0", m.captures)
end
t0 = time()
out1, t1 = run_tool(joinpath(AUDIT, "set_folds.jl"), "--shapes=$SHAPES", "--only=$SEQS", "--show=3"; project = STUB)
println(t1)
zero_tally(t1) || (print(out1); error("the stub mode's slice: $t1"))
out2, t2 = run_tool(joinpath(AUDIT, "set_folds.jl"), "--mode=traitworld", "--shapes=compiled,dynamic,callable",
                    "--only=/(declared|taken_back)\$", "--show=3"; project = TW)
println(t2)
zero_tally(t2) || (print(out2); error("the library mode's slice: $t2"))
out3, t3 = run_tool(joinpath(AUDIT, "set_folds_images.jl"); project = STUB)
println(t3)
m3 = match(r"(\d+) checks, (\d+) mismatches", t3)
(m3 !== nothing && m3.captures[2] == "0" && parse(Int, m3.captures[1]) > 1000) || (print(out3); error("the image mode: $t3"))
println("n49_set_folds: OK (", round(time() - t0; digits = 1), " s)")
