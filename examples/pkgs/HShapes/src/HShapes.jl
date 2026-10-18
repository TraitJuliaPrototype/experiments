"""
Heterogeneous collections at scale (examples/heterogeneous): a trait `Shape` with 64 conformances
in this image, and the plain twin, an abstract type `PShape` with 64 subtypes.
"""
module HShapes
using TraitWorld
@trait_module module ShapeCore
using TraitWorld
export Shape, area, total, mk, nshapes
@trait Shape{R} begin
    area(r::R)::Float64
end
"The sum of the areas: one worker, whatever the conformances."
total(v::Vector{Dynamic{Shape}}) = (s = 0.0; for d in v; s += area(d); end; s)
mk(x) = Dynamic{Shape}(x)
struct H1; a::Float64; end
@implement Shape{H1} begin area(s) = 1.0 * s.a end
struct H2; a::Float64; end
@implement Shape{H2} begin area(s) = 2.0 * s.a end
struct H3; a::Float64; end
@implement Shape{H3} begin area(s) = 3.0 * s.a end
struct H4; a::Float64; end
@implement Shape{H4} begin area(s) = 4.0 * s.a end
struct H5; a::Float64; end
@implement Shape{H5} begin area(s) = 5.0 * s.a end
struct H6; a::Float64; end
@implement Shape{H6} begin area(s) = 6.0 * s.a end
struct H7; a::Float64; end
@implement Shape{H7} begin area(s) = 7.0 * s.a end
struct H8; a::Float64; end
@implement Shape{H8} begin area(s) = 8.0 * s.a end
struct H9; a::Float64; end
@implement Shape{H9} begin area(s) = 9.0 * s.a end
struct H10; a::Float64; end
@implement Shape{H10} begin area(s) = 10.0 * s.a end
struct H11; a::Float64; end
@implement Shape{H11} begin area(s) = 11.0 * s.a end
struct H12; a::Float64; end
@implement Shape{H12} begin area(s) = 12.0 * s.a end
struct H13; a::Float64; end
@implement Shape{H13} begin area(s) = 13.0 * s.a end
struct H14; a::Float64; end
@implement Shape{H14} begin area(s) = 14.0 * s.a end
struct H15; a::Float64; end
@implement Shape{H15} begin area(s) = 15.0 * s.a end
struct H16; a::Float64; end
@implement Shape{H16} begin area(s) = 16.0 * s.a end
struct H17; a::Float64; end
@implement Shape{H17} begin area(s) = 17.0 * s.a end
struct H18; a::Float64; end
@implement Shape{H18} begin area(s) = 18.0 * s.a end
struct H19; a::Float64; end
@implement Shape{H19} begin area(s) = 19.0 * s.a end
struct H20; a::Float64; end
@implement Shape{H20} begin area(s) = 20.0 * s.a end
struct H21; a::Float64; end
@implement Shape{H21} begin area(s) = 21.0 * s.a end
struct H22; a::Float64; end
@implement Shape{H22} begin area(s) = 22.0 * s.a end
struct H23; a::Float64; end
@implement Shape{H23} begin area(s) = 23.0 * s.a end
struct H24; a::Float64; end
@implement Shape{H24} begin area(s) = 24.0 * s.a end
struct H25; a::Float64; end
@implement Shape{H25} begin area(s) = 25.0 * s.a end
struct H26; a::Float64; end
@implement Shape{H26} begin area(s) = 26.0 * s.a end
struct H27; a::Float64; end
@implement Shape{H27} begin area(s) = 27.0 * s.a end
struct H28; a::Float64; end
@implement Shape{H28} begin area(s) = 28.0 * s.a end
struct H29; a::Float64; end
@implement Shape{H29} begin area(s) = 29.0 * s.a end
struct H30; a::Float64; end
@implement Shape{H30} begin area(s) = 30.0 * s.a end
struct H31; a::Float64; end
@implement Shape{H31} begin area(s) = 31.0 * s.a end
struct H32; a::Float64; end
@implement Shape{H32} begin area(s) = 32.0 * s.a end
struct H33; a::Float64; end
@implement Shape{H33} begin area(s) = 33.0 * s.a end
struct H34; a::Float64; end
@implement Shape{H34} begin area(s) = 34.0 * s.a end
struct H35; a::Float64; end
@implement Shape{H35} begin area(s) = 35.0 * s.a end
struct H36; a::Float64; end
@implement Shape{H36} begin area(s) = 36.0 * s.a end
struct H37; a::Float64; end
@implement Shape{H37} begin area(s) = 37.0 * s.a end
struct H38; a::Float64; end
@implement Shape{H38} begin area(s) = 38.0 * s.a end
struct H39; a::Float64; end
@implement Shape{H39} begin area(s) = 39.0 * s.a end
struct H40; a::Float64; end
@implement Shape{H40} begin area(s) = 40.0 * s.a end
struct H41; a::Float64; end
@implement Shape{H41} begin area(s) = 41.0 * s.a end
struct H42; a::Float64; end
@implement Shape{H42} begin area(s) = 42.0 * s.a end
struct H43; a::Float64; end
@implement Shape{H43} begin area(s) = 43.0 * s.a end
struct H44; a::Float64; end
@implement Shape{H44} begin area(s) = 44.0 * s.a end
struct H45; a::Float64; end
@implement Shape{H45} begin area(s) = 45.0 * s.a end
struct H46; a::Float64; end
@implement Shape{H46} begin area(s) = 46.0 * s.a end
struct H47; a::Float64; end
@implement Shape{H47} begin area(s) = 47.0 * s.a end
struct H48; a::Float64; end
@implement Shape{H48} begin area(s) = 48.0 * s.a end
struct H49; a::Float64; end
@implement Shape{H49} begin area(s) = 49.0 * s.a end
struct H50; a::Float64; end
@implement Shape{H50} begin area(s) = 50.0 * s.a end
struct H51; a::Float64; end
@implement Shape{H51} begin area(s) = 51.0 * s.a end
struct H52; a::Float64; end
@implement Shape{H52} begin area(s) = 52.0 * s.a end
struct H53; a::Float64; end
@implement Shape{H53} begin area(s) = 53.0 * s.a end
struct H54; a::Float64; end
@implement Shape{H54} begin area(s) = 54.0 * s.a end
struct H55; a::Float64; end
@implement Shape{H55} begin area(s) = 55.0 * s.a end
struct H56; a::Float64; end
@implement Shape{H56} begin area(s) = 56.0 * s.a end
struct H57; a::Float64; end
@implement Shape{H57} begin area(s) = 57.0 * s.a end
struct H58; a::Float64; end
@implement Shape{H58} begin area(s) = 58.0 * s.a end
struct H59; a::Float64; end
@implement Shape{H59} begin area(s) = 59.0 * s.a end
struct H60; a::Float64; end
@implement Shape{H60} begin area(s) = 60.0 * s.a end
struct H61; a::Float64; end
@implement Shape{H61} begin area(s) = 61.0 * s.a end
struct H62; a::Float64; end
@implement Shape{H62} begin area(s) = 62.0 * s.a end
struct H63; a::Float64; end
@implement Shape{H63} begin area(s) = 63.0 * s.a end
struct H64; a::Float64; end
@implement Shape{H64} begin area(s) = 64.0 * s.a end
const nshapes = 64
end
using .ShapeCore
export Shape, area, total, mk

"The plain twin: an abstract type and methods; `ptotal` dispatches on each element."
module PlainShapes
abstract type PShape end
function parea end
ptotal(v::Vector{PShape}) = (s = 0.0; for x in v; s += parea(x); end; s)
struct P1 <: PShape; a::Float64; end
parea(s::P1) = 1.0 * s.a
struct P2 <: PShape; a::Float64; end
parea(s::P2) = 2.0 * s.a
struct P3 <: PShape; a::Float64; end
parea(s::P3) = 3.0 * s.a
struct P4 <: PShape; a::Float64; end
parea(s::P4) = 4.0 * s.a
struct P5 <: PShape; a::Float64; end
parea(s::P5) = 5.0 * s.a
struct P6 <: PShape; a::Float64; end
parea(s::P6) = 6.0 * s.a
struct P7 <: PShape; a::Float64; end
parea(s::P7) = 7.0 * s.a
struct P8 <: PShape; a::Float64; end
parea(s::P8) = 8.0 * s.a
struct P9 <: PShape; a::Float64; end
parea(s::P9) = 9.0 * s.a
struct P10 <: PShape; a::Float64; end
parea(s::P10) = 10.0 * s.a
struct P11 <: PShape; a::Float64; end
parea(s::P11) = 11.0 * s.a
struct P12 <: PShape; a::Float64; end
parea(s::P12) = 12.0 * s.a
struct P13 <: PShape; a::Float64; end
parea(s::P13) = 13.0 * s.a
struct P14 <: PShape; a::Float64; end
parea(s::P14) = 14.0 * s.a
struct P15 <: PShape; a::Float64; end
parea(s::P15) = 15.0 * s.a
struct P16 <: PShape; a::Float64; end
parea(s::P16) = 16.0 * s.a
struct P17 <: PShape; a::Float64; end
parea(s::P17) = 17.0 * s.a
struct P18 <: PShape; a::Float64; end
parea(s::P18) = 18.0 * s.a
struct P19 <: PShape; a::Float64; end
parea(s::P19) = 19.0 * s.a
struct P20 <: PShape; a::Float64; end
parea(s::P20) = 20.0 * s.a
struct P21 <: PShape; a::Float64; end
parea(s::P21) = 21.0 * s.a
struct P22 <: PShape; a::Float64; end
parea(s::P22) = 22.0 * s.a
struct P23 <: PShape; a::Float64; end
parea(s::P23) = 23.0 * s.a
struct P24 <: PShape; a::Float64; end
parea(s::P24) = 24.0 * s.a
struct P25 <: PShape; a::Float64; end
parea(s::P25) = 25.0 * s.a
struct P26 <: PShape; a::Float64; end
parea(s::P26) = 26.0 * s.a
struct P27 <: PShape; a::Float64; end
parea(s::P27) = 27.0 * s.a
struct P28 <: PShape; a::Float64; end
parea(s::P28) = 28.0 * s.a
struct P29 <: PShape; a::Float64; end
parea(s::P29) = 29.0 * s.a
struct P30 <: PShape; a::Float64; end
parea(s::P30) = 30.0 * s.a
struct P31 <: PShape; a::Float64; end
parea(s::P31) = 31.0 * s.a
struct P32 <: PShape; a::Float64; end
parea(s::P32) = 32.0 * s.a
struct P33 <: PShape; a::Float64; end
parea(s::P33) = 33.0 * s.a
struct P34 <: PShape; a::Float64; end
parea(s::P34) = 34.0 * s.a
struct P35 <: PShape; a::Float64; end
parea(s::P35) = 35.0 * s.a
struct P36 <: PShape; a::Float64; end
parea(s::P36) = 36.0 * s.a
struct P37 <: PShape; a::Float64; end
parea(s::P37) = 37.0 * s.a
struct P38 <: PShape; a::Float64; end
parea(s::P38) = 38.0 * s.a
struct P39 <: PShape; a::Float64; end
parea(s::P39) = 39.0 * s.a
struct P40 <: PShape; a::Float64; end
parea(s::P40) = 40.0 * s.a
struct P41 <: PShape; a::Float64; end
parea(s::P41) = 41.0 * s.a
struct P42 <: PShape; a::Float64; end
parea(s::P42) = 42.0 * s.a
struct P43 <: PShape; a::Float64; end
parea(s::P43) = 43.0 * s.a
struct P44 <: PShape; a::Float64; end
parea(s::P44) = 44.0 * s.a
struct P45 <: PShape; a::Float64; end
parea(s::P45) = 45.0 * s.a
struct P46 <: PShape; a::Float64; end
parea(s::P46) = 46.0 * s.a
struct P47 <: PShape; a::Float64; end
parea(s::P47) = 47.0 * s.a
struct P48 <: PShape; a::Float64; end
parea(s::P48) = 48.0 * s.a
struct P49 <: PShape; a::Float64; end
parea(s::P49) = 49.0 * s.a
struct P50 <: PShape; a::Float64; end
parea(s::P50) = 50.0 * s.a
struct P51 <: PShape; a::Float64; end
parea(s::P51) = 51.0 * s.a
struct P52 <: PShape; a::Float64; end
parea(s::P52) = 52.0 * s.a
struct P53 <: PShape; a::Float64; end
parea(s::P53) = 53.0 * s.a
struct P54 <: PShape; a::Float64; end
parea(s::P54) = 54.0 * s.a
struct P55 <: PShape; a::Float64; end
parea(s::P55) = 55.0 * s.a
struct P56 <: PShape; a::Float64; end
parea(s::P56) = 56.0 * s.a
struct P57 <: PShape; a::Float64; end
parea(s::P57) = 57.0 * s.a
struct P58 <: PShape; a::Float64; end
parea(s::P58) = 58.0 * s.a
struct P59 <: PShape; a::Float64; end
parea(s::P59) = 59.0 * s.a
struct P60 <: PShape; a::Float64; end
parea(s::P60) = 60.0 * s.a
struct P61 <: PShape; a::Float64; end
parea(s::P61) = 61.0 * s.a
struct P62 <: PShape; a::Float64; end
parea(s::P62) = 62.0 * s.a
struct P63 <: PShape; a::Float64; end
parea(s::P63) = 63.0 * s.a
struct P64 <: PShape; a::Float64; end
parea(s::P64) = 64.0 * s.a
end

"Values of the first n types of each form, a.k.a. the collection with n conformances."
traitvals(n) = Dynamic{Shape}[mk(getfield(ShapeCore, Symbol(:H, i))(1.0)) for i in 1:n]
plainvals(n) = PlainShapes.PShape[getfield(PlainShapes, Symbol(:P, i))(1.0) for i in 1:n]

TraitWorld.@workload begin
    for n in (2, 4, 16, 64)
        total(traitvals(n)); PlainShapes.ptotal(plainvals(n))
    end
end
end
