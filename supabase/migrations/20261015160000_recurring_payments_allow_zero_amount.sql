-- Allow amount = 0 for variable amount recurring payments / bills
ALTER TABLE public.recurring_payments 
  DROP CONSTRAINT IF EXISTS recurring_payments_amount_check;

ALTER TABLE public.recurring_payments 
  ADD CONSTRAINT recurring_payments_amount_check CHECK (amount >= 0);
