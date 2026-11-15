; Function Signature: fw_gen(U.Decay, Float64)
define double @julia_fw_gen_951(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %"m::Decay", double %"u::Float64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [4 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 32, i1 true)
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #11
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 8, ptr %gcframe1, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe1, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe1, ptr %tls_pgcstack, align 8
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::Decay" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 140416346152848) #6
  %"box::Decay.tag_addr" = getelementptr inbounds i8, ptr %"box::Decay", i64 -8
  store atomic i64 140416346152848, ptr %"box::Decay.tag_addr" unordered, align 8
  %"m::Decay.copyload" = load i64, ptr %"m::Decay", align 8
  store i64 %"m::Decay.copyload", ptr %"box::Decay", align 8
  %gc_slot_addr_1 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 24
  store ptr %"box::Decay", ptr %gc_slot_addr_1, align 8
  %0 = call i32 @ijl_isa(ptr nonnull %"box::Decay", ptr nonnull @"+Main.T.Model#955.jit")
  %.not = icmp eq i32 %0, 0
  store ptr null, ptr %gc_slot_addr_1, align 8
  %ptls_load18 = load ptr, ptr %ptls_field, align 8
  %"box::Decay5" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load18, i32 360, i32 16, i64 140416346152848) #6
  %"box::Decay5.tag_addr" = getelementptr inbounds i8, ptr %"box::Decay5", i64 -8
  store atomic i64 140416346152848, ptr %"box::Decay5.tag_addr" unordered, align 8
  store i64 %"m::Decay.copyload", ptr %"box::Decay5", align 8
  br i1 %.not, label %fail, label %pass

fail:                                             ; preds = %top
  call void @ijl_type_error(ptr nonnull @"_j_str_new#1", ptr nonnull @"+Main.T.Model#955.jit", ptr nonnull %"box::Decay5")
  unreachable

pass:                                             ; preds = %top
  %1 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"box::Decay5", ptr %1, align 8
  %2 = call double @j_step_956(ptr nocapture nonnull readonly %1, double %"u::Float64")
  %frame.prev19 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev19, ptr %tls_pgcstack, align 8
  ret double %2
}
