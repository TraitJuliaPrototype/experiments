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
- `n2_*.jl`                — intersections `All{X, Y}` (W-107, compiler §4.9), on `unified`
  8a9144928e: `n2_all_probe.jl` (subtyping and the normal form), `n2_all_form.jl` (the
  encoding where the runtime reads names, parameters and wrappers: the review of 2026-11-07, §6),
  `n2_all_dispatch.jl` (intersection, dispatch at an `All` bound), `n2_open_abstract.jl` (a set
  and an abstract type meet as `All{X, T}`: compiler §4.7, §5.3, C-33), `n2_all_rank.jl` (the rank
  of an intersection, §5.2), `n2_set_order_late.jl` (a later set-in-set membership orders two
  methods recorded as ambiguous, §5.2)
- `n3_image_memberships.jl` — memberships in package images (W-108, compiler §9): four packages on
  a fresh depot, both load orders, a call before and after a membership's load, an image built
  without the membership. TraitWorld's tests `override rule` and `module end` are W-108's other gates.
- W-109's gates are TraitWorld's tests `operation results`, `split`, `table`, `declared fields` and
  `classification` (TraitWorld `unified`, `test/core.jl`).
- `f1_facts_sites.jl`, `f2_policy_flags.jl`, `f3_policy_code.jl`, `f4_g2_bit.jl`, `f5_return_type.jl`, `f6_reach_policy.jl`, `f7_membership_edges.jl` — W-100 on branch `w100`: the facts
  inference and its run-time sites (compiler §1), the module and method flags (§2.1, §2.2), one
  CodeInstance per policy and calls between policies (§2.3, §2.4), G2's bit (§3.2), `return_type` (§1.4),
  the policy of the code that reaches a boundary by each way of calling, and a session under the test
  bed (§2.3–§2.5), the flag carried into keyword sorters and positional forwarders (C-43), positive
  memberships in the record and the code's worlds from their entries' (§3.1, §4.8)
- `m3_*.jl`                — the earlier attempt's later stages; not run. Each is re-judged
  at the stage that takes up its subject. `m3_ambiguity_dominance.jl` pins a rule the
  references do not have (a fixed-arity method at one set beating a `Vararg` at another;
  compiler §5.2 leaves two unrelated sets unordered, and dispatch raises at the member).
- `util.jl`               — CI walker (`Base.specializations` + `ci.next`)
- `n6_attribute.jl` — W-111: each trait argument's attribute by the five steps of traits §7.5 (the
  runtime at a dynamic call, inference at a static one), the casts and `Core.attributed_call`, `keep`,
  the run-time site that passes `Dynamic` on, the reserved names, identical results
- `n7_guards.jl` — W-112: a membership invalidates no code; a guarded call opens with its cell, an
  older world keeps the old answer, no guard through the type's own supertypes, a method at a set defined
  later invalidates the callers it shadows, the guarded call's result, the facts mode
