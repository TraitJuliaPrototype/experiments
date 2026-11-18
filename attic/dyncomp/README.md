# dyncomp: the work on `Compiled` and `Dynamic` (W-4)

Experiments of work item W-4 (`../../writeup/record/todo.md`), by the implementation plan, revision 3 (`../../writeup/plans/2026-10-20-dynamic-compiled-implementation.md`). Semantics only: these are checks, kept short. Proper measurements are W-17.

Run each alone on the shared machine:

    flock /tmp/claude-1000/julia-review.lock nice -n 19 ../../julia-1.13/julia --startup-file=no <script>

| Script | Registry | What it checks | Result (julia-1.13 3b8085c222, 2026-10-20) | Log |
|---|---|---|---|---|
| `spike_known_type.jl` | E-148 | `Compiler.known_type` in every entry shape (positional, keyword, required keyword, vararg, function argument, two positions), from plain code, code compiled by facts, and the prompt; `split_call` over a held value from both kinds of caller | 20 of 20 as expected; the split has its `isa` branches in both. **Lesson:** `known_type` must be evaluated in the entry's own body: a helper called with the `Any`-typed value is a run-time site in code compiled by facts, compiled for the value's type, where it folds to `true` | `logs/spike_known_type.log` |
| `spike_facts_untyped.jl` | E-148 | the facts untyped caller alone and after typed and plain callers, in six orders (written while looking for the cause above) | `untyped` in every order | `logs/spike_facts_untyped.log` |
