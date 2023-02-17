(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

val get_snippet : (Loc.t, Loc.t) Flow_ast.Program.t -> Loc.position -> string option
