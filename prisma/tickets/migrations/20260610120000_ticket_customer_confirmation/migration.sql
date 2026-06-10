-- Support ticket customer confirmation workflow: new statuses before CLOSED.

ALTER TABLE public.support_tickets
  DROP CONSTRAINT IF EXISTS support_tickets_status_check;

ALTER TABLE public.support_tickets
  ADD CONSTRAINT support_tickets_status_check CHECK (
    status IN (
      'OPEN',
      'IN_PROGRESS',
      'WAITING_CUSTOMER',
      'RESOLUTION_PROVIDED',
      'PENDING_CUSTOMER_CONFIRMATION',
      'REOPENED',
      'RESOLVED',
      'CLOSED',
      'CANCELLED'
    )
  );
