-- Spec 01: personal finances schema.
-- Amounts are whole COP pesos stored as bigint (no decimals, no float errors).
-- Every table is owned by a user and protected by row level security.

create table public.user_settings (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  reminder_hour smallint not null default 8 check (reminder_hour between 0 and 23),
  reminder_minute smallint not null default 0 check (reminder_minute between 0 and 59),
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  -- Lets child tables prove they point to a row of the same user.
  unique (id, user_id)
);

-- Pocket balances may be negative on purpose (user decision), so there is no
-- check constraint on balance.
create table public.pockets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  account_id uuid not null,
  name text not null check (length(trim(name)) > 0),
  balance bigint not null default 0,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  unique (account_id, name),
  foreign key (account_id, user_id) references public.accounts (id, user_id) on delete cascade
);

create table public.credit_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  entity text not null,
  name text not null,
  franchise text not null,
  last_four_digits text not null check (last_four_digits ~ '^[0-9]{4}$'),
  credit_limit bigint not null check (credit_limit >= 0),
  available_credit bigint not null check (available_credit >= 0 and available_credit <= credit_limit),
  currency text not null default 'COP' check (currency = 'COP'),
  cut_off_day smallint not null check (cut_off_day between 1 and 31),
  payment_due_day smallint not null check (payment_due_day between 1 and 31),
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create table public.recurring_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  amount bigint not null check (amount > 0),
  day_of_month smallint not null check (day_of_month between 1 and 31),
  start_date date not null,
  method_type text not null check (method_type in ('account_pocket', 'credit_card')),
  -- Pocket charged when paying from an account, or the category pocket when
  -- paying with a card.
  pocket_id uuid not null,
  card_id uuid,
  auto_deduct boolean not null default true,
  last_processed_date date,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  check ((method_type = 'credit_card') = (card_id is not null)),
  foreign key (pocket_id, user_id) references public.pockets (id, user_id),
  foreign key (card_id, user_id) references public.credit_cards (id, user_id) on delete cascade
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  occurred_on date not null,
  type text not null check (type in ('income', 'expense', 'card_charge', 'card_payment', 'pocket_transfer')),
  amount bigint not null check (amount > 0),
  pocket_id uuid,
  target_pocket_id uuid,
  card_id uuid,
  recurring_payment_id uuid,
  description text not null default '',
  created_at timestamptz not null default now(),
  check (
    case type
      when 'income' then pocket_id is not null and card_id is null and target_pocket_id is null
      when 'expense' then pocket_id is not null and card_id is null and target_pocket_id is null
      when 'card_charge' then pocket_id is not null and card_id is not null and target_pocket_id is null
      when 'card_payment' then pocket_id is not null and card_id is not null and target_pocket_id is null
      when 'pocket_transfer' then pocket_id is not null and target_pocket_id is not null and card_id is null
    end
  ),
  foreign key (pocket_id, user_id) references public.pockets (id, user_id),
  foreign key (target_pocket_id, user_id) references public.pockets (id, user_id),
  foreign key (card_id, user_id) references public.credit_cards (id, user_id),
  foreign key (recurring_payment_id, user_id) references public.recurring_payments (id, user_id) on delete set null (recurring_payment_id)
);

create index transactions_user_date_idx on public.transactions (user_id, occurred_on);

-- Aliases the NLP parser matches against ("rappi" -> a card, "graficolor" -> a pocket).
create table public.aliases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  alias text not null check (length(trim(alias)) > 0),
  account_id uuid,
  card_id uuid,
  pocket_id uuid,
  check (num_nonnulls(account_id, card_id, pocket_id) = 1),
  foreign key (account_id, user_id) references public.accounts (id, user_id) on delete cascade,
  foreign key (card_id, user_id) references public.credit_cards (id, user_id) on delete cascade,
  foreign key (pocket_id, user_id) references public.pockets (id, user_id) on delete cascade
);

-- Alerts are computed from due dates; only the ones already shown are stored.
create table public.alert_deliveries (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  alert_id text not null,
  delivered_at timestamptz not null default now(),
  primary key (user_id, alert_id)
);

-- Row level security: each user only sees and writes their own rows.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'user_settings', 'accounts', 'pockets', 'credit_cards',
    'recurring_payments', 'transactions', 'aliases', 'alert_deliveries'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'create policy %I on public.%I for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))',
      table_name || '_owner_policy', table_name
    );
  end loop;
end $$;
