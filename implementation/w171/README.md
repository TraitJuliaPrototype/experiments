# W-171 (E-542): an audit of every fold about a set, across worlds

**The registry's row (E-542).** Does compiled code keep any answer about a set outside the worlds where the answer
holds: every kind of question (a subtype test, `isa`, a typeassert, `new`'s field test, an intersection, type
equality, a method match, `applicable`, `hasmethod`, `which`) at every position a set can take in a type (the type, a
parameter covariant and invariant, a union, an intersection, a variable's upper bound, lower bound and both, `Type{T}`,
a type value, a `Vararg` tail, a family, a set's input, a supertrait through one and two entries, an abstract member, a
set as member, a parameter through a declared supertype, an intersection no type is in), through every change of the
world (a membership declared, a second one that makes a path, one taken back, one declared again, a method defined at
the set more and less specific, a method deleted, a member type defined later), compared with the answer asked afresh
in each world? Baseline: the runtime's own answer in the same world, asked by `ccall` (which neither inference nor code
generation folds), and the shape's expected answer. Would change the references: a mismatch is a soundness hole at a
rule of compiler §4 or §5, fixed there, and a case for the proofs.

The tool is `../audit/set_folds.jl` (how to run it, and its dated table: `../audit/README.md`, "The set-folds
report"). This directory holds its logs, the probes of each mismatch's pattern, and the candidate gates.

## Files

- `logs/set-folds-<build>-<commit>.log`: the tool's report on a build. `set-folds-w171-edb0e3dcae.log` is branch
  `w171` before its last commit (patterns 1, 2 and 4 fixed, pattern 3 still reported: `vararg`, `super_param`).
- `probes/`: one probe per pattern, each runnable alone (`julia --project=experiments/implementation <probe>`).
  `probes/gen/` is written by the tool (`--probes=`), one file per group's first mismatch.
- `gates/`: candidate gates for `gates/`, each failing on `next` dd42dc8c3f and passing on branch `w171`.

## Results, 2026-11-23

The tool's table per build: `../audit/README.md`, "The set-folds report". On `next` dd42dc8c3f: 348 cases, 96,880
checks, 8,975 mismatches in 1,134 groups (question, shape, sequence). The three known holes are reported on the builds
without their fixes and not on `next` (row 181 on `w159-bisect` 3037289af6, row 182 on `absence-worlds` 8884715703,
row 184 on `w143e` d1e64d8b56). On branch `w171` 2ddbe12394: 2,032 mismatches in 246 groups, all about dispatch.

### The patterns on `next`, and what was done

1. **Compile-time evaluation folds an answer about a set that inference did not fold** (int, eq, and `sub`, `isa`,
   `tassert`, `new` in the caller's form). A test about a set left unfolded (`<:`, `isa`, `typeassert`, `new`'s field
   test) is a builtin whose effects claim consistency, and `typeintersect` and `==` of types assert it
   (`@_total_meta`): a caller evaluated the callee at compile time and kept the answer, with an edge to the callee's
   code only, which records nothing. A typeassert's throw folded so ran into `unreachable` after the membership.
   Rule: compiler §4.8 (code that relies on an answer about a set holds only in the worlds where it does). Lemma:
   the invariant of Theorem 1 ("a record that is not complete", proofs §7). Fixed: `w171` edb0e3dcae (an unfolded set
   question and an unproved field test are not consistent; a call given a set type as a constant is not consistent
   and not evaluated at compile time). Gate `gates/n41_set_not_consistent.jl`. Probes `probes/typeintersect_fold.jl`,
   `probes/tassert_trap.jl`, `probes/tassert_inline.jl`.
2. **`jl_could_join` answers "no membership can change this" where one can:** two tuples of different lengths (a
   `Vararg` tail), `Type{S}` against `Type{<:X}`, a parameter through a declared supertype. Inference's frame-less
   meets (`tmeet`, a typeassert) and code generation's `<:` and `isa` fold such a negative with no edge. Rule:
   compiler §4.7, §4.8. Fixed: 461605c7f2. Gate `gates/n39_could_join_shapes.jl`. Probe `probes/codegen_vararg_fold.jl`.
3. **The mirror, `jl_subtype_via_membership` answers "the chain decided" where an entry did:** the same two shapes
   (a `Vararg` tail; a declared supertype's parameter). The positive folds with no entry recorded and stands after the
   membership is taken back. Rule: compiler §3.1, §4.8. Fixed: 2ddbe12394. Gate `n39` (its second half). Probe
   `probes/positive_vararg.jl`.
4. **A membership taken back left the callers of the member's instance that has no code** (`applicable`, `hasmethod`
   folded through the membership). Rule: compiler §5.5 (taken back, the instances at the member end with their
   callers). Fixed: 04bafd8f52 (the removal walk ends the instance's backedges, as a method's deletion does). Gate
   `gates/n40_removal_instance_callers.jl`. Probe `probes/app_taken_back.jl`.
5. **A method that names the member in a variable's lower bound, called at a type that names the set**
   (`h(::Ph{T}) where T>:S` at `Ph{X}`): the membership changes the selection and no walk replays the method, which the
   set-to-methods index does not list under the set. The dispatch caches (`_methods_by_ftype`, `applicable`,
   `hasmethod`, a call) and the callers' edges keep the old selection, declared or taken back. Rule: compiler §5.5.
   Not small: deviation C-162. Probes `probes/lb_dispatch.jl`, `probes/lb_dispatch_declared.jl`.
6. **Equality inside an invariant parameter through variables' bounds** (`Ph{Ph{T} where T>:X}` against
   `Ph{Ph{T} where T>:Union{X, S}}`): `<:` consults entries through the bounds and answers true once `S` joins, while
   `isa` compares the two concrete types as objects and stays false. Rule: compiler §4.5 (equality inside an invariant
   parameter consults no entry), §4.4 (`isa` and `<:` agree). Deviation C-163. Probe `probes/lb_invariant.jl`.
7. **A call at an abstract type, a set or a union that a membership makes match a method at the set**
   (`hasmethod(h, Tuple{AM})`, a call compiled once at a set `Y0`): the declaration's walk leaves the code that folded
   "no method" there, and the code that dropped the unmet match. Rule: compiler §5.5, §4.8. Deviation C-164. Probes
   `probes/gen/hasm-abstract_member-declared.jl`, `probes/gen/hasm-set_member-declared.jl`,
   `probes/gen/disp-set_member-declared.jl`, `probes/gen/app-set_member-declared.jl`.
8. **A type value's membership taken back:** a lookup at `Type{S}` made after the taking back is valid back in the
   worlds where the type value's entry held. Rule: compiler §4.10, §5.3. Deviation C-165. Probes
   `probes/gen/disp-type_value-taken_back.jl`, `probes/gen/app-type_value-taken_back.jl`.

### Checks of `w171` 2ddbe12394

- The gates in force: 77 passed, 0 failed; the stage gates 9 passed (`logs/gates-w171-2ddbe12394.log`).
- Base's `subtype`, `core`, `worlds`: SUCCESS (`logs/base-*-w171-2ddbe12394.log`).
- TraitWorld's tests as a file: no failure (`logs/traitworld-tests-w171-2ddbe12394.log`).
- The candidate gates `gates/n39`, `n40`, `n41`: each fails on `next` dd42dc8c3f and passes on `w171`.

## Second part (E-543)

**The registry's row (E-543).** After the fixes of the audit's four open patterns (compiler C-162 to C-165), does
the tool report nothing; what do its modes for package images and for the library's forms (the kept forms, declared
results with the `trusted` mark, `Callable`) find; and what does trait code pay for the folds the rule "a set answer
is not consistent" takes away (the library's and the ODE port's load and first run, a call through a trait at a known
type, a small stiff solve)? Baseline: the runtime's own answer in each world; for the cost, the build before the rule
on the same trait code, and each cell's plain twin. Would change the references: a mismatch is a hole at its rule; a
cost that a narrower sound rule avoids changes the rule; a cost the rule sets is a tension.

Branch `w171b` of the julia repository (worktree `wt/w171-julia`), on `w171` = `next` 2ddbe12394. Candidate gates
`gates/n42_…` and up: each fails on 2ddbe12394 and passes on `w171b`.

### The four patterns, each at its rule

| Pattern (row) | Cause | Fix (branch `w171b`) | Gate | The tool after it |
|---|---|---|---|---|
| a type value's membership taken back (C-165) | a kind of type object meets a set where the set takes a type value; that rests on the set's entries for type values, held on each value's TypeName, on no type of the query; a lookup's worlds were narrowed only by the query's entries, so the method cache's entry at the widened signature `Tuple{typeof(g), Type}`, made from a lookup at `Type{S}` in a world before the membership, answered `g(::Any)` in the worlds where it holds | 86cc20d662: a range asked at a query with a kind at a covariant place is narrowed by the type-value entries of the signature's sets and of the sets that join them (`jl_type_has_kind`, `value_entries_range`); the typemap's visitor asks it also where the intersection is empty. `src/subtype.c`, `src/typemap.c`: 67 lines added, 4 removed | `gates/n42_kind_value_worlds.jl` | 1,998 mismatches in 232 groups (`type_value` gone; log `set-folds-w171b-86cc20d662.log`) |
| a method with the member in a variable's lower bound (C-162) | a lower bound is the one contravariant place of a signature: there a type under the member, not the set, carries the membership (`h(::Ph{T}) where T >: S` takes `Ph{X}` once `S` joins `X`); the signature names no set, so the set-to-methods index did not list it and no walk replayed it, and a match's worlds were narrowed by the query's entries only | aa362a2ddd: the index lists each method with a lower bound at a covariant place under the key `nothing` (20 of Base's methods: `T >: Missing`, `T >: Nothing`); the declaration's and the removal's walks replay each whose bound meets the member, at the method's own signature (`lower_bound_targets`); the library's replay signatures name them; a match's worlds are narrowed by the signature's lower bounds' entries (`jl_sig_lower_bounds`). `src/gf.c`, `src/subtype.c`, `src/typemap.c`: 182 added, 5 removed | `gates/n43_lower_bound_replay.jl` | 920 in 130 (`lower_bound`, `lower_bound_rev`, `both_bounds` gone; `set-folds-w171b-aa362a2ddd.log`) |
| a call or `hasmethod` at an abstract type, a set or a union (C-164) | a membership adds no method: the code that leaves a call's choice to the run keeps its validity, and the walk keeps it (compiler §5.5). Two answers fold that choice at compile time with nothing that records it: a caller's compile-time evaluation of a callee whose method is chosen at the run among matches at a set (consistent effects; the tool's values are singletons), and `hasmethod`'s "no method covers these types", whose missing-method edge the walk keeps where the method matched before without covering | 9970f8799a: such a call and such an `applicable` are not consistent (`choice_rests_on_memberships`; row 187's rule); `hasmethod`'s negative folds only with the absence edges of the pairs the lookup dropped at a final pair, and is not folded where a method that meets the types rests on memberships or the types name a set. `Compiler/src/`: 54 added, 1 removed | `gates/n44_set_choice_not_folded.jl` | with C-163's fix: 0 (`set_member`, `abstract_member`, `union_both`, `lower_bound_eq` gone) |
| equality inside an invariant parameter through variables' bounds (C-163) | the equality consulted no entry, but a variable's bound was asked with entries wherever it was met, also for a variable bound inside the parameter being compared | 3c7394979a, decided by the reference (§4.5, §4.9: "two types inside an invariant parameter are equal in every world or in none"; §4.4): the walk keeps the invariant depth at which the outermost equality began (`noentry_depth`); a variable bound at that depth or deeper is part of the equality and its bounds are compared with no entry, in subtyping and in intersection. A variable bound outside the parameter (`Vector{<:X}`) is a subtype question with entries. `src/subtype.c`: 33 added, 13 removed | `gates/n45_invariant_bound_equality.jl` | 0 mismatches, 0 dynamic, 0 fresh-against-expected (`set-folds-w171b-3c7394979a.log`) |

**C-163's answers that change** (by the reference): `Ph{Ph{T} where T >: X} <: Ph{Ph{T} where T >: Union{X, S}}` is
false in every world (true on `next` once `S` joins `X`), and so are `==` of the two, their intersection (`Union{}`),
`hasmethod`, `applicable` and dispatch at a method typed by the second at the first's instance; `isa` is unchanged.
At the top (`A == B` for the two `UnionAll`s) a membership still counts, and so for an outer variable's bound
(`Vector{Ph{X}} <: Vector{Ph{T}} where T >: S`). `w143d/motiv/lb_bit.jl` prints `Vector{A} <: Vector{B}` false
after the membership now; row 181's fix (the bit sees a lower bound) is unaffected: it serves the top-level `A == B`.

**What the tool still cannot see** (found beside it, compiler C-166's candidate): a method at the member's own type
(`g(::S)`) defined before the membership, and a call compiled once at the set (`q(::X)`, which found `g(::X)` alone):
once `S` joins `X` the call at `X` meets `g(::S)`, and the caller keeps its static call (`probes/member_method_at_set.jl`).
The tool's shapes put methods only at `B`; a sequence with a method at `A` before the membership is the mode that
would count it.

### The tool's modes, and what they found

- **Package images** (`../audit/set_folds_images.jl`, the README's "The set-folds report"): on 3c7394979a one
  mismatch of 1,409: `loaded_after`, `set_member`, `x isa X` compiled before a package's image declared `Y0 in X`
  stayed `false`. Cause: package loading runs in a fixed older world (`_require_world_age`), and the method table's
  insertion of the image's methods asked its membership questions there; the membership's method at `Type{<:Y0}`
  meets `S0`'s absence edge only through `S0 in Y0`, an entry not in force in that world. Fix 054016ea75: the insertion
  asks in the world the image's methods begin in (`src/staticdata.c`, 5 lines; compiler §4.11, §9). Gate
  `gates/n46_image_activation_world.jl`. After it: 0 of 1,409 (`logs/set-folds-images-w171b-054016ea75.log`,
  `…-3e9c193025.log`); the refused image's own folded code answers by the refusal.
- **The library's forms** (`--mode=traitworld`): on 054016ea75 452 mismatches in 47 groups (and `forwarding` refused
  by the library, its field's type no member; the shape now declares it first):
  - `callable` (hasm, disp, app, which): `@implement Callable S` is an entry at every instance (`Callable{A, S}
    where {A, S}`), which the walk paired with a method's parameter (`Callable{Tuple{Int}, Int}`) by subtyping, so it
    replayed nothing. Fix d7b373bf92: such an instance reaches the parameter where the two meet
    (`membership_param_meets`, `src/gf.c`, 9 lines; compiler §5.5, §7.4). Gate `gates/n47_callable_every_instance.jl`.
  - `compiled`, `dynamic` (sub): the library makes each kept form a member by a pattern bounded by the set
    (`Compiled{Z} where Z <: X`); `Compiled{S} <: X` rests on `S`'s memberships, yet its non-membership was final, with
    a cell no membership of `S` meets. Fix 3e9c193025: a type on whose chain a pattern's variable is bounded by a set
    is no final non-member (`chain_has_set_bounded_pattern`, `src/datatype.c`, 23 lines; compiler §4.8, §6.9). Gate
    `gates/n48_kept_form_not_final.jl`.
  - `compiled` (hasm), 112 left on 3e9c193025: a membership adds the kept forms at the member under the set too
    (`Compiled{S}`), and the walk replays a method at the set at the member only; `hasmethod(h, Tuple{Compiled{S}})`
    keeps `false`. Not built (compiler C-167's candidate): the replay's signature would take the member's kept forms
    beside it (`Union{S, Compiled{S}}` for a concrete member, `Dynamic{Y}` for a set member). Probe
    `probes/kept_form_replay.jl`.
  - The operation's declared result with the `trusted` mark, the block, the forwarding field, the family by `where`
    and the library's deletion: no mismatch.

### Checks of `w171b` 3e9c193025

- The gates in force: 80 passed, 0 failed; the stage gates 9 passed (`logs/gates-w171b-3e9c193025.log`).
- Base's `subtype`, `core`, `worlds`, `ambiguous`, `reflection`: SUCCESS (`logs/base-*-w171b-3e9c193025.log`).
- TraitWorld's tests as a file: 120 test sets, no failure (`logs/traitworld-tests-w171b-3e9c193025.log`).
- The candidate gates `gates/n42` to `n48`: each fails on `next` 2ddbe12394 and passes on 3e9c193025 (`n47`, `n48`
  run with `--project=TraitWorld`, as their header says).
- The tool: 0 mismatches in the stub mode and the image mode; 112 in one shape in the library mode (C-167).

### What the folds the rule takes away cost (row 187 with `w171b`'s additions)

`cost/cost.sh` (log `cost/logs/cost-r1.log`): H is `w171b` 3e9c193025 (row 187 and C-164's rule: a set answer that
inference does not fold, a choice left to the run among methods at a set, `applicable` there, and a call given a
set's type as a constant are not consistent, and `hasmethod`'s negative at a set is not folded); B is
`wt/w143-julia` d1e64d8b56, the build before them (it also lacks rows 184 to 186 and 188, which change no fold's
consistency). The same trait trees (TraitWorld 0f54043af4, the ODE port 21a5aa57cf), product setting, strict mode
off, one thread; a warm-up process per cell and Julia, then 3 fresh processes each, H and B interleaved; load 2.0
to 2.7 on 128 cores. Idiomatic trait code; the ODE program's plain twin is plain code on the build.

| Cell | H (3 runs) | B (3 runs) |
|---|---|---|
| the library's load (`using TraitWorld`) | 71–76 ms | 73–74 ms |
| the ODE program's load | 425–437 ms (compile 57 ms) | 432–471 ms (compile 61 ms) |
| its first run | 353–356 ms (compile 351–354 ms) | 366–369 ms (compile 364–367 ms) |
| its second run | 0.92–0.94 ms | 0.94–0.97 ms |
| the plain twin: load, first run | 181–199 ms, 372–375 ms | 180–192 ms, 378–381 ms |
| E-513's calls: an operation at a known type, trait / plain | 0.79 / 0.79 ns | 0.79 / 0.79 ns |
| a method at the trait at a known type, trait / plain | 0.79 / 0.79 ns | 0.79 / 0.79 ns |
| a `Dynamic` default compiled once; `compiled_for`; a box held | 8.6–8.7; 2.38; 7.14 ns | 9.1; 2.38; 7.15 ns |
| `Vector{Shape}`; a `Dynamic{Shape}` field | 2.86–2.87; 5.56 ns | 2.86; 5.56 ns |
| a `Callable` argument boxed; `compiled_for(f)` | 25.8–29.2; 0.79 ns | 25.6–26.1; 0.79 ns |
| POLLU (20 states), the port boxed: min, median per solve | 0.565–0.567, 0.573–0.574 ms | 0.575–0.601, 0.583–0.607 ms |
| POLLU, `compiled_for(f)` | 0.534–0.544, 0.542–0.549 ms (one process 0.805) | 0.548–0.556, 0.555–0.563 ms |

No cell loses: the folds the rule takes away are not on these paths (an operation at a known type costs a plain
call's time on both). The one rule that could be narrower while staying sound: a call given a set's type as a
constant need not lose its consistency where the callee's effects are inferred, since inference already marks
every answer about a set it leaves to the run as not consistent (the builtins' tests, `new`'s field test, a choice
among methods at a set, `applicable`, a `ccall` into the runtime); only effects a method asserts (`@assume_effects`,
`@_total_meta`, as `typeintersect` and `==` of types do) can claim consistency over such an answer. Not built: no
cell shows a cost it would recover.
