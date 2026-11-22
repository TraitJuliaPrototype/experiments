# W-150: `operations(x)` at the REPL

**The item** (the work queue's W-150; the user: "do record operations(x) as an idea. It can wait until everything
else is done."): the operations available on a value or a type, grouped by trait, with their signatures, declared
results, defaults and docstrings; methods of no trait under "other"; a key binding that runs it on the word under the
cursor. It serves G-8 (simplicity, easy to teach): a user at the prompt asks "what can I do with this value?" and gets
the answer the contracts hold. Plain Julia's answer is `methodswith(T)` (InteractiveUtils): the methods of exported
names whose signature names `T` exactly, ungrouped.

The library: TraitWorld branch `w150` (worktree `wt/w158g-tw`), from `unified` 57879c3:
- 59f431e: a docstring before an operation in a trait's body documents its function at the declared signature
  (it was refused as "not an item of a trait's body"; `operations` reads it, and so does `?area`);
- 1d3451f: `operations`, its value and its `show`, the REPL key (`src/operations.jl`), the tests (`test/operations.jl`);
- a5ec7f0: the library's README.

Julia `next` cf0f039f51 (`julia-next`, read only).

## What `operations` shows

`operations(x)` (a value), `operations(T)` (a type, as for its values); the result is an `Operations` value:

| Field | What |
|---|---|
| `subject`, `kind` | the value or type as printed (or the name the key read); `:value`, `:type`, `:box`, `:wrapper`, `:boxtype`, `:trait` |
| `type` | the type whose operations are listed: the object's, for a box or a wrapper |
| `note` | what a box or a wrapper hides; for a function, where its signatures are |
| `traits` | one `TraitOperations` a trait: `trait`, `instance` (at the subject's parameters), `via` (`by the field shape`, `as AbstractVector`, `through Indexable`), `doc` (the trait's docstring, its first line), `operations` and `fields` (each an `OperationLine`: the text as the contract writes it, `note` `"a default"`, `doc`), `methods` (the methods at the trait, as written), `reached` (false behind a box for a trait the box does not reach); then one group per intersection `All{…}` the type is in, with its methods |
| `members` | for a trait: its member patterns in force (a type, a family by its name, an abstract type, a trait) |
| `other`, `more` | the methods at the type's own TypeName, at most `limit` (12), and how many more |

`show` (text/plain) prints the groups, one operation a line, the defaults and docstrings as comments aligned over the
contract's lines. The listing for the tutorial's circle (from `../../docs-examples/logs/tutorial-next-cf0f039f51-tw-a5ec7f0.log`, the script's `Geometry` holding
every section's methods at once):

```
Circle(1.0) is a Circle, a member of Shape

Shape
  operations:
    area(s::Shape)::Float64
    perimeter(s::Shape)::Float64
    describe(s::Shape)::String   # a default
  methods at Shape:
    ratio(s::Shape)
    bigger(a::Shape, b::Shape)
    title(s::Shape)
    fits(s::Shape; within, margin)
    scaled_area(s::Shape, k::Float64)
    scaled_area(s::Shape)
    largest(ss::Shape...)
    kind(s::Shape)
    add!(sc::Scene, s::Shape)

other: methods at Circle
    circle_ratio(c::Circle)
```

The REPL sessions below are the terminal's screen, from Julia's own fake terminal (the REPL's test helper,
`repl_session.jl`); each `julia> name` followed by a listing is Alt-o pressed after typing the name.

### Session 1: the key installed before the REPL starts, on the tutorial's `Shape` (`logs/session1-r2.log`)

```
julia> struct Circle; r::Float64; end

julia> Geometry.area(c::Circle) = π * c.r^2

julia> Geometry.perimeter(c::Circle) = 2π * c.r

julia> @implement Shape Circle

julia> c = Circle(1.0)
Circle(1.0)

julia> c
c is a Circle, a member of Shape

Shape
  operations:
    area(s::Shape)::Float64      # The area of the shape.
    perimeter(s::Shape)::Float64
    describe(s::Shape)::String   # a default
  methods at Shape:
    ratio(s::Shape)
    bigger(a::Shape, b::Shape)
    title(s::Shape)

julia> Shape
Shape: a trait with 1 declared member

Shape
  operations:
    area(s::Shape)::Float64      # The area of the shape.
    perimeter(s::Shape)::Float64
    describe(s::Shape)::String   # a default
  methods at Shape:
    ratio(s::Shape)
    bigger(a::Shape, b::Shape)
    title(s::Shape)

members
    Circle

julia> d = Dynamic{Shape}(c);

julia> d
d holds a Circle, a member of Shape
the box: only the operations and declared fields of Shape and its supertraits reach the Circle it holds; the rest needs unwrap(x)

Shape
  operations:
    area(s::Shape)::Float64      # The area of the shape.
    perimeter(s::Shape)::Float64
    describe(s::Shape)::String   # a default
  methods at Shape:
    ratio(s::Shape)
    bigger(a::Shape, b::Shape)
    title(s::Shape)

julia> x = 1.5
operations: ArgumentError: `1.5` is not a name

julia> x = 1.5;

julia> x
x is a Float64, a member of BoundedText

BoundedText, as Number
  # A value whose printed form has a known upper bound in bytes: `t…
  operations:
    textbound(x::BoundedText)::Int # An upper bound on the bytes `print(io, x)` writes. For a type, …

other: methods at Float64
    <(x::Int64, y::Float64)
    <(x::UInt64, y::Float64)
    <(x::Int128, y::Float64)
    <(x::UInt128, y::Float64)
    <(x::Float64, y::UInt128)
    <(x::Float64, y::Int128)
    <(x::Float64, y::UInt64)
    <(x::Float64, y::Int64)
    <(x::AbstractIrrational, y::Float64)
    <(x::Float64, y::AbstractIrrational)
    <=(x::UInt64, y::Float64)
    <=(x::Int128, y::Float64)
    … and 74 more (operations(x; limit = 86))
```

### Session 2: the key installed into a running REPL, on the demonstrators (`logs/session2-r2.log`)

A TraitTables column (a `Vector{Float64}`: `Column{Float64}`, BaseTraits' five, TraitMakie's `Sample`), an ODE problem
of the ODE port, a TraitMakie figure (a member of no trait: "other" only) and one of its plots, which an axis keeps boxed.

```
julia> using TraitTables, TraitDifferentialEquations, TraitMakie

julia> t = TraitTables.table("x" => [1.0, 2.0, 3.0], "n" => [1, 2, 3]);

julia> col = t["x"];

julia> TraitWorld.install_operations_key!(REPL_UNDER_TEST)

julia> col
col is a Vector{Float64}, a member of Column{Float64}, HasLength, Indexable{Float64}, Iterable{Float64}, MutableIndexable{Float64}, Resizable{Float64}, Sample

Column{T}, T = Float64
  # A column: its number of rows and its cells by index; `T` is the…
  operations:
    nrows(c::Column)::Int
    cell(c::Column{T}, i::Int)::T
  methods at Column:
    addcolumn!(t::Table, name::String, c::Column)
    take(c::Column, idx::Vector{Int64})
    sortperm_col(c::Column)
    floats(c::Column, skip::Bool)
    floats(c::Column)
    numsummary(c::Column, name::String, n::Int64, nmiss::Int64, T::String)
    othersummary(c::Column{E}, name::String, n::Int64, nmiss::Int64, T::String) where E
    summarize(c::Column, name::String)
    cellstring(c::Column, i::Int64)

HasLength, through Indexable
  # A finite number of items: `length(c)::Int`, expected in constan…
  operations:
    length(c::HasLength)::Int # Return the number of elements in the collection.

Indexable{T}, T = Float64 <: HasLength, through MutableIndexable
  # Reading by position: `c[i]` is a `T` for `i` in `firstindex(c):…
  operations:
    getindex(c::Indexable, i::Int)::T # Retrieve the value(s) stored at the given key or index within a…
    firstindex(c::Indexable)::Int     # Return the first index of `collection`. If `d` is given, return…
  methods at Indexable:
    asvector(x::Indexable{T}) where T

Iterable{T}, T = Float64, as AbstractArray
  # Base's iteration protocol, with the item type `T = eltype(Self)…
  operations:
    iterate(c::Iterable)::Union{Nothing, Tuple{T, Any}} # Advance the iterator to obtain the next element. If no elements
    iterate(c::Iterable, state)::Union{Nothing, Tuple{T, Any}} # Advance the iterator to obtain the next element. If no elements

MutableIndexable{T}, T = Float64 <: Indexable{T}
  # Writing by position: `c[i] = x` for an `x` of the item type kee…
  operations:
    setindex!(c::MutableIndexable, x::T, i::Int)::Any # Store the given value at the given key or index within a collec…

Resizable{T}, T = Float64 <: HasLength
  # Changing the number of items: `push!(c, x)` adds an item of the…
  operations:
    resize!(c::Resizable, n::Int)::Any # Resize `a` to contain `n` elements. If `n` is smaller than the …
    push!(c::Resizable, x::T)::Any     # Insert one or more `items` in `collection`. If `collection` is …

Sample
  # Values a histogram bins, by index.
  operations:
    nvalues(s::Sample)::Int
    value(s::Sample, i::Int)::Float64
  methods at Sample:
    binned(s::Sample, bins::Int64)
    add_hist!(ax::Axis, values::Sample, bins::Int64, color::ColorSpec)

methods at All{MutableIndexable{T}, Resizable{T}}
    retain!(f::Callable{Tuple{T}, Bool}, xs::All{MutableIndexable{T}, Resizable{T}}) where T

other: methods at Vector{Float64}
    +(A::Array, Bs::Array...)
    append!(a::Vector{T}, items::Union{Tuple, AbstractVector{<:T}}) where T
    cconvert(::Type{<:Ptr}, a::Array)
    cconvert(::Type{Ptr{P}}, a::Array) where P<:Union{Cstring, Cwstring, Ptr}
    cconvert(::Type{Ref{P}}, a::Array) where P<:Union{Cstring, Cwstring, Ptr}
    copy(a::Array)
    copyto!(dest::Array, doffs::Integer, src::Array, soffs::Integer, n::Integer)
    copyto!(dest::Array, doffs::Integer, src::Memory, soffs::Integer, n::Integer)
    copyto!(dest::Memory, doffs::Integer, src::Array, soffs::Integer, n::Integer)
    copyto!(dest::Array{T}, doffs::Integer, src::Array{T}, soffs::Integer, n::Integer) where T
    copyto!(dest::Array, src::Array)
    copyto!(dest::Array, src::Memory)
    … and 92 more (operations(x; limit = 104))

julia> f(du, u, p, t) = (du .= -p .* u; nothing)
f (generic function with 1 method)

julia> prob = ODEProblem(f, [1.0, 2.0], (0.0, 1.0), 0.5);

julia> prob
prob is an ODEProblem{…}, a member of HasCallbacks, HasJacobianPrototype, HasMassMatrix, ODEProblemTrait{Float64, Float64}, HasSystem

HasCallbacks
  # A problem that keeps callbacks (SciML's `ODEProblem(…; callback…
  operations:
    problem_callbacks(x::HasCallbacks)::Any

HasJacobianPrototype
  # A value with a Jacobian's sparsity prototype (SciML's `f.jac_pr…
  operations:
    jac_prototype(x::HasJacobianPrototype)::Any

HasMassMatrix
  # A value with a mass matrix `M` (SciML's `f.mass_matrix`): the p…
  operations:
    mass_matrix(x::HasMassMatrix)::Any

ODEProblemTrait{T, P}, T = Float64, P = Float64
  # What the solver needs from a problem: its initial state, time s…
  operations:
    rhs!(prob::ODEProblemTrait{T, P}, du::Vector{T}, u::Vector{T}, t::Float64)::Nothing
    jacobian!(prob::ODEProblemTrait{T, P}, J::Matrix{T}, u::Vector{T}, t::Float64)::Nothing # a default
    rhs_function(prob::ODEProblemTrait{T, P})::Any # a default; The user's function partially evaluated, for a solver that pick…
  fields:
    @const u0::Vector{T}
    @const tspan::Tuple{Float64, Float64}
    @const p::P
  methods at ODEProblemTrait:
    core_problem(prob::ODEProblemTrait{T, P}) where {T, P}
    with_problem(s::ODECore.CoreSolution{T}, prob::ODEProblemTrait{T, P}, sys, names, pt::Vector{Float64}, pu::Vector{P}) where {T, P}

HasSystem
  # A value that carries a system object (SciML's `f.sys`, `prob.f.…
  operations:
    system(x::HasSystem)::Any
  methods at HasSystem:
    getsystem(x::HasSystem)

other: methods at ODEProblem{…}
    core_problem(prob::ODEProblem{T, P, F, J}) where {T, P, F, J}
    remake(prob::ODEProblem; u0, tspan, p, callback)

julia> fig = Figure(size = (400, 300));

julia> fig
fig is a Figure, a member of no trait

other: methods at Figure
    add_axis!(f::Figure, row::Int64, col::Int64, xscale::Scale, yscale::Scale, title::String, xlabel::String, ylabel::String)
    render_png(f::Figure, path::String, px_per_unit::Float64)
    render_png(f::Figure, path::String)
    band!(fig::Figure, x::AbstractVector, lower::AbstractVector, upper::AbstractVector; kw...)
    band!(fig::Figure, lower, upper; color)
    barplot!(fig::Figure, x::AbstractVector, y::AbstractVector; color, width)
    getindex(fig::Figure, r::Integer, c::Integer)
    hist!(fig::Figure, x; bins, color)
    lines!(fig::Figure, x::AbstractVector, y::AbstractVector; kw...)
    lines!(fig::Figure, data; color, linewidth)
    plot!(fig::Figure, p)
    poly!(fig::Figure, x::AbstractVector, y::AbstractVector; kw...)
    … and 12 more (operations(x; limit = 24))

julia> fl = lines([1.0, 2.0, 3.0], [1.0, 4.0, 9.0]);

julia> pl = fl.axes[1].plots[1];

julia> pl
pl holds a Lines, a member of Plot
the box: only the operations and declared fields of Plot and its supertraits reach the Lines it holds; the rest needs unwrap(x)

Plot
  # A recipe: its data limits, how it draws itself onto a canvas, a…
  operations:
    datalimits(p::Plot)::NTuple{4, Float64}
    draw!(p::Plot, c::Canvas, t::Transform2D)::Nothing
    setcolor!(p::Plot, c::ColorSpec)::Nothing
  methods at Plot:
    add_plot!(ax::Axis, p::Plot)

julia> ODEProblemTrait
ODEProblemTrait: a trait with 1 declared member

ODEProblemTrait{T, P}
  # What the solver needs from a problem: its initial state, time s…
  operations:
    rhs!(prob::ODEProblemTrait{T, P}, du::Vector{T}, u::Vector{T}, t::Float64)::Nothing
    jacobian!(prob::ODEProblemTrait{T, P}, J::Matrix{T}, u::Vector{T}, t::Float64)::Nothing # a default
    rhs_function(prob::ODEProblemTrait{T, P})::Any # a default; The user's function partially evaluated, for a solver that pick…
  fields:
    @const u0::Vector{T}
    @const tspan::Tuple{Float64, Float64}
    @const p::P
  methods at ODEProblemTrait:
    core_problem(prob::ODEProblemTrait{T, P}) where {T, P}
    with_problem(s::ODECore.CoreSolution{T}, prob::ODEProblemTrait{T, P}, sys, names, pt::Vector{Float64}, pu::Vector{P}) where {T, P}

members
    ODEProblem
```

## The choices (mine), each with its reason

1. **The order of the traits:** the traits of the type's own module first, then the others, each by name. The type's
   own module's traits are what its author made it for; by name is an order a reader can scan. A subtrait's header
   names its supertraits (`Indexable{T}, T = Float64 <: HasLength`), and the supertrait's group says how the member
   reaches it (`through Indexable`).
2. **A method at a supertrait is listed under the supertrait,** the trait its signature names: each group is one
   trait's contract and its methods, and the supertrait has its own group (a member of the subtrait is a member of it).
   No method is listed twice.
3. **"other" is bounded:** at most `limit = 12` methods, then `… and N more (operations(x; limit = M))`. It lists the
   methods whose argument is declared at the type's own TypeName (`Vector{Float64}` takes `Array{T}` and `Vector{T}`;
   a `Union` that contains the type does not, as for `methodswith`), of functions a user can call by name: public in
   their module (exported or `public`), or of `Main`, or of the type's own module; not constructors, macros, names
   that start with `_`, Core's and the compiler's own methods, nor the members' methods of the operations listed
   above. Order: the type's module and `Main` first, then Base, then the rest, each by name. Without the bound a
   `Float64` lists 86 methods (on this build, the library and the REPL loaded: `logs/session1-r2.log`).
4. **Names:** as Julia prints them from `Main`, so a module prefix appears only where the name is not visible from
   `Main` (`plainop(p::Main.operations.Plain)` in the suite's module). A type whose printed form is longer than 48
   characters, or holds a kept form the user did not write (an ODE problem holds the box the port made of the user's
   function), is named `ODEProblem{…}`: its parameters are in the trait headers (`ODEProblemTrait{T, P}, T = Float64,
   P = Float64`). An operation prints as its contract writes it (`get(d::Keyed, k::K, default::D)::Union{V, D} where
   {D}`), with the trait's parameter names; a method as its signature is written, the keywords by name.
5. **Docstrings:** an operation's is the docstring at a signature that names the trait, else the function's own (for
   no signature), else the only one; its first line of prose. For another owner's function (Base's `length` in
   `HasLength`) that is Base's line. A docstring in the trait's body (59f431e) is the first kind.
6. **`Callable`** is not listed for a function: every function is a member of every signature its methods take, so
   the group would hold nothing particular to the function. The note points to `methods(f)`. `operations(Callable)`
   lists it; a box of `Callable` lists it.
7. **A box:** the object's groups, the box's trait and its supertraits marked reached, the others `(through
   unwrap(x))`, and "other" `(through unwrap(x))`; the note says that only the trait's operations and fields reach the
   object. **A wrapper:** the object's groups, all reached (the wrapper is a member of each of its object's traits);
   "other" through `unwrap(x)`.
8. **Not compiled into the image:** `operations` is a function a user calls, its entry a run-time site
   (`_runtime_site`, the rule of `../w167/README.md`); the first call in a session compiles it (1.8 s on this machine;
   later calls 0.1–0.3 s, a walk over every method, about 27 000).

## The key

- **Alt-o** (`"\eo"`, o for operations). Julia's REPL binds Alt-b, -c, -d, -e, -f, -l, -m, -n, -p, -t, -u, -w, -W, -y,
  -`.`, -`<`, -`>`, -`_` and Alt-Enter (`stdlib/REPL/src/LineEdit.jl` on `next`), not Alt-o. `"\eO"` (capital) is the
  terminals' prefix for function keys; lowercase `o` is not. `key = "…"` chooses another.
- **No package extension.** An extension on `REPL` would need `[weakdeps]` and `[extensions]` in the library's
  Project, and every manifest that develops the library resolved again, and it would rebind a key at `using
  TraitWorld` without being asked. `TraitWorld.install_operations_key!(repl = Base.active_repl)` reaches the REPL
  through `Base.REPL_MODULE_REF`:
  - before the REPL starts (from `atreplinit`): the interface is made with the key, `REPL.setup_interface(repl;
    extra_repl_keymap)`, as Julia's manual shows for a custom key;
  - in a running REPL: the key merged into the Julia prompt's keymap (`LineEdit.keymap_merge`).
- **For `startup.jl`:**

  ```julia
  atreplinit(repl -> (@eval using TraitWorld; TraitWorld.install_operations_key!(repl)))
  ```

  or at the prompt, `TraitWorld.install_operations_key!()`.
- **What it reads:** the word under the cursor with its dots (`LineEdit.current_word_with_dots`), a name or a dotted
  path, evaluated in the REPL's active module; anything else (a literal, a call) prints `operations: ArgumentError:
  … is not a name` and evaluates nothing. The listing prints below the line, which is redrawn as it was.

## How to run

```sh
cd /p/projects/coen/julia-trait-bound && source env.sh
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w150:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
cd experiments/implementation/w150
cp ../w158/g-probes/env_demo_g/Manifest.toml env/      # the environment: the library at wt/w158g-tw, the demonstrators
nice ../../../julia-next/julia --project=env repl_session.jl 1 > logs/session1-r2.log
nice ../../../julia-next/julia --project=env repl_session.jl 2 > logs/session2-r2.log
bash loadtime.sh                                       # the library's load, before (57879c3) and after (w150)
```

## Results, 2026-11-22

Builds: julia `next` cf0f039f51; TraitWorld `w150` a5ec7f0 (the code as at 1d3451f; a5ec7f0 adds the README);
TraitTables e1ec1f4, TraitDifferentialEquations 06c28c3, TraitMakie 1888698 (read only). Product setting, strict mode
off, niced, one Julia job at a time; the machine 128 cores, its 1-minute load 2.6 to 8.3 (others' jobs). The depot
`agent-depots/w150` stacked before the shared one.

| Check | Result |
|---|---|
| the library's suite (`logs/suite-r3.log`, a5ec7f0; `julia --project=. -e 'using TraitWorld; include("test/runtests.jl")'`) | 120 testsets pass (118 before; `core.jl`'s "a docstring in a trait's body" and `operations.jl`'s "operations", 67 checks) |
| the first commit alone (`logs/test-core-at-59f431e.log`) | `core.jl` at 59f431e passes, with its new testset (6 checks) |
| the docs' examples (`../../docs-examples/logs/*-next-cf0f039f51-tw-a5ec7f0.log`) | intro 33, tutorial 129 (126 and §4's three checks of `operations(Circle(1.0))`), strict 10; no failure, no deviation |
| the gates (`logs/gates-r1.log`; `LIB=wt/w158g-tw`, the code of 1d3451f) | 75 of 75, `n36_library_deep` among them (`OUTSIDE 0`, behind a run-time site by intent 7, named exceptions 2, of 362 instances: the image holds none of `operations`); stage gates 9 of 9 |
| the library's load (`logs/loadtime-r1.log`, `loadtime.sh`; a warm-up and 3 runs, a fresh process each; load 3.7–3.9) | `using TraitWorld`: 57879c3 56.1, 56.2, 56.6 ms; w150 55.8, 56.8, 56.5 ms: within the runs' spread |
| no form of the machinery in a listing (`test/operations.jl`) | no `Tuple{typeof(`, `var"#`, `##`, and no `Dynamic{` where none was written, for a member, a member of two traits, a forwarding member, a trait, a `Float64`, a `Vector{Float64}`, a plain struct and a function |
| the key, both ways of installing it (`logs/session1-r2.log`, `logs/session2-r2.log`) | the listings above, below the prompt's line; a literal under the cursor gives `ArgumentError: … is not a name` |

The demonstrators' environment (`env/`, the manifest copied from `../w158/g-probes/env_demo_g`, which points at this
worktree) compiled the three packages against the library in 42 s (`logs/env-precompile.log`).

## Not verified

- **A real terminal.** The key was driven through the REPL's fake terminal (pipes, 80 columns, no colour), as the
  REPL's own tests drive it; not typed in a terminal emulator. With colour, the headers print bold; not seen.
- **Pressed mid-line.** The sessions press the key at the end of the line. On a word in the middle of a line, or with
  the cursor just after `)`, `current_word_with_dots` decides what is read (`Dynamic{Shape}(c)` with the cursor at the
  end reads `c)`, which is no name).
- **Other REPL modes.** The key is bound at the Julia prompt only, not in help, shell or Pkg mode; with another key
  map installed by a package (OhMyREPL) after it, not tried.
- **Ports' types beyond the three.** The forks, NetworkDynamics, TraitCSV: not tried.
- **The cost on a large session.** The walk over every method took 0.1–0.3 s with the three demonstrators loaded
  (about 27 000 methods); not measured with the forks or a larger image.
- **"other" for `Any`, a `Union`, a `UnionAll` type given as `T`:** they give what the rule gives (for `Any`, every
  method with an untyped argument, bounded); not tested.
- **Docstrings for another owner's function** show that owner's line (Base's `length`): the rule, not a docstring the
  trait wrote. A trait that wants its own line documents the operation in its body; BaseTraits does not yet.
- The first call in a session compiles `operations` (1.8 s in a script; not measured at the REPL).
