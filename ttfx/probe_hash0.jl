# Specializations whose signature type has no hash (hash 0): their lookup and insertion scan a method's whole list.
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function census()
    z = 0; t = 0; zm = Dict{String,Int}()
    Base.visit(_MT) do m
        for mi in Base.specializations(m)
            t += 1
            ut = Base.unwrap_unionall(mi.specTypes)
            if ut isa DataType && ut.hash == 0
                z += 1; k = string(m.module, ".", m.name); zm[k] = get(zm, k, 0) + 1
            end
        end
    end
    z, t, zm
end
z0, t0, _ = census()
@eval using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie
z1, t1, zm = census()
println("specializations ", t0, " -> ", t1, "; with no hash ", z0, " -> ", z1)
for (k, n) in sort(collect(zm); by = last, rev = true)[1:8]; println("  ", n, "  ", k); end
