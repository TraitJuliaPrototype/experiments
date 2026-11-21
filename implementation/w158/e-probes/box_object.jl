# W-158, third part (C-152): the kept form's forwarding method at a box kept at a place typed by the set: its split at
# the object the box holds, round by round (`../probes/rounds.jl`), on `../probes/flow.jl`'s `boxes` (a box and a plain
# member in a `Vector{Shape7}`). Before: the forwarding method reads the object through `_fwd`, a box branch is left
# (`logs/c-box-object-ir.log`); after: it reads `getfield(d, :object)`, no box branch. Run from the library's project.
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "probes", "flow.jl"))
end
include(joinpath(@__DIR__, "..", "probes", "rounds.jl"))
check_rounds(boxes, (Int,); show = "", showcode = r"boxes|area7")
