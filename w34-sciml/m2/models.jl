# E-158: the models and callbacks of checks 1–5, as a user writes them (plain code). The callbacks
# are made by functions that take the library's `add_tstop!`/`terminate!`, so TDE and the control
# (PlainODE) run the same closures' bodies.

"The oscillator's parameters: mutable, so that a callback's write to `integ.p` reaches the solve."
mutable struct OscParams
    k::Float64
    c::Float64
    tk::Float64          # the next kick
end
osc!(du, u, p, t) = (du[1] = u[2]; du[2] = -p.k * u[1] - p.c * u[2]; nothing)
oscp() = OscParams(4.0, 0.1, 1.0)

"""
Three discrete callbacks: a kick at `p.tk` (the first one at the first step past it, the next ones
exactly, by `add_tstop!`); a damping change at t ≥ 4 (writes `p.c`); a stop at t ≥ 8.5 (`terminate!`).
Each logs `(name, t, u)` when it acts.
"""
function discrete_set(add_tstop!, terminate!, log)
    kick_c = (u, t, i) -> t >= i.p.tk
    kick_a = i -> (push!(log, (:kick, i.t, copy(i.u))); i.u[2] += 1.0; i.p.tk += 1.0; add_tstop!(i, i.p.tk); nothing)
    damp_c = (u, t, i) -> t >= 4.0 && i.p.c < 0.5
    damp_a = i -> (push!(log, (:damp, i.t, copy(i.u))); i.p.c = 0.5; nothing)
    stop_c = (u, t, i) -> t >= 8.5
    stop_a = i -> (push!(log, (:stop, i.t, copy(i.u))); terminate!(i); nothing)
    return ((kick_c, kick_a), (damp_c, damp_a), (stop_c, stop_a))
end

"The bouncing ball's parameters: gravity and the restitution, which a discrete callback lowers."
mutable struct BallParams
    g::Float64
    e::Float64
end
ball!(du, u, p, t) = (du[1] = u[2]; du[2] = -p.g; nothing)
ballp() = BallParams(9.81, 0.9)

"""
Two continuous callbacks (the ground: `u[1]`, the velocity reversed and scaled by `p.e`; the apex:
`u[2]`, logged only) and one discrete (from t ≥ 3, `p.e = 0.5`).
"""
function event_set(log)
    ground_c = (u, t, i) -> u[1]
    ground_a = i -> (push!(log, (:ground, i.t, copy(i.u))); i.u[2] = -i.p.e * i.u[2]; nothing)
    apex_c = (u, t, i) -> u[2]
    apex_a = i -> (push!(log, (:apex, i.t, copy(i.u))); nothing)
    soft_c = (u, t, i) -> t >= 3.0 && i.p.e > 0.5
    soft_a = i -> (push!(log, (:soft, i.t, copy(i.u))); i.p.e = 0.5; nothing)
    return ((ground_c, ground_a), (apex_c, apex_a)), ((soft_c, soft_a),)
end
