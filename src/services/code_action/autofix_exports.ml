(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module LocSet = Loc_collections.LocSet

let set_of_fixable_signature_verification_locations tolerable_errors =
  let open File_sig in
  let open Signature_error in
  let add_fixable_sig_ver_error acc = function
    | SignatureVerificationError
        ( ExpectedAnnotation (loc, _)
        | UnexpectedExpression (loc, _)
        | UnexpectedObjectKey (loc, _)
        | EmptyArray loc
        | EmptyObject loc
        | UnexpectedArraySpread (loc, _) ) ->
      LocSet.add loc acc
    | _ -> acc
  in
  List.fold_left add_fixable_sig_ver_error LocSet.empty tolerable_errors

let fix_signature_verification_error_at_loc
    ?remote_converter
    ~cx
    ~loc_of_aloc
    ~get_ast_from_shared_mem
    ~get_haste_module_info
    ~get_type_sig
    ~file_sig
    ~typed_ast =
  let open Insert_type in
  insert_type
    ~cx
    ~loc_of_aloc
    ~get_ast_from_shared_mem
    ~get_haste_module_info
    ~get_type_sig
    ~file_sig
    ~typed_ast
    ?remote_converter
    ~omit_targ_defaults:false
    ~strict:false
    ~ambiguity_strategy:Autofix_options.Generalize

let fix_signature_verification_errors
    ~file_key
    ~cx
    ~loc_of_aloc
    ~file_options
    ~get_ast_from_shared_mem
    ~get_haste_module_info
    ~get_type_sig
    ~file_sig
    ~typed_ast =
  let open Insert_type in
  let remote_converter =
    new Insert_type_imports.ImportsHelper.remote_converter
      ~loc_of_aloc
      ~file_options
      ~get_haste_module_info
      ~get_type_sig
      ~iteration:0
      ~file:file_key
      ~reserved_names:SSet.empty
  in
  let try_it loc (ast, it_errs) =
    try
      ( fix_signature_verification_error_at_loc
          ~remote_converter
          ~cx
          ~loc_of_aloc
          ~get_ast_from_shared_mem
          ~get_haste_module_info
          ~get_type_sig
          ~file_sig
          ~typed_ast
          ast
          loc,
        it_errs
      )
    with
    | FailedToInsertType err -> (ast, error_to_string err :: it_errs)
  in
  fun ast locs ->
    let ((loc, p), it_errors) = LocSet.fold try_it locs (ast, []) in
    let statements = add_imports remote_converter p.Flow_ast.Program.statements in
    let ast' = (loc, { p with Flow_ast.Program.statements }) in
    (ast', it_errors)
