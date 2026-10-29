# Experiment: set INVOKE_MATCHES_SPECPTR on each CodeInstance jl_read_codeinst_invoke spins on (an
# emulation of the fix for builtins), print which method it is, and count jl_code_for_interpreter calls.
set pagination off
set confirm off
handle SIGSEGV nostop noprint pass
handle SIGUSR2 nostop noprint pass
handle SIGINT nostop noprint pass
set breakpoint pending on
break gf.c:3800
commands
silent
printf "spin on: "
call (void)jl_(ci->def)
set var ci->flags = ci->flags | 2
continue
end
break jl_code_for_interpreter
commands
silent
continue
end
run
info breakpoints
quit
