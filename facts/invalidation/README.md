# Which definitions invalidate compiled code (S1–S8)

From the framing review (`writeup/reviews/2026-10-18-framing-and-motivation.md` §0), adapted in session 29 for the in-tree facts mode.

    julia inval.jl                               # plain
    JULIA_COMPILE_BY_FACTS=1 julia inval.jl      # the facts mode (julia-1.13 880ae49dad and later)

Result (session 29, patched 1.13.2): plain invalidates in S1–S5, S7, S8; facts mode only in S4 (a stakeholder), S5 (a winning pirate), S7 (a redefined `const`); S6 (a losing pirate) never. S1–S3 and S8 are code that is not fully typed. `map(f2, Real[])` is `Vector{Float64}` in both modes. The two logs are the reviewer's runs (stock, and the Compiler copy in facts mode).
