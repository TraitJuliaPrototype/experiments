# The gates

A gate is a Julia script that asserts a rule of the references on a built tree: it prints `<name>: OK` and exits 0, or
asserts. One Julia process per gate, niced, 4 cores (`source env.sh` first).

## How to run

    experiments/implementation/gates/run_all.sh julia-next             # every gate in force, then every stage gate
    ALL=1 experiments/implementation/gates/run_all.sh julia-next       # the same, the long stage gates too (none now)
    experiments/implementation/gates/run_all.sh julia-next 'm[12]_*'   # the gates in force that match a pattern: '[nf]*', 'n20_*'
    LIB=TraitWorld-base experiments/implementation/gates/run_all.sh julia-unified   # another tree of the library

- One line per gate: `PASS name`, or `FAIL name (exit n)` with the last lines of its output. Then the tallies:
  `gates: …` for the gates in force and, without a pattern, `stage gates: …`. Exit status 1 if any failed.
- **"The gates pass"** means this command without a pattern: every gate in force and every stage gate
  (playbook §3, open issue 237).
- A pattern that matches no gate in force is looked up in `not-in-force/` and `retired/`, so that the scripts of
  earlier experiments that name such a file still run it.

## What is in force

- **The gates in force** are the files `*.jl` in this directory, but `util.jl` (shared probes): 72 files, `m1_*` and
  `m2_*` (the type system and dispatch, 30), `n*` (35) and `f*` (7). The list is below.
- **The project.** A gate runs with the stub library of `../src/Traits.jl` (`--project=experiments/implementation`:
  `@trait X`, `@implement X S`, `declare_membership`; no contract checks, no fields, no operations as entries). A gate
  whose header has the line `# project: TraitWorld` runs with the library's tree (`--project=TraitWorld`), since its
  rule is the library's: `n8_callable_box.jl`, `n26_callable_late_method.jl`.
- **Expected failures inside a gate.** None. W-165 flipped the two that W-164 wrote (`n8_callable.jl`, the tie of two
  methods at `Callable` instances, compiler C-147; `n20_unmet_lookup.jl` (5), the unmet lookup's ambiguity at
  `Callable` and at a bare parametric set, C-148): each now asserts the rule, and fails on `next` a5bd871cce
  (`../w165/logs/gates-head-flipped.log`).
- **The stage gates** are the gates of each stage of the running iteration, kept in the stage's directory and
  listed in `stage_gates.txt`, one line each: the path relative to `experiments/implementation/`, the project
  (`none`, `stub`, `TraitWorld`) and flags (`verdict`: the script exits 0 either way and its last line must hold
  `: OK`; `long`: run only with `ALL=1`; `runs`: it asserts nothing, it prints what it measures and passes if it
  runs).

  | Stage gate | What it holds | Project |
  |---|---|---|
  | `w155/gate_deep.jl` | D-5: the G2 bit is the deep class (compiler §3.2; E-417) | none |
  | `w155b/gate_d11.jl` | D-11: a membership adds no type equality inside an invariant parameter (compiler §4.5; E-456) | TraitWorld, verdict |
  | `w160/check/new_fold.jl` | E-436: the fold at `new` records its edge, a non-member is still refused (compiler §4.8) | TraitWorld |
  | `w160/check/stores.jl` | E-441: whether a store into storage typed by the trait queries the membership when it runs | TraitWorld, runs |
  | `w160/check/kept_own.jl` | E-444: the walk replays a method at a bound the signature sets, at its own signature (compiler §5.5) | stub |
  | `w160/check/mistakes.jl` | E-440: E-401's mistakes, read at the box | TraitWorld, runs |
  | `w161/merge/delete_forwarder.jl` | E-496: code that decided a positive membership ends when the membership is taken back | TraitWorld |
  | `w161/d2/gate.jl` | E-500, D-2: `Callable` is a contract at the box (traits §9; compiler §7.4) | TraitWorld |
  | `w161/d4/op150.jl` | E-498, D-4: an operation is an entry, an untyped method serves it (traits §4.1; open issue 150) | TraitWorld |

  Not listed: `w161/d4/mistakes.sh` (E-498, fifteen processes and a table, no verdict) and the suites of
  `w161/suites.sh` (the library's, the ports', Julia's test files).
- **Retired gates** go to `retired/`, with a line here: which rule replaced the gate's and which gate holds it.
  None is retired: W-164 rewrote each of the four gates that asserted a replaced rule.
- **Not in force: `not-in-force/m3_*.jl`** (9). The earlier attempt's later stages (the facts policy and the record:
  run-time sites and effects, the record's kinds, the G2 bit and counts, fold records, an image round trip, the
  ambiguity report with dominance, the test bed `all`). They call the session marks `Compiler.mark_facts!` and
  `mark_concrete!`, which the module option and the method flag replaced, and need packages this project lacks;
  they fail when run. Each is re-judged at the stage that takes up its subject. `m3_ambiguity_dominance.jl` pins a
  rule the references do not have (a fixed-arity method at one set beating a `Vararg` at another; compiler §5.2
  leaves two unrelated sets unordered, and dispatch raises at the member). Their `include` names `../util.jl`.

## Results

| Date | Build | What | Result |
|---|---|---|---|
| 2026-11-18 | `next` 02139b2168, TraitWorld `w156` ea72682 (the attribute's surface removed: traits T-126, T-127); load 17 to 19 of 128 | `run_all.sh julia-next` (W-156): `n8_callable_box`, `w161/d2/gate.jl` take the library's `compiled_for`; `w160/check/new_fold.jl`, `stores.jl`, `mistakes.jl` write `@trait_module` without `first_seen = false` | gates in force 72 of 72; stage gates 9 of 9; 124 s (`logs/w156b-julia-next.log`) |
| 2026-11-18 | `next` a5bd871cce (the binary reports `a5bd871cce*`), TraitWorld `unified` 51e3a86; load 4 to 13 of 128 | `run_all.sh julia-next` (W-164) | gates in force 72 of 72; stage gates 9 of 9; 120 s (`logs/w164-julia-next.log`) |
| 2026-11-18 | `unified` 8fccf1e182 (the tag `prototype-2026-11`), TraitWorld `unified` 3e64ede | `run_all.sh julia-unified` (W-164) | gates in force 67 of 72: `n8_callable`, `n20_unmet_lookup`, `n22_declared_assert` fail at the replaced rule's assertion, `n8_callable_box` and `n26_callable_late_method` because the library's head does not load there; stage gates 0 of 9 (the library's head does not load; `gate_deep` fails 5 checks, `kept_own` 4 of 4 callers ended: the rules of D-5 and E-444); 142 s (`logs/w164-julia-unified.log`) |
| 2026-11-18 | `unified` 8fccf1e182 with the tag's library (`LIB=TraitWorld-base`, e11c7cc) | the two gates run with the library | `n26_callable_late_method` fails at the replaced rule (`typeof(nf) <: Callable{Tuple{Int}, Int}` is false there); `n8_callable_box` cannot run (`TraitWorld.ByType` is missing) (`logs/w164-julia-unified-traitworld-base.log`) |
| 2026-11-18 | `next` a5bd871cce | `run_all.sh` with a pattern, as its callers run it: `'m1_*'`, a single name, a name not in force | 11 of 11; 1 of 1; `m3_g2_bit` found in `not-in-force/` and run (it fails); an unknown name runs nothing (`logs/w164-pattern-julia-next.log`) |
| 2026-11-18 | `next` a5bd871cce, TraitWorld 3e64ede | one wrong assertion per rewritten case, the replaced rule's answer (`logs/w164_mutants.sh`) | 9 of 9 fail on the head, as they should (`logs/w164-mutants-julia-next.log`) |
| 2026-11-18 | `w165` 02139b2168 (W-165; the binary reports `02139b2168*`), TraitWorld `unified` 3e64ede; load 3 to 5 of 128 | `run_all.sh wt/w165-julia`, with the two checks flipped | gates in force 72 of 72; stage gates 9 of 9 (`../w165/logs/gates-w165.log`); the two flipped gates fail on `next` a5bd871cce, as they should (`../w165/logs/gates-head-flipped.log`) |

## The gates in force

The M-number in a file name is the milestone or stage whose gate it is. A gate without an entry here says what it
gates in its header comment.

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
  methods' own arity and names the joint signature: the audit's A7, compiler §5.4),
  `m2_ambiguity_predates.jl` (only the ambiguities a membership creates, E-346) and
  `m2_ambiguity_declared_super.jl` (each method the membership makes applicable asked at the
  member: ties with a method at a closed declared supertype, at `Any`, a superset's, a joint
  method's; no finding through a set the member is not in; W-132, E-347)
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
- `util.jl`               — shared probes: a function's CodeInstances, the current world, the absence edges a
  CodeInstance holds
- `n6_attribute.jl` — W-111: each trait argument's attribute by the five steps of traits §7.5 (the
  runtime at a dynamic call, inference at a static one), the casts and `Core.attributed_call`, `keep`,
  the run-time site that passes `Dynamic` on, the reserved names, identical results
- `n7_guards.jl` — W-140: a membership invalidates as a method does. A call holds no guard and no cell;
  the membership invalidates the caller whose selection it changes, an older world keeps the old
  answer; a caller matched through the type's own supertypes stays valid; a method at a set defined
  later invalidates no caller at a non-member; the call's own result; the facts mode
- `n8_callable.jl` — W-113, rewritten by W-164 (stub): `Callable{A, S}`'s memberships are entries (compiler
  §4.3, §7.4 "Memberships"; traits §9): every `Function` a member of every instance, whatever its methods; a
  callable type that is no `Function` only by its declaration (`@implement Callable T`, lowering §9); a method's
  definition or deletion begins or ends no membership and ends no code compiled on the answer; the builtins' types
  never members (compiler §4.1); a method at `Callable` takes every function; E-267's question answered from the
  entries in either order. W-165 (compiler §4.6, §4.9, C-147): two methods that differ only in `A` or `S` tie at
  every function (`All{X{A}, X{B}}`, neither more specific, `isambiguous`, a call's `MethodError`, in compiled code
  too); a method at the intersection resolves it and ranks above each; a member of one instance only keeps its
  method; for a set `HP20{N, R}` with the input `N`: disjoint at one name and another `R`, meeting at two names, unmet
  until a member is at both, then the report at the membership, the tie and the earlier caller invalidated.
  *Catches:* membership by methods (`uppercase` no member at `Tuple{Int}`), a method definition that changes an
  answer. *Shown:* it fails on the tag's Julia (`logs/w164-julia-unified.log`), and its wrong assertions fail on
  the head (`logs/w164-mutants-julia-next.log`).
- `n8_callable_box.jl` — W-164 (TraitWorld), W-113's cases that the box holds today (traits §9; compiler §6.3,
  §7.4 "The check at the box"): a plain function boxed, the box refused at the call that passes a function with no
  method at `A`, also at `A` fixed by another argument; the result asserted to `S`, never converted, returned or
  used, the function a constant of the caller, `S` at the method's variable; a box's call outside `A` raises; a
  wrapper checked where it enters, its calls the function's own (GT-24). `w161/d2/gate.jl` holds the rest.
  *Catches:* a converted result, an unchecked box, a wrapper's call asserted to `A`. *Shown:* its wrong assertions
  fail on the head (`logs/w164-mutants-julia-next.log`); on the tag's Julia it cannot run (the tag's library has no
  `TraitWorld.ByType`, the library's head does not load).
- `n9_fully_typed.jl` — W-114: fully typed mode, by a method's meta and a module's option: compiled by
  facts; code with a run-time site (in it or a facts callee) or an abstract result starts with the check,
  fully typed code has none; warn once, enforce at every run, Julia's error without a hook
- `n20_unmet_lookup.jl` — E-331, E-334, C-82 (compiler §4.8, §4.9, §5.4): a match met only at an intersection no
  type is in is dropped from dispatch's lookup, its final cell on the caller; a membership that meets it returns the
  match and the ambiguity. Case (5), rewritten by W-164: a `Callable` component is a set as any, met only by a type
  declared in both (a call method makes no membership); W-165 (C-148): the lookup that drops the match reports no
  ambiguity, at `Callable`, its instance and a bare parametric set, the caller's call is static with the cell
  (`AbstractString`, `Callable`), and the declaration invalidates it. *Catches:* a call method
  that meets `All{AbstractString, Callable}`. *Shown:* it fails on the tag's Julia, and its wrong assertion fails
  on the head.
- `n22_declared_assert.jl` — open issue 171, rewritten by W-164 (stub; traits §4.1, §7.9; compiler §4.1, §6.8,
  §7.1): an operation is an entry of its set's contract (`jl_set_contract_operations`), no method at the set; the
  call at the set is inferred as the entry's declared result, asserted and never converted (a redefined serving
  method raises `TypeError`; the dynamic call returns the member's result); a method's declared result at the set,
  with no entry, declares nothing. The gate writes the entry as the library's `@trait` does. *Catches:* a declared
  result read from a method at the set, a converted result. *Shown:* it fails on the tag's Julia, and its wrong
  assertions fail on the head.
- `n25_image_before_set_method.jl` — W-140: code in a package image, compiled where its callee had no
  method at a trait, is invalidated by a later membership, whether the method came before the image's
  load or after (`../w140/image_then_method.jl`, with the packages `../w140/PlainF`, `PlainG`)
- `n26_callable_late_method.jl` — W-140, rewritten by W-164 (TraitWorld; compiler §7.4, §6.3; traits §9): a method
  defined after code that passes the function at `Callable{A, S}` begins no membership (the method at `Callable` is
  selected before and after; one at `Any` beside it is not taken); it changes the box's test, a fact with its edge
  to the function's dispatch at `A`: the code compiled while there was no method at `A` refuses the function and is
  ended by the method at `A`, not by one at another signature; also with `A` fixed by another argument, and with
  the function a value typed `Any`; a constructor with a bare `Callable` argument leaves another constructor's
  caller in the deep class. *Catches:* a function without the method sent to the method at `Any` (membership by
  methods), a box's test that does not follow a later method. *Shown:* it fails on the tag's Julia with the tag's
  library (`logs/w164-julia-unified-traitworld-base.log`), and its wrong assertions fail on the head.
- `n27_invariant_parameter.jl` — W-140: a membership replays no method that names the set only as an
  invariant parameter (`Vector{X}`); where the set bounds a variable (`Vector{<:X}`) it reaches the caller
- `n28_wide_caller.jl` — W-140: a membership adds no method: a caller at `Any` or at an abstract argument
  and the wide instance of another method stay valid; the caller and the instance at the member's own
  type, and a caller at a union of non-members, follow
- `n31_isa_narrows.jl` — compiler §4.8 (E-373): a test `x isa X` at a set narrows the true branch to the
  set and folds no negative; a result annotation at a trait is inferred as the trait; a membership
  declared later is followed
