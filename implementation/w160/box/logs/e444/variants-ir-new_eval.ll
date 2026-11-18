; Function Signature: fw_eval(U.Decay, Float64)
define double @julia_fw_eval_1145(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %"m::Decay", double %"u::Float64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 24, i1 true)
  %0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
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
  %"box::Decay" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 140674622359376) #5
  %"box::Decay.tag_addr" = getelementptr inbounds i8, ptr %"box::Decay", i64 -8
  store atomic i64 140674622359376, ptr %"box::Decay.tag_addr" unordered, align 8
  %"m::Decay.copyload" = load i64, ptr %"m::Decay", align 8
  store i64 %"m::Decay.copyload", ptr %"box::Decay", align 8
  store ptr %"box::Decay", ptr %0, align 8
  %1 = call double @j_step_1149(ptr nocapture nonnull readonly %0, double %"u::Float64")
  %frame.prev3 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev3, ptr %tls_pgcstack, align 8
  ret double %1
}
