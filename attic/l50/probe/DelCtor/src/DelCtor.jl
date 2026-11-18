module DelCtor
struct S; w::Int; end
struct P{T}; w::T; end
struct K
    w::Int
    K(x; k = 1) = new(length(x) * k)
end
for (T, sig) in ((S, Tuple{Type{S},Any}), (P, Tuple{Type{P},Any}), (K, Tuple{Type{K},Any}))
    m = Base._methods_by_ftype(sig, -1, Base.get_world_counter())
end
const MS = which(S, Tuple{Any}); Base.delete_method(MS)
const MP = which(P, Tuple{Any}); Base.delete_method(MP)
const MK = which(K, Tuple{Any}); Base.delete_method(MK)
const MKK = which(Core.kwcall, Tuple{NamedTuple, Type{K}, Any}); Base.delete_method(MKK)
S(::Nothing, x) = invoke(S, MS, x)
P(::Nothing, x) = invoke(P, MP, x)
K(::Nothing, x) = invoke(K, MK, x)
Core.kwcall(nt::NamedTuple, ::Type{K}, ::Nothing, x) = invoke(Core.kwcall, MKK, nt, K, x)
S(@nospecialize(x)) = S(nothing, x)
P(@nospecialize(x)) = P(nothing, x)
K(@nospecialize(x)) = K(nothing, x)
Core.kwcall(@nospecialize(nt::NamedTuple), ::Type{K}, @nospecialize(x)) = Core.kwcall(nt, K, nothing, x)
f() = (S(2.0), P(1), K([1,2]), K([1,2]; k = 3))
precompile(f, ())
end
