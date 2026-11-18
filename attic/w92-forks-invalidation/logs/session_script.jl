Base.cumulative_compile_timing(true)
using REPL
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function _allcis()
    s = Base.IdSet{Any}()
    Base.visit(_MT) do m
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci isa Core.CodeInstance; push!(s, ci); ci = isdefined(ci, :next) ? ci.next : nothing; end
        end
    end
    s
end
_mi(ci) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
_disp(x) = (show(IOContext(REPL.LimitIO(IOBuffer(), 10^7), :limit => true, :displaysize => (40, 120)), MIME"text/plain"(), x); nothing)
const _ST = Ref{Any}(nothing)
function _m(name)
    t = time(); c = Base.cumulative_compile_time_ns()[1] / 1e9
    if _ST[] !== nothing
        t0, c0, before = _ST[]
        new = [ci for ci in _allcis() if !(ci in before)]
        byown = Dict{Any,Int}(); bymod = Dict{Any,Int}()
        for ci in new
            byown[ci.owner] = get(byown, ci.owner, 0) + 1
            m = _mi(ci).def; k = (ci.owner, m isa Method ? Base.moduleroot(m.module) : Core)
            bymod[k] = get(bymod, k, 0) + 1
        end
        println("S ", rpad(name, 18), " wall ", lpad(round(t - t0; digits = 3), 6), " compile ", lpad(round(c - c0; digits = 3), 6),
                " new ", lpad(length(new), 5), "  ", join(("$(repr(o)) $(m) $n" for ((o, m), n) in sort!(collect(bymod); by = last, rev = true)[1:min(end, 5)]), "; "))
    end
    _ST[] = (time(), Base.cumulative_compile_time_ns()[1] / 1e9, _allcis())
    nothing
end
_m("start")
using CSV, DataFrames, Statistics, Dates
_m("imports")
D = get(ENV, "DATA", "data"); tmp = tempname(); nothing
_disp(D)
df = CSV.read(joinpath(D, "people.csv"), DataFrame);
_m("read")
_disp(df)
_m("show")
_disp(describe(df))
_m("describe")
sub = subset(select(df, :id, :city, :income), :income => ByRow(x -> !ismissing(x) && x > 5e4))
_disp(sub)
_m("select_filter")
_disp(sort(df, [:city, :income], rev = [false, true]))
_m("sort")
_disp(combine(groupby(df, :city), :income => mean ∘ skipmissing => :mean_income, nrow))
_m("groupby_combine")
_disp(transform(df, [:age, :income] => ByRow((a, i) -> coalesce(i, 0.0) / max(coalesce(a, 1), 1)) => :ratio))
_m("user_function")
_disp(innerjoin(df, CSV.read(joinpath(D, "orders.csv"), DataFrame), on = :id))
_m("join")
df.income_k = df.income ./ 1000;
_m("add_column")
_disp(CSV.write(tmp, df))
_m("write")
s2 = CSV.read(joinpath(D, "sensors.csv"), DataFrame)
_disp(s2)
_m("2_read_show")
_disp(describe(s2))
_m("2_describe")
_disp(sort(s2, [:tag, :s1]))
_m("2_sort")
_disp(combine(groupby(s2, :tag), :s1 => mean ∘ skipmissing => :m1, :s2 => maximum ∘ skipmissing => :x2, nrow))
_m("2_groupby_combine")
using InlineStrings
_m("3_using")
df3 = CSV.read(joinpath(D, "people.csv"), DataFrame; stringtype = String15)
_disp(df3)
_m("3_read_show")
_disp(describe(df3))
_m("3_describe")
_disp(combine(groupby(df3, :city), :income => mean ∘ skipmissing => :mean_income, nrow))
_m("3_groupby_combine")
