%-----------------------------------------------------------------------%
% vim: ts=4 sw=4 et
%-----------------------------------------------------------------------%
:- module pz.bytecode.
%
% Common code for reading or writing PZ bytecode.
%
% Copyright (C) 2015 Paul Bone
% Distributed under the terms of the GPLv2 see ../LICENSE.tools
%
%-----------------------------------------------------------------------%

:- interface.

:- import_module int.
:- import_module string.

%-----------------------------------------------------------------------%

:- func pzf_magic = int.

:- func pzf_id_string = string.

:- func pzf_version = int.

%-----------------------------------------------------------------------%

% Constants for encoding option types.

:- func pzf_opt_entry_proc = int.

%-----------------------------------------------------------------------%

% Constants for encoding data types.

:- func pzf_data_basic = int.
:- func pzf_data_array = int.
:- func pzf_data_struct = int.

    % Encode the data width.
    %
:- pred pzf_data_width_int(pz_data_width::in, int::out) is det.

%-----------------------------------------------------------------------%

% Instruction encoding

:- pred instr_opcode(pz_instr, int).
:- mode instr_opcode(in, out) is det.

:- type immediate_value
    --->    no_immediate
    ;       immediate8(int)
    ;       immediate16(int)
    ;       immediate32(int)
    ;       immediate64(int).

:- pred instr_immediate(pz::in, pz_instr::in, immediate_value::out) is det.

%-----------------------------------------------------------------------%
%-----------------------------------------------------------------------%

:- implementation.

:- import_module list.

:- pragma foreign_decl("C",
"
#include ""pz_format.h""
#include ""pz_instructions.h""
").

%-----------------------------------------------------------------------%

:- pragma foreign_proc("C",
    pzf_magic = (Magic::out),
    [will_not_call_mercury, thread_safe, promise_pure],
    "
        Magic = PZ_MAGIC_NUMBER;
    ").

%-----------------------------------------------------------------------%

pzf_id_string =
    format("%s version %d", [s(id_string_part), i(pzf_version)]).

:- func id_string_part = string.

:- pragma foreign_proc("C",
    id_string_part = (X::out),
    [will_not_call_mercury, thread_safe, promise_pure],
    "
    /*
     * Cast away the const qualifier, Mercury won't modify this string
     * because it does not have a unique mode.
     */
    X = (char*)PZ_MAGIC_STRING_PART;
    ").

%-----------------------------------------------------------------------%

:- pragma foreign_proc("C",
    pzf_version = (X::out),
    [will_not_call_mercury, thread_safe, promise_pure],
    "X = PZ_FORMAT_VERSION;").

%-----------------------------------------------------------------------%

:- pragma foreign_proc("C",
    pzf_opt_entry_proc = (X::out),
    [will_not_call_mercury, thread_safe, promise_pure],
    "X = PZ_OPT_ENTRY_PROC;").

%-----------------------------------------------------------------------%

:- pragma foreign_proc("C",
    pzf_data_basic = (X::out),
    [will_not_call_mercury, thread_safe, promise_pure],
    "X = PZ_DATA_BASIC;").
:- pragma foreign_proc("C",
    pzf_data_array = (X::out),
    [will_not_call_mercury, thread_safe, promise_pure],
    "X = PZ_DATA_ARRAY;").
:- pragma foreign_proc("C",
    pzf_data_struct = (X::out),
    [will_not_call_mercury, thread_safe, promise_pure],
    "X = PZ_DATA_STRUCT;").

pzf_data_width_int(Width, BasicWidth \/ WidthTypeInt) :-
    basic_width(Width, BasicWidth),
    width_type(Width, WidthType),
    width_type_int(WidthType, WidthTypeInt).

:- pred basic_width(pz_data_width::in, int::out) is det.

basic_width(w8,       0x01).
basic_width(w16,      0x02).
basic_width(w32,      0x04).
basic_width(w64,      0x08).
basic_width(ptr,      0x00).
% for now, these values are always 32 bits wide.
basic_width(w_ptr,    0x04).
basic_width(w_fast,   0x04).

:- type width_type
    --->    word
    ;       pointer
    ;       word_pointer
    ;       word_fast.

:- pred width_type(pz_data_width::in, width_type::out) is det.

width_type(w8,      word).
width_type(w16,     word).
width_type(w32,     word).
width_type(w64,     word).
width_type(w_fast,  word_fast).
width_type(w_ptr,   word_pointer).
width_type(ptr,     pointer).

:- pred width_type_int(width_type::in, int::out) is det.

width_type_int(word,            width_type_normal).
width_type_int(pointer,         width_type_ptr).
width_type_int(word_fast,       width_type_fast).
width_type_int(word_pointer,    width_type_wptr).

:- func width_type_normal = int.
:- pragma foreign_proc("C",
    width_type_normal = (Num::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Num = PZ_DATA_WIDTH_TYPE_NORMAL;").

:- func width_type_ptr = int.
:- pragma foreign_proc("C",
    width_type_ptr = (Num::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Num = PZ_DATA_WIDTH_TYPE_PTR;").

:- func width_type_wptr = int.
:- pragma foreign_proc("C",
    width_type_wptr = (Num::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Num = PZ_DATA_WIDTH_TYPE_WPTR;").

:- func width_type_fast = int.
:- pragma foreign_proc("C",
    width_type_fast = (Num::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Num = PZ_DATA_WIDTH_TYPE_FAST;").

%-----------------------------------------------------------------------%

instr_opcode(pzi_load_immediate_8(_),  op_load_immediate_8).
instr_opcode(pzi_load_immediate_16(_), op_load_immediate_16).
instr_opcode(pzi_load_immediate_32(_), op_load_immediate_32).
instr_opcode(pzi_load_immediate_64(_), op_load_immediate_64).
instr_opcode(pzi_load_data_ref(_),     op_load_data_ref).
instr_opcode(pzi_add,                  op_add).
instr_opcode(pzi_sub,                  op_sub).
instr_opcode(pzi_mul,                  op_mul).
instr_opcode(pzi_div,                  op_div).
instr_opcode(pzi_dup,                  op_dup).
instr_opcode(pzi_swap,                 op_swap).
instr_opcode(pzi_call(_),              op_call).

:- func op_load_immediate_8 = int.
:- pragma foreign_proc("C",
    op_load_immediate_8 = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_LOAD_IMMEDIATE_8;").

:- func op_load_immediate_16 = int.
:- pragma foreign_proc("C",
    op_load_immediate_16 = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_LOAD_IMMEDIATE_16;").

:- func op_load_immediate_32 = int.
:- pragma foreign_proc("C",
    op_load_immediate_32 = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_LOAD_IMMEDIATE_32;").

:- func op_load_immediate_64 = int.
:- pragma foreign_proc("C",
    op_load_immediate_64 = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_LOAD_IMMEDIATE_64;").

:- func op_load_data_ref = int.
:- pragma foreign_proc("C",
    op_load_data_ref = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_LOAD_IMMEDIATE_DATA;").

:- func op_add = int.
:- pragma foreign_proc("C",
    op_add = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_ADD;").

:- func op_sub = int.
:- pragma foreign_proc("C",
    op_sub = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_SUB;").

:- func op_mul = int.
:- pragma foreign_proc("C",
    op_mul = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_MUL;").

:- func op_div = int.
:- pragma foreign_proc("C",
    op_div = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_DIV;").

:- func op_dup = int.
:- pragma foreign_proc("C",
    op_dup = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_DUP;").

:- func op_swap = int.
:- pragma foreign_proc("C",
    op_swap = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_SWAP;").

:- func op_call = int.
:- pragma foreign_proc("C",
    op_call = (Int::out),
    [will_not_call_mercury, promise_pure, thread_safe],
    "Int = PZI_CALL;").

instr_immediate(PZ, Instr, Imm) :-
    ( Instr = pzi_load_immediate_8(Int),
        Imm = immediate8(Int)
    ; Instr = pzi_load_immediate_16(Int),
        Imm = immediate16(Int)
    ; Instr = pzi_load_immediate_32(Int),
        Imm = immediate32(Int)
    ; Instr = pzi_load_immediate_64(Int),
        Imm = immediate64(Int)
    ; Instr = pzi_load_data_ref(DID),
        Imm = immediate32(DID ^ pzd_id_num)
    ; Instr = pzi_call(PID),
        Imm = immediate32(pzp_id_get_num(PZ, PID))
    ;
        ( Instr = pzi_add
        ; Instr = pzi_sub
        ; Instr = pzi_mul
        ; Instr = pzi_div
        ; Instr = pzi_dup
        ; Instr = pzi_swap
        ),
        Imm = no_immediate
    ).

%-----------------------------------------------------------------------%
%-----------------------------------------------------------------------%
