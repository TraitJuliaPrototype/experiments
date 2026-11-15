; Function Signature: call_once_in(U.Decay, Float64)
define double @julia_call_once_in_1354(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %"m::Decay", double %"u::Float64") local_unnamed_addr #0 {
top:
  %jlcallframe1 = alloca [3 x ptr], align 8
  %gcframe2 = alloca [5 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe2, i8 0, i64 40, i1 true)
  %0 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 12, ptr %gcframe2, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe2, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe2, ptr %tls_pgcstack, align 8
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::Decay" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 140136675355152) #10
  %"box::Decay.tag_addr" = getelementptr inbounds i8, ptr %"box::Decay", i64 -8
  store atomic i64 140136675355152, ptr %"box::Decay.tag_addr" unordered, align 8
  %"m::Decay.copyload" = load i64, ptr %"m::Decay", align 8
  store i64 %"m::Decay.copyload", ptr %"box::Decay", align 8
  %gc_slot_addr_1 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 24
  store ptr %"box::Decay", ptr %gc_slot_addr_1, align 8
  %1 = call nonnull ptr @j__box_1357(ptr nonnull %"box::Decay")
  %.tag_addr = getelementptr inbounds i8, ptr %1, i64 -8
  %.tag = load atomic volatile i64, ptr %.tag_addr unordered, align 8
  %2 = and i64 %.tag, -16
  %3 = inttoptr i64 %2 to ptr
  %4 = icmp ult i64 %.tag, 1024
  br i1 %4, label %guard_pass, label %guard_exit

L4:                                               ; preds = %guard_exit
  store ptr %1, ptr %0, align 8
  store ptr null, ptr %gc_slot_addr_25, align 8
  %5 = call double @j_step_1360(ptr nocapture nonnull readonly %0, double %"u::Float64")
  br label %L17

L8:                                               ; preds = %guard_exit
  %6 = call i32 @ijl_isa(ptr nonnull %1, ptr nonnull @"+Main.T.Model#1361.jit")
  %.not2 = icmp eq i32 %6, 0
  br i1 %.not2, label %L13, label %L10

L10:                                              ; preds = %L8
  %7 = call double @j_fw_once_in_1362(ptr nonnull %1, double %"u::Float64")
  br label %L17

L13:                                              ; preds = %L8
  %ptls_load11 = load ptr, ptr %ptls_field, align 8
  %"box::Float64" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load11, i32 360, i32 16, i64 140136803939680) #10
  %"box::Float64.tag_addr" = getelementptr inbounds i8, ptr %"box::Float64", i64 -8
  store atomic i64 140136803939680, ptr %"box::Float64.tag_addr" unordered, align 8
  store double %"u::Float64", ptr %"box::Float64", align 8
  store ptr %"box::Float64", ptr %gc_slot_addr_1, align 8
  store ptr @"jl_global#1363.jit", ptr %jlcallframe1, align 8
  %8 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 8
  store ptr %1, ptr %8, align 8
  %9 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 16
  store ptr %"box::Float64", ptr %9, align 8
  %jl_f_throw_methoderror_ret = call nonnull ptr @jl_f_throw_methoderror(ptr null, ptr nonnull %jlcallframe1, i32 3)
  call void @llvm.trap()
  unreachable

L17:                                              ; preds = %L10, %L4
  %value_phi = phi double [ %5, %L4 ], [ %7, %L10 ]
  %frame.prev15 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev15, ptr %tls_pgcstack, align 8
  ret double %value_phi

guard_pass:                                       ; preds = %top
  %10 = getelementptr inbounds nuw i8, ptr @jl_small_typeof, i64 %2
  %11 = load ptr, ptr %10, align 8
  br label %guard_exit

guard_exit:                                       ; preds = %guard_pass, %top
  %typeof = phi ptr [ %3, %top ], [ %11, %guard_pass ]
  store ptr null, ptr %gc_slot_addr_1, align 8
  %gc_slot_addr_25 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 32
  store ptr %1, ptr %gc_slot_addr_25, align 8
  %12 = call i32 @ijl_subtype(ptr nonnull %typeof, ptr nonnull @"jl_global#1359.jit")
  %.not = icmp eq i32 %12, 0
  br i1 %.not, label %L8, label %L4
}
