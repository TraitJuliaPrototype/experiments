# W-158, fourth part: lays the worktree's change (wt/w158-julia, after d8f65ef1ea) over the session's compiler
# (`../../w156/tools/cc_patch.jl`), to try it in a session of a Julia built before it (julia-next d8f65ef1ea).
# PATCH_NAMES (abstractinterpretation.jl) and PATCH_TYPEINFER (typeinfer.jl) override the lists.
include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
let src = joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w158-julia", "Compiler", "src")
    names = Symbol.(split(get(ENV, "PATCH_NAMES",
        "closed_reaches closed_entry_free closed_candidates_in closed_callable_split abstract_call_unknown closed_choosing_type closed_choice_bits closed_note_result! abstract_call_gf_by_type")))
    cc_patch(joinpath(src, "abstractinterpretation.jl"), names)
    extra = get(ENV, "PATCH_TYPEINFER", "")
    isempty(extra) || cc_patch(joinpath(src, "typeinfer.jl"), Symbol.(split(extra)))
    Base.Compiler._verify_trim_world_age[] = Base.get_world_counter()
end
