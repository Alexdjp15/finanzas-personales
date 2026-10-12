-- Atomic money operations. Each runs as the caller (security invoker), so row
-- level security still applies, and each updates balances and records the
-- transaction in one database transaction.

create or replace function public.record_pocket_movement(
  p_type text,
  p_pocket_id uuid,
  p_amount bigint,
  p_date date,
  p_description text default ''
) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if p_type not in ('income', 'expense') then
    raise exception 'invalid_type' using errcode = 'P0001';
  end if;
  if p_amount <= 0 then
    raise exception 'invalid_amount' using errcode = 'P0001';
  end if;

  -- Negative balances are allowed by design, so expenses are never blocked.
  update public.pockets
     set balance = balance + case when p_type = 'income' then p_amount else -p_amount end
   where id = p_pocket_id;
  if not found then
    raise exception 'pocket_not_found' using errcode = 'P0002';
  end if;

  insert into public.transactions (occurred_on, type, amount, pocket_id, description)
  values (p_date, p_type, p_amount, p_pocket_id, p_description)
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.record_card_charge(
  p_card_id uuid,
  p_pocket_id uuid,
  p_amount bigint,
  p_date date,
  p_description text default ''
) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'invalid_amount' using errcode = 'P0001';
  end if;

  -- A charge only consumes credit; the pocket is just the category.
  update public.credit_cards
     set available_credit = available_credit - p_amount
   where id = p_card_id and available_credit >= p_amount;
  if not found then
    raise exception 'insufficient_credit' using errcode = 'P0001';
  end if;

  insert into public.transactions (occurred_on, type, amount, pocket_id, card_id, description)
  values (p_date, 'card_charge', p_amount, p_pocket_id, p_card_id, p_description)
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.record_card_payment(
  p_card_id uuid,
  p_pocket_id uuid,
  p_amount bigint,
  p_date date,
  p_description text default ''
) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'invalid_amount' using errcode = 'P0001';
  end if;

  update public.credit_cards
     set available_credit = available_credit + p_amount
   where id = p_card_id and credit_limit - available_credit >= p_amount;
  if not found then
    raise exception 'payment_exceeds_debt' using errcode = 'P0001';
  end if;

  update public.pockets set balance = balance - p_amount where id = p_pocket_id;
  if not found then
    raise exception 'pocket_not_found' using errcode = 'P0002';
  end if;

  insert into public.transactions (occurred_on, type, amount, pocket_id, card_id, description)
  values (p_date, 'card_payment', p_amount, p_pocket_id, p_card_id, p_description)
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.transfer_between_pockets(
  p_from_pocket_id uuid,
  p_to_pocket_id uuid,
  p_amount bigint,
  p_date date,
  p_description text default ''
) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  from_account uuid;
  to_account uuid;
  new_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'invalid_amount' using errcode = 'P0001';
  end if;

  select account_id into from_account from public.pockets where id = p_from_pocket_id;
  select account_id into to_account from public.pockets where id = p_to_pocket_id;
  if from_account is null or to_account is null then
    raise exception 'pocket_not_found' using errcode = 'P0002';
  end if;
  if from_account <> to_account then
    raise exception 'pockets_in_different_accounts' using errcode = 'P0001';
  end if;

  update public.pockets set balance = balance - p_amount where id = p_from_pocket_id;
  update public.pockets set balance = balance + p_amount where id = p_to_pocket_id;

  insert into public.transactions (occurred_on, type, amount, pocket_id, target_pocket_id, description)
  values (p_date, 'pocket_transfer', p_amount, p_from_pocket_id, p_to_pocket_id, p_description)
  returning id into new_id;
  return new_id;
end $$;

-- Annual close: call only after the export has been saved by the client.
-- Pocket balances and card credit stay as the opening balances of the new year.
create or replace function public.delete_transactions_of_year(p_year int)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.transactions where extract(year from occurred_on) = p_year;
  get diagnostics deleted_count = row_count;
  return deleted_count;
end $$;

-- Mirrors the Dart rule: a payment set on day 31 is charged on the last day
-- of shorter months.
create or replace function public.clamped_date(p_year int, p_month int, p_day int)
returns date
language sql
immutable
set search_path = ''
as $$
  select least(
    make_date(p_year, p_month, 1) + (p_day - 1),
    (make_date(p_year, p_month, 1) + interval '1 month - 1 day')::date
  )
$$;

-- Server job: charges every automatic recurring payment that is due.
-- Idempotent through last_processed_date. A card without enough credit leaves
-- the payment pending instead of failing the whole run.
create or replace function public.process_due_recurring_payments(p_today date default current_date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment record;
  month_cursor date;
  due date;
  last_done date;
  processed integer := 0;
begin
  for payment in
    select * from public.recurring_payments where auto_deduct order by user_id, id
  loop
    last_done := payment.last_processed_date;
    month_cursor := date_trunc('month', payment.start_date)::date;
    loop
      due := public.clamped_date(
        extract(year from month_cursor)::int,
        extract(month from month_cursor)::int,
        payment.day_of_month
      );
      exit when due > p_today;

      if due >= payment.start_date and (last_done is null or due > last_done) then
        if payment.method_type = 'credit_card' then
          update public.credit_cards
             set available_credit = available_credit - payment.amount
           where id = payment.card_id and available_credit >= payment.amount;
          exit when not found;
          insert into public.transactions
            (user_id, occurred_on, type, amount, pocket_id, card_id, recurring_payment_id, description)
          values
            (payment.user_id, due, 'card_charge', payment.amount, payment.pocket_id, payment.card_id, payment.id, payment.name);
        else
          update public.pockets set balance = balance - payment.amount where id = payment.pocket_id;
          insert into public.transactions
            (user_id, occurred_on, type, amount, pocket_id, recurring_payment_id, description)
          values
            (payment.user_id, due, 'expense', payment.amount, payment.pocket_id, payment.id, payment.name);
        end if;

        update public.recurring_payments set last_processed_date = due where id = payment.id;
        last_done := due;
        processed := processed + 1;
      end if;

      month_cursor := (month_cursor + interval '1 month')::date;
    end loop;
  end loop;
  return processed;
end $$;

-- The server job must never be callable from the public API.
revoke execute on function public.process_due_recurring_payments(date) from public, anon, authenticated;
