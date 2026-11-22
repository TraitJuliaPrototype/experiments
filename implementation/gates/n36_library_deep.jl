# project: TraitWorld
# W-167 (open issue 254; compiler §3.2, facts §2.2): the library's own code is in the deep class, so that no unrelated
# load ends it. Every hook the runtime or Base calls (at a definition, a module's end, an image's load, a package's
# load) has its instance in the class, and no instance of the library outside the class is on a hook's path, a
# macro's or a tool's: the code that handles values of any type by its purpose is reached through a run-time site by
# intent (`_runtime_site`), and `@trait`'s expansion is the named exception. The lists and their reasons:
# `../w167/lib_static.jl` (QUIET here); the flags are read by `../w167/flags.jl`, which checks itself.
ENV["QUIET"] = "1"
include(joinpath(@__DIR__, "..", "w167", "lib_static.jl"))
@assert length(hookroots) >= 10 "the hooks' instances are in the library's image ($(length(hookroots)))"
@assert all(g2, hookroots) "every hook is in the deep class: outside " * join(short.(filter(!g2, hookroots)), ", ")
@assert count(g2, lib) > length(lib) ÷ 2 "most of the library's instances are in the class ($(count(g2, lib)) of $(length(lib)))"
@assert isempty(rest) "no instance outside the class but behind a run-time site and the named exceptions: " *
                      join(string.(path.(rest), " ", short.(rest, 100)), "; ")
println("n36_library_deep: OK")
