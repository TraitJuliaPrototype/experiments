# W-150: a REPL session driven through Julia's own fake terminal (the REPL's test helper), so that the transcript is
# what the key prints. Two sessions:
#   1. the key installed before the REPL starts (the `atreplinit` path of startup.jl), on the tutorial's Shape;
#   2. the key installed into a running REPL, on the demonstrators' types: a TraitTables column, an ODE problem, a
#      TraitMakie figure and one of its plots.
# Run from this directory (README.md): julia --project=env repl_session.jl [1|2]
using REPL, TraitWorld
println("TraitWorld: ", pathof(TraitWorld))
include(joinpath(Sys.BINDIR, "..", "share", "julia", "stdlib", "v$(VERSION.major).$(VERSION.minor)", "REPL", "test",
                 "FakeTerminals.jl"))
import .FakeTerminals: FakeTerminal

const KEY = "\eo"              # Alt-o
const CLEAR = "\x15"           # ^U: the line being edited is killed, so that the next input starts empty

# Each item: a line typed and entered, or (word, :key): the word typed, Alt-o pressed, the line cleared.
function session(items; install_before::Bool)
    input = Pipe(); output = Pipe(); err = Pipe()
    for p in (input, output, err)
        Base.link_pipe!(p, reader_supports_async = true, writer_supports_async = true)
    end
    term = FakeTerminal(input.out, output.in, err.in, false)
    repl = REPL.LineEditREPL(term, false)
    repl.options = REPL.Options(confirm_exit = false, style_input = false, auto_insert_closing_bracket = false,
                                hascolor = false)
    global REPL_UNDER_TEST = repl
    install_before && TraitWorld.install_operations_key!(repl)      # as `atreplinit` runs it, before the interface
    buf = IOBuffer()
    reader = @async write(buf, output.out)
    errbuf = IOBuffer()
    ereader = @async write(errbuf, err.out)
    t = @async REPL.run_repl(repl)
    for it in items
        if it isa Tuple
            write(input.in, it[1], KEY, CLEAR)
        else
            write(input.in, it, "\n")
        end
    end
    write(input.in, "\x04")                                          # ^D at an empty prompt: the REPL ends
    wait(t)
    close(input.in); close(output.in); close(err.in)
    wait(reader); wait(ereader)
    return String(take!(buf)), String(take!(errbuf))
end

# The terminal's output as a reader sees it: a small screen that follows the REPL's moves (carriage return, cursor
# right and up, erase to the end of the line); each prompt's line as it was left
function plain(s::String)
    lines = [Char[]]
    row, col = 1, 0
    i = firstindex(s)
    while i <= lastindex(s)
        c = s[i]
        if c == '\e'
            m = match(r"^\e\[(\??)([0-9;]*)([A-Za-z])", SubString(s, i))
            if m !== nothing
                n = isempty(m.captures[2]) ? 1 : parse(Int, split(m.captures[2], ';')[1])
                k = m.captures[3]
                if isempty(m.captures[1])
                    k == "C" && (col += n)
                    k == "D" && (col = max(0, col - n))
                    k == "A" && (row = max(1, row - n))
                    k == "B" && (row += n; while length(lines) < row; push!(lines, Char[]); end)
                    k == "K" && (resize!(lines[row], min(length(lines[row]), col)))
                end
                i += ncodeunits(m.match)
                continue
            end
        elseif c == '\r'
            col = 0
        elseif c == '\n'
            row += 1; col = 0
            while length(lines) < row; push!(lines, Char[]); end
        else
            l = lines[row]
            while length(l) < col; push!(l, ' '); end
            col < length(l) ? (l[col + 1] = c) : push!(l, c)
            col += 1
        end
        i = nextind(s, i)
    end
    out = String[]
    for l in lines
        t = rstrip(String(l))
        (t == "julia>" && !isempty(out) && out[end] == "") && continue      # an empty prompt redrawn
        push!(out, t)
    end
    return join(out, '\n')
end

const which = isempty(ARGS) ? "1" : ARGS[1]

if which == "1"
    # the tutorial's library and member (traits-by-example §2–§4), defined before the session; the session types one line
    # at a time
    setup = quote
        module Geometry
        using TraitWorld
        export Shape, area, perimeter, describe, ratio, bigger, title
        @trait Shape begin
            "The area of the shape."
            area(s::Shape)::Float64
            perimeter(s::Shape)::Float64
            describe(s::Shape)::String = "a shape of area $(area(s))"
        end
        ratio(s::Shape) = area(s) / perimeter(s)
        bigger(a::Shape, b::Shape) = area(a) > area(b)
        title(s::Shape) = uppercasefirst(describe(s))
        end
        using .Geometry
    end
    Core.eval(Main, Expr(:toplevel, setup.args...))
    out, errs = session(Any[
        "struct Circle; r::Float64; end",
        "Geometry.area(c::Circle) = π * c.r^2",
        "Geometry.perimeter(c::Circle) = 2π * c.r",
        "@implement Shape Circle",
        "c = Circle(1.0)",
        ("c", :key),
        ("Shape", :key),
        "d = Dynamic{Shape}(c);",
        ("d", :key),
        ("x = 1.5", :key),                 # the word under the cursor is `1.5`: no name
        "x = 1.5;",
        ("x", :key),
    ]; install_before = true)
else
    out, errs = session(Any[
        "using TraitTables, TraitDifferentialEquations, TraitMakie",
        "t = TraitTables.table(\"x\" => [1.0, 2.0, 3.0], \"n\" => [1, 2, 3]);",
        "col = t[\"x\"];",
        "TraitWorld.install_operations_key!(REPL_UNDER_TEST)",          # into the running REPL
        ("col", :key),
        "f(du, u, p, t) = (du .= -p .* u; nothing)",
        "prob = ODEProblem(f, [1.0, 2.0], (0.0, 1.0), 0.5);",
        ("prob", :key),
        "fig = Figure(size = (400, 300));",
        ("fig", :key),
        "fl = lines([1.0, 2.0, 3.0], [1.0, 4.0, 9.0]);",
        "pl = fl.axes[1].plots[1];",          # an axis keeps its plots boxed, Dynamic{Plot}
        ("pl", :key),
        ("ODEProblemTrait", :key),
    ]; install_before = false)
end
get(ENV, "W150_RAW", "") == "1" && (println(repr(out)); exit())
println(plain(out))
isempty(errs) || println("STDERR:\n", errs)
