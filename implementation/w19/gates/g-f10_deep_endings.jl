# Gate for the facts series' F10 (declares no trait): what a definition ends of the deep class. Switched on
# (`jl_set_deep_endings(1)`), the runtime keeps, for each method definition and deletion that ends code
# compiled by facts and deep G2, the kind, the cause (the method) and the CodeInstance ended; a tool takes
# the list (`jl_take_deep_endings`). Plain code, and code outside the class, are not kept; switched off,
# nothing is. (The third kind, :validation, needs a package image: not covered here.)
#     julia --startup-file=no g-f10_deep_endings.jl
const G2 = 0x10; const FACTS = 0x20
take() = (r = ccall(:jl_take_deep_endings, Any, ()); r === nothing ? Any[] : r)
cis_of(f, T) = (mi = Base.method_instance(f, T); out = Core.CodeInstance[]; ci = mi.cache;
                while true; ci.owner === nothing && push!(out, ci); isdefined(ci, :next) || break; ci = ci.next; end; out)

module FM
Base.Experimental.@compiler_options facts=true
g(x::Int) = 1
f(x::Int) = g(x) + 1
h(x::Int) = g(x) + 2
end
plain_g(x::Int) = 1
plain_f(x::Int) = plain_g(x) + 1

@assert FM.f(1) == 2 && FM.h(1) == 3 && plain_f(1) == 2
ci_f = only(cis_of(FM.f, (Int,)))
@assert ci_f.flags & (G2 | FACTS) == G2 | FACTS "f's code is facts code in the deep class"
@assert ccall(:jl_set_deep_endings, Cint, (Cint,), 1) == 0

# a definition that replaces g(::Int) ends f's and h's code: kind :definition, the cause the new method
@eval FM g(x::Int) = 10
list = take()
@assert length(list) >= 6 && length(list) % 3 == 0
kinds = list[1:3:end]; causes = list[2:3:end]; ended = list[3:3:end]
@assert all(==(:definition), kinds)
newg = which(FM.g, (Int,))
@assert all(c -> c === newg, causes)
@assert ci_f in ended
@assert all(ci -> ci.flags & (G2 | FACTS) == G2 | FACTS, ended)
@assert FM.f(1) == 11 && FM.h(1) == 12

# plain code that a definition ends is not kept
@eval plain_g(x::Int) = 5
@assert isempty(take()) && plain_f(1) == 6

# a deletion: kind :deletion, the cause the method deleted
@eval FM g(x::Integer) = 20
take()
@assert FM.f(1) == 11
Base.delete_method(which(FM.g, (Int,)))
list = take()
@assert !isempty(list) && all(==(:deletion), list[1:3:end]) && all(c -> c === newg, list[2:3:end])
@assert FM.f(1) == FM.g(1) + 1   # the method the deleted one replaced, or g(::Integer)

# switched off: nothing is kept
@assert ccall(:jl_set_deep_endings, Cint, (Cint,), 0) == 1
@eval FM g(x::Int) = 30
@assert isempty(take()) && FM.f(1) == 31
println("g-f10_deep_endings: OK")
