# W-158, second part: lays the worktree's closed rules (members by flow, the kept form by use, no member)
# over the session's compiler (`../../w156/tools/cc_patch.jl`), to try them in a session before a build.
# Usage: include("patch_c.jl") in a session of a Julia built before the change (wt/w158-julia 61277571fa).
include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
let src = joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w158-julia", "Compiler", "src")
    cc_patch(joinpath(src, "abstractinterpretation.jl"),
             [:CLOSED_FLOWS, :CLOSED_NO_MEMBER, :CLOSED_NO_MEMBER_MET, :CLOSED_SET_PLACES, :CLOSED_PLACE_OF, :CLOSED_UNIONALL_PLACES,
              :closed_set_place, :closed_place, :note_used_type!, :note_closed_flow!, :closed_used_reset!,
              :closed_reaching_places, :closed_set_of, :closed_candidates, :closed_reaches, :closed_candidates_in,
              :closed_candidates_grew, :closed_member_types, :closed_no_member, :closed_member_split,
              :closed_choice_bits, :closed_kept_form, :closed_end_code!, :closed_build_reinfer!, :closed_box_object, :closed_drop_boxes, :operation_split_type, :abstract_call_gf_by_type])
    cc_patch(joinpath(src, "typeinfer.jl"), [:closed_note_value!, :closed_note_used!, :closed_no_member_round, :closed_invalidate_callers!, :closed_check])
    cc_patch(joinpath(src, "ssair", "inlining.jl"), [:handle_call!])
    cc_patch(joinpath(src, "verifytrim.jl"), [:get_verify_typeinf_trim]; mod = Base.Compiler.TrimVerifier)
    # (the verifier runs in a world of its own: the latest, so that it sees the definition above)
    Base.Compiler._verify_trim_world_age[] = Base.get_world_counter()
end
