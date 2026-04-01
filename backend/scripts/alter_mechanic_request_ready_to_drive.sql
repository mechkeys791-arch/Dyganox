-- Optional: if not using spring.jpa.hibernate.ddl-auto=update (PostgreSQL).
ALTER TABLE mechanic_requests ADD COLUMN IF NOT EXISTS mechanic_ready_to_drive BOOLEAN DEFAULT FALSE;
