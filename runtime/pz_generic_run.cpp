/*
 * Plasma bytecode exection (generic portable version)
 * vim: ts=4 sw=4 et
 *
 * Copyright (C) 2015-2018 Plasma Team
 * Distributed under the terms of the MIT license, see ../LICENSE.code
 */

#include "pz_common.h"

#include "pz_gc.h"
#include "pz_interp.h"
#include "pz_trace.h"
#include "pz_util.h"

#include <stdio.h>

#include "pz_generic_closure.h"
#include "pz_generic_run.h"

static void
trace_stacks(PZ_Heap_Mark_State *state, void *stacks_);

int
pz_generic_main_loop(PZ_Stacks *stacks,
                     pz::Heap *heap,
                     PZ_Closure *closure)
{
    int retcode;
    stacks->esp = 0;
    uint8_t *ip = static_cast<uint8_t*>(closure->code);
    void *env = closure->data;

    pz_trace_state(ip, stacks->rsp, stacks->esp,
            (uint64_t *)stacks->expr_stack);
    while (true) {
        PZ_Instruction_Token token = (PZ_Instruction_Token)(*ip);

        ip++;
        switch (token) {
            case PZT_NOP:
                pz_trace_instr(stacks->rsp, "nop");
                break;
            case PZT_LOAD_IMMEDIATE_8:
                stacks->expr_stack[++stacks->esp].u8 = *ip;
                ip++;
                pz_trace_instr(stacks->rsp, "load imm:8");
                break;
            case PZT_LOAD_IMMEDIATE_16:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                stacks->expr_stack[++stacks->esp].u16 = *(uint16_t *)ip;
                ip += 2;
                pz_trace_instr(stacks->rsp, "load imm:16");
                break;
            case PZT_LOAD_IMMEDIATE_32:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 4);
                stacks->expr_stack[++stacks->esp].u32 = *(uint32_t *)ip;
                ip += 4;
                pz_trace_instr(stacks->rsp, "load imm:32");
                break;
            case PZT_LOAD_IMMEDIATE_64:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 8);
                stacks->expr_stack[++stacks->esp].u64 = *(uint64_t *)ip;
                ip += 8;
                pz_trace_instr(stacks->rsp, "load imm:64");
                break;
            case PZT_ZE_8_16:
                stacks->expr_stack[stacks->esp].u16 =
                    stacks->expr_stack[stacks->esp].u8;
                pz_trace_instr(stacks->rsp, "ze:8:16");
                break;
            case PZT_ZE_8_32:
                stacks->expr_stack[stacks->esp].u32 =
                    stacks->expr_stack[stacks->esp].u8;
                pz_trace_instr(stacks->rsp, "ze:8:32");
                break;
            case PZT_ZE_8_64:
                stacks->expr_stack[stacks->esp].u64 =
                    stacks->expr_stack[stacks->esp].u8;
                pz_trace_instr(stacks->rsp, "ze:8:64");
                break;
            case PZT_ZE_16_32:
                stacks->expr_stack[stacks->esp].u32 =
                    stacks->expr_stack[stacks->esp].u16;
                pz_trace_instr(stacks->rsp, "ze:16:32");
                break;
            case PZT_ZE_16_64:
                stacks->expr_stack[stacks->esp].u64 =
                    stacks->expr_stack[stacks->esp].u16;
                pz_trace_instr(stacks->rsp, "ze:16:64");
                break;
            case PZT_ZE_32_64:
                stacks->expr_stack[stacks->esp].u64 =
                    stacks->expr_stack[stacks->esp].u32;
                pz_trace_instr(stacks->rsp, "ze:32:64");
                break;
            case PZT_SE_8_16:
                stacks->expr_stack[stacks->esp].s16 =
                    stacks->expr_stack[stacks->esp].s8;
                pz_trace_instr(stacks->rsp, "se:8:16");
                break;
            case PZT_SE_8_32:
                stacks->expr_stack[stacks->esp].s32 =
                    stacks->expr_stack[stacks->esp].s8;
                pz_trace_instr(stacks->rsp, "se:8:32");
                break;
            case PZT_SE_8_64:
                stacks->expr_stack[stacks->esp].s64 =
                    stacks->expr_stack[stacks->esp].s8;
                pz_trace_instr(stacks->rsp, "se:8:64");
                break;
            case PZT_SE_16_32:
                stacks->expr_stack[stacks->esp].s32 =
                    stacks->expr_stack[stacks->esp].s16;
                pz_trace_instr(stacks->rsp, "se:16:32");
                break;
            case PZT_SE_16_64:
                stacks->expr_stack[stacks->esp].s64 =
                    stacks->expr_stack[stacks->esp].s16;
                pz_trace_instr(stacks->rsp, "se:16:64");
                break;
            case PZT_SE_32_64:
                stacks->expr_stack[stacks->esp].s64 =
                    stacks->expr_stack[stacks->esp].s32;
                pz_trace_instr(stacks->rsp, "se:32:64");
                break;
            case PZT_TRUNC_64_32:
                stacks->expr_stack[stacks->esp].u32 =
                    stacks->expr_stack[stacks->esp].u64 & 0xFFFFFFFFu;
                pz_trace_instr(stacks->rsp, "trunc:64:32");
                break;
            case PZT_TRUNC_64_16:
                stacks->expr_stack[stacks->esp].u16 =
                    stacks->expr_stack[stacks->esp].u64 & 0xFFFF;
                pz_trace_instr(stacks->rsp, "trunc:64:16");
                break;
            case PZT_TRUNC_64_8:
                stacks->expr_stack[stacks->esp].u8 =
                    stacks->expr_stack[stacks->esp].u64 & 0xFF;
                pz_trace_instr(stacks->rsp, "trunc:64:8");
                break;
            case PZT_TRUNC_32_16:
                stacks->expr_stack[stacks->esp].u16 =
                    stacks->expr_stack[stacks->esp].u32 & 0xFFFF;
                pz_trace_instr(stacks->rsp, "trunc:32:16");
                break;
            case PZT_TRUNC_32_8:
                stacks->expr_stack[stacks->esp].u8 =
                    stacks->expr_stack[stacks->esp].u32 & 0xFF;
                pz_trace_instr(stacks->rsp, "trunc:32:8");
                break;
            case PZT_TRUNC_16_8:
                stacks->expr_stack[stacks->esp].u8 =
                    stacks->expr_stack[stacks->esp].u16 & 0xFF;
                pz_trace_instr(stacks->rsp, "trunc:16:8");
                break;

#define PZ_RUN_ARITHMETIC(opcode_base, width, signedness, operator,         \
                          op_name)                                          \
    case opcode_base##_##width:                                             \
        stacks->expr_stack[stacks->esp - 1].signedness##width =             \
                (stacks->expr_stack[stacks->esp - 1].signedness##width      \
            operator stacks->expr_stack[stacks->esp].signedness##width);    \
        stacks->esp--;                                                      \
        pz_trace_instr(stacks->rsp, op_name);                               \
        break
#define PZ_RUN_ARITHMETIC1(opcode_base, width, signedness, operator,        \
                           op_name)                                         \
    case opcode_base##_##width:                                             \
        stacks->expr_stack[stacks->esp].signedness##width =                 \
                operator stacks->expr_stack[stacks->esp].signedness##width; \
        pz_trace_instr(stacks->rsp, op_name);                               \
        break

                PZ_RUN_ARITHMETIC(PZT_ADD, 8, s, +, "add:8");
                PZ_RUN_ARITHMETIC(PZT_ADD, 16, s, +, "add:16");
                PZ_RUN_ARITHMETIC(PZT_ADD, 32, s, +, "add:32");
                PZ_RUN_ARITHMETIC(PZT_ADD, 64, s, +, "add:64");
                PZ_RUN_ARITHMETIC(PZT_SUB, 8, s, -, "sub:8");
                PZ_RUN_ARITHMETIC(PZT_SUB, 16, s, -, "sub:16");
                PZ_RUN_ARITHMETIC(PZT_SUB, 32, s, -, "sub:32");
                PZ_RUN_ARITHMETIC(PZT_SUB, 64, s, -, "sub:64");
                PZ_RUN_ARITHMETIC(PZT_MUL, 8, s, *, "mul:8");
                PZ_RUN_ARITHMETIC(PZT_MUL, 16, s, *, "mul:16");
                PZ_RUN_ARITHMETIC(PZT_MUL, 32, s, *, "mul:32");
                PZ_RUN_ARITHMETIC(PZT_MUL, 64, s, *, "mul:64");
                PZ_RUN_ARITHMETIC(PZT_DIV, 8, s, /, "div:8");
                PZ_RUN_ARITHMETIC(PZT_DIV, 16, s, /, "div:16");
                PZ_RUN_ARITHMETIC(PZT_DIV, 32, s, /, "div:32");
                PZ_RUN_ARITHMETIC(PZT_DIV, 64, s, /, "div:64");
                PZ_RUN_ARITHMETIC(PZT_MOD, 8, s, %, "rem:8");
                PZ_RUN_ARITHMETIC(PZT_MOD, 16, s, %, "rem:16");
                PZ_RUN_ARITHMETIC(PZT_MOD, 32, s, %, "rem:32");
                PZ_RUN_ARITHMETIC(PZT_MOD, 64, s, %, "rem:64");
                PZ_RUN_ARITHMETIC(PZT_AND, 8, u, &, "and:8");
                PZ_RUN_ARITHMETIC(PZT_AND, 16, u, &, "and:16");
                PZ_RUN_ARITHMETIC(PZT_AND, 32, u, &, "and:32");
                PZ_RUN_ARITHMETIC(PZT_AND, 64, u, &, "and:64");
                PZ_RUN_ARITHMETIC(PZT_OR, 8, u, |, "or:8");
                PZ_RUN_ARITHMETIC(PZT_OR, 16, u, |, "or:16");
                PZ_RUN_ARITHMETIC(PZT_OR, 32, u, |, "or:32");
                PZ_RUN_ARITHMETIC(PZT_OR, 64, u, |, "or:64");
                PZ_RUN_ARITHMETIC(PZT_XOR, 8, u, ^, "xor:8");
                PZ_RUN_ARITHMETIC(PZT_XOR, 16, u, ^, "xor:16");
                PZ_RUN_ARITHMETIC(PZT_XOR, 32, u, ^, "xor:32");
                PZ_RUN_ARITHMETIC(PZT_XOR, 64, u, ^, "xor:64");
                PZ_RUN_ARITHMETIC(PZT_LT_U, 8, u, <, "ltu:8");
                PZ_RUN_ARITHMETIC(PZT_LT_U, 16, u, <, "ltu:16");
                PZ_RUN_ARITHMETIC(PZT_LT_U, 32, u, <, "ltu:32");
                PZ_RUN_ARITHMETIC(PZT_LT_U, 64, u, <, "ltu:64");
                PZ_RUN_ARITHMETIC(PZT_LT_S, 8, s, <, "lts:8");
                PZ_RUN_ARITHMETIC(PZT_LT_S, 16, s, <, "lts:16");
                PZ_RUN_ARITHMETIC(PZT_LT_S, 32, s, <, "lts:32");
                PZ_RUN_ARITHMETIC(PZT_LT_S, 64, s, <, "lts:64");
                PZ_RUN_ARITHMETIC(PZT_GT_U, 8, u, >, "gtu:8");
                PZ_RUN_ARITHMETIC(PZT_GT_U, 16, u, >, "gtu:16");
                PZ_RUN_ARITHMETIC(PZT_GT_U, 32, u, >, "gtu:32");
                PZ_RUN_ARITHMETIC(PZT_GT_U, 64, u, >, "gtu:64");
                PZ_RUN_ARITHMETIC(PZT_GT_S, 8, s, >, "gts:8");
                PZ_RUN_ARITHMETIC(PZT_GT_S, 16, s, >, "gts:16");
                PZ_RUN_ARITHMETIC(PZT_GT_S, 32, s, >, "gts:32");
                PZ_RUN_ARITHMETIC(PZT_GT_S, 64, s, >, "gts:64");
                PZ_RUN_ARITHMETIC(PZT_EQ, 8, s, ==, "eq:8");
                PZ_RUN_ARITHMETIC(PZT_EQ, 16, s, ==, "eq:16");
                PZ_RUN_ARITHMETIC(PZT_EQ, 32, s, ==, "eq:32");
                PZ_RUN_ARITHMETIC(PZT_EQ, 64, s, ==, "eq:64");
                PZ_RUN_ARITHMETIC1(PZT_NOT, 8, u, !, "not:8");
                PZ_RUN_ARITHMETIC1(PZT_NOT, 16, u, !, "not:16");
                PZ_RUN_ARITHMETIC1(PZT_NOT, 32, u, !, "not:16");
                PZ_RUN_ARITHMETIC1(PZT_NOT, 64, u, !, "not:16");

#undef PZ_RUN_ARITHMETIC
#undef PZ_RUN_ARITHMETIC1

#define PZ_RUN_SHIFT(opcode_base, width, operator, op_name)           \
    case opcode_base##_##width:                                       \
        stacks->expr_stack[stacks->esp - 1].u##width =                \
          (stacks->expr_stack[stacks->esp - 1].u##width operator      \
            stacks->expr_stack[stacks->esp].u8);                      \
        stacks->esp--;                                                \
        pz_trace_instr(stacks->rsp, op_name);                         \
        break

                PZ_RUN_SHIFT(PZT_LSHIFT, 8, <<, "lshift:8");
                PZ_RUN_SHIFT(PZT_LSHIFT, 16, <<, "lshift:16");
                PZ_RUN_SHIFT(PZT_LSHIFT, 32, <<, "lshift:32");
                PZ_RUN_SHIFT(PZT_LSHIFT, 64, <<, "lshift:64");
                PZ_RUN_SHIFT(PZT_RSHIFT, 8, >>, "rshift:8");
                PZ_RUN_SHIFT(PZT_RSHIFT, 16, >>, "rshift:16");
                PZ_RUN_SHIFT(PZT_RSHIFT, 32, >>, "rshift:32");
                PZ_RUN_SHIFT(PZT_RSHIFT, 64, >>, "rshift:64");

#undef PZ_RUN_SHIFT

            case PZT_DUP:
                stacks->esp++;
                stacks->expr_stack[stacks->esp] =
                    stacks->expr_stack[stacks->esp - 1];
                pz_trace_instr(stacks->rsp, "dup");
                break;
            case PZT_DROP:
                stacks->esp--;
                pz_trace_instr(stacks->rsp, "drop");
                break;
            case PZT_SWAP: {
                PZ_Stack_Value temp;
                temp = stacks->expr_stack[stacks->esp];
                stacks->expr_stack[stacks->esp] =
                    stacks->expr_stack[stacks->esp - 1];
                stacks->expr_stack[stacks->esp - 1] = temp;
                pz_trace_instr(stacks->rsp, "swap");
                break;
            }
            case PZT_ROLL: {
                uint8_t        depth = *ip;
                PZ_Stack_Value temp;
                ip++;
                switch (depth) {
                    case 0:
                        fprintf(stderr, "Illegal rot depth 0");
                        abort();
                    case 1:
                        break;
                    default:
                        /*
                         * subtract 1 as the 1st element on the stack is
                         * stacks->esp - 0, not stacks->esp - 1
                         */
                        depth--;
                        temp = stacks->expr_stack[stacks->esp - depth];
                        for (int i = depth; i > 0; i--) {
                            stacks->expr_stack[stacks->esp - i] =
                                stacks->expr_stack[stacks->esp - (i - 1)];
                        }
                        stacks->expr_stack[stacks->esp] = temp;
                }
                pz_trace_instr2(stacks->rsp, "roll", depth + 1);
                break;
            }
            case PZT_PICK: {
                /*
                 * As with PZT_ROLL we would subract 1 here, but we also
                 * have to add 1 because we increment the stack pointer
                 * before accessing the stack.
                 */
                uint8_t depth = *ip;
                ip++;
                stacks->esp++;
                stacks->expr_stack[stacks->esp] =
                    stacks->expr_stack[stacks->esp - depth];
                pz_trace_instr2(stacks->rsp, "pick", depth);
                break;
            }
            case PZT_CALL:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                stacks->return_stack[++stacks->rsp] = static_cast<uint8_t*>(env);
                stacks->return_stack[++stacks->rsp] = (ip + MACHINE_WORD_SIZE);
                ip = *(uint8_t **)ip;
                pz_trace_instr(stacks->rsp, "call");
                break;
            case PZT_TCALL:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                ip = *(uint8_t **)ip;
                pz_trace_instr(stacks->rsp, "tcall");
                break;
            case PZT_CALL_CLOSURE: {
                PZ_Closure *closure;

                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                stacks->return_stack[++stacks->rsp] = static_cast<uint8_t*>(env);
                stacks->return_stack[++stacks->rsp] = (ip + MACHINE_WORD_SIZE);
                closure = *(PZ_Closure **)ip;
                ip = static_cast<uint8_t*>(closure->code);
                env = closure->data;

                pz_trace_instr(stacks->rsp, "call_closure");
                break;
            }
            case PZT_CALL_IND: {
                PZ_Closure *closure;

                stacks->return_stack[++stacks->rsp] = static_cast<uint8_t*>(env);
                stacks->return_stack[++stacks->rsp] = ip;

                closure = (PZ_Closure *)stacks->expr_stack[stacks->esp--].ptr;
                ip = static_cast<uint8_t*>(closure->code);
                env = closure->data;

                pz_trace_instr(stacks->rsp, "call_ind");
                break;
            }
            case PZT_CJMP_8:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                if (stacks->expr_stack[stacks->esp--].u8) {
                    ip = *(uint8_t **)ip;
                    pz_trace_instr(stacks->rsp, "cjmp:8 taken");
                } else {
                    ip += MACHINE_WORD_SIZE;
                    pz_trace_instr(stacks->rsp, "cjmp:8 not taken");
                }
                break;
            case PZT_CJMP_16:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                if (stacks->expr_stack[stacks->esp--].u16) {
                    ip = *(uint8_t **)ip;
                    pz_trace_instr(stacks->rsp, "cjmp:16 taken");
                } else {
                    ip += MACHINE_WORD_SIZE;
                    pz_trace_instr(stacks->rsp, "cjmp:16 not taken");
                }
                break;
            case PZT_CJMP_32:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                if (stacks->expr_stack[stacks->esp--].u32) {
                    ip = *(uint8_t **)ip;
                    pz_trace_instr(stacks->rsp, "cjmp:32 taken");
                } else {
                    ip += MACHINE_WORD_SIZE;
                    pz_trace_instr(stacks->rsp, "cjmp:32 not taken");
                }
                break;
            case PZT_CJMP_64:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                if (stacks->expr_stack[stacks->esp--].u64) {
                    ip = *(uint8_t **)ip;
                    pz_trace_instr(stacks->rsp, "cjmp:64 taken");
                } else {
                    ip += MACHINE_WORD_SIZE;
                    pz_trace_instr(stacks->rsp, "cjmp:64 not taken");
                }
                break;
            case PZT_JMP:
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                ip = *(uint8_t **)ip;
                pz_trace_instr(stacks->rsp, "jmp");
                break;
            case PZT_RET:
                ip = stacks->return_stack[stacks->rsp--];
                env = stacks->return_stack[stacks->rsp--];
                pz_trace_instr(stacks->rsp, "ret");
                break;
            case PZT_ALLOC: {
                uintptr_t size;
                void     *addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                size = *(uintptr_t *)ip;
                ip += MACHINE_WORD_SIZE;
                // pz_gc_alloc uses size in machine words, round the value
                // up and convert it to words rather than bytes.
                addr = heap->alloc(
                        (size+MACHINE_WORD_SIZE-1) / MACHINE_WORD_SIZE,
                        trace_stacks, stacks);
                stacks->expr_stack[++stacks->esp].ptr = addr;
                pz_trace_instr(stacks->rsp, "alloc");
                break;
            }
            case PZT_MAKE_CLOSURE: {
                void       *code, *data;

                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                code = *(void**)ip;
                ip = (ip + MACHINE_WORD_SIZE);
                data = stacks->expr_stack[stacks->esp].ptr;
                PZ_Closure *closure = pz_alloc_closure(heap,
                        trace_stacks, stacks);
                pz_init_closure(closure, static_cast<uint8_t*>(code), data);
                stacks->expr_stack[stacks->esp].ptr = closure;
                pz_trace_instr(stacks->rsp, "make_closure");
                break;
            }
            case PZT_LOAD_8: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (ptr - * ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                stacks->expr_stack[stacks->esp + 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->expr_stack[stacks->esp].u8 = *(uint8_t *)addr;
                stacks->esp++;
                pz_trace_instr(stacks->rsp, "load_8");
                break;
            }
            case PZT_LOAD_16: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (ptr - * ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                stacks->expr_stack[stacks->esp + 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->expr_stack[stacks->esp].u16 = *(uint16_t *)addr;
                stacks->esp++;
                pz_trace_instr(stacks->rsp, "load_16");
                break;
            }
            case PZT_LOAD_32: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (ptr - * ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                stacks->expr_stack[stacks->esp + 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->expr_stack[stacks->esp].u32 = *(uint32_t *)addr;
                stacks->esp++;
                pz_trace_instr(stacks->rsp, "load_32");
                break;
            }
            case PZT_LOAD_64: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (ptr - * ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                stacks->expr_stack[stacks->esp + 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->expr_stack[stacks->esp].u64 = *(uint64_t *)addr;
                stacks->esp++;
                pz_trace_instr(stacks->rsp, "load_64");
                break;
            }
            case PZT_LOAD_PTR: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (ptr - ptr ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                stacks->expr_stack[stacks->esp + 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->expr_stack[stacks->esp].ptr = *(void **)addr;
                stacks->esp++;
                pz_trace_instr(stacks->rsp, "load_ptr");
                break;
            }
            case PZT_STORE_8: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (* ptr - ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                *(uint8_t *)addr = stacks->expr_stack[stacks->esp - 1].u8;
                stacks->expr_stack[stacks->esp - 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->esp--;
                pz_trace_instr(stacks->rsp, "store_8");
                break;
            }
            case PZT_STORE_16: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (* ptr - ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                *(uint16_t *)addr = stacks->expr_stack[stacks->esp - 1].u16;
                stacks->expr_stack[stacks->esp - 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->esp--;
                pz_trace_instr(stacks->rsp, "store_16");
                break;
            }
            case PZT_STORE_32: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (* ptr - ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                *(uint32_t *)addr = stacks->expr_stack[stacks->esp - 1].u32;
                stacks->expr_stack[stacks->esp - 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->esp--;
                pz_trace_instr(stacks->rsp, "store_32");
                break;
            }
            case PZT_STORE_64: {
                uint16_t offset;
                void *   addr;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, 2);
                offset = *(uint16_t *)ip;
                ip += 2;
                /* (* ptr - ptr) */
                addr = stacks->expr_stack[stacks->esp].ptr + offset;
                *(uint64_t *)addr = stacks->expr_stack[stacks->esp - 1].u64;
                stacks->expr_stack[stacks->esp - 1].ptr =
                    stacks->expr_stack[stacks->esp].ptr;
                stacks->esp--;
                pz_trace_instr(stacks->rsp, "store_64");
                break;
            }
            case PZT_GET_ENV: {
                stacks->expr_stack[++stacks->esp].ptr = env;
                pz_trace_instr(stacks->rsp, "get_env");
                break;
            }

            case PZT_END:
                retcode = stacks->expr_stack[stacks->esp].s32;
                if (stacks->esp != 1) {
                    fprintf(stderr, "Stack misaligned, esp: %d should be 1\n",
                            stacks->esp);
                    abort();
                }
                pz_trace_instr(stacks->rsp, "end");
                pz_trace_state(ip, stacks->rsp, stacks->esp,
                        (uint64_t *)stacks->expr_stack);
                return retcode;
            case PZT_CCALL: {
                pz::pz_builtin_c_func callee;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                callee = *(pz::pz_builtin_c_func *)ip;
                stacks->esp = callee(stacks->expr_stack, stacks->esp);
                ip += MACHINE_WORD_SIZE;
                pz_trace_instr(stacks->rsp, "ccall");
                break;
            }
            case PZT_CCALL_ALLOC: {
                pz::pz_builtin_c_alloc_func callee;
                ip = (uint8_t *)ALIGN_UP((uintptr_t)ip, MACHINE_WORD_SIZE);
                callee = *(pz::pz_builtin_c_alloc_func *)ip;
                stacks->esp = callee(stacks->expr_stack, stacks->esp, heap,
                        trace_stacks, stacks);
                ip += MACHINE_WORD_SIZE;
                pz_trace_instr(stacks->rsp, "ccall");
                break;
            }
#ifdef PZ_DEV
            case PZT_INVALID_TOKEN:
                fprintf(stderr, "Attempt to execute poisoned memory\n");
                abort();
#endif
            default:
                fprintf(stderr, "Unknown opcode\n");
                abort();
        }
        pz_trace_state(ip, stacks->rsp, stacks->esp,
                (uint64_t *)stacks->expr_stack);
    }
}

static void
trace_stacks(PZ_Heap_Mark_State *state, void *stacks_)
{
    PZ_Stacks *stacks = (PZ_Stacks*)stacks_;

    pz::pz_gc_mark_root_conservative(state, stacks->expr_stack,
            stacks->esp * sizeof(PZ_Stack_Value));
    pz::pz_gc_mark_root_conservative_interior(state, stacks->return_stack,
            stacks->rsp * MACHINE_WORD_SIZE);
}
