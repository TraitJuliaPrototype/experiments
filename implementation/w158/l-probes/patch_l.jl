# C-157: lays the patch (l-probes/patch/inlining.jl, julia-next's file with the change; the diff:
# l-probes/patch-l.diff) over the session's compiler (`../../w156/tools/cc_patch.jl`), and makes the runtime
# infer in the latest world from here on, so that code compiled after this point uses it.
include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
cc_patch(joinpath(@__DIR__, "patch", "inlining.jl"),
         [:handle_call!, :handle_cases!, :handle_dispatched_result!, :holds_declared_callable, :declares_callable_result])
Base.Compiler.activate_codegen!()
