# The fresh-eye reviews of the references (2026-10-26)

The scripts behind the four reviews `writeup/reviews/2026-10-26-{traits,facts,compiler,lowering}-fresh-eye.md`. Each review cites them as `scratchpad/<name>`: they were written in the session's scratchpad and filed here.

| File | Review | What it checks |
|---|---|---|
| `probe.jl` | traits | P1–P8: bounds of one trait at different fixed parameters, a trait's name on an operation's second argument, `Kept{X}(x)` at the prompt, `@implement` of a bundle, a family with a block, a subtrait's kept value at a supertrait's bound |
| `vararg_lemma_o.jl` | facts H1 | an owned method whose only owned type is in a `Vararg` tail wins at a fact of a non-stakeholder |
| `assert_one_up.jl` | facts H2 | a method-level `@assume_effects :foldable` one frame above a run-time site still folds |
| `owned_tw.jl` | facts M1 | ownership attributed to the module a method is evaluated in |
| `buildcheck.jl` | compiler | which commit the system image holds (names defined in `Base.Compiler`) |
| `names.txt` | lowering | TraitWorld's names, for checking the citations |

**How to run** (one at a time, through the shared lock):

```sh
flock /tmp/claude-1000/julia-review.lock env JULIA_NUM_PRECOMPILE_TASKS=1 JULIA_NUM_THREADS=1 \
  taskset -c 0-1 ionice -c3 nice -n 19 julia-1.13/usr/bin/julia --startup-file=no <script>
```

## Results

| Date | Build | Script | Result | Log |
|---|---|---|---|---|
| 2026-10-26 | system image 6d480d0753 (the build of 2026-10-21; fa4e7f5798 not built) | `vararg_lemma_o.jl` | reproduces: the facts CodeInstance of `M.k(::Int)` gets a finite `max_world`; `k(1)` 1, then 2 | `vararg_lemma_o.rerun.log` |
| 2026-10-26 | same | `assert_one_up.jl` | reproduces: after redefining `g`, plain 2, facts 1; the control (assertion on the frame with the site) 2 | `assert_one_up.rerun.log` |

Both reruns were made by the session that commissioned the reviews, independently of the reviewers' own runs.
