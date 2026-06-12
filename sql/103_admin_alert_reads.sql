-- Persist admin dashboard alert read/dismiss state (support tickets, on-demand escalations).
CREATE TABLE IF NOT EXISTS public.admin_alert_reads (
    admin_user_id character varying(128) COLLATE pg_catalog."default" NOT NULL,
    alert_key character varying(255) COLLATE pg_catalog."default" NOT NULL,
    read_at timestamp(6) with time zone NOT NULL DEFAULT NOW(),
    CONSTRAINT admin_alert_reads_pkey PRIMARY KEY (admin_user_id, alert_key)
);

CREATE INDEX IF NOT EXISTS admin_alert_reads_admin_user_id_idx
    ON public.admin_alert_reads (admin_user_id, read_at DESC);
