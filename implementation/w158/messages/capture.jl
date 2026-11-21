# Included before a script whose error messages are to be collected (README.md). Every message the script computes
# with `sprint(showerror, e)`, which the library's tests and the documentation's examples use for each message they
# check, and every log record that reaches the global logger, is written to the file `$MSG_OUT` at exit: one record
# per line, `<source>\t<kind>\t<message, escaped>`. The source is the first frame of the calling script.
# This file pirates `Base.sprint` at `showerror` in the process it runs in; it is a tool, not a library.

const _MSG_RECORDS = Tuple{String,String,String}[]
const _MSG_SCRIPT_DIRS = filter(!isempty, split(get(ENV, "MSG_SOURCES", ""), ':'))

function _msg_source()
    for fr in stacktrace()
        f = string(fr.file)
        endswith(f, "capture.jl") && continue
        any(d -> startswith(f, d), _MSG_SCRIPT_DIRS) && return string(basename(f), ":", fr.line)
    end
    return "?"
end

function Base.sprint(f::typeof(showerror), args...; kw...)
    s = invoke(Base.sprint, Tuple{Function, Vararg{Any}}, f, args...; kw...)
    e = isempty(args) ? nothing : args[1]
    push!(_MSG_RECORDS, (_msg_source(), string(nameof(typeof(e))), s))
    return s
end

struct _MsgLogger <: Base.CoreLogging.AbstractLogger
    next::Base.CoreLogging.AbstractLogger
end
Base.CoreLogging.min_enabled_level(l::_MsgLogger) = Base.CoreLogging.min_enabled_level(l.next)
Base.CoreLogging.shouldlog(l::_MsgLogger, args...) = true
Base.CoreLogging.catch_exceptions(::_MsgLogger) = true
function Base.CoreLogging.handle_message(l::_MsgLogger, level, message, _module, group, id, file, line; kw...)
    level >= Base.CoreLogging.Warn &&
        push!(_MSG_RECORDS, (string(basename(string(file)), ":", line), string("log ", level), string(message)))
    Base.CoreLogging.shouldlog(l.next, level, _module, group, id) &&
        Base.CoreLogging.handle_message(l.next, level, message, _module, group, id, file, line; kw...)
end
Base.CoreLogging.global_logger(_MsgLogger(Base.CoreLogging.global_logger()))

atexit() do
    out = get(ENV, "MSG_OUT", "")
    isempty(out) && return
    open(out, "a") do io
        for (src, kind, msg) in _MSG_RECORDS
            println(io, src, '\t', kind, '\t', escape_string(msg))
        end
    end
end
