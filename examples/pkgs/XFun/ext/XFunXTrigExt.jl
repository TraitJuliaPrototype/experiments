# S9, the extension exception (design.md §3.2): an extension of a stakeholder (XFun owns `score`)
# whose method applies at a fact of compiled code (`score(::Float64)`) without mentioning its
# trigger's types. Loading the unrelated XTrig activates it.
module XFunXTrigExt
using XFun, XTrig
XFun.score(x::Float64) = 2.0 * x
end
