# Gate (compiler §4.3, §9; E-545, C-168): an image's activated memberships are walked, and the code they end is
# ended, before the world counter advances to them, as at a declaration: two threads that read the counter and ask a
# call compiled for each member while a third loads the images that declare the memberships never run code compiled
# before a membership in its world. Runs `../probes/image_thread_race.jl` (40 images, 200 methods at the set). A
# candidate for `gates/`; fails on `next` 0bbd759c13.
#     julia --project=experiments/implementation n56_image_activation_order.jl
up(f) = (d = @__DIR__; while !ispath(joinpath(d, f)) && dirname(d) != d; d = dirname(d); end; joinpath(d, f))
probe = up(joinpath("w171", "probes", "image_thread_race.jl"))
proj = dirname(dirname(dirname(probe)))
out = read(`$(Base.julia_cmd()) --startup-file=no --project=$proj $probe 40 200`, String)
println(strip(out))
m = match(r"(\d+) images, (\d+) checks, (\d+) wrong.*every caller answers :X: (true|false)", out)
@assert m !== nothing && parse(Int, m.captures[2]) > 100 && m.captures[3] == "0" && m.captures[4] == "true" "wrong answers while images load: $out"
println("n56_image_activation_order: OK")
