%-----------------------------------------------------------------------%
% Plasma arity checking
% vim: ts=4 sw=4 et
%
% Copyright (C) 2017-2019 Plasma Team
% Distributed under the terms of the MIT see ../LICENSE.code
%
% Annotate each expression with its arity (the number of things it returns).
%
%-----------------------------------------------------------------------%
:- module core.arity_chk.
%-----------------------------------------------------------------------%
:- interface.

:- import_module result.
:- import_module compile_error.

%-----------------------------------------------------------------------%

:- pred arity_check(errors(compile_error)::out, core::in, core::out) is det.

%-----------------------------------------------------------------------%
%-----------------------------------------------------------------------%
:- implementation.

:- import_module cord.
:- import_module unit.

:- import_module core.util.

%-----------------------------------------------------------------------%

arity_check(Errors, !Core) :-
    process_noerror_funcs(compute_arity_func, Errors, !Core).

:- pred compute_arity_func(core::in, Unused::in, function::in,
    result(function, compile_error)::out) is det.

compute_arity_func(Core, _, Func0, Result) :-
    func_get_type_signature(Func0, _, _, DeclaredArity),
    ( if func_get_body(Func0, Varmap, Args, Captured, Expr0) then
        compute_arity_expr(Core, Expr0, Expr, ArityResult),
        ( ArityResult = ok(yes(Arity)),
            ( if Arity = DeclaredArity then
                func_set_body(Varmap, Args, Captured, Expr, Func0, Func),
                Result = ok(Func)
            else
                Result = return_error(func_get_context(Func0),
                    ce_arity_mismatch_func(DeclaredArity, Arity))
            )
        ; ArityResult = ok(no),
            func_set_body(Varmap, Args, Captured, Expr, Func0, Func),
            Result = ok(Func)
        ; ArityResult = errors(Errors),
            Result = errors(Errors)
        )
    else
        unexpected($file, $pred, "Imported function")
    ).

:- pred compute_arity_expr(core::in, expr::in, expr::out,
    result(maybe(arity), compile_error)::out) is det.

compute_arity_expr(Core, expr(ExprType0, CodeInfo0), expr(ExprType, CodeInfo),
        Result) :-
    ( ExprType0 = e_tuple(Exprs0),
        compute_arity_expr_tuple(Core, Exprs0, Exprs, CodeInfo0, CodeInfo,
            Result),
        ExprType = e_tuple(Exprs)
    ; ExprType0 = e_let(Vars, ExprLet0, ExprIn0),
        compute_arity_expr_let(Core, Vars, Result, ExprLet0, ExprLet,
            ExprIn0, ExprIn, CodeInfo0, CodeInfo),
        ExprType = e_let(Vars, ExprLet, ExprIn)
    ; ExprType0 = e_call(Callee, Args, MaybeResources),
        ExprType = e_call(Callee, Args, MaybeResources),
        compute_arity_expr_call(Core, Callee, Args, CodeInfo0, CodeInfo,
            Result)
    ; ExprType0 = e_match(Var, Cases0),
        compute_arity_expr_match(Core, Cases0, Cases, CodeInfo0, CodeInfo,
            Result),
        ExprType = e_match(Var, Cases)
    ;
        ( ExprType0 = e_var(_)
        ; ExprType0 = e_constant(_)
        ; ExprType0 = e_construction(_, _)
        ; ExprType0 = e_closure(_, _)
        ),
        Arity = arity(1),
        code_info_set_arity(Arity, CodeInfo0, CodeInfo),
        ExprType = ExprType0,
        Result = ok(yes(Arity))
    ).

:- pred compute_arity_expr_tuple(core::in, list(expr)::in, list(expr)::out,
    code_info::in, code_info::out, result(maybe(arity), compile_error)::out)
    is det.

compute_arity_expr_tuple(Core, !Exprs, !CodeInfo, Result) :-
    map2(compute_arity_expr_in_tuple(Core), !Exprs, TupleErrorss),
    Arity = arity(length(!.Exprs)),
    code_info_set_arity(Arity, !CodeInfo),

    TupleErrors = cord_list_to_cord(TupleErrorss),
    ( if is_empty(TupleErrors) then
        Result = ok(yes(Arity))
    else
        Result = errors(TupleErrors)
    ).

:- pred compute_arity_expr_in_tuple(core::in, expr::in, expr::out,
    errors(compile_error)::out) is det.

compute_arity_expr_in_tuple(Core, !Expr, Errors) :-
    compute_arity_expr(Core, !Expr, Result),
    ( Result = errors(Errors)
    ; Result = ok(MaybeArity),
        ( MaybeArity = yes(Arity),
            ( if Arity = arity(1) then
                Errors = init
            else
                Errors = error(code_info_get_context(!.Expr ^ e_info),
                    ce_arity_mismatch_tuple)
            )
        ; MaybeArity = no,
            push_arity_into_expr(arity(1), !Expr),
            Errors = init
        )
    ).

:- pred compute_arity_expr_let(core::in, list(T)::in,
    result(maybe(arity), compile_error)::out, expr::in, expr::out,
    expr::in, expr::out, code_info::in, code_info::out) is det.

compute_arity_expr_let(Core, Vars, Result, !ExprLet,
        !ExprIn, !CodeInfo) :-
    compute_arity_expr(Core, !ExprLet, LetRes),
    compute_arity_expr(Core, !ExprIn, InRes),
    VarsArity = arity(length(Vars)),
    ( LetRes = ok(MaybeLetArity),
        ( MaybeLetArity = yes(LetArity),
            ( if VarsArity = LetArity then
                Result0 = ok(unit)
            else
                Result0 = return_error(code_info_get_context(!.CodeInfo),
                    ce_arity_mismatch_expr(LetArity, VarsArity))
            )
        ; MaybeLetArity = no,
            push_arity_into_expr(VarsArity, !ExprLet),
            Result0 = ok(unit)
        ),
        ( InRes = ok(MaybeExprArity),
            ( Result0 = ok(_),
                ( MaybeExprArity = yes(ExprArity),
                    code_info_set_arity(ExprArity, !CodeInfo),
                    Result = ok(yes(ExprArity))
                ; MaybeExprArity = no,
                    Result = ok(no)
                )
            ; Result0 = errors(Errors),
                Result = errors(Errors)
            )
        ; InRes = errors(InErrors),
            ( Result0 = ok(_),
                Result = errors(InErrors)
            ; Result0 = errors(Errors),
                Result = errors(InErrors ++ Errors)
            )
        )
    ; LetRes = errors(LetErrors),
        ( InRes = ok(_),
            Result = errors(LetErrors)
        ; InRes = errors(InErrors),
            Result = errors(LetErrors ++ InErrors)
        )
    ).

:- pred compute_arity_expr_call(core::in, callee::in, list(T)::in,
    code_info::in, code_info::out, result(maybe(arity), compile_error)::out)
    is det.

compute_arity_expr_call(Core, Callee, Args, !CodeInfo, Result) :-
    ( Callee = c_plain(FuncId),
        core_get_function_det(Core, FuncId, CalleeFn),
        func_get_type_signature(CalleeFn, Inputs, _, Arity),
        length(Inputs, InputsLen),
        length(Args, ArgsLen),
        ( if InputsLen = ArgsLen then
            InputErrors = init
        else
            InputErrors = error(code_info_get_context(!.CodeInfo),
                ce_parameter_number(length(Inputs), length(Args)))
        ),
        code_info_set_arity(Arity, !CodeInfo),
        ( if is_empty(InputErrors) then
            Result = ok(yes(Arity))
        else
            Result = errors(InputErrors)
        )
    ; Callee = c_ho(_),
        Result = ok(no)
    ).

:- pred compute_arity_expr_match(core::in, list(expr_case)::in,
    list(expr_case)::out, code_info::in, code_info::out,
    result(maybe(arity), compile_error)::out) is det.

compute_arity_expr_match(Core, !Cases, !CodeInfo, Result) :-
    Context = code_info_get_context(!.CodeInfo),
    map2(compute_arity_case(Core), !Cases, CaseResults),
    Result0 = result_list_to_result(CaseResults),
    ( Result0 = ok(CaseArities),
        filter_map((pred(yes(A)::in, A::out) is semidet), CaseArities,
            KnownCaseArities),
        (
            KnownCaseArities = [],
            Result = ok(no)
        ;
            KnownCaseArities = [Arity | _],
            ( if all_same(KnownCaseArities) then
                code_info_set_arity(Arity, !CodeInfo),
                map(update_arity_case(Arity), !Cases),
                Result = ok(yes(Arity))
            else
                Result = return_error(Context,
                    ce_arity_mismatch_match(CaseArities))
            )
        )
    ; Result0 = errors(Errors),
        Result = errors(Errors)
    ).

:- pred compute_arity_case(core::in, expr_case::in, expr_case::out,
    result(maybe(arity), compile_error)::out) is det.

compute_arity_case(Core, e_case(Pat, Expr0), e_case(Pat, Expr), Result) :-
    compute_arity_expr(Core, Expr0, Expr, Result).

:- pred update_arity_case(arity::in, expr_case::in, expr_case::out) is det.

update_arity_case(Arity, e_case(Pat, Expr0), e_case(Pat, Expr)) :-
    CodeInfo0 = Expr0 ^ e_info,
    ( if code_info_get_arity(CodeInfo0, _Arity0) then
        Expr = Expr0
    else
        push_arity_into_expr(Arity, Expr0, Expr)
    ).

:- pred push_arity_into_expr(arity::in, expr::in, expr::out) is det.

push_arity_into_expr(Arity, !Expr) :-
    some [!CodeInfo] (
        !:CodeInfo = !.Expr ^ e_info,
        ( if not code_info_get_arity(!.CodeInfo, _) then
            code_info_set_arity(Arity, !CodeInfo),
            !Expr ^ e_info := !.CodeInfo,
            some [!EType] (
                !:EType = !.Expr ^ e_type,
                ( !.EType = e_let(Vars, Let, In0),
                    push_arity_into_expr(Arity, In0, In),
                    !:EType = e_let(Vars, Let, In)
                ; !.EType = e_call(_, _, _)
                ; !.EType = e_match(Var, Cases0),
                    Cases = map((func(e_case(Pat, E0)) = e_case(Pat, E) :-
                            push_arity_into_expr(Arity, E0, E)
                        ), Cases0),
                    !:EType = e_match(Var, Cases)
                ;
                    ( !.EType = e_tuple(_)
                    ; !.EType = e_var(_)
                    ; !.EType = e_constant(_)
                    ; !.EType = e_construction(_, _)
                    ; !.EType = e_closure(_, _)
                    ),
                    unexpected($file, $pred,
                        "This expression should already have an arity")
                ),
                !Expr ^ e_type := !.EType
            )
        else
            true
        )
    ).

%-----------------------------------------------------------------------%
%-----------------------------------------------------------------------%
