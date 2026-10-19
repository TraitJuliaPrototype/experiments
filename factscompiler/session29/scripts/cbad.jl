using TraitWorld
@trait_module module T2
using TraitWorld
@trait Col begin
    cv(c::Col)::Vector{Float64}
end
@implement Col Vector{Float64} begin cv(c) = c end
SCALE = 2.0
c_bad(c::Col) = (s = 0.0; for x in cv(c); s += SCALE * x; end; s)
end
T2.c_bad([1.0])
w = only(m for m in methods(T2.c_bad) if !TraitWorld._is_entry(m))
sig = Base.unwrap_unionall(w.sig)
src = only(code_typed(T2.c_bad, ([1.0] |> typeof,)))[1]
for (i, st) in enumerate(src.code); s = sprint(show, st); (occursin("SCALE", s) || occursin("getglobal", s)) && println(i, ": ", s); end
