# W-158, fifth part: lays this part's compiler change (wt/w158-julia, after dc11704ef7) over the session's compiler
# (`../../w156/tools/cc_patch.jl`), to try it in a session of dc11704ef7. PATCH_NAMES overrides the list.
include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
let src = joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w158-julia", "Compiler", "src")
    names = Symbol.(split(get(ENV, "PATCH_NAMES",
        "CLOSED_FORWARDERS closed_is_forwarder closed_forwarder closed_forwarder_call closed_member_split abstract_call_gf_by_type")))
    cc_patch(joinpath(src, "abstractinterpretation.jl"), names)
    Base.Compiler._verify_trim_world_age[] = Base.get_world_counter()
end
