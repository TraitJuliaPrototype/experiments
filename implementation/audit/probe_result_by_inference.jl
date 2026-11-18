# Open issue 171 (the documentation review of 2026-11-09, H4): at a value typed by a closed type with a contract
# (`IO`), does an operation's result depend on what inference knows? Plain code only; no trait module, no TraitWorld.
# Run it twice, as is and with `--compile=min` (the interpreter): on vanilla Julia every line prints what the
# stream's own method returns.
struct S <: IO end
Base.write(::S, ::UInt8) = UInt(7)          # a count of another integer type, as Core's streams and Filesystem.File
struct R <: IO end
Base.write(::R, ::UInt8) = "seven"          # a result that does not convert to the declared Int
direct(s) = write(s, 0x01)                  # the stream's type known
viaIO(v::Vector{IO}) = write(v[1], 0x01)    # a value typed IO: the split, the declared result
viaAny(v::Vector{Any}) = write(v[1], 0x01)  # a value typed Any: a dynamic call
show1(label, f) = println(rpad(label, 28), try r = f(); "$(typeof(r)) $(repr(r))" catch e; "raises $(typeof(e))" end)
show1("UInt count, the type known", () -> direct(S()))
show1("UInt count, through IO", () -> viaIO(IO[S()]))
show1("UInt count, through Any", () -> viaAny(Any[S()]))
show1("String, the type known", () -> direct(R()))
show1("String, through IO", () -> viaIO(IO[R()]))
show1("String, through Any", () -> viaAny(Any[R()]))
