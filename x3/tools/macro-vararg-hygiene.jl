# Found in X3 slice 4 (E-226), a bug of Julia's own (stock 1.11.7, 1.12.3 and 1.13.2 alike; the patched build too):
# inside a macro's quote, hygiene writes `Vararg` as `Main.Vararg`, and the lowering of a method with keywords does not
# see a qualified `Vararg` as a vararg. So `f(fig, args::Vararg{Any, N}; kw...) where {N}` binds `args` to one tuple of
# the arguments. Without keywords, or with `Vararg` escaped, it is right. MakieCompat's `@recipe` escapes it.
#     julia experiments/x3/tools/macro-vararg-hygiene.jl   # prints Tuple{Tuple{...}}, then Tuple{...} twice
inner(args...) = typeof(args)
macro wrong(name)
    quote
        $(esc(name))(fig, args::Vararg{Any, N}; kw...) where {N} = inner(args...)
    end
end
macro right(name)
    V = esc(:Vararg)
    quote
        $(esc(name))(fig, args::$V{Any, N}; kw...) where {N} = inner(args...)
    end
end
macro nokw(name)
    quote
        $(esc(name))(fig, args::Vararg{Any, N}) where {N} = inner(args...)
    end
end
@wrong f1
@right f2
@nokw f3
println(f1(1, [1.0], [2.0]; a = 1))
println(f2(1, [1.0], [2.0]; a = 1))
println(f3(1, [1.0], [2.0]))
