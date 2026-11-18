# W-157, the second batch (applied to julia-s3/base): Val(x) builds with new; IOContext stores a property
# through ImmutableDict's own constructor by invoke.
import sys
B = sys.argv[1]
def sub(p, old, new):
    s = open(p).read(); assert old in s, (p, old[:60]); open(p, 'w').write(s.replace(old, new))
sub(f'{B}/essentials.jl', '''struct Val{x}
end

Val(x) = Val{x}()''', '''struct Val{x}
    Val{x}() where {x} = new{x}()
    # built with `new`: a call of the constructor at `Val{x}` for a value `x` not known where `Val(x)` is
    # compiled is a call at a type no caller names, which a method for another `Val{y}` can intercept
    Val(x) = new{x}()
end''')
sub(f'{B}/show.jl', '''function IOContext{IO_t}(io::IO, KV::Pair, KVs::Pair...) where {IO_t}
    d = ImmutableDict{Symbol,Any}(ioproperties(io), KV[1], KV[2])
    for kv in KVs
        d = ImmutableDict{Symbol,Any}(d, kv[1], kv[2])
    end
    return IOContext{IO_t}(io, d)
end

function IOContext(io::IO, KV::Pair)
    d = ioproperties(io)
    return IOContext(io, ImmutableDict{Symbol,Any}(d, KV[1], KV[2]))
end''', '''# A property is stored by the dictionary's own constructor, through `invoke`: the value is kept whatever
# its type (often a type, `:typeinfo => T`), and a call at the value's type is one that a package's
# method for its own type could intercept.
function IOContext{IO_t}(io::IO, KV::Pair, KVs::Pair...) where {IO_t}
    d = invoke(ImmutableDict{Symbol,Any}, Tuple{ImmutableDict, Any, Any}, ioproperties(io), KV[1], KV[2])
    for kv in KVs
        d = invoke(ImmutableDict{Symbol,Any}, Tuple{ImmutableDict, Any, Any}, d, kv[1], kv[2])
    end
    return IOContext{IO_t}(io, d)
end

function IOContext(io::IO, KV::Pair)
    d = ioproperties(io)
    return IOContext(io, invoke(ImmutableDict{Symbol,Any}, Tuple{ImmutableDict, Any, Any}, d, KV[1], KV[2]))
end''')
print("applied")
