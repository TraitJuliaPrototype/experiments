# W-170 (E-538), open issue 264: does the ODE port's image hold ODECore's callback instances at a session's types
# (P = Vector{Float64}), which E-536 found compiled in the session? For each signature: the method instance, its code
# instances (in the image or not, valid in the current world, with machine code or inferred code only).
#     julia --project=<env> probe264.jl
using TraitWorld, TraitDifferentialEquations
const C = TraitDifferentialEquations.ODECore
const U, P = Vector{Float64}, Vector{Float64}
const SV = Dynamic{C.StepView{U,Float64}}
sigs = Any[
    Tuple{typeof(push!), Vector{C.StepCallback{U,Float64}}, C.ParamCallback{U,Float64,P}},
    Tuple{typeof(push!), Vector{C.StepEvent{U,Float64}}, C.ParamEvent{U,Float64,P}},
    Tuple{typeof(C.step_event_initialize!), C.ParamEvent{U,Float64,P}, U, Float64, SV},
    Tuple{typeof(C._sync_in!), C.ParamIntegrator{U,Float64,P}, SV},
    Tuple{typeof(C.adapt_callbacks!), C.ParamIntegrator{U,Float64,P}, C.EnteredCallbacks{U,Float64,P}},
]
inimg(x) = ccall(:jl_object_in_image, Cint, (Any,), x) != 0
w = Base.get_world_counter()
for sig in sigs
    mi = try Base.method_instance(sig) catch; nothing end    # does not create one
    mi === nothing && (mi = ccall(:jl_method_lookup_by_tt, Any, (Any, Csize_t, Any), sig, w, nothing))
    if !(mi isa Core.MethodInstance)
        println("R ", sig, " | no method instance"); continue
    end
    cis = String[]
    if isdefined(mi, :cache)
        ci = mi.cache
        while true
            push!(cis, string("CI in_image=", inimg(ci), " valid=", ci.min_world <= w <= ci.max_world, " world ", ci.min_world, "-",
                              ci.max_world == typemax(UInt) ? "∞" : ci.max_world, " invoke=", ci.invoke != C_NULL,
                              " inferred=", isdefined(ci, :inferred) && ci.inferred !== nothing))
            isdefined(ci, :next) || break
            ci = ci.next
        end
    end
    println("R ", sig, " | MI in_image=", inimg(mi), " | ", isempty(cis) ? "no code instance" : join(cis, "; "))
end
