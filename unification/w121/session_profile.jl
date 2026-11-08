using Profile
Profile.init(n = 10^7, delay = 0.0005)
empty!(ARGS); push!(ARGS, ENV["CSVF"], ENV["PNGF"])
t0 = time()
Profile.@profile include(ENV["SCRIPT"])
println("whole: ", round(time() - t0, digits = 3))
function classes()
data, lidict = Profile.retrieve()
cls = Dict{String,Int}(); total = 0
keys_ = [("member check", "check_first_use"), ("loading", "_require"), ("inference/compile", "typeinf"), ("codegen", "jl_compile")]
start = 1; i = 3; n = length(data)
while i <= n
    if data[i] == 0 && data[i-1] == 0 && data[i-2] in 1:3
        tid = data[i-5]; sl = data[i-2] != 1; fr = @view data[start:i-6]; start = i + 1
        if tid == 1 && !sl && !isempty(fr)
            total += 1
            names = [string(f.func) for ip in fr for f in get(lidict, ip, Base.StackTraces.StackFrame[])]
            c = "other"
            for (nm, k) in keys_
                any(x -> occursin(k, x), names) && (c = nm; break)
            end
            cls[c] = get(cls, c, 0) + 1
        end
        i += 3
    else
        i += 1
    end
end
for (k, v) in sort(collect(cls); by = last, rev = true); println(rpad(k, 20), round(100v / total, digits = 1), " %  (", v, ")"); end

end
classes()
