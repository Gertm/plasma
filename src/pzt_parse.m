%-----------------------------------------------------------------------%
% vim: ts=4 sw=4 et
%-----------------------------------------------------------------------%
:- module pzt_parse.
%
% Parse the PZ textual representation.
%
% Copyright (C) 2015 Paul Bone
% Distributed under the terms of the GPLv2 see ../LICENSE.tools
%
%-----------------------------------------------------------------------%

:- interface.

%-----------------------------------------------------------------------%

:- import_module io.
:- import_module string.

:- import_module asm_ast.
:- import_module asm_error.
:- import_module result.

:- pred parse(string::in, result(asm, asm_error)::out, io::di, io::uo) is det.

%-----------------------------------------------------------------------%
%-----------------------------------------------------------------------%

:- implementation.

:- import_module cord.
:- import_module list.
:- import_module map.
:- import_module maybe.
:- import_module require.

:- import_module context.
:- import_module lex_util.
:- import_module parsing.
:- import_module parsing.bnf.
:- import_module parsing.gen.
:- import_module pz.
:- import_module pz.code.
:- import_module lex.
:- import_module symtab.

%-----------------------------------------------------------------------%

parse(Filename, Result, !IO) :-
    parse_file(Filename, lexemes, ignore_tokens, pz_bnf, Result0, !IO),
    ( Result0 = ok(PZNode),
        ( PZNode = pzt(AST) ->
            Result = ok(AST)
        ;
            unexpected($file, $pred, "Wrong node type")
        )
    ; Result0 = errors(Errors),
        Result = errors(map(
            (func(error(C, E)) = error(C, e_read_src_error(E))), Errors))
    ).

%-----------------------------------------------------------------------%

:- type pzt_token == token(token_basic).

:- type token_basic
    --->    proc
    ;       block
    ;       data
    ;       array
    ;       ret
    ;       cjmp
    ;       w ; w8 ; w16 ; w32 ; w64 ; w_ptr ; ptr
    ;       open_curly
    ;       close_curly
    ;       open_paren
    ;       close_paren
    ;       dash
    ;       equals
    ;       semicolon
    ;       comma
    ;       period
    ;       identifier
    ;       number
    ;       comment
    ;       whitespace
    ;       eof.

:- func lexemes = list(lexeme(lex_token(token_basic))).

lexemes = [
        ("proc"             -> return_simple(proc)),
        ("block"            -> return_simple(block)),
        ("data"             -> return_simple(data)),
        ("array"            -> return_simple(array)),
        ("ret"              -> return_simple(ret)),
        ("cjmp"             -> return_simple(cjmp)),
        ("w"                -> return_simple(w)),
        ("w8"               -> return_simple(w8)),
        ("w16"              -> return_simple(w16)),
        ("w32"              -> return_simple(w32)),
        ("w64"              -> return_simple(w64)),
        ("w_ptr"            -> return_simple(w_ptr)),
        ("ptr"              -> return_simple(ptr)),
        ("{"                -> return_simple(open_curly)),
        ("}"                -> return_simple(close_curly)),
        ("("                -> return_simple(open_paren)),
        (")"                -> return_simple(close_paren)),
        ("-"                -> return_simple(dash)),
        ("="                -> return_simple(equals)),
        (","                -> return_simple(comma)),
        ("."                -> return_simple(period)),
        (";"                -> return_simple(semicolon)),
        (lex.identifier     -> return_string(identifier)),
        (?("-") ++ lex.nat  -> return_string(number)),
        ("//" ++ (*(anybut("\n")))
                            -> return_simple(comment)),
        (lex.whitespace     -> return_simple(whitespace))
    ].

:- pred ignore_tokens(lex_token(token_basic)::in) is semidet.

ignore_tokens(lex_token(whitespace, _)).
ignore_tokens(lex_token(comment, _)).

%-----------------------------------------------------------------------%
%-----------------------------------------------------------------------%

:- func pz_bnf = bnf(token_basic, non_terminal, pz_node).

pz_bnf = bnf(pzt, eof, [
        bnf_rule("plasma textual bytecode", pzt, [
            bnf_rhs([], const(pzt(asm([])))),
            bnf_rhs([nt(item), nt(pzt)],
                (func(Nodes) =
                    ( Nodes = [item(X), pzt(asm(Xs))] ->
                        pzt(asm([X | Xs]))
                    ;
                        unexpected($module, $pred, string(Nodes))
                    )))
            ]),
        bnf_rule("item", item, [
            bnf_rhs([nt(proc)], identity),
            bnf_rhs([nt(data)], identity)
        ]),

        bnf_rule("proc", proc, [
            bnf_rhs([t(proc), nt(qname), nt(proc_sig), nt(proc_body),
                    t(semicolon)],
                (func(Nodes) =
                    ( Nodes = [context(Context), symbol(Name), proc_sig(Sig),
                            nil, _] ->
                        item(asm_entry(Name, Context, asm_proc_decl(Sig)))
                    ; Nodes = [context(Context), symbol(Name),
                            proc_sig(Sig), blocks(Blocks), _] ->
                        item(asm_entry(Name, Context,
                            asm_proc(Sig, Blocks)))
                    ;
                        unexpected($module, $pred, string(Nodes))
                    )
                ))
            ]),
        bnf_rule("proc sig", proc_sig, [
            bnf_rhs([t(open_paren), nt(data_width_list), t(dash),
                    nt(data_width_list), t(close_paren)],
                (func(Nodes) =
                    ( if
                        Nodes = [_, data_width_list(Inputs), _,
                            data_width_list(Outputs), _]
                    then
                        proc_sig(pz_signature(Inputs, Outputs))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),
        bnf_rule("data width list", data_width_list, [
            bnf_rhs([],
                const(data_width_list([]))),
            bnf_rhs([nt(data_width), nt(data_width_list)],
                (func(Nodes) =
                    ( if
                        Nodes = [data_width(Width),
                            data_width_list(Widths)]
                    then
                        data_width_list([Width | Widths])
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),
        bnf_rule("proc body", proc_body, [
            bnf_rhs([],
                const(nil)),
            bnf_rhs([t(open_curly), nt(instrs_or_blocks), t(close_curly)],
                identity_nth(2))
            ]),
        bnf_rule("proc body", instrs_or_blocks, [
            bnf_rhs([nt(instrs)],
                (func(Nodes) =
                    ( if
                        Nodes = [instrs(Is)],
                        Is = [I | _],
                        I = pzt_instruction(_, Context)
                    then
                        blocks([pzt_block("_", Is, Context)])
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                )),
            bnf_rhs([nt(block), nt(blocks)],
                (func(Nodes) =
                    ( if Nodes = [block(B), blocks(Bs)] then
                        blocks([B | Bs])
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),
        bnf_rule("blocks", blocks, [
            bnf_rhs([],
                const(blocks([]))),
            bnf_rhs([nt(block), nt(blocks)],
                (func(Nodes) =
                    ( if Nodes = [block(B), blocks(Bs)] then
                        blocks([B | Bs])
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),
        bnf_rule("block", block, [
            bnf_rhs([t(block), t(identifier), t(open_curly), nt(instrs),
                    t(close_curly)],
                (func(Nodes) =
                    ( if
                        Nodes = [context(Context), string(Name, _), _,
                            instrs(Instrs), _]
                    then
                        block(pzt_block(Name, Instrs, Context))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),

        bnf_rule("instructions", instrs, [
            bnf_rhs([],
                const(instrs([]))),
            bnf_rhs([nt(instr), nt(instrs)],
                (func(Nodes) =
                    ( if Nodes = [instr(I), instrs(Is)] then
                        instrs([I | Is])
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),
        bnf_rule("instruction", instr, [
            bnf_rhs([t(identifier)],
                (func(Nodes) =
                    ( if Nodes = [string(S, C)] then
                        instr(pzt_instruction(pzti_word(symbol(S)), C))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                )),
            bnf_rhs([t(number)],
                (func(Nodes) =
                    ( if Nodes = [num(N, C)] then
                        instr(pzt_instruction(
                            pzti_load_immediate(N), C))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                )),
            bnf_rhs([t(ret)],
                (func(Nodes) =
                    ( if Nodes = [context(C)] then
                        instr(pzt_instruction(pzti_ret, C))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                )),
            bnf_rhs([t(cjmp), t(identifier)],
                (func(Nodes) =
                    ( if Nodes = [context(C), string(Dest, _)] then
                        instr(pzt_instruction(pzti_cjmp(Dest), C))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),

        bnf_rule("data", data, [
            bnf_rhs([t(data), t(identifier), t(equals), nt(data_type),
                    nt(data_value), t(semicolon)],
                (func(Nodes) =
                    ( if
                        Nodes = [context(Context), string(Name, _), _,
                            data_type(Type), data_value(Value), _]
                    then
                        item(asm_entry(symbol(Name), Context,
                            asm_data(Type, Value)))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
        ]),
        bnf_rule("data type", data_type, [
            bnf_rhs([t(array), t(open_paren), nt(data_width),
                    t(close_paren)],
                (func(Nodes) =
                    ( if Nodes = [_, _, data_width(Width), _] then
                        data_type(type_array(Width))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
        ]),
        bnf_rule("data value", data_value, [
            bnf_rhs([t(open_curly), nt(number_list), t(close_curly)],
                (func(Nodes) =
                    ( if Nodes = [_, num_list(List), _] then
                        data_value(pzv_sequence(List))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
        ]),
        bnf_rule("number list", number_list, [
            bnf_rhs([],
                const(num_list([]))),
            bnf_rhs([t(number), nt(number_list)],
                (func(Nodes) =
                    ( if Nodes = [num(X, _), num_list(Xs)] then
                        num_list([X | Xs])
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
        ]),

        bnf_rule("data width", data_width, [
            bnf_rhs([t(w)], const(data_width(w_fast))),
            bnf_rhs([t(w8)], const(data_width(w8))),
            bnf_rhs([t(w16)], const(data_width(w16))),
            bnf_rhs([t(w32)], const(data_width(w32))),
            bnf_rhs([t(w64)], const(data_width(w64))),
            bnf_rhs([t(w_ptr)], const(data_width(w_ptr))),
            bnf_rhs([t(ptr)], const(data_width(ptr)))
            ]),

        bnf_rule("qualified name", qname, [
            bnf_rhs([t(identifier), nt(qname_cont)],
                (func(Nodes) =
                    ( if Nodes = [string(Name1, _), string(Name2, _)] then
                        symbol(symbol(Name1, Name2))
                    else if Nodes = [string(Name, _), nil] then
                        symbol(symbol(Name))
                    else
                        unexpected($file, $pred, string(Nodes))
                    )
                ))
            ]),
        bnf_rule("qualified name", qname_cont, [
            bnf_rhs([],
                const(nil)),
            bnf_rhs([t(period), t(identifier)],
                identity_nth(2))
            ])
    ]).

:- type non_terminal
    --->    pzt
    ;       item
    ;       proc
    ;       proc_sig
    ;       proc_body
    ;       instrs_or_blocks
    ;       blocks
    ;       block
    ;       instrs
    ;       instr
    ;       data
    ;       data_type
    ;       data_value
    ;       data_width_list
    ;       data_width
    ;       qname
    ;       qname_cont
    ;       number_list.

:- type pz_node
    --->    pzt(asm)
    ;       item(asm_entry)
    ;       proc_sig(pz_signature)
    ;       blocks(list(pzt_block))
    ;       block(pzt_block)
    ;       instrs(list(pzt_instruction))
    ;       instr(pzt_instruction)
    ;       data_type(pz_data_type)
    ;       data_value(pz_data_value)
    ;       data_width_list(list(pz_data_width))
    ;       data_width(pz_data_width)
    ;       symbol(symbol)
    ;       context(context)
    ;       string(string, context)
    ;       num(int, context)
    ;       num_list(list(int))
    ;       nil.

:- instance token_to_result(token_basic, pz_node) where [
        token_to_result(Terminal, MaybeString, Context) =
            ( if
                ( Terminal = proc
                ; Terminal = data
                ; Terminal = block
                ; Terminal = ret
                ; Terminal = cjmp
                )
            then
                context(Context)
            else if
                Terminal = identifier,
                MaybeString = yes(String)
            then
                string(String, Context)
            else if
                Terminal = number,
                MaybeString = yes(String)
            then
                num(det_to_int(String), Context)
            else
                nil
            )
    ].

%-----------------------------------------------------------------------%

:- pred token_is_data_width(token_basic::in, pz_data_width::out) is semidet.

token_is_data_width(w,      w_fast).
token_is_data_width(w8,     w8).
token_is_data_width(w16,    w16).
token_is_data_width(w32,    w32).
token_is_data_width(w64,    w64).
token_is_data_width(w_ptr,  w_ptr).
token_is_data_width(ptr,    ptr).

%-----------------------------------------------------------------------%
%-----------------------------------------------------------------------%
