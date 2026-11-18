# E-363: a message measured as E-5 measured it: with its stack trace, in full and as the REPL limits
# it (types in frames shortened); lines, bytes, frames, the longest line. Both texts are written to
# logs/<form>-<tag>_{full,limited}.txt.
function report(form, tag, f)
    e, bt = try
        f(); (nothing, nothing)
    catch err
        (err, catch_backtrace())
    end
    e === nothing && (println("$form | $tag | no error"); return)
    full = sprint(io -> showerror(IOContext(io, :limit => false), e, bt))
    lim = sprint(io -> showerror(IOContext(io, :stacktrace_types_limited => Ref(false), :displaysize => (50, 120)), e, bt))
    head = first(split(sprint(showerror, e), '\n'))
    for (name, s) in (("limited", lim), ("full", full))
        ls = split(s, '\n')
        frames = [i for i in eachindex(ls) if occursin(r"^\s*\[\d+\]", ls[i])]
        msg = isempty(frames) ? length(ls) : findfirst(l -> startswith(l, "Stacktrace:"), ls) - 1
        println("$form | $tag | $name | lines $(length(ls)) | message lines $msg | bytes $(sizeof(s)) | frames $(length(frames)) | longest line $(maximum(length, ls))")
        write(joinpath(@__DIR__, "logs", "$form-$(tag)_$name.txt"), s)
    end
    println("$form | $tag | first line | ", first(head, 200))
end
