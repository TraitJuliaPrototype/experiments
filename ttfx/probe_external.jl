# E-176: the methods a load adds to functions their package does not own (external methods), per package,
# against all methods it adds. julia --project=<env> probe_external.jl <package names...>
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function methods_by_root()
    ext = Dict{Module,Int}(); all_ = Dict{Module,Int}()
    Base.visit(_MT) do m
        r = Base.moduleroot(m.module)
        all_[r] = get(all_, r, 0) + 1
        sig = Base.unwrap_unionall(m.sig)
        sig isa DataType && !isempty(sig.parameters) || return
        F = sig.parameters[1]
        fr = F isa DataType ? Base.moduleroot(F.name.module) : r
        fr === r || (ext[r] = get(ext, r, 0) + 1)
    end
    ext, all_
end
e0, a0 = methods_by_root()
t = @elapsed for p in ARGS; @eval using $(Symbol(p)); end
e1, a1 = methods_by_root()
E = sum(values(e1)) - sum(values(e0)); A = sum(values(a1)) - sum(values(a0))
println("load ", round(t; digits = 2), " s; methods added ", A, ", of which external ", E)
rows = sort([(get(e1, k, 0) - get(e0, k, 0), get(a1, k, 0) - get(a0, k, 0), k) for k in keys(a1)]; by = x -> (x[1], x[2]), rev = true)
for (e, a, k) in rows[1:min(12, end)]; println("  ", rpad(string(k), 28), " external ", e, " of ", a); end
