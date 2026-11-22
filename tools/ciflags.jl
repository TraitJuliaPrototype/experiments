# W-168 (open issue 257): the runtime's code-instance flags, read through the runtime's own definitions, for the
# experiments' tools. `include` it, then `using .CIFlags`; it needs nothing but Julia.
#
#     ci_facts(ci)        a CodeInstance compiled by facts      (the runtime's accessor `Base.Compiler.ci_policy_facts`)
#     ci_g2(ci)           a CodeInstance that carries the G2 bit (deep G2, compiler §3.2)
#     code_instances(mi)  the CodeInstances of a MethodInstance, valid or not (its `cache` chain)
#     facts_of(x), g2_of(x)   x is a CodeInstance, or a MethodInstance (then: any of its CodeInstances, owner nothing)
#     entry_kind(x)       :facts, :g2facts, :plain or :none for an entry of an invalidation log (a MethodInstance on
#                         the head: its flags are in its CodeInstances, not in the entry)
#     facts_mask(), g2_mask()   the bits, read from the build's julia.h (`JL_CI_FLAGS_FACTS`, `JL_CI_FLAGS_G2`); 0x00
#                         where the build has none (vanilla)
#     selfcheck(; expect_facts)   the accessor and the header's bit agree on every CodeInstance of the loaded code
#                         that has one; with `expect_facts = true` there must be at least one facts CodeInstance
#     require_facts(n, what)      a tool that counts facts code calls this with its count: 0 fails the run
#
# Why not a constant in each tool: a tool that holds `0x20` itself breaks silently when the layout moves, and a
# tool that reads the flag from a log entry breaks silently when the entry's type is not the one it expects
# (open issue 257: `w134/cause.jl` read the flag of CodeInstances, and the log holds MethodInstances).
module CIFlags
export ci_facts, ci_g2, code_instances, facts_of, g2_of, entry_kind, facts_mask, g2_mask, selfcheck, require_facts

function _header_mask(name::String)
    h = joinpath(Sys.BINDIR, Base.INCLUDEDIR, "julia", "julia.h")
    isfile(h) || return nothing
    for l in eachline(h)
        m = match(Regex("^#define\\s+" * name * "\\s+0b([01]+)"), l)
        m === nothing || return parse(UInt8, m.captures[1]; base = 2)
    end
    return nothing
end
const _FACTS = Ref{Union{Nothing,UInt8}}(nothing); const _G2 = Ref{Union{Nothing,UInt8}}(nothing)
const _READ = Ref(false)
function _read!()
    _READ[] && return
    _FACTS[] = _header_mask("JL_CI_FLAGS_FACTS"); _G2[] = _header_mask("JL_CI_FLAGS_G2"); _READ[] = true
end
facts_mask() = (_read!(); something(_FACTS[], 0x00))
g2_mask() = (_read!(); something(_G2[], 0x00))

_flags(ci::Core.CodeInstance) = getfield(ci, :flags, :monotonic)::UInt8
const _ACCESSOR = Ref{Any}(nothing)
function _accessor()
    _ACCESSOR[] === nothing || return _ACCESSOR[]
    C = isdefined(Base, :Compiler) ? Base.Compiler : nothing
    _ACCESSOR[] = C !== nothing && isdefined(C, :ci_policy_facts) ? getfield(C, :ci_policy_facts) : false
end
"A CodeInstance compiled by facts: the runtime's accessor where the build has it, else the header's bit."
ci_facts(ci::Core.CodeInstance) = (a = _accessor(); a === false ? (_flags(ci) & facts_mask()) != 0x00 : a(ci)::Bool)
"A CodeInstance with the G2 bit (the runtime has no accessor: the header's bit, which the compiler's own code tests)."
ci_g2(ci::Core.CodeInstance) = (_flags(ci) & g2_mask()) != 0x00

"The CodeInstances of `mi`, newest first, valid or invalidated."
function code_instances(mi::Core.MethodInstance)
    out = Core.CodeInstance[]
    isdefined(mi, :cache) || return out
    ci = mi.cache
    while true
        push!(out, ci)
        isdefined(ci, :next) || break
        ci = ci.next
    end
    return out
end
facts_of(ci::Core.CodeInstance) = ci_facts(ci)
facts_of(mi::Core.MethodInstance) = any(ci -> ci.owner === nothing && ci_facts(ci), code_instances(mi))
g2_of(ci::Core.CodeInstance) = ci_g2(ci)
g2_of(mi::Core.MethodInstance) = any(ci -> ci.owner === nothing && ci_g2(ci), code_instances(mi))
facts_of(x) = false
g2_of(x) = false

"`:g2facts`, `:facts`, `:plain`, or `:none` (no code at all, or not an instance) for a log entry or an instance."
function entry_kind(x)
    x isa Core.CodeInstance || x isa Core.MethodInstance || return :none
    x isa Core.MethodInstance && isempty(code_instances(x)) && return :none
    return facts_of(x) ? (g2_of(x) ? :g2facts : :facts) : :plain
end

"""
The accessor and the header's bit agree on every CodeInstance reachable from the methods of the loaded modules
(`n` of them are looked at); `expect_facts` additionally requires one facts CodeInstance. Returns
`(checked, facts, g2)`; throws where they disagree.
"""
function selfcheck(; expect_facts::Bool = false, limit::Int = 200_000)
    n = nf = ng = 0
    mask = facts_mask()
    Base.visit(Core.methodtable) do m
        n >= limit && return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            for ci in code_instances(mi)
                n += 1
                f = ci_facts(ci); nf += f; ng += ci_g2(ci)
                (_accessor() === false || mask == 0x00 || f == ((_flags(ci) & mask) != 0x00)) ||
                    error("CIFlags: the runtime's accessor and the header's bit disagree on a CodeInstance of ", mi.specTypes)
            end
        end
    end
    expect_facts && nf == 0 && error("CIFlags: no CodeInstance compiled by facts among $n: the flag is not read right, or nothing is compiled by facts")
    return (checked = n, facts = nf, g2 = ng)
end

"A tool that counts facts code: a count of 0 where the code is compiled by facts means the tool reads the wrong thing."
require_facts(n::Integer, what::AbstractString) =
    n > 0 || error("CIFlags: 0 facts instances among ", what, ": the flag is not read right (open issue 257)")
end # module
