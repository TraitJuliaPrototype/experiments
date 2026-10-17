# Recovery test (plan §3, next steps): BaseBenchmarks' raytrace and parse_json, each with the
# mitigations of the facts mode as source edits, timed in this process's mode.
#     JULIA_FACTS_COMPILER=0|1 julia --pkgimages=no --project=benv recovery/recovery.jl
using Compiler
Compiler.activate!(; reflection = true, codegen = true)
using BaseBenchmarks
const SRC = joinpath(pkgdir(BaseBenchmarks), "src", "problem")

function variant(file, name, edits)
    s = read(joinpath(SRC, file), String)
    for (a, b) in edits
        occursin(a, s) || error("$name: no `$a`")
        s = replace(s, a => b)
    end
    s = replace(s, r"^module \w+"m => "module $name")
    return include_string(Main, s)
end

rt_assert = ["i = intersect(j, i, ray)" => "i = intersect(j, i, ray)::Hit",
             "i = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), ray)" => "i = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), ray)::Hit",
             "si = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), sray)" => "si = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), sray)::Hit"]
rt_union = ["objs::Vector{Scene}" => "objs::Vector{Union{Sphere, Group}}",
            "Group(b, Scene[])" => "Group(b, Union{Sphere, Group}[])"]
RT = [("plain", variant("Raytracer.jl", :RTPlain, [])),
      ("assert", variant("Raytracer.jl", :RTAssert, rt_assert)),
      ("union", variant("Raytracer.jl", :RTUnion, rt_union))]

# parse_json: the values in containers of a concrete wrapper (the analogue of Dynamic{X})
js_wrap = ["module JSONParse" => "module JSONParse\nstruct JV; v::Any; end\nBase.hash(a::JV, h::UInt) = hash(a.v, h)\nBase.:(==)(a::JV, b::JV) = a.v == b.v\nBase.isequal(a::JV, b::JV) = isequal(a.v, b.v)",
           "object = Dict{AbstractString, Any}()" => "object = Dict{AbstractString, JV}()",
           "object[str] = val" => "object[str] = JV(val)",
           "object = Set()" => "object = Set{JV}()",
           "push!(object, val)" => "push!(object, JV(val))"]
# the standard fix for a captured, reassigned variable (julia#15276): a typed local
js_typed = ["    pos = 1\n" => "    local pos::Int = 1\n"]
JS = [("plain", variant("JSONParse.jl", :JSPlain, [])), ("wrap", variant("JSONParse.jl", :JSWrap, js_wrap)),
      ("typed", variant("JSONParse.jl", :JSTyped, js_typed)), ("both", variant("JSONParse.jl", :JSBoth, vcat(js_typed, js_wrap)))]
jstr = read(joinpath(SRC, "data", "test.json"), String)

best(f, n) = (f(); minimum(@elapsed(f()) for _ in 1:n))
mode = Compiler.FACTS_MODE[] ? "facts" : "plain"
for (v, M) in RT
    println(mode, " raytrace ", rpad(v, 7), round(best(() -> M.perf_raytrace(5, 256, 4), 5) * 1e3, digits = 1), " ms")
end
for (v, M) in JS
    println(mode, " json     ", rpad(v, 7), round(best(() -> M.perf_parse_json(jstr), 200) * 1e6, digits = 1), " µs")
end
