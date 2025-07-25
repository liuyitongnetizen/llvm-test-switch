; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --check-attributes --check-globals
; RUN: opt -aa-pipeline=basic-aa -passes=attributor -attributor-manifest-internal  -attributor-annotate-decl-cs  -S < %s | FileCheck %s --check-prefixes=CHECK,TUNIT
; RUN: opt -aa-pipeline=basic-aa -passes=attributor-cgscc -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,CGSCC

declare noalias ptr @malloc(i64) allockind("alloc,uninitialized") allocsize(0)

declare void @nocapture_func_frees_pointer(ptr nocapture)

declare void @func_throws(...)

declare void @sync_func(ptr %p)

declare void @sync_will_return(ptr %p) willreturn nounwind

declare void @no_sync_func(ptr nocapture %p) nofree nosync willreturn

declare void @nofree_func(ptr nocapture %p) nofree  nosync willreturn

declare void @foo(ptr %p)

declare void @foo_nounw(ptr %p) nounwind nofree

declare void @usei8(i8)
declare void @usei8p(ptr nocapture)

declare i32 @no_return_call() noreturn

declare void @free(ptr nocapture) allockind("free")

declare void @llvm.lifetime.start.p0(i64, ptr nocapture) nounwind

;.
; CHECK: @G = internal global ptr undef, align 4
;.
define void @h2s_value_simplify_interaction(i1 %c, ptr %A) {
; CHECK-LABEL: define {{[^@]+}}@h2s_value_simplify_interaction
; CHECK-SAME: (i1 [[C:%.*]], ptr nofree readnone captures(none) [[A:%.*]]) {
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[ADD:%.*]] = add i64 2, 2
; CHECK-NEXT:    [[M:%.*]] = tail call noalias align 16 ptr @malloc(i64 noundef [[ADD]])
; CHECK-NEXT:    br i1 [[C]], label [[T:%.*]], label [[F:%.*]]
; CHECK:       t:
; CHECK-NEXT:    br i1 false, label [[DEAD:%.*]], label [[F2:%.*]]
; CHECK:       f:
; CHECK-NEXT:    br label [[J:%.*]]
; CHECK:       f2:
; CHECK-NEXT:    [[L:%.*]] = load i8, ptr [[M]], align 16
; CHECK-NEXT:    call void @usei8(i8 [[L]])
; CHECK-NEXT:    call void @no_sync_func(ptr noalias nofree noundef nonnull align 16 captures(none) dereferenceable(1) [[M]]) #[[ATTR11:[0-9]+]]
; CHECK-NEXT:    br label [[J]]
; CHECK:       dead:
; CHECK-NEXT:    unreachable
; CHECK:       j:
; CHECK-NEXT:    [[PHI:%.*]] = phi ptr [ [[M]], [[F]] ], [ null, [[F2]] ]
; CHECK-NEXT:    tail call void @no_sync_func(ptr nofree noundef align 16 captures(none) [[PHI]]) #[[ATTR11]]
; CHECK-NEXT:    ret void
;
entry:
  %add = add i64 2, 2
  %m = tail call noalias align 16 ptr @malloc(i64 %add)
  br i1 %c, label %t, label %f

t:
  br i1 false, label %dead, label %f2

f:
  br label %j

f2:
  %l = load i8, ptr %m, align 1
  call void @usei8(i8 %l)
  call void @no_sync_func(ptr noundef %m) nounwind
  br label %j

dead:
  br label %j

j:
  %phi = phi ptr [ %m, %f ], [ null, %f2 ], [ %A, %dead ]
  tail call void @no_sync_func(ptr noundef %phi) nounwind
  ret void
}

define void @nofree_arg_only(ptr %p1, ptr %p2) {
; CHECK-LABEL: define {{[^@]+}}@nofree_arg_only
; CHECK-SAME: (ptr nofree captures(none) [[P1:%.*]], ptr captures(none) [[P2:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    tail call void @free(ptr captures(none) [[P2]])
; CHECK-NEXT:    tail call void @nofree_func(ptr nofree captures(none) [[P1]])
; CHECK-NEXT:    ret void
;
bb:
  tail call void @free(ptr %p2)
  tail call void @nofree_func(ptr %p1)
  ret void
}

; TEST 1 - negative, pointer freed in another function.

define void @test1() {
; CHECK-LABEL: define {{[^@]+}}@test1() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    tail call void @nocapture_func_frees_pointer(ptr noalias captures(none) [[I]])
; CHECK-NEXT:    tail call void (...) @func_throws()
; CHECK-NEXT:    tail call void @free(ptr noalias captures(none) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @nocapture_func_frees_pointer(ptr %i)
  tail call void (...) @func_throws()
  tail call void @free(ptr %i)
  ret void
}

; TEST 2 - negative, call to a sync function.

define void @test2() {
; CHECK-LABEL: define {{[^@]+}}@test2() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    tail call void @sync_func(ptr [[I]])
; CHECK-NEXT:    tail call void @free(ptr captures(none) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @sync_func(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

; TEST 3 - 1 malloc, 1 free

define void @test3() {
; CHECK-LABEL: define {{[^@]+}}@test3() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I_H2S]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @no_sync_func(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

define void @test3a(ptr %p) {
; CHECK-LABEL: define {{[^@]+}}@test3a
; CHECK-SAME: (ptr captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    tail call void @nofree_arg_only(ptr noalias nofree captures(none) [[I_H2S]], ptr captures(none) [[P]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @nofree_arg_only(ptr %i, ptr %p)
  tail call void @free(ptr %i)
  ret void
}

declare noalias ptr @aligned_alloc(i64 allocalign, i64) allockind("alloc,uninitialized,aligned") allocsize(1)

define void @test3b(ptr %p) {
; CHECK-LABEL: define {{[^@]+}}@test3b
; CHECK-SAME: (ptr captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 128, align 32
; CHECK-NEXT:    tail call void @nofree_arg_only(ptr noalias nofree captures(none) [[I_H2S]], ptr captures(none) [[P]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @aligned_alloc(i64 32, i64 128)
  tail call void @nofree_arg_only(ptr %i, ptr %p)
  tail call void @free(ptr %i)
  ret void
}

; leave alone non-constant alignments.
define void @test3c(i64 %alignment) {
; CHECK-LABEL: define {{[^@]+}}@test3c
; CHECK-SAME: (i64 [[ALIGNMENT:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @aligned_alloc(i64 [[ALIGNMENT]], i64 noundef 128)
; CHECK-NEXT:    tail call void @free(ptr noalias captures(none) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @aligned_alloc(i64 %alignment, i64 128)
  tail call void @free(ptr %i)
  ret void
}

; leave alone a constant-but-invalid alignment
define void @test3d(ptr %p) {
; CHECK-LABEL: define {{[^@]+}}@test3d
; CHECK-SAME: (ptr captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @aligned_alloc(i64 noundef 33, i64 noundef 128)
; CHECK-NEXT:    tail call void @nofree_arg_only(ptr noalias nofree captures(none) [[I]], ptr captures(none) [[P]])
; CHECK-NEXT:    tail call void @free(ptr noalias captures(none) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @aligned_alloc(i64 33, i64 128)
  tail call void @nofree_arg_only(ptr %i, ptr %p)
  tail call void @free(ptr %i)
  ret void
}

declare noalias ptr @calloc(i64, i64) allockind("alloc,zeroed") allocsize(0,1)

define void @test0() {
; CHECK-LABEL: define {{[^@]+}}@test0() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 8, align 1
; CHECK-NEXT:    call void @llvm.memset.p0.i64(ptr [[I_H2S]], i8 0, i64 8, i1 false)
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I_H2S]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @calloc(i64 2, i64 4)
  tail call void @no_sync_func(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

; TEST 4
define void @test4() {
; CHECK-LABEL: define {{[^@]+}}@test4() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    tail call void @nofree_func(ptr noalias nofree captures(none) [[I_H2S]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @nofree_func(ptr %i)
  ret void
}

; TEST 5 - not all exit paths have a call to free, but all uses of malloc
; are in nofree functions and are not captured

define void @test5(i32 %arg, ptr %p) {
; CHECK-LABEL: define {{[^@]+}}@test5
; CHECK-SAME: (i32 [[ARG:%.*]], ptr captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    [[I1:%.*]] = icmp eq i32 [[ARG]], 0
; CHECK-NEXT:    br i1 [[I1]], label [[BB3:%.*]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    tail call void @nofree_func(ptr noalias nofree captures(none) [[I_H2S]])
; CHECK-NEXT:    br label [[BB4:%.*]]
; CHECK:       bb3:
; CHECK-NEXT:    tail call void @nofree_arg_only(ptr noalias nofree captures(none) [[I_H2S]], ptr captures(none) [[P]])
; CHECK-NEXT:    br label [[BB4]]
; CHECK:       bb4:
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  %i1 = icmp eq i32 %arg, 0
  br i1 %i1, label %bb3, label %bb2

bb2:
  tail call void @nofree_func(ptr %i)
  br label %bb4

bb3:
  tail call void @nofree_arg_only(ptr %i, ptr %p)
  tail call void @free(ptr %i)
  br label %bb4

bb4:
  ret void
}

; TEST 6 - all exit paths have a call to free

define void @test6(i32 %arg) {
; CHECK-LABEL: define {{[^@]+}}@test6
; CHECK-SAME: (i32 [[ARG:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    [[I1:%.*]] = icmp eq i32 [[ARG]], 0
; CHECK-NEXT:    br i1 [[I1]], label [[BB3:%.*]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    tail call void @nofree_func(ptr noalias nofree captures(none) [[I_H2S]])
; CHECK-NEXT:    br label [[BB4:%.*]]
; CHECK:       bb3:
; CHECK-NEXT:    br label [[BB4]]
; CHECK:       bb4:
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  %i1 = icmp eq i32 %arg, 0
  br i1 %i1, label %bb3, label %bb2

bb2:
  tail call void @nofree_func(ptr %i)
  tail call void @free(ptr %i)
  br label %bb4

bb3:
  tail call void @free(ptr %i)
  br label %bb4

bb4:
  ret void
}

; TEST 7 - free is dead.

define void @test7() {
; CHECK-LABEL: define {{[^@]+}}@test7() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    [[I1:%.*]] = tail call i32 @no_return_call() #[[ATTR4:[0-9]+]]
; CHECK-NEXT:    unreachable
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  %i1 = tail call i32 @no_return_call()
  tail call void @free(ptr %i)
  ret void
}

; TEST 8 - Negative: bitcast pointer used in capture function

define void @test8() {
; CHECK-LABEL: define {{[^@]+}}@test8() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    tail call void @no_sync_func(ptr nofree captures(none) [[I]])
; CHECK-NEXT:    store i32 10, ptr [[I]], align 4
; CHECK-NEXT:    tail call void @foo(ptr nonnull align 4 dereferenceable(4) [[I]])
; CHECK-NEXT:    tail call void @free(ptr nonnull align 4 captures(none) dereferenceable(4) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @no_sync_func(ptr %i)
  store i32 10, ptr %i, align 4
  %i2 = load i32, ptr %i, align 4
  tail call void @foo(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

; TEST 9 - FIXME: malloc should be converted.
define void @test9() {
; CHECK-LABEL: define {{[^@]+}}@test9() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    tail call void @no_sync_func(ptr nofree captures(none) [[I]])
; CHECK-NEXT:    store i32 10, ptr [[I]], align 4
; CHECK-NEXT:    tail call void @foo_nounw(ptr nofree nonnull align 4 dereferenceable(4) [[I]]) #[[ATTR11]]
; CHECK-NEXT:    tail call void @free(ptr nonnull align 4 captures(none) dereferenceable(4) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @no_sync_func(ptr %i)
  store i32 10, ptr %i, align 4
  %i2 = load i32, ptr %i, align 4
  tail call void @foo_nounw(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

; TEST 10 - 1 malloc, 1 free

define i32 @test10() {
; CHECK-LABEL: define {{[^@]+}}@test10() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I_H2S]])
; CHECK-NEXT:    store i32 10, ptr [[I_H2S]], align 4
; CHECK-NEXT:    [[I2:%.*]] = load i32, ptr [[I_H2S]], align 4
; CHECK-NEXT:    ret i32 [[I2]]
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @no_sync_func(ptr %i)
  store i32 10, ptr %i, align 4
  %i2 = load i32, ptr %i, align 4
  tail call void @free(ptr %i)
  ret i32 %i2
}

; TEST 11

define void @test11() {
; CHECK-LABEL: define {{[^@]+}}@test11() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    tail call void @sync_will_return(ptr [[I_H2S]]) #[[ATTR11]]
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  tail call void @sync_will_return(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

; TEST 12
define i32 @irreducible_cfg(i32 %arg) {
; CHECK-LABEL: define {{[^@]+}}@irreducible_cfg
; CHECK-SAME: (i32 [[ARG:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    store i32 10, ptr [[I_H2S]], align 4
; CHECK-NEXT:    [[I2:%.*]] = icmp eq i32 [[ARG]], 1
; CHECK-NEXT:    br i1 [[I2]], label [[BB3:%.*]], label [[BB5:%.*]]
; CHECK:       bb3:
; CHECK-NEXT:    [[I4:%.*]] = add nsw i32 [[ARG]], 5
; CHECK-NEXT:    br label [[BB11:%.*]]
; CHECK:       bb5:
; CHECK-NEXT:    br label [[BB6:%.*]]
; CHECK:       bb6:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i32 [ [[I12:%.*]], [[BB11]] ], [ 1, [[BB5]] ]
; CHECK-NEXT:    [[I7:%.*]] = load i32, ptr [[I_H2S]], align 4
; CHECK-NEXT:    [[I8:%.*]] = add nsw i32 [[I7]], -1
; CHECK-NEXT:    store i32 [[I8]], ptr [[I_H2S]], align 4
; CHECK-NEXT:    [[I9:%.*]] = icmp ne i32 [[I7]], 0
; CHECK-NEXT:    br i1 [[I9]], label [[BB10:%.*]], label [[BB13:%.*]]
; CHECK:       bb10:
; CHECK-NEXT:    br label [[BB11]]
; CHECK:       bb11:
; CHECK-NEXT:    [[DOT1:%.*]] = phi i32 [ [[I4]], [[BB3]] ], [ [[DOT0]], [[BB10]] ]
; CHECK-NEXT:    [[I12]] = add nsw i32 [[DOT1]], 1
; CHECK-NEXT:    br label [[BB6]]
; CHECK:       bb13:
; CHECK-NEXT:    [[I16:%.*]] = load i32, ptr [[I_H2S]], align 4
; CHECK-NEXT:    ret i32 [[I16]]
;
bb:
  %i = call noalias ptr @malloc(i64 4)
  store i32 10, ptr %i, align 4
  %i2 = icmp eq i32 %arg, 1
  br i1 %i2, label %bb3, label %bb5

bb3:
  %i4 = add nsw i32 %arg, 5
  br label %bb11

bb5:
  br label %bb6

bb6:
  %.0 = phi i32 [ %i12, %bb11 ], [ 1, %bb5 ]
  %i7 = load i32, ptr %i, align 4
  %i8 = add nsw i32 %i7, -1
  store i32 %i8, ptr %i, align 4
  %i9 = icmp ne i32 %i7, 0
  br i1 %i9, label %bb10, label %bb13

bb10:
  br label %bb11

bb11:
  %.1 = phi i32 [ %i4, %bb3 ], [ %.0, %bb10 ]
  %i12 = add nsw i32 %.1, 1
  br label %bb6

bb13:
  %i14 = load i32, ptr %i, align 4
  call void @free(ptr %i)
  %i16 = load i32, ptr %i, align 4
  ret i32 %i16
}


define i32 @malloc_in_loop(i32 %arg) {
; CHECK-LABEL: define {{[^@]+}}@malloc_in_loop
; CHECK-SAME: (i32 [[ARG:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = alloca i32, align 4
; CHECK-NEXT:    [[I1:%.*]] = alloca ptr, align 8
; CHECK-NEXT:    [[I11:%.*]] = alloca i8, i32 0, align 8
; CHECK-NEXT:    store i32 [[ARG]], ptr [[I]], align 4
; CHECK-NEXT:    br label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    [[I3:%.*]] = load i32, ptr [[I]], align 4
; CHECK-NEXT:    [[I4:%.*]] = add nsw i32 [[I3]], -1
; CHECK-NEXT:    store i32 [[I4]], ptr [[I]], align 4
; CHECK-NEXT:    [[I5:%.*]] = icmp sgt i32 [[I4]], 0
; CHECK-NEXT:    br i1 [[I5]], label [[BB6:%.*]], label [[BB9:%.*]]
; CHECK:       bb6:
; CHECK-NEXT:    [[I7_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    br label [[BB2]]
; CHECK:       bb9:
; CHECK-NEXT:    ret i32 5
;
bb:
  %i = alloca i32, align 4
  %i1 = alloca ptr, align 8
  store i32 %arg, ptr %i, align 4
  br label %bb2

bb2:
  %i3 = load i32, ptr %i, align 4
  %i4 = add nsw i32 %i3, -1
  store i32 %i4, ptr %i, align 4
  %i5 = icmp sgt i32 %i4, 0
  br i1 %i5, label %bb6, label %bb9

bb6:
  %i7 = call noalias ptr @malloc(i64 4)
  store i32 1, ptr %i7, align 8
  br label %bb2

bb9:
  ret i32 5
}

; Malloc/Calloc too large
define i32 @test13() {
; CHECK-LABEL: define {{[^@]+}}@test13() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef 256)
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I]])
; CHECK-NEXT:    store i32 10, ptr [[I]], align 4
; CHECK-NEXT:    [[I2:%.*]] = load i32, ptr [[I]], align 4
; CHECK-NEXT:    tail call void @free(ptr noalias nonnull align 4 captures(none) dereferenceable(4) [[I]])
; CHECK-NEXT:    ret i32 [[I2]]
;
bb:
  %i = tail call noalias ptr @malloc(i64 256)
  tail call void @no_sync_func(ptr %i)
  store i32 10, ptr %i, align 4
  %i2 = load i32, ptr %i, align 4
  tail call void @free(ptr %i)
  ret i32 %i2
}

define i32 @test_sle() {
; CHECK-LABEL: define {{[^@]+}}@test_sle() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef -1)
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I]])
; CHECK-NEXT:    store i32 10, ptr [[I]], align 4
; CHECK-NEXT:    [[I2:%.*]] = load i32, ptr [[I]], align 4
; CHECK-NEXT:    tail call void @free(ptr noalias nonnull align 4 captures(none) dereferenceable(4) [[I]])
; CHECK-NEXT:    ret i32 [[I2]]
;
bb:
  %i = tail call noalias ptr @malloc(i64 -1)
  tail call void @no_sync_func(ptr %i)
  store i32 10, ptr %i, align 4
  %i2 = load i32, ptr %i, align 4
  tail call void @free(ptr %i)
  ret i32 %i2
}

define i32 @test_overflow() {
; CHECK-LABEL: define {{[^@]+}}@test_overflow() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @calloc(i64 noundef 65537, i64 noundef 65537)
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I]])
; CHECK-NEXT:    store i32 10, ptr [[I]], align 4
; CHECK-NEXT:    [[I2:%.*]] = load i32, ptr [[I]], align 4
; CHECK-NEXT:    tail call void @free(ptr noalias nonnull align 4 captures(none) dereferenceable(4) [[I]])
; CHECK-NEXT:    ret i32 [[I2]]
;
bb:
  %i = tail call noalias ptr @calloc(i64 65537, i64 65537)
  tail call void @no_sync_func(ptr %i)
  store i32 10, ptr %i, align 4
  %i2 = load i32, ptr %i, align 4
  tail call void @free(ptr %i)
  ret i32 %i2
}

define void @test14() {
; CHECK-LABEL: define {{[^@]+}}@test14() {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @calloc(i64 noundef 64, i64 noundef 4)
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I]])
; CHECK-NEXT:    tail call void @free(ptr noalias captures(none) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @calloc(i64 64, i64 4)
  tail call void @no_sync_func(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

define void @test15(i64 %S) {
; CHECK-LABEL: define {{[^@]+}}@test15
; CHECK-SAME: (i64 [[S:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 [[S]])
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree captures(none) [[I]])
; CHECK-NEXT:    tail call void @free(ptr noalias captures(none) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 %S)
  tail call void @no_sync_func(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

define void @test16a(i8 %v, ptr %P) {
; CHECK-LABEL: define {{[^@]+}}@test16a
; CHECK-SAME: (i8 [[V:%.*]], ptr nofree readnone captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    store i8 [[V]], ptr [[I_H2S]], align 1
; CHECK-NEXT:    tail call void @no_sync_func(ptr noalias nofree noundef nonnull captures(none) dereferenceable(1) [[I_H2S]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  store i8 %v, ptr %i, align 1
  tail call void @no_sync_func(ptr %i)
  tail call void @free(ptr nonnull dereferenceable(1) %i)
  ret void
}

define void @test16b(i8 %v, ptr %P) {
; CHECK-LABEL: define {{[^@]+}}@test16b
; CHECK-SAME: (i8 [[V:%.*]], ptr nofree writeonly captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    store ptr [[I]], ptr [[P]], align 8
; CHECK-NEXT:    tail call void @no_sync_func(ptr nofree captures(none) [[I]])
; CHECK-NEXT:    tail call void @free(ptr captures(none) [[I]])
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  store ptr %i, ptr %P, align 8
  tail call void @no_sync_func(ptr %i)
  tail call void @free(ptr %i)
  ret void
}

define void @test16c(i8 %v, ptr %P) {
; CHECK-LABEL: define {{[^@]+}}@test16c
; CHECK-SAME: (i8 [[V:%.*]], ptr nofree writeonly captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    store ptr [[I_H2S]], ptr [[P]], align 8
; CHECK-NEXT:    tail call void @no_sync_func(ptr nofree captures(none) [[I_H2S]]) #[[ATTR11]]
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  store ptr %i, ptr %P, align 8
  tail call void @no_sync_func(ptr %i) nounwind
  tail call void @free(ptr %i)
  ret void
}

define void @test16d(i8 %v, ptr %P) {
; CHECK-LABEL: define {{[^@]+}}@test16d
; CHECK-SAME: (i8 [[V:%.*]], ptr nofree writeonly captures(none) [[P:%.*]]) {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    store ptr [[I]], ptr [[P]], align 8
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  store ptr %i, ptr %P, align 8
  ret void
}

@G = internal global ptr undef, align 4
define void @test16e(i8 %v) norecurse {
; CHECK: Function Attrs: norecurse
; CHECK-LABEL: define {{[^@]+}}@test16e
; CHECK-SAME: (i8 [[V:%.*]]) #[[ATTR9:[0-9]+]] {
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[I_H2S:%.*]] = alloca i8, i64 4, align 1
; CHECK-NEXT:    store ptr [[I_H2S]], ptr @G, align 8
; CHECK-NEXT:    call void @usei8p(ptr nofree captures(none) [[I_H2S]]) #[[ATTR12:[0-9]+]]
; CHECK-NEXT:    ret void
;
bb:
  %i = tail call noalias ptr @malloc(i64 4)
  store ptr %i, ptr @G, align 8
  %i1 = load ptr, ptr @G, align 8
  call void @usei8p(ptr nocapture nofree %i1) nocallback nosync nounwind willreturn
  call void @free(ptr %i)
  ret void
}

;.
; CHECK: attributes #[[ATTR0:[0-9]+]] = { allockind("alloc,uninitialized") allocsize(0) }
; CHECK: attributes #[[ATTR1:[0-9]+]] = { nounwind willreturn }
; CHECK: attributes #[[ATTR2:[0-9]+]] = { nofree nosync willreturn }
; CHECK: attributes #[[ATTR3:[0-9]+]] = { nofree nounwind }
; CHECK: attributes #[[ATTR4]] = { noreturn }
; CHECK: attributes #[[ATTR5:[0-9]+]] = { allockind("free") }
; CHECK: attributes #[[ATTR6:[0-9]+]] = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
; CHECK: attributes #[[ATTR7:[0-9]+]] = { allockind("alloc,uninitialized,aligned") allocsize(1) }
; CHECK: attributes #[[ATTR8:[0-9]+]] = { allockind("alloc,zeroed") allocsize(0,1) }
; CHECK: attributes #[[ATTR9]] = { norecurse }
; CHECK: attributes #[[ATTR10:[0-9]+]] = { nocallback nofree nounwind willreturn memory(argmem: write) }
; CHECK: attributes #[[ATTR11]] = { nounwind }
; CHECK: attributes #[[ATTR12]] = { nocallback nosync nounwind willreturn }
;.
;; NOTE: These prefixes are unused and the list is autogenerated. Do not add tests below this line:
; CGSCC: {{.*}}
; TUNIT: {{.*}}
