-- Migration: Add account_number to accounts and retention cleanup function

ALTER TABLE public.accounts 
ADD COLUMN IF NOT EXISTS account_number TEXT NOT NULL DEFAULT '';

-- Retention cleanup function: deletes transactions older than 365 days / 1 year
CREATE OR REPLACE FUNCTION delete_transactions_older_than_one_year()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  WITH deleted AS (
    DELETE FROM public.transactions
    WHERE occurred_on < (CURRENT_DATE - INTERVAL '1 year')
    RETURNING id
  )
  SELECT count(*) INTO deleted_count FROM deleted;
  RETURN deleted_count;
END;
$$;
