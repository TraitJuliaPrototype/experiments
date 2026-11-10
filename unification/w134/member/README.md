# E-360: what a member costs on a real library

W-134 (d), E-112's form. Registry: E-360. Current numbers: `writeup/design/evidence.md` §1.

**The question.** A package adds one member to a library's trait. What does its image carry: how many instances, of whose methods, and how many bytes? Does it carry the library's generic code again? What does the plain form of the same member carry?

## The packages

`gen.jl <dir>` writes them; `pkgs/` is generated and not committed.

| Package | The member | Its image holds |
|---|---|---|
| ColA0 | `struct Rep{T}`, `Base.eltype`, `@implement Column{T} Rep{T} where {T}` (TraitTables) | the declaration alone |
| ColA1 | the same | and the library's work on it: a table with a `Rep{Float64}` and a `Rep{Int}` column, summarized, sorted and cut |
| PColA0 | `Rep{T} <: AbstractVector{T}` (PlainTables, the plain twin) | the declaration alone |
| PColA1 | the same | and the same work |
| ProbA0 | a parameter struct `LP` and its right-hand side, for TraitDifferentialEquations' problem | the declaration alone |
| ProbA1 | the same | and a solve with Tsit5 |
| ProbA2 | the same | and solves with Tsit5 and Rodas5 |

The ODE member has no plain twin (open issue 160).

## What is counted

`measure.jl <package> <library>...`, in a fresh process, after the library is loaded:
- the valid instances that the package's load adds, by the module of their method and by facts or plain;
- of these, the instances whose signature does not name the member (none of the package's exported names, and not a method of the package);
- the instances that the load ends;
- the image's bytes: the `.ji` and the `.so`;
- the load's time.

## How to run

```
SHOW=40 HEADN=45 bash run.sh e360    # generates pkgs/, a build pass and 2 passes; logs/e360.log
```

## Results (2026-11-10)

`unified` 36b653bb3b, TraitWorld-unified 048c44e, TraitDifferentialEquations-unified 6658c65, TraitTables-unified 160639e, TraitReport-unified a4bcf33. The product setting, strict mode off, one thread. A build pass and 2 passes; the counts and bytes are the same in all three. Load 7.6–8.9 of 128 cores. Idiomatic trait code against a plain twin.

| Package | Instances | by facts | not naming the member | ended | image, `.ji` + `.so` bytes | over the declaration |
|---|---|---|---|---|---|---|
| ColA0 | 0 | 0 | 0 | 0 | 1,657 + 29,568 | |
| ColA1 | 42 | 17 | 14 | 0 | 1,893 + 126,120 | +96.8 kB |
| PColA0 | 0 | 0 | 0 | 0 | 1,569 + 26,640 | |
| PColA1 | 146 | 0 | 14 | 0 | 1,805 + 266,432 | +240.0 kB |
| ProbA0 | 0 | 0 | 0 | 0 | 2,878 + 30,864 | |
| ProbA1 | 65 | 26 | 34 | 0 | 2,965 + 155,488 | +124.7 kB |
| ProbA2 | 68 | 29 | 34 | 0 | 3,053 + 169,512 | +138.8 kB |

By the method's module:
- ColA1: Base 21 (plain), TraitTables 9 (facts), ColA1 8 (facts), Core 4 (plain).
- PColA1: Base 123, PlainTables 12, PColA1 6, Core 5; all plain.
- ProbA1: Base 32 (plain), ODECore 18 (facts), Core 7 (plain), TraitDifferentialEquations 4 (facts), ProbA1 3 (facts), TraitWorld 1 (facts).
- ProbA2: ODECore 19 and TraitDifferentialEquations 5; the rest as ProbA1.

Each load takes 3.2–6.2 ms and ends no instance.

## Reading

- **A declaration costs no instance.** The image of a package that only declares a member holds none, in the trait form and in the plain form.
- **The trait member with its work carries 0.29× the plain twin's instances and 0.40× its added bytes** (42 against 146; 96.8 kB against 240.0 kB). The plain twin compiles Base's `AbstractVector` code for its type (123 instances of Base's methods against 21).
- **No image carries the library's generic code again, but for one instance.** The instances that do not name the member are the workload's own calls into Base: a range collected, a `Vector{Float64}` sorted, the keyword arguments of the call to `solve`. Twelve of the 14 are the same in the trait form and the plain twin. The trait form has one of the library's methods among them: `TableCore.sortperm_col` at `Vector{Float64}`, a type that is no member's.
- **A second solver adds 3 instances and 14 kB** to the parameter struct's image (ProbA2 over ProbA1).
- The library's instances for a member are per member type: 9 of TraitTables' for two cell types of `Rep`, 22 of the ODE library's for `LP` with one solver.

## Logs

`logs/e360.log`.
