#= base/reflection.jl =#
function invoke_interp_compiler(interp, fname::Symbol, args...)
    if interp === nothing
        return invoke_default_compiler(fname, args...)
    elseif REFLECTION_COMPILER[] === nothing && typeof(interp) === Compiler.NativeInterpreter
        # the native compiler with an interpreter of its own (another cache owner, another world) runs in
        # the compiler's world, as the default one does: its code is never invalidated by later definitions
        return invoke_in_typeinf_world(getglobal(Compiler, fname), args...)
    else
        T = typeof(interp)
        while true
            Tname = typename(T).name
            Tname === :Any && error("Expected AbstractInterpreter")
            Tname === :AbstractInterpreter && break
            T = supertype(T)
        end
        return getglobal(typename(T).module, fname)(args...)
    end
end

