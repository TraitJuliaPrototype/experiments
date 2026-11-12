# W-143: a fully typed Base surface for trait code. The tool (E-368)

Open issue 179: with "fully typed is exactly what compiles ahead", a hole in Base below a trait program fails its build. The question here: how many holes there are at the signatures typed code calls Base with, and whether a few functions carry them.

## The tool

`base_surface.jl` takes each exported function of the modules named. It tries one argument of each of twelve broad types (`String`, `Int`, `Float64`, `Bool`, `Char`, `Symbol`, vectors of `Int`, `Float64` and `String`, a `Dict{String,Int}`, a `Tuple{Int,Int}`, a `UnitRange{Int}`), and pairs `(T, T)`, `(T, Int)`, `(T, String)`. A signature counts where the function has a method and inference gives a result. It asks `fully_typed` at each, and groups the holes by their root cause and by the function they sit in. Nothing is run: the functions are only inferred.

```
cd TraitWorld-unified && source ../env.sh
../julia-unified/julia -t 1 --startup-file=no --project=. ../experiments/unification/w143/base_surface.jl 600
../julia-unified/julia -t 1 --startup-file=no --project=. ../experiments/unification/w143/base_surface.jl 400 LinearAlgebra Statistics Random Dates Printf
```

The first argument is a budget in seconds; functions left when it runs out are counted.

## Results, 2026-11-12 (`unified` f6ad3008b4, TraitWorld `unified` 4a1dc03; one run each; load 2 to 5 of 128; `logs/base.log`, `logs/stdlibs.log`)

| | Base | LinearAlgebra, Statistics, Random, Dates, Printf |
|---|---|---|
| exported functions looked at | 837 | 183 |
| signatures with a method and a result | 6,179 | 474 |
| fully typed | 4,413 (71.4 %) | 326 (68.8 %) |
| with a hole | 1,244 (20.1 %) | 148 (31.2 %) |
| the report itself failed | 522 (8.4 %) | 0 |
| exported functions with a hole at some signature | 164 | 36 |
| functions the holes sit in | 106 | 27 |
| sites, and the share of the first 5 and the first 20 of those functions | 11,819; 73 %, 91 % | 932; 52 %, 98 % |
| signatures whose only cause is a call at a union the session does not split | 166 | 36 |

**Where the holes sit in Base** (sites): `typejoin` 3,808; `ntuple` 2,082; `setproperty!` 2,020; `rehash!` 364; `_growend_internal!` 312; `current_exceptions` 288; `summarysize` 275; `to_tuple_type` 246; `collect` 230.

**The causes, by kind:**
- **Paths that build an error:** the exception stack and backtrace formatting (`current_exceptions`, `_reformat_bt`), reached from growing an array or rehashing a dictionary. About 100 signatures each.
- **A field set by a name that is not a constant:** `setproperty!` converts to `fieldtype(…)`, a `Type`. 351 signatures.
- **Reflection and type computation:** `typejoin`, `code_lowered`, `methods`, `rewrap_unionall`. By purpose.
- **`IO`:** `print` and `println` at 46 signatures each, `display`, `redisplay`. By purpose (GT-5, GT-10).
- **Logging and deprecation:** a call in the latest world (`invokelatest` to the logger), `depwarn`.
- **A call at a small union:** 166 signatures have only this cause. A build splits such a call; the session's report does not (traits T-107). These are not holes of Base.

## What it says

- The holes are concentrated: five functions hold 73 % of Base's sites, twenty hold 91 %. A programme of small patches is plausible for the paths that build an error, `setproperty!` and `ntuple`.
- Reflection, `IO` and logging are dynamic by purpose, as open issue 179 expected.
- The report is the session's. It over-counts (the union case) and can miss a hole a build finds (Base's `repeat(::Char, ::Int)` is reported fully typed here and failed TraitTables' build, E-364). The build's own verdict per signature is the next step, with W-142.
- The report failed on 522 signatures of Base: a defect of the library's report to fix with W-142.
- Signatures are tried by type alone, so some are calls no program makes (`foldl(String, String)`). They inflate both columns.
