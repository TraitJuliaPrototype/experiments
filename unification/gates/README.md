# Gate scripts

Run against a built tree, from the workspace root, one Julia process per gate:

    experiments/unification/gates/run_all.sh julia-unified 'm[12]_*'

The stub library is `../src/Traits.jl` (`@trait X`, `@implement X S`).

Scripts print `<name>: OK` on success and assert otherwise. The M-number in the
file name is the milestone whose gate it belongs to:

- `m1_late_implement.jl`  — late membership appears only in newer worlds
- `m1_compiled_isa.jl`    — code compiled before the membership answers both
  worlds (isa, subtype, tuple-parameter, typeassert forms; review H3)
- `m1_worlds_minworld.jl` — positive folds carry the entry's `min_world`
  (review M6)
- `m1_typevalue_isa.jl`   — a type value is a member only by an entry for
  `Type{S}`; an entry for `S` answers `S <: X`, never `S isa X` (compiler §4.10)
- `m1_parametric_set.jl`  — `@trait X{P}` and the bare-name membership (member
  of every instance); narrow declarations are narrow (open question 4)
- `m1_open_family_fold.jl` — B1: same-open-family parameter negatives must not
  fold to permanent `Const(false)`; compiled calls agree with runtime truth
- `m1_late_open_stale.jl`  — a set is open from its declaration; opening a
  published type is refused (compiler §4.1, the audit's A5)
- `m1_parametric_member.jl` — M1: parametric `@implement Mem{T} Set{T}` binds
  narrow (pattern/instance tvar sharing), not family-wide
- `m1_union_isa.jl`        — M3: type value `S isa Union{X, ...}` answers
  through union arms; isa ≡ dispatch
- `m1_no_wrappers.jl`      — Core has no attribute wrappers and no `Keyed`; the
  entry carries the receiver; a set's TypeName has a contract slot (C-20 retired)
- `m1_audit_probes.jl`     — the audit's probes P1, P3–P8 as assertions, one
  instance per member, the set's supertype, the world protocol (W-98)
- `m2_*.jl`                — dispatch at sets (W-98's second commit, W-99); among them
  `m2_ambiguity_report.jl` (one warning at the second membership; a set-in-set method
  on both sides suppresses it) and `m2_ambiguity_arity.jl` (the report asks at the
  methods' own arity and names the joint signature: the audit's A7, compiler §5.4)
- `n2_*.jl`                — intersections `All{X, Y}` (W-107, compiler §4.9), on branch
  `w107-probe`: `n2_all_probe.jl` (subtyping and the normal form), `n2_all_form.jl` (the
  encoding where the runtime reads names, parameters and wrappers: the review of 2026-11-07, §6),
  `n2_all_dispatch.jl` (intersection, dispatch at an `All` bound), `n2_open_abstract.jl` (a set
  and an abstract type meet as `All{X, T}`: compiler §4.7, §5.3, C-33)
- `m3_*.jl`                — the earlier attempt's later stages; not run. Each is re-judged
  at the stage that takes up its subject. `m3_ambiguity_dominance.jl` pins a rule the
  references do not have (a fixed-arity method at one set beating a `Vararg` at another;
  compiler §5.2 leaves two unrelated sets unordered, and dispatch raises at the member).
- `util.jl`               — CI walker (`Base.specializations` + `ci.next`)
