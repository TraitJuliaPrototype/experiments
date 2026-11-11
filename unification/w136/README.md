# E-362: error messages for a fixed list of mistakes, trait code against plain Julia (W-136, G-5)

**The question:** for the same mistake, what does a user of a trait library see, and what does a user of the same library in plain Julia see. When is the error raised, what does it name, how long is it. Registry row: `writeup/record/experiments.md` E-362. Current numbers: `writeup/design/evidence.md` §4d.

## The set-up

- **One library, written twice.** `lib_trait.jl`: a trait module with `Shape` (`area`, `perimeter`, a default `label`), generic code over it (`ratio`, `title`, `report`), `Named` (a declared field) and `Scalable` (`scale(s, k::Float64)::Self`). `lib_plain.jl`: the same as an abstract type with documented generic functions.
- **One mistake per case, in both forms:** `cases/<n>_<name>.trait.jl` and `.plain.jl`. The user's code is the same but for how the type joins.
- **Each case is a script in a fresh process,** so the message is what `julia script.jl` prints. A `PHASE` line before each step shows how far the script got.
- **The trait form** runs on `julia-unified` with TraitWorld; again under strict mode (`JULIA_TW_STRICT=1`) for cases 04a, 05 and 06. **The plain form** runs on `julia-vanilla` (v1.13.2), and again on `julia-unified` without the library as a control.

## How to run

```
source ../../../env.sh
bash run.sh            # every case, one process at a time -> logs/<case>.<form>.out, logs/summary.md
bash run.sh 06         # the cases whose name matches
```

- `summarize.py` reads the outputs: the last phase reached, the exception, the message's lines and bytes (from `ERROR:` to `Stacktrace:`), the stack's frames, the first frame's place, the warnings. Two more columns count a pattern of form: signatures printed as a tuple type (`Tuple{typeof(f), …}`), and the library's own frames above the user's line.
- `logs/before-05991fc/`: the first run, on TraitWorld 05991fc, before the messages were changed (below).

## Results, 2026-11-11

`julia-unified` dd3f6d839b, `julia-vanilla` v1.13.2 45b6d15e34, TraitWorld 158d000 (the outputs are the same on 99c4934). Product setting. One run each (the outputs do not vary), load 7 of 128 cores. The plain form's output on the unified build equals vanilla's in every case.

| # | The mistake | Trait form | Plain Julia |
|---|---|---|---|
| 01 | A type joins without one operation | `ImplementError` **at the `@implement` line**. 2 lines, 128 bytes. Names the type, the trait, and the operation with its declared signature | `MethodError` **at the first call**, raised in the library's `ratio`, two frames below the user's line. 2 lines, 167 bytes. Names `perimeter(::Circle)`; nothing says it belongs to an interface |
| 02a | An operation returns `Int`, declared `Float64` | `ImplementError` at the `@implement` line. 2 lines, 153 bytes. Names the operation, the inferred and the declared result | **No message.** The program runs and prints the right number |
| 02b | An operation returns a `Symbol`, declared `String` | `ImplementError` at the `@implement` line. 2 lines, 154 bytes | `MethodError` at the first call, raised in the library's `title`: `no method matching uppercasefirst(::Symbol)`, with three candidates from Base. 10 lines, 455 bytes. Names neither `label` nor the user's method |
| 03a | A value that is no member, passed to a library function | `MethodError` at the call, the user's line first. 7 lines, 426 bytes. Julia's message, and a hint: the value's type is no member of `Shape`, the declared members, and the line that declares one | `MethodError` at the call, the user's line first. 6 lines, 312 bytes |
| 03b | An operation called with an `Int` where `Float64` is declared | `MethodError` at the call. 9 lines, 579 bytes. A hint gives the declared signature. Before it stands Julia's sentence for a thrown `MethodError` ("manually thrown … intentionally marked as unimplemented"), and the first frame and first candidate are the trait's own method, at the `@trait` line | `MethodError` at the call, the user's line first. 6 lines, 350 bytes. The candidate is the user's method, with the argument that differs |
| 04a | A type under two interfaces, one function with a method at each | A **warning at the second `@implement`**, naming the two methods and the joint method. Then `MethodError` at the call, with `tag(::All{Named, Shape})` to define. Under strict mode: `ImplementError` at the second `@implement`, 3 lines, 330 bytes | **Cannot be written:** a type has one supertype. The second interface is a convention with an untyped method, which loses to the method at `Shape` silently. Prints `[shape]` |
| 04b | Two methods that tie for two shapes (`overlap(a::Shape, b)`, `overlap(a, b::Shape)`) | A **warning at the `@implement`**, then the same `MethodError` at the call. 10 lines, 435 bytes | `MethodError` at the call. 10 lines, 435 bytes |
| 05 | A pirate: `Base.uppercasefirst(::String)` redefined, which the library calls | Without strict mode: no message; the library's output changes. Under strict mode: `PirateError` **at the definition**, 3 lines, 484 bytes: the method, the library function whose compiled code it would change, three fixes | No message; the library's output changes |
| 06 | A method defined after the type joined returns a `String` on one branch | `ImplementError` **at the method's definition**; the method does not exist. 5 lines, 488 bytes: the method with its line, the member, the operation's declared signature, the inferred and the declared result, the fix | `MethodError` **at a later call**, raised in Base's `round`, three frames below the user's line: `no method matching round(::String, ::RoundingMode{:Nearest}; digits::Int64)`. 11 lines, 585 bytes |
| 07a | The type never joined | `MethodError` at the call. 7 lines, 392 bytes. A hint: "`Circle` is not a member of `Shape`; `@implement Shape Circle` declares it" | `MethodError` at the call. 6 lines, 311 bytes |
| 07b | `struct Circle <: Shape` with its methods, and no `@implement` | `ImplementError` at the first use. 2 lines, 140 bytes: "struct Circle <: Shape is used before its `@implement Shape Circle`" | **No such mistake:** the subtype declaration is all there is |
| 08 | A type joins inside a running function, which then stores a value in a `Vector{Shape}` | `MethodError` at the `push!`: "Cannot `convert` an object of type Circle to an object of type Shape. The applicable method may be too new: running in world age …". 6 lines, 285 bytes. Names the world, not the membership | **Runs.** A new subtype is seen at once |
| 09 | The library's author reads a field the contract does not give (`s.mass`) | `TraitUseError` **when the library's method is defined**, before any user's type exists. 2 lines, 175 bytes: the function, the field, the line, the trait | `FieldError` **at a user's call**, raised in the library: "type Circle has no field `mass`". 1 line, 84 bytes. The user's type is named as the one at fault |

All counts: `logs/summary.md`. Every message in full: `logs/<case>.<form>.out`.

## Reading

- **Five mistakes are reported earlier by the trait form, at the line that makes them:** 01, 02a, 02b, 06 (the declaration or the definition, against a later call or never) and 09 (the library's build, against a user's session). Two more, 04a and 04b, by a warning at the membership, an error under strict mode.
- **Where plain Julia reports at a call, the error is raised inside the library, or inside Base under it** (01, 02b, 06, 09). The message names the function that happened to fail (`uppercasefirst`, `round`), not the operation the user got wrong. The trait form's messages name the trait, the type, the operation and its declared signature, and are 2 to 5 lines against 1 to 11.
- **Two are the same message with a hint added** (03a, 07a).
- **One is worse in the trait form** (03b): the hint gives the declared signature, but Julia's sentence about a thrown `MethodError` misleads, and the user's own method is the second candidate, not the first.
- **A pirate is silent in both unless strict mode is on** (05).
- **Two failures exist only in the trait form.** 07b: a member by its definition needs its `@implement`; the message names the line to write. 08: a membership is seen from the world of its declaration, where a subtype is seen at once; the message is Julia's for a method too new and does not say that a membership is the cause.
- **02a is a program plain Julia runs correctly, and the trait form refuses.** The contract's result type is what lets the library be compiled once; the refusal is the price, paid at the declaration.

## What the first run found in the trait form's messages, and what was changed

The first run was on `julia-unified` 564a2288e2 with TraitWorld 05991fc (`logs/before-05991fc/`). Fixed in TraitWorld 6a8ee7f and 158d000 (`test/messages.jl`) and `julia-unified` dd3f6d839b:

| Found | Case | Now |
|---|---|---|
| "infers its result as Int64, **wider than** the declared Float64": `Int64` is not wider | 02a, 02b | "outside the declared" where the inferred type is no supertype of the declared one |
| A refused method was headed "Circle cannot be a member of Shape", though it stays one; one line of 450 bytes that also printed the call as `Tuple{typeof(area), Circle}` | 06 | "a method is refused: Circle is a member of Shape, and the method would break its check", on four lines, the fix last |
| Strict mode's refusal printed twice ("caused by: …"), with 15 frames | 04a | once, 7 frames |
| "`getproperty(Main.Geometry.Shape, Symbol)` at line 10 is not in the contract" | 09 | "the field `mass` of a Main.Geometry.Shape at line 10 …" |
| The trait's method for an operation lay at `TraitWorld/src/trait.jl:345` in the candidates and the first frame | 03b | at the user's `@trait` line |
| `@trait_module bounded` was refused, though the syntax summary lists the bare name | 09 | accepted, as `bounded = true` |
| Signatures printed as tuple types, `Tuple{typeof(Geometry.tag), Geometry.Named}`: 12 in the 16 trait runs (the runtime's ambiguity warning, strict mode's refusal built from it, `PirateError`) | 04a, 04b, 05 | 0: `tag(Geometry.Named)` from the runtime, `uppercasefirst(::String)` from the library's one printer (`_callform`), which the pirate's and the untyped receiver's messages use too |

Left, recorded as open issue 177 (`writeup/open-issues.md`):

- The library's own frames stand above the user's line: three at an `@implement`, two at a method's definition, four at the `bounded` check (24 in the 16 trait runs; plain Julia's runs have none of a library's checker, since nothing checks).
- Julia's sentence for a thrown `MethodError` at an operation called outside its declared signature (03b).
- The message for a membership too new (08): the tension GT-14.

## Limits

- The library is small and the mistakes are single. A port's messages against upstream's and against its plain twin's are E-363, `sciml/`: SciML's three error cases, none of them a mistake against a contract, where the port is shorter than upstream and no better than its twin.
- "Names the contract" is read from the messages by hand, case by case; the lines, bytes and frames are counted by `summarize.py`.
- One library author's plain form. A plain library can check an interface by hand (a `hasmethod` test, a test suite for implementers); none is written here.
