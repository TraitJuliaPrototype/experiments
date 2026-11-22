# W-167 (open issue 255): the memberships a port's load activates, by whether the member's type is new with the load
# (its type's module is a module the load brought) or was in the session before (Base's, the library's, a dependency
# loaded earlier). A membership of a new type can end no code compiled before the load (facts §2.2, "What invalidates
# nothing"); the walk still lowers the dispatch caches.        julia --project=<env> memb_count.jl <Pkg>...
using TraitWorld
before = Set{Module}(Base.moduleroot(m) for m in values(Base.loaded_modules))
n0 = Int(ccall(:jl_activated_memberships_count, Csize_t, ()))
for p in ARGS; @eval using $(Symbol(p)); end
list = ccall(:jl_activated_memberships, Any, ())::Core.SimpleVector
typemod(@nospecialize(T)) = (u = Base.unwrap_unionall(T); u isa DataType ? Base.moduleroot(u.name.module) : nothing)
new = 0; old = 0; byroot = Dict{Any,Int}()
for i in n0+1:length(list)
    S = getfield(list[i], :member); r = typemod(S)
    byroot[r] = get(byroot, r, 0) + 1
    (r !== nothing && !(r in before)) ? (global new += 1) : (global old += 1)
end
println("MEMBERSHIPS activated by ", join(ARGS, "+"), ": ", length(list) - n0, " | member's type new with the load ", new, " | in the session before ", old)
for (k, v) in sort(collect(byroot); by = last, rev = true); println("    ", v, " ", k); end
