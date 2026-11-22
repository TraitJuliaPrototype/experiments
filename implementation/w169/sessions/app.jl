# W-169: a demonstrator's program as a session runs it (E-521's w120/session_marks.jl): the program's file (which
# loads its packages; its check stays behind `invokelatest` with VERIFY=0), the first run of `main`, a second.
# W169_APP: the program's file; W169_ARGS: its arguments, separated by spaces.
const APP = ENV["W169_APP"]
const APPARGS = String[String(a) for a in split(get(ENV, "W169_ARGS", ""))]
#@ load
include(APP)
#@ first run
Base.invokelatest(main, APPARGS)
#@ second run
Base.invokelatest(main, APPARGS)
