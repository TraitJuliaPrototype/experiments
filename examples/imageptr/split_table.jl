# A split's table kept in a package image: HShapes' `total` is compiled in its workload over 64
# implementations, so the table of its split's last branch was filled while the image was built,
# with that session's pointers. In a new session the table must count as empty and fill again,
# not call them (julia-1.13 711484a23e, compiler §4.3).
#     julia --project=env imageptr/split_table.jl
include(joinpath(@__DIR__, "..", "common.jl"))
using HShapes, TraitWorld
const SC = HShapes.ShapeCore
"This session's split tables, by signature (the registry the inliner fills when it compiles a split)."
tables() = (t = @atomic Base.Compiler.SPLIT_TABLES.table; t === nothing ? Any[] : collect(keys(t)))
fromhere(k) = k[1] <: TraitWorld._DynOp && k[1].parameters[1] === SC.Shape
v = HShapes.traitvals(64)
before = count(fromhere, tables())
r1 = SC.total(v); r2 = SC.total(v)
alloc(v) = (SC.total(v); @allocated SC.total(v))
check("a split's table kept in a package image is filled again in a new session: the right sum, twice", r1 == r2 == sum(1.0:64.0))
check("the table used is the image's: `total` was not compiled again here, so this session made no table for its signature",
      before == 0 && count(fromhere, tables()) == 0)
check("once filled, a call costs no allocation", alloc(v) == 0)
summary()
