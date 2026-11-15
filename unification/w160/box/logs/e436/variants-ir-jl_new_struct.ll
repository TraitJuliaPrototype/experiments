; Function Signature: fw_ccall(U.Decay, Float64)
define double @julia_fw_ccall_927(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %"m::Decay", double %"u::Float64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 24, i1 true)
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe1, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe1, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe1, ptr %tls_pgcstack, align 8
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::Decay" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 140500493400272) #8
  %"box::Decay.tag_addr" = getelementptr inbounds i8, ptr %"box::Decay", i64 -8
  store atomic i64 140500493400272, ptr %"box::Decay.tag_addr" unordered, align 8
  %"m::Decay.copyload" = load i64, ptr %"m::Decay", align 8
  store i64 %"m::Decay.copyload", ptr %"box::Decay", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"box::Decay", ptr %gc_slot_addr_0, align 8
  %0 = call nonnull ptr (ptr, ...) @ijl_new_struct.found.jit(ptr nonnull @"+Core.Dynamic#930.jit", ptr nonnull %"box::Decay")
  %.tag_addr = getelementptr inbounds i8, ptr %0, i64 -8
  %.tag = load atomic volatile i64, ptr %.tag_addr unordered, align 8
  %1 = and i64 %.tag, -16
  %exactly_isa = icmp eq i64 %1, ptrtoint (ptr @"+Core.Dynamic#930.jit" to i64)
  br i1 %exactly_isa, label %guard_exit, label %fail

fail:                                             ; preds = %top
  store ptr null, ptr %gc_slot_addr_0, align 8
  call void @ijl_type_error(ptr nonnull @"_j_str_typeassert#2", ptr nonnull @"+Core.Dynamic#930.jit", ptr nonnull %0)
  unreachable

guard_exit:                                       ; preds = %top
  store ptr %0, ptr %gc_slot_addr_0, align 8
  %2 = call double @j_step_933(ptr nocapture nonnull readonly %0, double %"u::Float64")
  %frame.prev16 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev16, ptr %tls_pgcstack, align 8
  ret double %2
}
