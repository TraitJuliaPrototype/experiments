# W-143e: the library's test files one by one, each in a module of its own as runtests.jl does, a failure not stopping
# the rest; one line per file.     julia --project=TraitWorld traitworld_each.jl
using Test
const D = joinpath(dirname(Base.active_project()), "test")
files = ("overview.jl", "core.jl", "acceptance.jl", "trait_modules.jl", "callable.jl", "fullytyped.jl", "ownership.jl", "hints.jl", "verify.jl", "basetraits.jl", "strict.jl", "strict_membership.jl", "report.jl", "owner_only.jl", "delete.jl", "recheck.jl", "declared.jl", "messages.jl", "storage.jl", "build.jl", "bytype.jl", "trusted.jl", "operations.jl")
res = String[]
for f in files
    r = try
        redirect_stdout(devnull) do; Base.include(Module(Symbol(splitext(f)[1])), joinpath(D, f)); end
        "pass"
    catch e
        "FAIL: " * first(sprint(showerror, e), 200)
    end
    push!(res, "$f: $r"); println(res[end])
end
