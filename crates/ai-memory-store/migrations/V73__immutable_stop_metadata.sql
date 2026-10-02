-- Freeze result references in the same transaction as the Stop observation.
-- Existing observations stay intact; legacy pending native spool entries may
-- attach their retained metadata once after matching the committed excerpt.
CREATE TABLE hook_stop_metadata (
    observation_id BLOB PRIMARY KEY REFERENCES observations(id) ON DELETE CASCADE,
    metadata_json TEXT NOT NULL
);
