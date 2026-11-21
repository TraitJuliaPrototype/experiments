# C-157, diagnosis: does the runtime's compile of `passes` pass through the inliner's assertion?
# Lays a tracing copy of `handle_declared_result!` and of `abstract_call_unknown`'s Callable branch over Base.Compiler.
const Callable = Core.Callable
const CC = Base.Compiler
@eval CC function handle_declared_result!(ir::IRCode, idx::Int, stmt::Expr, info::DeclaredResultInfo)
    Core.println("TRACE handle_declared_result! rt=", info.rt, " stmt=", stmt)
    inst = ir[SSAValue(idx)]
    call = insert_node!(ir, SSAValue(idx), NewInstruction(stmt, Any, NoCallInfo(), inst[:line], nothing))
    inst[:stmt] = Expr(:call, GlobalRef(Core, :typeassert), call, info.rt)
    inst[:info] = NoCallInfo()
    inst[:flag] = IR_FLAG_NULL
    return nothing
end
@eval CC function optimize(interp::AbstractInterpreter, opt::OptimizationState, caller::InferenceResult)
    ir = run_passes_ipo_safe(opt.src, opt)
    tr = opt.linfo isa MethodInstance && opt.linfo.def isa Method && opt.linfo.def.name === :passes
    tr && Core.println("TRACE after passes, ", typeof(interp), ":\n", ir)
    ir = insert_fully_typed_check!(ir, interp, opt.linfo, caller)
    ipo_dataflow_analysis!(interp, opt, ir, caller)
    finishopt!(interp, opt, ir)
    tr && Core.println("TRACE after finishopt:\n", opt.src)
    return nothing
end
CC.activate_codegen!()   # the runtime infers in the latest world from here on
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
v = Callable{Tuple{Float64}, Bool}[x -> 1]
r = try passes(v, 2.0) catch e; e end
println("result: ", r isa Exception ? sprint(showerror, r) : repr(r))
