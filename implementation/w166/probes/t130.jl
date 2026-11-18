# W-166, stage 1 (traits T-130, lowering L-67): a function of `Self` that an equation names answers through a kept
# form as for its object. At a plain member, a box and a wrapper: `eltype` at the value and at the type, a method
# that computes with `eltype(t)`, `zero(eltype(t))`, `keytype`/`valtype` of `Keyed`, a box of a subtrait, a box of
# an intersection of two traits whose equations name `eltype`.
#     (cd TraitWorld && $JN --project=. ../experiments/implementation/w166/probes/t130.jl)
using TraitWorld
v = [3.0, 1.0, 2.0]
forms = (("plain", v), ("box Iterable", Dynamic{Iterable{Float64}}(v)), ("box MutableIndexable", Dynamic{MutableIndexable{Float64}}(v)),
         ("wrapper", compiled_for(v)))
firstzero(t) = zero(eltype(t))                 # untyped: a box of MutableIndexable is no Iterable
newvec(t) = Vector{eltype(t)}(undef, 0)
for (name, x) in forms
    r = try
        (eltype = eltype(x), eltype_type = eltype(typeof(x)), zero = firstzero(x), vec = typeof(newvec(x)),
         inferred = Base.return_types(firstzero, (typeof(x),)))
    catch e
        sprint(showerror, e)[1:min(end, 200)]
    end
    println(rpad(name, 22), r)
end
dct = Dict("a" => 1)
for (name, x) in (("plain", dct), ("box Keyed", Dynamic{Keyed{String, Int}}(dct)), ("wrapper", compiled_for(dct)))
    r = try (keytype = keytype(x), valtype = valtype(x), keytype_type = keytype(typeof(x))) catch e; sprint(showerror, e)[1:min(end, 200)] end
    println(rpad(name, 22), r)
end
r = try eltype(Dynamic{All{Iterable{Float64}, Indexable{Float64}}}(v)) catch e; sprint(showerror, e)[1:min(end, 300)] end
println(rpad("box All{Iterable, Indexable}", 22), " ", r)
