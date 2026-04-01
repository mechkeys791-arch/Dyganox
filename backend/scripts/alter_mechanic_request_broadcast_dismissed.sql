-- Optional: if JPA ddl-auto is not update, add column manually (PostgreSQL).
ALTER TABLE mechanic_requests ADD COLUMN IF NOT EXISTS broadcast_dismissed_mechanic_ids VARCHAR(2000);
