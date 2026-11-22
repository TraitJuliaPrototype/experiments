import sys; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
sub('Compiler/src/ssair/inlining.jl', '''    # an operation's split: never fully covered, its branches asserted; a `Callable`'s (a closed
    # build's) checked as the box's call checks
    fallback_rt = split ? info.rt : nothing
    kind = split && callable_set_type(widenconst(sig.ft)) ? IR_FLAG_TRUSTED_CALLABLE : UInt32(0)
    # (a closed build's split with no branch, a set with no member: the `MethodError` below)
''', '''    # an operation's split: never fully covered, its branches asserted
    fallback_rt = split ? info.rt : nothing
    kind = UInt32(0)
''')
