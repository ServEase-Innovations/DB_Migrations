-- On-demand CRM escalation sets engagement_status = 'CRM_ESCALATED'.
-- Safe to re-run: drops and recreates engagements_engagement_status_check.

ALTER TABLE public.engagements
  DROP CONSTRAINT IF EXISTS engagements_engagement_status_check;

ALTER TABLE public.engagements
  ADD CONSTRAINT engagements_engagement_status_check
  CHECK (
    engagement_status IS NULL
    OR engagement_status::text = ANY (
      ARRAY[
        'CREATED'::text,
        'PAYMENT_PENDING'::text,
        'PAYMENT_FAILED'::text,
        'OPEN_FOR_ACCEPTANCE'::text,
        'CRM_ESCALATED'::text,
        'ASSIGNED'::text,
        'IN_PROGRESS'::text,
        'COMPLETED'::text,
        'CANCELLED'::text,
        'EXPIRED'::text,
        'UNASSIGNED'::text
      ]
    )
  );
