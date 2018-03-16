(**
 * Copyright (c) 2015, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(*****************************************************************************)
(* Module building workers.
 * A worker is a subprocess executing an arbitrary function.
 * You should first create a fixed amount of workers and then use those
 * because the amount of workers is limited and to make the load-balancing
 * of tasks better (cf multiWorker.ml).
 *)
(*****************************************************************************)

type process_id = int
exception Worker_failed of (process_id * Unix.process_status)
(* Worker killed by Out Of Memory. *)
exception Worker_oomed
(** Raise this exception when sending work to a worker that is already busy.
 * We should never be doing that, and this is an assertion error. *)
exception Worker_busy

type send_job_failure =
  | Worker_already_exited of Unix.process_status
  | Other_send_job_failure of exn

exception Worker_failed_to_send_job of send_job_failure

(* The type of a worker visible to the outside world *)
type worker
(* An empty type *)
type void
(* Get the worker's id *)
val worker_id: worker -> int
(* Has the worker been killed *)
val is_killed: worker -> bool
(* Mark the worker as busy. Throw if it is already busy *)
val mark_busy: worker -> unit
(* Mark the worker as free *)
val mark_free: worker -> unit
(* If the worker isn't prespawned, spawn the worker *)
val spawn: worker -> (void, Worker.request) Daemon.handle
(* If the worker isn't prespawned, close the worker *)
val close: worker -> (void, Worker.request) Daemon.handle -> unit
(* If there is a call_wrapper, apply it and create the Request *)
val wrap_request: worker -> ('x -> 'b) -> 'x -> Worker.request

type call_wrapper = { wrap: 'x 'b. ('x -> 'b) -> 'x -> 'b }

(*****************************************************************************)
(* The handle is what we get back when we start a job. It's a "future"
 * (sometimes called a "promise"). The scheduler uses the handle to retrieve
 * the result of the job when the task is done (cf multiWorker.ml).
 *)
(*****************************************************************************)
type ('a, 'b) handle

type 'a entry
val register_entry_point:
  restore:('a -> unit) -> 'a entry

(* Creates a pool of workers. *)
val make:
  (** See docs in WorkerController.worker for call_wrapper. *)
  ?call_wrapper: call_wrapper ->
  saved_state : 'a ->
  entry       : 'a entry ->
  nbr_procs   : int ->
  gc_control  : Gc.control ->
  heap_handle : SharedMem.handle ->
    worker list

(* Call in a sub-process (CAREFUL, GLOBALS ARE COPIED) *)
val call: worker -> ('a -> 'b) -> 'a -> ('a, 'b) handle

(* Retrieves the job that the worker is currently processing *)
val get_job: ('a, 'b) handle -> 'a

(* Retrieves the result (once the worker is done) hangs otherwise *)
val get_result: ('a, 'b) handle -> 'b

(* Selects among multiple handles those which are ready. *)
type ('a, 'b) selected = {
  readys: ('a, 'b) handle list;
  waiters: ('a, 'b) handle list;
  (* Additional (non worker) ready fds that we selected on. *)
  ready_fds: Unix.file_descr list;
}
val select: ('a, 'b) handle list -> Unix.file_descr list -> ('a, 'b) selected

(* Returns the worker which produces this handle *)
val get_worker: ('a, 'b) handle -> worker

(* Killall the workers *)
val killall: unit -> unit

val cancel : ('a, 'b) handle list -> unit
