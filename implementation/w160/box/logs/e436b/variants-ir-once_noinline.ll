; Function Signature: call_once_ni(U.Decay, Float64)
define double @julia_call_once_ni_1284(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %"m::Decay", double %"u::Float64") local_unnamed_addr #0 {
top:
  %jlcallframe1 = alloca [3 x ptr], align 8
  %gcframe2 = alloca [4 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe2, i8 0, i64 32, i1 true)
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #14
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 8, ptr %gcframe2, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe2, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe2, ptr %tls_pgcstack, align 8
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::Decay" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 140136675355152) #9
  %"box::Decay.tag_addr" = getelementptr inbounds i8, ptr %"box::Decay", i64 -8
  store atomic i64 140136675355152, ptr %"box::Decay.tag_addr" unordered, align 8
  %"m::Decay.copyload" = load i64, ptr %"m::Decay", align 8
  store i64 %"m::Decay.copyload", ptr %"box::Decay", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"box::Decay", ptr %gc_slot_addr_0, align 8
  store ptr @"+Core.Dynamic#1289.jit", ptr %jlcallframe1, align 8
  %0 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 8
  store ptr %"box::Decay", ptr %0, align 8
  %1 = call nonnull ptr @ijl_invoke(ptr nonnull @"jl_global#1288.jit", ptr nonnull %jlcallframe1, i32 2, ptr nonnull @"-TraitWorld._box#1287.jit")
  %.tag_addr = getelementptr inbounds i8, ptr %1, i64 -8
  %.tag = load atomic volatile i64, ptr %.tag_addr unordered, align 8
  %2 = and i64 %.tag, -16
  %3 = inttoptr i64 %2 to ptr
  %4 = icmp ult i64 %.tag, 1024
  br i1 %4, label %guard_pass, label %guard_exit

L4:                                               ; preds = %guard_exit
  %5 = call double @j_fw_once_ni_1292(ptr nonnull %1, double %"u::Float64")
  br label %L16

L7:                                               ; preds = %guard_exit
  %6 = call i32 @ijl_isa(ptr nonnull %1, ptr nonnull @"+Main.T.Model#1293.jit")
  %.not2 = icmp eq i32 %6, 0
  br i1 %.not2, label %L12, label %L9

L9:                                               ; preds = %L7
  %7 = call double @j_fw_once_ni_1294(ptr nonnull %1, double %"u::Float64")
  br label %L16

L12:                                              ; preds = %L7
  %ptls_load9 = load ptr, ptr %ptls_field, align 8
  %"box::Float64" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load9, i32 360, i32 16, i64 140136803939680) #9
  %"box::Float64.tag_addr" = getelementptr inbounds i8, ptr %"box::Float64", i64 -8
  store atomic i64 140136803939680, ptr %"box::Float64.tag_addr" unordered, align 8
  store double %"u::Float64", ptr %"box::Float64", align 8
  store ptr %"box::Float64", ptr %gc_slot_addr_0, align 8
  store ptr @"jl_global#1295.jit", ptr %jlcallframe1, align 8
  store ptr %1, ptr %0, align 8
  %8 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 16
  store ptr %"box::Float64", ptr %8, align 8
  %jl_f_throw_methoderror_ret = call nonnull ptr @jl_f_throw_methoderror(ptr null, ptr nonnull %jlcallframe1, i32 3)
  call void @llvm.trap()
  unreachable

L16:                                              ; preds = %L9, %L4
  %value_phi = phi double [ %5, %L4 ], [ %7, %L9 ]
  %frame.prev13 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev13, ptr %tls_pgcstack, align 8
  ret double %value_phi

guard_pass:                                       ; preds = %top
  %9 = getelementptr inbounds nuw i8, ptr @jl_small_typeof, i64 %2
  %10 = load ptr, ptr %9, align 8
  br label %guard_exit

guard_exit:                                       ; preds = %guard_pass, %top
  %typeof = phi ptr [ %3, %top ], [ %10, %guard_pass ]
  store ptr null, ptr %gc_slot_addr_0, align 8
  %gc_slot_addr_1 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 24
  store ptr %1, ptr %gc_slot_addr_1, align 8
  %11 = call i32 @ijl_subtype(ptr nonnull %typeof, ptr nonnull @"jl_global#1291.jit")
  %.not = icmp eq i32 %11, 0
  br i1 %.not, label %L7, label %L4
}
; WARNING: This code may not match what actually runs.
; Function Signature: fw_once_ni(T.Model, Float64)
define double @julia_fw_once_ni_1296(ptr noundef nonnull %"m::Model", double %"u::Float64") local_unnamed_addr #0 {
top:
  %jlcallframe1 = alloca [3 x ptr], align 8
  %gcframe2 = alloca [4 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe2, i8 0, i64 32, i1 true)
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #14
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 8, ptr %gcframe2, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe2, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe2, ptr %tls_pgcstack, align 8
  %0 = call nonnull ptr @j__box_1299(ptr nonnull %"m::Model")
  %.tag_addr = getelementptr inbounds i8, ptr %0, i64 -8
  %.tag = load atomic volatile i64, ptr %.tag_addr unordered, align 8
  %1 = and i64 %.tag, -16
  %2 = inttoptr i64 %1 to ptr
  %3 = icmp ult i64 %.tag, 1024
  br i1 %3, label %guard_pass, label %guard_exit

L4:                                               ; preds = %guard_exit
  %4 = call double @j_fw_once_ni_1301(ptr nonnull %0, double %"u::Float64")
  br label %L28

L7:                                               ; preds = %guard_exit
  %5 = call i32 @ijl_isa(ptr nonnull %0, ptr nonnull @"+Main.T.Model#1302.jit")
  %.not14 = icmp eq i32 %5, 0
  br i1 %.not14, label %L26, label %L9

L9:                                               ; preds = %L7
  store ptr @"+Core.Dynamic#1305.jit", ptr %jlcallframe1, align 8
  %6 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 8
  store ptr %0, ptr %6, align 8
  %7 = call nonnull ptr @ijl_invoke(ptr nonnull @"jl_global#1304.jit", ptr nonnull %jlcallframe1, i32 2, ptr nonnull @"-TraitWorld._box#1303.jit")
  %.tag_addr22 = getelementptr inbounds i8, ptr %7, i64 -8
  %.tag23 = load atomic volatile i64, ptr %.tag_addr22 unordered, align 8
  %8 = and i64 %.tag23, -16
  %9 = inttoptr i64 %8 to ptr
  %10 = icmp ult i64 %.tag23, 1024
  br i1 %10, label %guard_pass1, label %guard_exit2

L13:                                              ; preds = %guard_exit2
  %11 = call double @j_fw_once_ni_1301(ptr nonnull %7, double %"u::Float64")
  br label %L28

L16:                                              ; preds = %guard_exit2
  %12 = call i32 @ijl_isa(ptr nonnull %7, ptr nonnull @"+Main.T.Model#1302.jit")
  %.not16 = icmp eq i32 %12, 0
  br i1 %.not16, label %L21, label %L18

L18:                                              ; preds = %L16
  %13 = call double @julia_fw_once_ni_1296(ptr %7, double %"u::Float64")
  br label %L28

L21:                                              ; preds = %L16
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::Float64" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 140136803939680) #9
  %"box::Float64.tag_addr" = getelementptr inbounds i8, ptr %"box::Float64", i64 -8
  store atomic i64 140136803939680, ptr %"box::Float64.tag_addr" unordered, align 8
  store double %"u::Float64", ptr %"box::Float64", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"box::Float64", ptr %gc_slot_addr_0, align 8
  store ptr @"jl_global#1306.jit", ptr %jlcallframe1, align 8
  store ptr %7, ptr %6, align 8
  %14 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 16
  store ptr %"box::Float64", ptr %14, align 8
  %jl_f_throw_methoderror_ret = call nonnull ptr @jl_f_throw_methoderror(ptr null, ptr nonnull %jlcallframe1, i32 3)
  call void @llvm.trap()
  unreachable

L26:                                              ; preds = %L7
  %ptls_field25 = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load26 = load ptr, ptr %ptls_field25, align 8
  %"box::Float6411" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load26, i32 360, i32 16, i64 140136803939680) #9
  %"box::Float6411.tag_addr" = getelementptr inbounds i8, ptr %"box::Float6411", i64 -8
  store atomic i64 140136803939680, ptr %"box::Float6411.tag_addr" unordered, align 8
  store double %"u::Float64", ptr %"box::Float6411", align 8
  %gc_slot_addr_017 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"box::Float6411", ptr %gc_slot_addr_017, align 8
  store ptr @"jl_global#1306.jit", ptr %jlcallframe1, align 8
  %15 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 8
  store ptr %0, ptr %15, align 8
  %16 = getelementptr inbounds nuw i8, ptr %jlcallframe1, i64 16
  store ptr %"box::Float6411", ptr %16, align 8
  %jl_f_throw_methoderror_ret12 = call nonnull ptr @jl_f_throw_methoderror(ptr null, ptr nonnull %jlcallframe1, i32 3)
  call void @llvm.trap()
  unreachable

L28:                                              ; preds = %L18, %L13, %L4
  %value_phi = phi double [ %4, %L4 ], [ %11, %L13 ], [ %13, %L18 ]
  %frame.prev31 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev31, ptr %tls_pgcstack, align 8
  ret double %value_phi

guard_pass:                                       ; preds = %top
  %17 = getelementptr inbounds nuw i8, ptr @jl_small_typeof, i64 %1
  %18 = load ptr, ptr %17, align 8
  br label %guard_exit

guard_exit:                                       ; preds = %guard_pass, %top
  %typeof = phi ptr [ %2, %top ], [ %18, %guard_pass ]
  %gc_slot_addr_1 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 24
  store ptr %0, ptr %gc_slot_addr_1, align 8
  %19 = call i32 @ijl_subtype(ptr nonnull %typeof, ptr nonnull @"jl_global#1300.jit")
  %.not = icmp eq i32 %19, 0
  br i1 %.not, label %L7, label %L4

guard_pass1:                                      ; preds = %L9
  %20 = getelementptr inbounds nuw i8, ptr @jl_small_typeof, i64 %8
  %21 = load ptr, ptr %20, align 8
  br label %guard_exit2

guard_exit2:                                      ; preds = %guard_pass1, %L9
  %typeof3 = phi ptr [ %9, %L9 ], [ %21, %guard_pass1 ]
  store ptr %7, ptr %gc_slot_addr_1, align 8
  %22 = call i32 @ijl_subtype(ptr nonnull %typeof3, ptr nonnull @"jl_global#1300.jit")
  %.not15 = icmp eq i32 %22, 0
  br i1 %.not15, label %L16, label %L13
}
