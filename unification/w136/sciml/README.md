# E-363: SciML's three error cases: upstream, the port, and the port's plain twin (W-136, G-5)

**The question:** E-5 measured three classic SciML failures on upstream (`experiments/errors/`), and E-90 compared the trait port's messages with them on the package prototype. Here the three are run again in three forms, on today's builds. The third form, the port's twin without traits, separates what the traits give from what a small library gives. Registry row: `writeup/record/experiments.md` E-363. Current numbers: `writeup/design/evidence.md` §4d.

## The cases and the forms

1. A right-hand side reads parameters the problem was never given.
2. A `Float64` cache in the right-hand side, under a gradient by ForwardDiff.
3. The same cache under Rodas5's automatic Jacobian.

- **upstream** (`upstream.jl`): OrdinaryDiffEqTsit5 2.1.4, OrdinaryDiffEqRosenbrock 2.7.4, SciMLBase 3.55.0, ForwardDiff 1.4.7, on `julia-vanilla`. Project `env_upstream/`, resolved offline. The packages are read from the home depot; the workspace's depot does not have them.
- **trait** (`port.jl trait`): TraitDifferentialEquations on `julia-unified`.
- **plain** (`port.jl plain`): PlainODE, the same solver without traits (FunctionWrappers for the right-hand side), on `julia-vanilla`.

`report.jl` measures a message as E-5 did: with its stack trace, in full and as the REPL limits it; lines, bytes, frames, the longest line.

## How to run

```
source ../../../../env.sh
bash run.sh        # one process per form -> logs/run.log; each message's text in logs/<form>-<case>_{full,limited}.txt
```

## Results, 2026-11-11

`julia-unified` dd3f6d839b, `julia-vanilla` v1.13.2 45b6d15e34, TraitWorld 99c4934, TraitDifferentialEquations 5e342f7. One run each (the texts do not vary), load 8 of 128 cores.

The message in full, with its stack trace: lines / bytes / frames / longest line.

| Case | Upstream | The port (traits) | The port's plain twin |
|---|---|---|---|
| 1. parameters never passed | 72 / 10,725 / 28 / 3,903 | 35 / 3,706 / 16 / 415 | 33 / 2,606 / 15 / 272 |
| 2. a `Float64` cache under a gradient | 106 / 14,380 / 45 / 5,688 | 83 / 9,471 / 35 / 715 | 87 / 8,079 / 37 / 758 |
| 3. the same cache under Rodas5 | 81 / 89,806 / 22 / 33,983 | 81 / 7,410 / 34 / 689 | 71 / 4,448 / 29 / 227 |

As the REPL limits it (types in frames shortened): bytes / longest line.

| Case | Upstream | The port (traits) | The port's plain twin |
|---|---|---|---|
| 1 | 5,631 / 1,529 | 2,706 / 139 | 2,497 / 182 |
| 2 | 7,076 / 1,529 | 5,271 / 148 | 5,694 / 184 |
| 3 | 4,631 / 163 | 5,012 / 144 | 4,198 / 152 |

What the message says, before the stack trace:

| Case | Upstream | The port and its plain twin |
|---|---|---|
| 1 | 12 lines written by SciML: "An indexing operation was performed on a NullParameters object. This means no parameters were passed …", with the two common causes | `MethodError: no method matching getindex(::Nothing, ::Int64)`, 2 lines. The first frame is the user's function |
| 2 | `MethodError: no method matching Float64(::ForwardDiff.Dual{…})`, 12 lines | the same `MethodError`, 12 lines |
| 3 | 36 lines written by SciML: "First call to automatic differentiation for the Jacobian failed …", with three fixes, then the `MethodError` | the `MethodError` alone, 12 lines |

`typeof(integrator)` upstream: 3,666 characters, 75 type-parameter lists.

## Reading

- **Against upstream the port's messages are shorter:** in full 0.35, 0.66 and 0.08 of the bytes, and the longest line 415 to 715 characters against 3,903 to 33,983. The lines and frames are fewer in cases 1 and 2 and not in case 3 (81 lines both; 34 frames against 22).
- **Against its plain twin the port's messages are not better.** They are the same errors, raised at the same place, and the trait form's are longer: 1.42, 1.17 and 1.67 times the bytes in full. So what is shorter than upstream is what a small library with an erased right-hand side gives, with traits or with FunctionWrappers. The traits are not what shortens it.
- **None of the three is a mistake against a contract.** Each is raised at run time, inside the user's own function, under the solver. No check at a declaration or a definition sees it: inference does not prove that `p[1]` at `p::Nothing`, or a conversion of a dual number to `Float64`, fails. E-362's gains (a mistake reported at the line that makes it) do not reach these cases.
- **Upstream says more in cases 1 and 3:** SciML wrote the explanation by hand, with the fixes. The port gives the bare `MethodError`.
- **The types in the port's frames are short because the function is erased:** a frame reads `Dynamic{All{Callable{…}, Callable{…}}}`, where upstream's carries the integrator's type.

## Found on the way

- **Hints from BaseTraits on a `MethodError` of Base's `getindex`** (case 1, the first run on TraitWorld 158d000): four lines, "`Nothing` is not a member of `Indexable`; `@implement Indexable Nothing` declares it" and the same for `Keyed`. Wrong advice for a user who forgot the parameters. Fixed in TraitWorld 99c4934: no hint at an operation that is another owner's function (traits §11.4). The message went from 6 lines to 2.
- **A proposal for case 1** (open issue 177 (d)): the right-hand side at `p::Nothing` infers `Union{}`: it always throws. A `Callable` whose result infers `Union{}` at the declared arguments could be refused where the function enters, at `ODEProblem(…)` or `solve`, with the declared signature.

## Limits

- Three cases, one port. The cases were chosen in session 22 as SciML's classic failures, not as mistakes against a contract.
- Upstream's versions are those installed on this host, not E-5's (Julia 1.12.2, the default environment of that day). E-5's numbers were 71, 101 and 81 lines; 29, 44 and 22 frames; longest line 3,789, 5,574 and 33,673.
- While the upstream environment was precompiled, MKL_jll fetched an artifact (oneTBB) into the experiment's depot.
