# W-166b: the probe `b_join.jl` with the compiler's change of the worktree `wt/w166-julia` laid over the
# session's compiler (`cc_patch`): the build's check, run in the session, reads the same rules.
include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
cc_patch(joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w166-julia", "Compiler", "src", "abstractinterpretation.jl"),
         [:closed_wrapper_set, :closed_wrapper_of, :closed_wrapper_bits, :closed_member_types,
          :closed_has_set_argument, :closed_member_split, :abstract_call_gf_by_type])
include(joinpath(@__DIR__, "b_join.jl"))
