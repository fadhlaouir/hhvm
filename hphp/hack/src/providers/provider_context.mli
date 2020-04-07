(**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the "hack" directory of this source tree.
 *
 *)

module PositionedSyntaxTree : sig
  include module type of
      Full_fidelity_syntax_tree.WithSyntax (Full_fidelity_positioned_syntax)
end

(** Various information associated with a given file.

It's important to create an [entry] when processing data about a single file for
two reasons:

  - To ensure that subsequent operations on the same file have a consistent view
    of the same file. That is, they won't read the file from disk twice and
    potentially introduce a race condition.
  - To ensure that subsequent operations on the same file don't recalculate the
    same data (such as an AST). This is important for performance, particularly
    for IDE operation latency.

To create a new entry for a file, use [Provider_context.add_entry].

There should generally be no more than one or two entries inside the
[Provider_context.t] at a given time. Be careful not to try to store every
single file's data in memory at once. Once you're done processing a file (e.g.
you have the TAST and don't need to access further data), then you should
discard the [entry] and the [Provider_context.t] that it came from.
*)
type entry = {
  path: Relative_path.t;
  contents: string;
  mutable source_text: Full_fidelity_source_text.t option;
      (** this source text, if present, came from the entry's path+contents *)
  mutable parser_return: Parser_return.t option;
      (** this parser_return, if present, came from source_text via Ast_provider.parse
    under ~full:true ~keep_errors:true *)
  mutable ast_errors: Errors.t option;  (** same invariant as parser_return *)
  mutable cst: PositionedSyntaxTree.t option;
  mutable tast: Tast.program option;
  mutable tast_errors: Errors.t option;
  mutable symbols: Relative_path.t SymbolOccurrence.t list option;
}

(** We often operate on collection of entries. *)
type entries = entry Relative_path.Map.t

(** A context allowing the caller access to data for files and symbols in the
codebase. In particular, this is used as a parameter to [Decl_provider]
functions to access the decl for a given symbol.

Depending on the [backend] setting, data may be cached in local memory, in
shared memory, out of process, etc.

You can examine an individual file in the codebase by constructing an [entry]
for it. For example, you can call [Provider_context.add_entry] to create a new
[entry], and then [Tast_provider.compute_tast_and_errors_unquarantined].

Some operations may make changes to global state (e.g. write to shared memory
heaps). To ensure that no changes escape the scope of your operation, use
[Provider_utils.respect_but_quarantine_unsaved_changes]. *)
type t

(** The empty context, for use at the top-level of stand-alone tools which don't
have a [ServerEnv.env].

If you have a [ServerEnv.env], you probably want to use
[Provider_utils.ctx_from_server_env] instead. *)
val empty_for_tool :
  popt:ParserOptions.t ->
  tcopt:TypecheckerOptions.t ->
  backend:Provider_backend.t ->
  t

(** The empty context, for use with Multiworker workers. This assumes that the
backend is shared memory. We don't want to serialize and send the entire
[ServerEnv.env] to these workers because a [ServerEnv.env] contains large data
objects (such as the forward naming table). *)
val empty_for_worker : popt:ParserOptions.t -> tcopt:TypecheckerOptions.t -> t

(** The empty context, for use in tests, where there may not be a
[ServerEnv.env] available. *)
val empty_for_test : popt:ParserOptions.t -> tcopt:TypecheckerOptions.t -> t

(** The empty context, for use in debugging aides in production code, where
there may not be a [ServerEnv.env] available. *)
val empty_for_debugging :
  popt:ParserOptions.t -> tcopt:TypecheckerOptions.t -> t

(** Creates an entry *)
val make_entry : path:Relative_path.t -> contents:string -> entry

(** Adds the entry into the supplied [Provider_context.t], overwriting
if the context already had an entry of the same path, and returns a new
[Provider_context.t] which includes that entry. 
Note: for most callers, [add_entry_if_missing] is more appropriate. *)
val add_or_overwrite_entry : ctx:t -> entry -> t

(** Similar to [add_or_overwrite_entry], but makes a new entry with contents. 
Also returns the new entry for convenience.  It's important that
callers use the resulting [Provider_context.t]. That way, if a
subsequent operation tries to access data about the same file, it will get
the [entry] we just added rather than reading from disk. *)
val add_or_overwrite_entry_contents :
  ctx:t -> path:Relative_path.t -> contents:string -> t * entry

(** Similar to [add_entry], but (1) returns the existing entry if one
was already there, (2) if one wasn't there, then adds a new entry
by reading the contents of the path from disk; may throw if those
contents can't be read. *)
val add_entry_if_missing : ctx:t -> path:Relative_path.t -> t * entry

(** Get the [ParserOptions.t] contained within the [t]. *)
val get_popt : t -> ParserOptions.t

(** Get the [TypecheckerOptions.t] contained within the [t]. *)
val get_tcopt : t -> TypecheckerOptions.t

(** Update the [TypecheckerOptions.t] contained within the [t]. *)
val map_tcopt : t -> f:(TypecheckerOptions.t -> TypecheckerOptions.t) -> t

(** Get the [Provider_backend.t] that backs this [t]. *)
val get_backend : t -> Provider_backend.t

(** Get the entries currently contained in this [t]. *)
val get_entries : t -> entries

(** Are we within [Provider_utils.respect_but_quarantine_unsaved_changes] ? *)
val is_quarantined : unit -> bool

(** Internal functions **)

(** Called by [Provider_utils.respect_but_quarantine_unsaved_changes] upon entry.
Don't call it directly yourself. *)
val set_is_quarantined_internal : unit -> unit

(** Called by [Provider_utils.respect_but_quarantine_unsaved_changes] upon exit.
Don't call it directly yourself. *)
val unset_is_quarantined_internal : unit -> unit

(** Telemetry for a provider_context includes the current cache state of its backend,
plus 'counters' like how many times cache has been read or evicted. *)
val get_telemetry : t -> Telemetry.t

(** This function resets the 'counters' associated with telemetry. *)
val reset_telemetry : t -> unit
