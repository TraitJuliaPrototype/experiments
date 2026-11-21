# W-158, third part: lays the worktree's change (wt/w158-julia, after 8b35e4b77c) over the session's compiler
# (`../../w156/tools/cc_patch.jl`), to try it in a session of 8b35e4b77c's build before a build.
include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
let src = joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w158-julia", "Compiler", "src")
    cc_patch(joinpath(src, "abstractinterpretation.jl"),
             [:closed_member_type, :closed_member_split, :closed_callable_split, :abstract_call_unknown, :declared_field_in,
              :abstract_call_gf_by_type, :callable_set_type, :abstract_apply])
    cc_patch(joinpath(src, "typeinfer.jl"), [:closed_note_constant!, :closed_holds_none, :closed_note_held!, :closed_note_used!])
    Core.eval(Base.Compiler.TrimVerifier, :(using ..Compiler: use_const_api, mi_policy_facts_at, ci_policy_facts, &, |, UInt8))
    cc_patch(joinpath(src, "verifytrim.jl"), [:verify_codeinstance!, :get_verify_typeinf_trim]; mod = Base.Compiler.TrimVerifier)
    isfile(joinpath(@__DIR__, "patch_e_extra.jl")) && include(joinpath(@__DIR__, "patch_e_extra.jl"))
    Base.Compiler._verify_trim_world_age[] = Base.get_world_counter()
end
