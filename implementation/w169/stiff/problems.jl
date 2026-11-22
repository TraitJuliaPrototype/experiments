# E-537: the problems, written once. Each stack's program includes this file, so the right-hand sides, the initial
# states, the parameters and the callbacks' functions are the same text on every stack. In place, on a flat
# `Vector{Float64}` (the port's Rodas5 takes `Vector{Float64}` states).

# --- the 2-D Brusselator (SciMLBenchmarks' form, periodic boundaries), BN x BN grid, 2 BN^2 states ---------------
const BN = parse(Int, get(ENV, "BRUSS_N", "16"))
const BX = collect(range(0.0, 1.0; length = BN))
@inline blim(a) = a == BN + 1 ? 1 : a == 0 ? BN : a
@inline bidx(i, j, k) = i + (j - 1) * BN + (k - 1) * BN * BN
bforce(x, y, t) = (((x - 0.3)^2 + (y - 0.6)^2) <= 0.1^2) * (t >= 1.1) * 5.0
function bruss!(du, u, p, t)
    A, B, alpha, dx = p
    a = alpha / dx^2
    @inbounds for j in 1:BN, i in 1:BN
        x, y = BX[i], BX[j]
        ip1, im1, jp1, jm1 = blim(i + 1), blim(i - 1), blim(j + 1), blim(j - 1)
        u1 = u[bidx(i, j, 1)]
        u2 = u[bidx(i, j, 2)]
        du[bidx(i, j, 1)] = a * (u[bidx(im1, j, 1)] + u[bidx(ip1, j, 1)] + u[bidx(i, jp1, 1)] + u[bidx(i, jm1, 1)] - 4u1) +
                            B + u1^2 * u2 - (A + 1) * u1 + bforce(x, y, t)
        du[bidx(i, j, 2)] = a * (u[bidx(im1, j, 2)] + u[bidx(ip1, j, 2)] + u[bidx(i, jp1, 2)] + u[bidx(i, jm1, 2)] - 4u2) +
                            A * u1 - u1^2 * u2
    end
    nothing
end
function bruss_u0()
    u = zeros(2 * BN * BN)
    for j in 1:BN, i in 1:BN
        x, y = BX[i], BX[j]
        u[bidx(i, j, 1)] = 22 * (y * (1 - y))^(3 / 2)
        u[bidx(i, j, 2)] = 27 * (x * (1 - x))^(3 / 2)
    end
    return u
end
const BRUSS_P = (3.4, 1.0, 10.0, 1.0 / (BN - 1))
const BRUSS_TSPAN = (0.0, 11.5)

# --- POLLU, the air pollution model (Verwer 1994; the IVP test set's form): 20 species, 25 reactions ------------
const PK = (0.35, 26.6, 1.23e4, 8.6e-4, 8.2e-4, 1.5e4, 1.3e-4, 2.4e4, 1.65e4, 9.0e3, 2.2e-2, 1.2e4, 1.88,
            1.63e4, 4.8e6, 3.5e-4, 1.75e-2, 1.0e8, 4.44e11, 1.24e3, 2.1, 5.78, 4.74e-2, 1.78e3, 3.12)
function pollu!(dy, y, k, t)
    r1 = k[1] * y[1];           r2 = k[2] * y[2] * y[4];     r3 = k[3] * y[5] * y[2]
    r4 = k[4] * y[7];           r5 = k[5] * y[7];            r6 = k[6] * y[7] * y[6]
    r7 = k[7] * y[9];           r8 = k[8] * y[9] * y[6];     r9 = k[9] * y[11] * y[2]
    r10 = k[10] * y[11] * y[1]; r11 = k[11] * y[13];         r12 = k[12] * y[10] * y[2]
    r13 = k[13] * y[14];        r14 = k[14] * y[1] * y[6];   r15 = k[15] * y[3]
    r16 = k[16] * y[4];         r17 = k[17] * y[4];          r18 = k[18] * y[16]
    r19 = k[19] * y[16];        r20 = k[20] * y[17] * y[6];  r21 = k[21] * y[19]
    r22 = k[22] * y[19];        r23 = k[23] * y[1] * y[4];   r24 = k[24] * y[19] * y[1]
    r25 = k[25] * y[20]
    dy[1] = -r1 - r10 - r14 - r23 - r24 + r2 + r3 + r9 + r11 + r12 + r22 + r25
    dy[2] = -r2 - r3 - r9 - r12 + r1 + r21
    dy[3] = -r15 + r1 + r17 + r19 + r22
    dy[4] = -r2 - r16 - r17 - r23 + r15
    dy[5] = -r3 + r4 + r4 + r6 + r7 + r13 + r20
    dy[6] = -r6 - r8 - r14 - r20 + r3 + r18 + r18
    dy[7] = -r4 - r5 - r6 + r13
    dy[8] = r4 + r5 + r6 + r7
    dy[9] = -r7 - r8
    dy[10] = -r12 + r7 + r9
    dy[11] = -r9 - r10 + r8 + r11
    dy[12] = r9
    dy[13] = -r11 + r10
    dy[14] = -r13 + r12
    dy[15] = r14
    dy[16] = -r18 - r19 + r16
    dy[17] = -r20
    dy[18] = r20
    dy[19] = -r21 - r22 - r24 + r23 + r25
    dy[20] = -r25 + r24
    nothing
end
function pollu_u0()
    u = zeros(20)
    u[2] = 0.2; u[4] = 0.04; u[7] = 0.1; u[8] = 0.3; u[9] = 0.01; u[17] = 0.007
    return u
end
const POLLU_TSPAN = (0.0, 60.0)

# --- the callbacks: a periodic pulse, a discrete callback checked after each accepted step (every stack's
# DiscreteCallback); its next time is reset before each solve (`reset_pulse!`), so no state is carried ---------------
const NEXT = Ref(0.0)
const PULSES = Ref(0)
reset_pulse!(t0) = (NEXT[] = t0; PULSES[] = 0; nothing)
# The last pulse comes before the span's end: a pulse at the last step would be saved after its affect by the port
# and upstream (SciML's save_positions) and before it by PlainODE, so the final states would differ by the pulse.
# the Brusselator: every 0.5 in time, species 1 raised by 0.1 everywhere (22 pulses, 0.5 to 11.0, on [0, 11.5])
bruss_cond(u, t, integ) = t >= NEXT[] && NEXT[] <= 11.0
function bruss_affect!(integ)
    NEXT[] += 0.5; PULSES[] += 1
    v = integ.u
    for k in 1:BN * BN
        v[k] += 0.1
    end
    nothing
end
# POLLU: every 3.0 in time, NO (species 2) raised by 0.01 (19 pulses, 3 to 57, on [0, 60])
pollu_cond(u, t, integ) = t >= NEXT[] && NEXT[] <= 57.0
function pollu_affect!(integ)
    NEXT[] += 3.0; PULSES[] += 1
    v = integ.u
    v[2] += 0.01
    nothing
end

# the problem by name: (rhs, u0, tspan, p, cond, affect, first pulse)
problem(name) = name == "bruss" ? (bruss!, bruss_u0(), BRUSS_TSPAN, BRUSS_P, bruss_cond, bruss_affect!, 0.5) :
                name == "pollu" ? (pollu!, pollu_u0(), POLLU_TSPAN, PK, pollu_cond, pollu_affect!, 3.0) :
                error("problem: bruss or pollu")
