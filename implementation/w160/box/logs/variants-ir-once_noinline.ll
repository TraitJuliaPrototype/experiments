; Function Signature: call_once_ni(U.Decay, Float64)
define double @julia_call_once_ni_1266(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %"m::Decay", double %"u::Float64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 24, i1 true)
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #10
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe1, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe1, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe1, ptr %tls_pgcstack, align 8
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::Decay" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 140087015920912) #5
  %"box::Decay.tag_addr" = getelementptr inbounds i8, ptr %"box::Decay", i64 -8
  store atomic i64 140087015920912, ptr %"box::Decay.tag_addr" unordered, align 8
  %"m::Decay.copyload" = load i64, ptr %"m::Decay", align 8
  store i64 %"m::Decay.copyload", ptr %"box::Decay", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"box::Decay", ptr %gc_slot_addr_0, align 8
  %0 = call double @j_step2_1269(ptr nonnull %"box::Decay", double %"u::Float64")
  %frame.prev4 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev4, ptr %tls_pgcstack, align 8
  ret double %0
}
; WARNING: This code may not match what actually runs.
; Function Signature: step2(T.Model, Float64)
define double @julia_step2_1271(ptr noundef nonnull %"m::Model", double %"u::Float64") local_unnamed_addr #0 {
top:
  %jlcallframe1 = alloca [3 x ptr], align 8
  %gcframe2 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe2, i8 0, i64 24, i1 true)
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe2, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe2, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe2, ptr %tls_pgcstack, align 8
  %"m::Model.tag_addr" = getelementptr inbounds i8, ptr %"m::Model", i64 -8
  %"m::Model.tag" = load atomic volatile i64, ptr %"m::Model.tag_addr" unordered, align 8
  %0 = and i64 %"m::Model.tag", -16
  %1 = icmp ult i64 %"m::Model.tag", 1024
  br i1 %1, label %guard_exit, label %guard_exit.thread

L3:                                               ; preds = %isa5, %guard_exit.thread, %guard_exit
  store ptr @"jl_global#1276.jit", ptr %jlcallframe1, align 8
  %2 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 8
  store ptr @"+Core.Dynamic#1277.jit", ptr %2, align 8
  %3 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 16
  store ptr %"m::Model", ptr %3, align 8
  %jl_f_attributed_call_ret = call nonnull ptr @jl_f_attributed_call(ptr null, ptr nonnull %jlcallframe1, i32 3)
  %jl_f_attributed_call_ret.tag_addr = getelementptr inbounds i8, ptr %jl_f_attributed_call_ret, i64 -8
  %jl_f_attributed_call_ret.tag = load atomic volatile i64, ptr %jl_f_attributed_call_ret.tag_addr unordered, align 8
  %4 = and i64 %jl_f_attributed_call_ret.tag, -16
  %exactly_isa = icmp eq i64 %4, ptrtoint (ptr @"+Core.Dynamic#1277.jit" to i64)
  br i1 %exactly_isa, label %guard_pass18, label %fail

L8:                                               ; preds = %guard_pass18, %isa5
  %root_phi = phi ptr [ %"m::Model", %isa5 ], [ %12, %guard_pass18 ]
  %5 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %root_phi, ptr %5, align 8
  %6 = call double @j_step2_1278(ptr nocapture nonnull readonly %5, double %"u::Float64")
  %frame.prev26 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev26, ptr %tls_pgcstack, align 8
  ret double %6

guard_exit:                                       ; preds = %top
  %7 = getelementptr inbounds nuw i8, ptr @jl_small_typeof, i64 %0
  %8 = load ptr, ptr %7, align 8
  %datatype_name = load ptr, ptr %8, align 8
  %9 = icmp eq ptr %datatype_name, @"jl_global#1274.jit"
  br i1 %9, label %L3, label %isa5

guard_exit.thread:                                ; preds = %top
  %10 = inttoptr i64 %0 to ptr
  %datatype_name22 = load ptr, ptr %10, align 8
  %11 = icmp eq ptr %datatype_name22, @"jl_global#1274.jit"
  br i1 %11, label %L3, label %isa5

isa5:                                             ; preds = %guard_exit.thread, %guard_exit
  %datatype_name4 = phi ptr [ %datatype_name22, %guard_exit.thread ], [ %datatype_name, %guard_exit ]
  %.not = icmp eq ptr %datatype_name4, @"jl_global#1275.jit"
  br i1 %.not, label %L3, label %L8

fail:                                             ; preds = %L3
  call void @ijl_type_error(ptr nonnull @"_j_str_typeassert#1", ptr nonnull @"+Core.Dynamic#1277.jit", ptr nonnull %jl_f_attributed_call_ret)
  unreachable

guard_pass18:                                     ; preds = %L3
  %12 = load atomic ptr, ptr %jl_f_attributed_call_ret unordered, align 8
  br label %L8
}
