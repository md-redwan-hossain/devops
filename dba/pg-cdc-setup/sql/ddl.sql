-- Apply by hand before starting audit_worker.
-- Table is excluded from sequin_pub and sequin.yaml (loop safety).

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid PRIMARY KEY,
    occurred_at timestamptz NOT NULL,
    schema_name varchar(70) NOT NULL,
    table_name varchar(70) NOT NULL,
    operation_type varchar(1) NOT NULL
        CHECK (operation_type IN ('i', 'u', 'd')),
    row_identity jsonb NOT NULL,
    row_changes jsonb,
    commit_lsn bigint NOT NULL,
    user_id varchar(70) NULL,
    UNIQUE (row_identity, commit_lsn)
);

CREATE INDEX IF NOT EXISTS audit_logs_occurred_at_idx
    ON public.audit_logs (occurred_at);
