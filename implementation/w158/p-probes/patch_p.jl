# W-158, seventh part: lays this part's compiler change (wt/w158-julia, after 85bd884a57) over the session's compiler
# (`../../w156/tools/cc_patch.jl`), to try it in a session of 85bd884a57. PATCH_NAMES overrides the list. A session
# patch does not reach a trimmed build's own inference (the fifth part's finding).
include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
let src = joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w158-julia", "Compiler", "src")
    names = Symbol.(split(get(ENV, "PATCH_NAMES", "declared_operation_result abstract_call_gf_by_type abstract_invoke")))
    cc_patch(joinpath(src, "abstractinterpretation.jl"), names)
end
Base.Compiler.activate_codegen!()      # a statement of its own: inference then runs in the world of the definitions
