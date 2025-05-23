(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module CodeLocSet : Flow_set.S with type elt = string * Loc.t

type t

val empty : t

(* Raises if the given loc has `source` set to `None` *)
val add : Loc.t -> Suppression_comments.applicable_codes -> t -> t

val add_lint_suppressions : Loc_collections.LocSet.t -> t -> t

val remove : File_key.t -> t -> t

(* Union the two collections of suppressions. If they both contain suppressions for a given file,
 * include both sets of suppressions. *)
val union : t -> t -> t

(* Union the two collections of suppressions. If they both contain suppressions for a given file,
 * discard those included in the first argument. *)
val update_suppressions : t -> t -> t

val all_unused_locs : t -> Loc_collections.LocSet.t

val universally_suppressed_codes : t -> CodeLocSet.t

val filter_suppressed_errors :
  root:File_path.t ->
  file_options:Files.options option ->
  unsuppressable_error_codes:SSet.t ->
  loc_of_aloc:(ALoc.t -> Loc.t) ->
  t ->
  Flow_error.ErrorSet.t ->
  unused:t ->
  Flow_errors_utils.ConcreteLocPrintableErrorSet.t
  * (ALoc.t Flow_intermediate_error_types.intermediate_error * Loc_collections.LocSet.t) list
  * t

(* We use an PrintableErrorSet here (as opposed to a ConcretePrintableErrorSet) because this operation happens
   during merge rather than during collation as filter_suppressed_errors does *)
val filter_lints :
  t ->
  Flow_error.ErrorSet.t ->
  (* If needed, we will resolve abstract locations using these tables. Context.aloc_tables is most
   * likely the right thing to pass to this. *)
  ALoc.table Lazy.t Utils_js.FilenameMap.t ->
  include_suppressions:bool ->
  ExactCover.lint_severity_cover Utils_js.FilenameMap.t ->
  Flow_error.ErrorSet.t * Flow_error.ErrorSet.t * t

val get_lint_settings : 'a ExactCover.t Utils_js.FilenameMap.t -> Loc.t -> 'a option

val filter_by_file : Utils_js.FilenameSet.t -> t -> t
