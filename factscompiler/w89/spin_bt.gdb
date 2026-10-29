set pagination off
set confirm off
handle SIGSEGV nostop noprint pass
handle SIGUSR2 nostop noprint pass
handle SIGINT nostop noprint pass
set breakpoint pending on
break gf.c:3800
run
bt 12
frame 0
p *ci
p ci->def
p jl_(ci->def)
p jl_(ci->owner)
p ci->flags
p ci->invoke
p ci->specptr
p jl_(ci->rettype)
frame 1
info locals
p jl_(mi)
p jl_(owner)
p compile_option
kill
quit
