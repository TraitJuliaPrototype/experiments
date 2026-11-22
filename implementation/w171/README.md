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
