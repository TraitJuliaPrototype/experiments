# W-142 (compiler C-86): a trait with a member at an abstract type; a value known only by the trait.
using TraitWorld
@trait Sized begin
    size_of(s::Sized)::Int
end
abstract type Animal end
struct Dog <: Animal; w::Int; end
struct Cat <: Animal; w::Int; end
size_of(a::Dog) = a.w
size_of(a::Cat) = a.w + 1
@implement Sized Animal
function (@main)(args::Vector{String})::Cint
    xs = Sized[Dog(3), Cat(4)]
    t = 0
    for x in xs
        t += size_of(x)
    end
    println(Core.stdout, t)
    return 0
end
