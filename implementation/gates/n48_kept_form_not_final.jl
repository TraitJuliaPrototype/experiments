# project: TraitWorld
# Gate (compiler §4.8, §6.9; E-543): the library declares each kept form a member of its set by a pattern bounded
# by the set (`Compiled{Z} where Z <: X`), so `Compiled{S} <: X` holds where `S <: X` does, and `Dynamic{Y} <: X`
# where `Y <: X`. Code compiled before `S` joins `X` must not keep `false`, and code compiled after it is taken back
# must not keep `true`. Found by the set-folds report's library mode. A candidate for `gates/`; fails on `next`
# 2ddbe12394.
#     julia --project=TraitWorld n48_kept_form_not_final.jl
using TraitWorld
@trait X48
@trait Y48
struct S48 end
qc() = Core.Compiled{S48} <: X48
qd() = Core.Dynamic{Y48} <: X48
@assert qc() === false && qd() === false
TraitWorld.@implement X48 S48
@assert qc() === true "Compiled{S} <: X compiled before the membership: $(qc())"
TraitWorld.delete_membership(X48, S48)
@assert qc() === false "taken back: $(qc())"
TraitWorld.@implement X48 Y48
@assert qd() === true "Dynamic{Y} <: X compiled before the membership: $(qd())"
println("n48_kept_form_not_final: OK")
