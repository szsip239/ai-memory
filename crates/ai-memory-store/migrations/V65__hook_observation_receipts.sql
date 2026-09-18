-- Reuse the existing ingest ledger for exact-result delivery on native spool
-- replay. Old keys intentionally have no guessed observation association.
ALTER TABLE ingest_keys ADD COLUMN observation_id BLOB REFERENCES observations(id) ON DELETE SET NULL;
