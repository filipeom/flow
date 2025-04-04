(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open Base.Result.Let_syntax
module FilenameSet = Utils_js.FilenameSet

let spf = Printf.sprintf

type error =
  | RecoverableShouldReinitNonLazily of {
      msg: string;
      updates: Utils_js.FilenameSet.t;
    }
  | Unrecoverable of {
      msg: string;
      exit_status: Exit.t;
    }

let is_incompatible_package_json ~options ~reader =
  (* WARNING! Be careful when adding new incompatibilities to this function. While dfind will
   * return any file which changes within the watched directories, watchman only watches for
   * specific extensions and files. Make sure to update the watchman_expression_terms in our
   * watchman file watcher! *)
  let is_incompatible filename_str =
    let filename = File_key.JsonFile filename_str in
    match Sys_utils.cat_or_failed filename_str with
    | None -> Module_js.Incompatible Module_js.Unknown (* Failed to read package.json *)
    | Some content ->
      let result = Parsing_service_js.parse_package_json_file ~options content filename in
      Module_js.package_incompatible ~reader filename result
  in
  fun ~want ~sroot ~file_options f ->
    if
      (String.starts_with ~prefix:sroot f || Files.is_included file_options f)
      && Filename.basename f = "package.json"
      && want f
    then
      is_incompatible f
    else
      Module_js.Compatible

let get_updated_flowconfig config_path =
  let (config, hash) = FlowConfig.get_with_hash ~allow_cache:false config_path in
  match config with
  | Ok (config, _warnings) -> Ok (config, hash)
  | Error _ ->
    Error
      (Unrecoverable
         { msg = "Config changed in an incompatible way"; exit_status = Exit.Flowconfig_changed }
      )

let assert_compatible_flowconfig_version =
  let not_satisfied version_constraint =
    not (Semver.satisfies ~include_prereleases:true version_constraint Flow_version.version)
  in
  fun config ->
    match FlowConfig.required_version config with
    | Some version_constraint when not_satisfied version_constraint ->
      let msg =
        spf
          "Wrong version of Flow. The config specifies version %s but this is version %s"
          version_constraint
          Flow_version.version
      in
      Error (Unrecoverable { msg; exit_status = Exit.Flowconfig_changed })
    | _ -> Ok ()

(** determines whether the flowconfig changed in a way that requires restarting

    this is currently very coarse: any textual change will invalidate it, even just
    a comment. but this does prevent restarting when the file is merely touched,
    which is a relatively common occurrence with source control or build scripts.

    the ideal solution is to process updates to the config incrementally.for
    example, adding a new ignore dir could be processed the same way deleting
    all of those files would be handled. *)
let assert_compatible_flowconfig_change ~options config_path =
  let old_hash = Options.flowconfig_hash options in
  let%bind (new_config, new_hash) = get_updated_flowconfig config_path in
  let new_hash = Xx.to_string new_hash in
  if String.equal old_hash new_hash then
    Ok ()
  else
    let () = Hh_logger.error "Flowconfig hash changed from %S to %S" old_hash new_hash in
    let%bind () = assert_compatible_flowconfig_version new_config in
    Error
      (Unrecoverable
         { msg = "Config changed in an incompatible way"; exit_status = Exit.Flowconfig_changed }
      )

(** Checks whether [updates] includes the flowconfig, and if so whether the change can
    be handled incrementally (returns [Ok ()]) or we need to restart (returns [Error]) *)
let check_for_flowconfig_change ~options ~skip_incompatible config_path updates =
  let config_changed = (not skip_incompatible) && SSet.mem config_path updates in
  if not config_changed then
    Ok ()
  else
    assert_compatible_flowconfig_change ~options config_path

let check_for_package_json_changes ~is_incompatible_package_json ~skip_incompatible updates =
  let incompatible_packages =
    updates
    |> SSet.elements
    |> Base.List.filter_map ~f:(fun file ->
           match is_incompatible_package_json file with
           | Module_js.Compatible -> None
           | Module_js.Incompatible reason -> Some (file, reason)
       )
  in
  if (not skip_incompatible) && incompatible_packages <> [] then
    let messages =
      incompatible_packages
      |> List.rev_map (fun (file, reason) ->
             spf
               "Modified package: %s (%s)"
               file
               (Module_js.string_of_package_incompatible_reason reason)
         )
      |> String.concat "\n"
    in
    Error
      (Unrecoverable
         {
           msg = spf "%s\nPackages changed in an incompatible way" messages;
           exit_status = Exit.Flowconfig_changed;
         }
      )
  else
    Ok ()

(** Check if the file's hash has changed *)
let did_content_change ~reader filename =
  let file = File_key.LibFile filename in
  match Sys_utils.cat_or_failed filename with
  | None -> true (* Failed to read lib file *)
  | Some content ->
    let reader = Abstract_state_reader.State_reader reader in
    not (Parsing_service_js.does_content_match_file_hash ~reader file content)

let check_for_lib_changes ~reader ~all_libs ~root ~skip_incompatible ~filter_wanted_updates updates
    =
  let flow_typed_path = File_path.to_string (Files.get_flowtyped_path root) in
  let is_changed_lib filename =
    let is_lib = SSet.mem filename all_libs || filename = flow_typed_path in
    is_lib && did_content_change ~reader filename
  in
  let libs = updates |> SSet.filter is_changed_lib in
  if (not skip_incompatible) && not (SSet.is_empty libs) then
    let messages =
      SSet.elements libs |> List.rev_map (spf "Modified lib file: %s") |> String.concat "\n"
    in
    let updates = filter_wanted_updates updates in
    Error
      (RecoverableShouldReinitNonLazily
         { msg = spf "%s\nLib files changed in an incompatible way" messages; updates }
      )
  else
    Ok ()

let filter_wanted_updates ~file_options ~sroot ~want updates =
  let is_flow_file = Files.is_flow_file ~options:file_options in
  SSet.fold
    (fun f acc ->
      if
        is_flow_file f
        (* note: is_included may be expensive. check in-root match first. *)
        && ((Files.implicitly_include_root file_options && String.starts_with ~prefix:sroot f)
           || Files.is_included file_options f
           )
        && (* removes excluded and lib files. the latter are already filtered *)
        want f
      then
        let filename =
          (* At this point, we already checked whether libdef files are touched.
           * If so, we already decided that the server should restart, and this
           * function won't be called. *)
          Files.filename_from_string
            ~options:file_options
            ~consider_libdefs:false
            ~all_unordered_libs:SSet.empty
            f
        in
        FilenameSet.add filename acc
      else
        acc)
    updates
    FilenameSet.empty

(* This function takes a set of filenames. We have been told that these files have changed. The
 * main job of this function is to tell
 *
 * 1. Do we care about this file? Maybe the file is ignored or has the wrong extension
 * 2. If we do care, are we unable to incrementally check this change. For example, maybe a libdef
 *    changed or the .flowconfig changed. Maybe one day we'll learn to incrementally check those
 *    changes, but for now we just need to exit and restart from scratch *)
let process_updates ?(skip_incompatible = false) ~options ~previous_all_unordered_libs updates =
  let reader = State_reader.create () in
  let file_options = Options.file_options options in
  let all_libs =
    let known_libs = previous_all_unordered_libs in
    let (_, maybe_new_libs) = Files.ordered_and_unordered_lib_paths file_options in
    SSet.union known_libs maybe_new_libs
  in
  let root = Options.root options in
  let config_path = Server_files_js.config_file (Options.flowconfig_name options) root in
  let sroot = File_path.to_string root ^ Filename.dir_sep in
  (* We can ignore libdef here, since we check below that whether we touched libdef files,
   * if so, we will restart anyways. *)
  let want = Files.wanted ~options:file_options ~include_libdef:false all_libs in
  let is_incompatible_package_json =
    is_incompatible_package_json ~options ~reader ~want ~sroot ~file_options
  in
  (* Die if the .flowconfig changed *)
  let%bind () = check_for_flowconfig_change ~options ~skip_incompatible config_path updates in
  (* Die if a package.json changed in an incompatible way *)
  let%bind () =
    check_for_package_json_changes ~is_incompatible_package_json ~skip_incompatible updates
  in
  let filter_wanted_updates = filter_wanted_updates ~file_options ~sroot ~want in
  (* Try to recover/die if libs files have changed *)
  let%bind () =
    check_for_lib_changes ~reader ~all_libs ~root ~skip_incompatible ~filter_wanted_updates updates
  in
  (* Return only the updates we care about *)
  Ok (filter_wanted_updates updates)
