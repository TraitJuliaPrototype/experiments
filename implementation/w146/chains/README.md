# E-389: the compiler's CodeInstance chains (W-146, item 8)

The question: E-388's profile found the runtime's lookup of compiled code at an `invoke` at a fifth to a third of inference's time. Why is the compiler's code deep on its chains, and what does it cost?

## How it was found

- `../../w145/profile/chain_position.jl`: in the world inference runs in, the position of the compiler's runnable code on each instance's chain, and the instances compiled more than once.
- A diagnostic at `jl_mi_cache_insert` (not committed): a line for each third valid entry on a chain. In the debugger, a breakpoint at that line with a backtrace; `gdb -x gdbcmds` following a package's precompile worker.
- The backtraces name `add_codeinsts_to_jit!` and `compile!` (`Compiler/src/typeinfer.jl`): a CodeInstance not in the cache takes an equivalent cached one's code, and the search took only the first entry by ABI, refusing it where its result edges differed.

## The fix

`unified` 9c6c9270f3: `equivalent_cached_ci` takes any entry of the chain with the same result edges, a compiled one first ([compiler §3.3](../../../../writeup/reference/compiler.md#33-the-code-slot)).

## Results, 2026-11-14

`unified` 9c6c9270f3 against 21c9b33e39; TraitWorld 2072e75; product setting, strict mode off, one thread; load 1 to 2.5 of 128. Current numbers: [the evidence](../../../../writeup/design/evidence.md).

| | before | after |
|---|---|---|
| the compiler's instances compiled more than once | 451 | 0 |
| the deepest runnable code on a chain | 19 | 4 |
| `sys.so` | 247.2 MB | 215.0 MB |
| upstream's eight steps: inference (vanilla 2.08 s) | 3.57 s | 3.12 s |
| upstream's eight steps | 10.29 s | 9.91 s |
| the forks' session | 4.00–4.06 s | 3.74–3.85 s |
| setting D | 1.95 s | 1.89–1.91 s |
| the ODE session | 1.31 s | 1.24 s |
| NetworkDynamics' workload | 45.0–45.2 s | 43.4–43.7 s |

Logs: `logs/chain_position.log`, `../../w145/profile/logs/*-fix.log` and `summary-fix.md`, `../../e289/logs/*-w146b.log`, `../../w120/logs/sessions-r389.log`, `ndport/logs/unified/r389-*.log`.
