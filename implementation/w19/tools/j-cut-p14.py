import sys, subprocess; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
def git(*a): return subprocess.run(['git']+list(a),capture_output=True,text=True,check=True).stdout
B='98960887b3'
# boot.jl: no kept forms
P='base/boot.jl'
s=rd(P); i=s.index("\n# The kept forms: ordinary structs with no rule of subtyping."); j=s.index("# a call of a value known as `Callable{A, S}`: its arguments are of `A`", i)
s=s[:i]+"\n"+s[j:]; wr(P,s)
sub(P, "    # the box made by `new` with no conversion: its field test is the membership test\n    _new_dynamic(::Type{D}, @nospecialize(x)) where {D} = $(Expr(:new, :D, :x))\n", "")
# the Julia wrapper of jl_is_trait_arg_type: the closed build's
P='Compiler/src/abstractinterpretation.jl'
s=rd(P); i=s.index("is_trait_arg_type(@nospecialize(t)) = ccall(:jl_is_trait_arg_type"); k=s.rfind("\n",0,i-1)
line=s[k+1:i]; print(repr(line))
j=s.index("\n",i)+1
if s[j]=='\n': j+=1
s=s[:k+1]+s[j:] if line.startswith('#') else s[:i]+s[j:]
wr(P,s)
# C
sub('src/julia.h', "    uint8_t erases:1;         // a set of Core's build whose arguments are compiled once by default: `Callable`\n    uint8_t _unused:2;", "    uint8_t _unused:3;")
sub('src/datatype.c', "    tn->never_member = 0;\n    tn->erases = 0;\n", "    tn->never_member = 0;\n")
sub('src/jltypes.c', "        cb->name->erases = 1;\n", "")
sub('src/jl_exported_funcs.inc', "    XX(jl_is_trait_arg_type) \\\n", "")
open('/tmp/claude-harvest/w19f/base_gf.c','w').write(git('show',B+':src/gf.c'))
