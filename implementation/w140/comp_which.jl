# W-140: which instance a later member's load ends in E-358's composition (trait packages).
#   JULIA_LOAD_PATH=<w134/comp/pkgs/trait>:<w134/env_lib>:@stdlib julia comp_which.jl
const C = Base.require(Main, :CompCore)
const v = Base.invokelatest(() -> C.Shape[])
const mods = Module[]
work() = (t = C.work(v); for m in mods; t += m.own(m.make(), 3); end; t)
function add(name)
    m = Base.require(Main, name); push!(mods, m)
    Base.invokelatest(push!, v, Base.invokelatest(m.make)); Base.invokelatest(work)
end
add(:CompM01); add(:CompM02)
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
add(:CompM03)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
for x in log
    println(x isa Core.CodeInstance ? "  CI  $(x.def) [$(x.min_world), $(x.max_world == typemax(UInt) ? "∞" : x.max_world)]" : "  $(typeof(x).name.name)  $x")
end
