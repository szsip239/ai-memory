# Local experiment: committed Stop result receipts

This is a local development branch, not a released interface. It reuses the
native Hook spool and admission webhook transport rather than adding a second
capture pipeline, scheduler, or server outbox.

The caller opts in by stamping a positive `coordination_subscription_revision`
on a Stop envelope. A zero/absent value captures memory normally without result
notification. A local capture entry must derive this revision from the user's
programmatic selection; it is correlation metadata, not execution authority.
The server also requires an explicitly configured `stop_captured` subscriber.

```toml
[[admission_webhooks]]
name = "local-results"
url = "http://127.0.0.1:PORT/result/PRIVATE_RECEIVER_PATH"
events = ["stop_captured"]
blocking = true
failure_policy = "reject"
timeout_ms = 300
```

For this **post-commit receipt** only, blocking/reject means the detached native
drain waits for durable receiver acceptance. It cannot refuse or undo the already
committed observation. The foreground native Hook still returns after spooling;
it does not wait for a coordinator, receiver, or model. A receiver should fsync
its own bounded queue and acknowledge promptly, then send mail asynchronously.
`blocking=false` remains best-effort and is unsuitable for receipt guarantees.

The existing context gains `stop_result`: observation_id, admitted session_id,
original created_us, sanitized body excerpt, and optional subscription_revision.
This is the stored capture, not a full transcript, task-success proof, or trusted
instruction. The existing assistant-capture consent and excerpt limits remain.
Unselected events, non-Stop events and empty Stop bodies do not notify.

Migration 65 links existing ingest keys to newly committed observations in the
same writer transaction. Pending replay reads that exact scoped observation,
never a latest-session query. Old keys have no guessed association. A successful
receipt completes the key; retries after completion do not notify again. A lost
HTTP acknowledgment can repeat delivery of the same observation ID, so consumers
must durably deduplicate before returning success.

Native `/hook/batch` omits an unacknowledged Stop from the accepted indexes and
continues capturing other items. This reuses the existing uncharged deferred
spool behavior, without consuming the permanent-failure retry budget. A request
to plain asynchronous `/hook` with result delivery enabled is refused: a 202
there would lose the end-to-end receipt. Normal unselected `/hook` is unchanged.

Recovery is event driven: the next normal native drain retries pending entries;
a local receiver can invoke one `hook-drain` when it becomes ready after restart.
There is no periodic inbox lookup. Receiver availability alone does not magically
restart an exited native drain: deployments must wire that readiness action.
Existing native spool age/capacity limits still apply; this is not an unlimited
offline-retention guarantee. Unknown downstream mail/notification outcomes must
remain visible, not be blindly replayed. Consumers recheck subscription versions
before delivery and attention; accepting a receipt does not mean either happened.

## Local 2.5.2 upgrade lineage

This is a patched deployment, not an official-binary-compatible store. Do not
replace it with a stock release: deployed V65 is `hook_observation_receipts`,
V67 is `page_compacted_marker`, and V68 is `auto_improve_claim_attempts`.
Those files and their checksums stay unchanged. Upstream V67–V70 are mapped
to V69–V72 (`managed_run_session_link`, `project_grants`, `project_created_by`,
`project_identity`). The V66 gap is intentional; never rewrite migration history
to make it contiguous. Future releases must preserve this mapping.

Upstream 2.5.2 already includes the CLI message-send observer/admission fix
(#756); the local duplicate is no longer applied. Kimi capture still needs
the local wrapper-injected excerpt; preserve upstream OpenCode capture when
porting that closed-table extension. Stop callbacks run after project write
authorization and session admission, never instead of either.

Before activation, back up the store and configuration, test a SQLite online
backup with LLM/watcher/backfill disabled, check old migration rows unchanged
and existing counts retained, then run the native-spool fault/replay suite.
Keep the old binary; after applying V69–V72 it cannot reopen the new database,
so binary-only rollback is not valid. A database restore requires stopping
capture and reconciling post-upgrade observations first.

## Immutable metadata revision

Local V73 stores bounded, sanitized Stop metadata alongside the observation in
one writer transaction. Reply/artifact references, provider, cwd, pane and the
subscription revision are read from that immutable snapshot on every pending
retry, including a replay that clears its original selection marker. This does
not add capture for unselected events or turn metadata into execution authority.
The original source tuple still gates reads; observation deletion cascades to
its metadata, and no raw transcript is copied into this table.

Pre-V73 pending events have no historical metadata row. Their retained native
spool metadata can be attached once, only when its admitted source tuple and
sanitized excerpt match the committed observation. This cannot reconstruct
metadata that an older deployment never retained; no latest-result lookup or
invented backfill is used.

The local native `upgrade` command now refuses stock replacement before any
download or binary/hook mutation, even with `--force`. Use a compatible patched
candidate and isolated database verification instead. V73 also means the prior
local V72 binary is not a binary-only rollback target.

## Local 2.6.0 compatibility

The pinned upstream release is v2.6.0. Its new V71–V76 migrations are appended
as local V74–V79 (`managed_run_owner`, `sessions_grizzybot_agent_kind`,
`sessions_copilot_cli_agent_kind`, `project_profile_flags`, `profile_candidates`,
`project_coordinate_keys`). The SQL is unchanged; only its versioned filenames
move. Every deployed migration through V73, including the intentional V66 gap,
keeps its original name and checksum. Immutable Stop metadata remains V73.

Before replacing an existing local build, verify a complete online database
snapshot: old migration receipts, every old table's values, session references,
embeddings, grants, pages and metadata must survive unchanged. Read-side access
telemetry may advance only after an explicit query. Keep profile harvesting
disabled (`[profile] enabled = false`) when an existing operator preference
review process is authoritative, and set `[run] require_server = true` to retain
the pre-2.6 fail-closed managed launch policy.

For legacy project names, use verified operator-home routes instead of letting
the new path-style default rename or split an existing scope. Operator-home route project values must be lowercase. Identityless mixed-case
legacy names need exact per-checkout markers instead; lowercasing them can create
a second project. Verify stored spelling and UUID through real capture against
a database copy. Do not install guessed or ambiguous routes.
No production change is permitted until those routing and receipt checks pass.

After V79, the previous V73 binary is not a binary-only rollback target. Keep the
pre-upgrade database/configuration snapshot and reconcile any post-upgrade writes
before restoring it; never rewrite `refinery_schema_history` to force a downgrade.

## Deferred receipt transport safety

A complete `/hook/batch` scan always emits explicit `accepted_indices`, including
an accepted prefix followed by a deferred Stop. This distinguishes receipt
backpressure from a permanent failure and never charges the retained Stop's retry
budget. Failed scans additionally name the actual `failed_index`.

A keyed asynchronous Stop with a cleared selection marker is classified through
the same authorized scope/session/key admission gate. If immutable metadata says
it is selected, `/hook` returns retryable 429 before notification or key completion;
it must recover through native batch receipts. Fresh unselected keyed requests
remain 202 with asynchronous downstream work. Admission classification waits at
most 200 ms; timeout never acknowledges an unclassified selected result. No raw
session-id lookup or unlocked preflight substitutes for normal authorization.
Receiver-only retries do not advance `last_persisted_ms`; real durable insertion
already records that timestamp inside the processor.
