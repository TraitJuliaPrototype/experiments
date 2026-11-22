#!/usr/bin/env python3
"""W-19: the final diff's added lines by part of PLAN.md, from funcsizes.py's output (an estimate).
usage: parts.py < funcs.tsv [part]   -- each (file, function) goes to the first part whose rule matches
'file-regex:function-regex'; the rest is listed as 'unassigned'. With a part name: its rows."""
import sys, re, collections
P = [
 ('G  general (the up/* patches)', [r'base/(reinterpretarray|promotion|operators|task|sort|strings/string|essentials)\.jl:.*',
   r'src/runtime_ccall\.cpp:.*', r'contrib/.*:.*', r'src/gf\.c:(call_cache_any_ok|sig_match_any|sig_match_fast|dp_.*|jl_dispatch_profile.*|jl_get_specialization1_worlds|call_cache_stats)$',
   r'src/codegen\.cpp:(emit_abi_call|emit_cfunction|gen_cfun_wrapper)$', r'Compiler/src/ssair/inlining\.jl:(only_vararg_widened|get_cached_result)$',
   r'Compiler/src/optimize\.jl:(InliningState|OptimizationState)$', r'base/runtime_internals\.jl:(datatype_fieldcount|fieldcount.*|isabstracttype|datatype_alignment|datatype_npointers)$',
   r'base/reflection\.jl:invoke_interp_compiler$', r'Compiler/src/tfuncs\.jl:abstract_applicable$']),
 ('F1 nortsite effect, run-time sites', [r'Compiler/src/effects\.jl:.*', r'Compiler/src/facts\.jl:(unedged_effects|facts_mode)$']),
 ('F2 policy: module option, method flag, lowering', [r'base/experimental\.jl:.*', r'src/module\.c:(jl_method_policy|facts_all|method_is_builtin|jl_set_module_facts|<toplevel>)$',
   r'src/(ast\.c|ast\.scm|julia-syntax\.scm):.*', r'src/method\.c:jl_method_set_source$']),
 ('F3 the facts inference (fact signatures)', [r'Compiler/src/facts\.jl:(is_fact_sig|vararg_fact|concrete_member|fact_splits_ok|tuple_union_lengths!|union_split_cost|is_closure_type|kinds_ok|facts_find_method_matches|<toplevel>)$',
   r'Compiler/src/abstractinterpretation\.jl:(abstract_call_gf_by_type|abstract_call_unknown|infercalls|abstract_call_known)$']),
 ('F4 one CodeInstance per policy; calls between policies', [r'src/gf\.c:(mi_policy.*|jl_mi_policy_at|ci_policy.*|jl_ci_set_policy|jl_method_inferred_with_abi|jl_type_infer.*|jl_compile_method_internal.*|_jl_invoke|jl_invoke.*|apply_generic_reach|jl_apply_generic.*|jl_rettype_inferred.*|_jl_rettype_inferred|jl_get_method_inferred.*|jl_gf_invoke.*|jl_method_compiled_callptr|jl_new_codeinst|jl_call_in_typeinf_world|emit_codeinst_and_edges)$',
   r'src/(builtins\.c|interpreter\.c|engine\.cpp|builtin_proto\.h):.*', r'src/codegen\.cpp:(applygeneric_for|invoke_for.*|code_reach|mk_reach_builtin_map|builtin_func_for|emit_call|emit_invoke.*|init_jit_functions|emit_tojlinvoke|JL_GCC_IGNORE_START|<toplevel>)$',
   r'Compiler/src/cicache\.jl:.*', r'Compiler/src/facts\.jl:(method_policy.*|mi_policy.*|other_policy|ci_policy_facts|policy_interp|infers_other_policy|interp_for_policy|typeinf_other_policy|at)$',
   r'Compiler/src/types\.jl:(NativeInterpreter|set_code_policy!)$', r'Compiler/src/typeinfer\.jl:(typeinf_ext_toplevel|add_codeinsts_to_jit!|typeinf_edge|typeinf_type)$']),
 ('F5 return_type under either policy', [r'Compiler/src/tfuncs\.jl:(return_type_tfunc|early_consteval_world_sensitive)$', r'Compiler/src/typeinfer\.jl:return_type$']),
 ('F6 the deep class: G2, edges by code, the call signature', [r'Compiler/src/facts\.jl:(edges_satisfy_g2|name_callee_code|is_own|is_membership_mi|is_absence_sig)$',
   r'Compiler/src/typeinfer\.jl:(finish_cycle|finish!|codeinst_as_edge|store_backedges|Base\.iterate|adjust_effects|finishinfer!)$', r'Compiler/src/stmtinfo\.jl:.*',
   r'src/gf\.c:(_invalidate_dispatch_backedges|jl_ci_set_g2|jl_method_instance_add_backedge|jl_method_table_add_backedge)$']),
 ('F7 images and --trim under the policy', [r'src/staticdata_utils\.c:.*', r'Compiler/src/facts\.jl:rtsite_target.*$', r'Compiler/src/typeinfer\.jl:(compile!|collectinvokes!|equivalent_cached_ci)$']),
 ('F8 owner-only functions', [r'src/module\.c:(jl_set_owner_only|jl_binding_owner_only_p|jl_module_public.*|jl_set_open_operation|jl_binding_open_operation_p)$', r'Compiler/src/facts\.jl:(is_owner_only|owner_only_call)$']),
 ('F9 what a definition ended (deep endings)', [r'src/gf\.c:(.*deep_ending.*|note_deep_ending|is_deep_facts_code|invalidate_code_instance|jl_invalidate_code_instance)$', r'Compiler/src/reinfer\.jl:.*']),
 ('F10 fully typed mode', [r'.*:(.*fully_typed.*|jl_not_fully_typed)$', r'src/module\.c:jl_method_fully_typed$']),
 ('T1 Core types, TypeName slots, the bits', [r'src/jltypes\.c:(jl_init_types|post_boot_hooks|jl_precompute_memoized_dt|jl_new_typename_in|<toplevel>)$', r'src/julia\.h:.*', r'test/.*:.*', r'base/boot\.jl:<toplevel>$', r'base/runtime_internals\.jl:.*', r'src/datatype\.c:jl_new_typename_in$']),
 ('T2 sets, memberships, subtyping', [r'src/subtype\.c:(?!intersect).*', r'src/datatype\.c:(jl_declare_membership|jl_set_open_set|index_entry|publish_entry|set_at_inputs|same_inputs|jl_set_input_params|instances_at_set|pattern_second_instance|jl_set_member_patterns|patterns_may_meet|jl_entry_intersection|jl_is_open_set|open_set_witness|set_entries_meet|entry_.*|jl_delete_membership|_Atomic)$']),
 ('T3 intersections All', [r'src/jltypes\.c:(jl_type_all|all_.*|inst_type_w_)$', r'src/subtype\.c:intersect.*$', r'base/show\.jl:show_datatype$', r'src/datatype\.c:(all_type_met|intersection_met|member_meets_others)$']),
 ('T4 dispatch at sets, specificity, the ambiguity report', [r'src/typemap\.c:.*', r'src/gf\.c:(index_func_set_method|jl_methods_at_set|jl_open_set_methods_of|jl_index_open_set_methods|jl_func_methods_at_sets|membership_ambig.*|membership_ambiguities|jl_membership_ambiguit.*|ml_matches.*|get_intersect.*|match_at_member|sig_at_member|jl_matching_methods.*|open_set_.*|sig_has_open_set|set_types_position|position_type|jl_argtype_without_function|method_function_search_type|method_in)$',
   r'src/datatype\.c:(ambiguity_message|jl_take_activation_ambiguities)$', r'base/reflection\.jl:.*', r'Compiler/src/methodtable\.jl:.*']),
 ('T5 a membership invalidates as a method does', [r'src/gf\.c:(jl_membership_dispatch_walk|membership_subst.*|jl_membership_removal_walk|membership_removal_backedges|invalidate_intersecting|replay_matched_before|set_name_nested|declared_parameter|membership_.*|jl_membership_.*|invalidate_all_mt_cache|uncache_.*|_typename_invalidate_backedges|jl_method_table_invalidate|jl_set_membership_walk_invalidates|jl_implements_functype|jl_is_implements_sig)$']),
 ('T6 the membership\'s method, folds and their edges', [r'src/method\.c:jl_new_membership_method$', r'src/datatype\.c:(membership_absence|absence_.*|membership_method_sig|jl_membership_method_sig|names_foreign_var)$', r'Compiler/src/typeutils\.jl:.*',
   r'Compiler/src/abstractinterpretation\.jl:(prove_type_test!|abstract_eval_new|record_match_memberships!|isa_condition)$', r'Compiler/src/optimize\.jl:new_expr_effect_flags$', r'src/cgutils\.cpp:.*', r'src/codegen\.cpp:(update_julia_type|emit_builtin_call|emit_new_struct)$', r'Compiler/src/(abstractlattice|typelattice)\.jl:.*', r'Compiler/src/tfuncs\.jl:(isa_tfunc|subtype_tfunc|builtin_tfunction|<toplevel>)$']),
 ('T7 final negatives, closed after load, unmet intersections', [r'src/datatype\.c:(jl_membership_final.*|jl_unmet_final_cells|unmet_argument|jl_has_unmet_argument|final_pair_component|module_loaded|type_declarers_loaded|jl_set_closed_after_load|jl_is_closed_after_load|abstract_member|kind_meets.*)$',
   r'src/gf\.c:(drop_unmet_matches|jl_invalidate_code_instances_new_world)$', r'base/(loading|sysimg|Base)\.jl:.*', r'src/toplevel\.c:.*']),
 ('T8 memberships in images', [r'src/staticdata\.c:.*', r'src/datatype\.c:(jl_activate_memberships|activation_conflicts|jl_activated_memberships.*|jl_memberships_activated|note_activated)$', r'src/gf\.c:(jl_member_checks_activated|jl_activated_member_checks|member_checks_activated_list|jl_method_table_activate|image)$']),
 ('T9 hooks for the library (definition, image, module end, expansion, deletion, member, strict)', [r'src/gf\.c:(jl_call_.*hook|call_library_hook|member_.*|jl_member_.*|jl_membership_method_retire|jl_method_table_disable|jl_method_table_insert)$', r'src/method\.c:method_def$', r'src/(init|task|iddict)\.c:.*', r'src/julia_threads\.h:.*']),
 ('T10 declared results, fields, contracts, operations', [r'src/method\.c:(declared_result_of|<toplevel>)$', r'src/gf\.c:jl_method_set_declared_result$', r'src/datatype\.c:(jl_set_contract.*|jl_declare_contract|has_contract|jl_contract_operations|jl_set_declared_fields|jl_set_erases|jl_set_enumerable)$',
   r'Compiler/src/abstractinterpretation\.jl:(declared_operation_result|declared_field_.*|operation_entries!|declared_result_at)$', r'Compiler/src/ssair/inlining\.jl:handle_declared_result!$']),
 ('T11 the split and the table', [r'.*splittable\.jl:.*', r'base/splittarget\.jl:.*', r'Compiler/src/ssair/inlining\.jl:(split_.*|ir_inline_unionsplit!|cfg_inline_unionsplit!|handle_call!|assemble_inline_todo!|<toplevel>)$', r'Compiler/src/abstractinterpretation\.jl:operation_split_type$',
   r'src/datatype\.c:(register_candidate|jl_register_candidate|unregister_candidates|jl_candidates_of)$', r'src/gf\.c:jl_split_table_ptr$']),
 ('T12 Callable', [r'.*:(.*callable.*|handle_callable_call!)$', r'src/builtins\.c:JL_CALLABLE$']),
 ('T13 IO: the contract, IOContext{IO}, the display', [r'base/iotrait\.jl:.*', r'base/multimedia\.jl:.*', r'stdlib/.*:.*', r'base/show\.jl:.*']),
 ('T14 the kept forms (Dynamic, Compiled) and the forwarders', [r'base/boot\.jl:.*', r'src/gf\.c:(is_trait_arg_type|jl_compilation_sig|jl_isa_compileable_sig)$', r'src/datatype\.c:jl_set_erases$']),
 ('T15 the trusted effect and its checks', [r'Compiler/src/ssair/inlining\.jl:(check_trusted_result!|trusted_result_check)$', r'Compiler/src/optimize\.jl:<toplevel>$']),
 ('T16 a closed build', [r'.*:(closed_.*|.*closed.*|note_used_type!|note_closed_.*|CLOSED.*)$', r'Compiler/src/verifytrim\.jl:.*', r'Compiler/src/precompile\.jl:.*', r'Compiler/src/ssair/inlining\.jl:compileable_specialization$']),
 ('T17 the definition-time check interpreter', [r'Compiler/src/types\.jl:<toplevel>$', r'Compiler/src/bootstrap\.jl:.*', r'Compiler/src/Compiler\.jl:.*']),
 ('X  GC roots, exports, static show, headers', [r'src/gc-(stock|mmtk)\.c:.*', r'src/jl_exported_.*:.*', r'src/rtutils\.c:.*', r'src/julia_internal\.h:.*']),
]
rules=[(name,[re.compile(r) for r in rs]) for name,rs in P]
tot=collections.Counter(); rows=collections.defaultdict(list)
for line in sys.stdin:
    n,f,fn=line.rstrip('\n').split('\t'); n=int(n); key=f+':'+fn
    for name,rs in rules:
        if any(r.fullmatch(key) for r in rs): break
    else: name='unassigned'
    tot[name]+=n; rows[name].append((n,key))
if len(sys.argv)>1:
    for n,k in sorted(rows[sys.argv[1]],reverse=True)[:60]: print(n,k)
else:
    for name,_ in P+[('unassigned',None)]: print(f"{tot[name]:6d}  {name}")
    print(f"{sum(tot.values()):6d}  total")
