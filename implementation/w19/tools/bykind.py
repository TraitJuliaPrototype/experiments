#!/usr/bin/env python3
"""W-19: an estimate of the final diff's added lines by kind, from funcsizes.py's output.
usage: funcsizes.py ... | bykind.py
Each (file, function) is assigned by the first rule that matches its name, then by its file.
An estimate: a function changed for two kinds counts for the first rule only; '<toplevel>'
lines (comments, declarations, struct fields) go by file."""
import sys, re, collections
GENERAL = {('base/reinterpretarray.jl','*'),('base/promotion.jl','*'),('base/operators.jl','*'),('base/task.jl','*'),
           ('base/sort.jl','*'),('base/strings/string.jl','*'),('base/essentials.jl','*'),
           ('src/runtime_ccall.cpp','*'),('contrib/generate_precompile.jl','*'),('src/staticdata_utils.c','queue_external_cis')}
GEN_FN = set('''call_cache_any_ok sig_match_any sig_match_fast dp_count dp_count_site dp_enabled jl_dispatch_profile_print
jl_dispatch_profile_reset jl_get_specialization1_worlds emit_abi_call emit_cfunction gen_cfun_wrapper only_vararg_widened
finish_cycle get_cached_result InliningState OptimizationState finishinfer! abstract_applicable datatype_fieldcount fieldcount
fieldcount_noerror isabstracttype datatype_alignment datatype_npointers invoke_interp_compiler IOContext call_cache_stats'''.split())
FACTS = re.compile(r'polic|facts|g2|G2|rtsite|owner_only|deep_ending|deep_facts|reach|REACH|fully_typed|nortsite|other_policy|'
                   r'equivalent_cached|name_callee|edges_satisfy|codeinst_as_edge|callsig|CallSig|_add_edges_impl|store_backedges|'
                   r'ForwardToBackedge|invalidate_dispatch_backedges|fact_|vararg_fact|kinds_ok|union_split|tuple_union|'
                   r'is_closure_type|concrete_member|typeinf_ext_toplevel|compile!|add_codeinsts|jl_compile_method_internal|'
                   r'jl_type_infer|_jl_invoke|jl_invoke|apply_generic|jl_apply_generic|eval_body|Effects|is_better_effects|'
                   r'jl_rettype_inferred|cicache|InternalCodeCache|interp_for|set_code_policy|NativeInterpreter|not_fully_typed')
TRAITS = re.compile(r'member|[sS]et\b|_set_|set_|sets|trait|[cC]allable|contract|operation|split|closed|declared|cast|'
                    r'attributed|erasing|forwarder|expansion|hook|unmet|final|[aA]ll\b|_all|implements|candidate|typemap|'
                    r'intersect|subtype|reach|could_join|Dynamic|Compiled|trusted|open|enumerable|absence|isa_condition|'
                    r'activ|entry|entries|input|kind_meets|witness|morespecific|disjoint|obvious|type_all|show_datatype|'
                    r'supertrait|erases|isambiguous|has_unmet|ambig|prove_type|new_expr|emit_isa|tmeet|isa_tfunc|'
                    r'subtype_tfunc|typename|TypeName|post_boot|jl_init_types|inst_type|precompute|abstract_eval_new|'
                    r'record_|note_|replay|position|loaded|walk|cells|Splittarget|_SplitTarget|_to_declared|'
                    r'iotrait|abstract_call|abstract_invoke|handle_|infercalls|method_def|jl_method_set_source|'
                    r'jl_new_typename|update_julia_type|emit_new_struct|cfg_inline|ir_inline|assemble_inline|compileable_spec')
TRAIT_FILES = ('src/subtype.c','src/jltypes.c','src/datatype.c','src/typemap.c','base/iotrait.jl','base/splittable.jl',
               'base/splittarget.jl','Compiler/src/splittable.jl','base/Base.jl','base/sysimg.jl','base/boot.jl','base/show.jl',
               'base/multimedia.jl','stdlib/REPL/src/REPL.jl','test/core.jl','base/loading.jl','src/julia-syntax.scm',
               'src/ast.scm','src/rtutils.c','src/typemap.c','src/cgutils.cpp','src/gc-stock.c','src/gc-mmtk.c','src/staticdata.c')
FACT_FILES = ('Compiler/src/facts.jl','Compiler/src/effects.jl','Compiler/src/cicache.jl','src/engine.cpp','src/interpreter.c',
              'src/builtins.c','src/module.c','Compiler/src/reinfer.jl','base/experimental.jl','src/builtin_proto.h')
tot=collections.Counter(); rows=collections.defaultdict(list)
for line in sys.stdin:
    n,f,fn = line.rstrip('\n').split('\t'); n=int(n)
    if (f,'*') in GENERAL or (f,fn) in GENERAL or fn in GEN_FN: k='general'
    elif fn!='<toplevel>' and FACTS.search(fn): k='facts'
    elif fn!='<toplevel>' and TRAITS.search(fn): k='traits'
    elif f in TRAIT_FILES: k='traits'
    elif f in FACT_FILES: k='facts'
    else: k='unassigned'
    tot[k]+=n; rows[k].append((n,f,fn))
for k,v in tot.most_common(): print(f"{k:12s} {v:6d}")
if len(sys.argv)>1:
    for n,f,fn in sorted(rows[sys.argv[1]], reverse=True)[:int(sys.argv[2]) if len(sys.argv)>2 else 40]: print(f"  {n}\t{f}\t{fn}")
